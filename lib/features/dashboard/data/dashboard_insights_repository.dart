import '../../../core/utils/budget_period.dart';
import '../../../core/utils/app_time_zone.dart';
import '../../../core/network/api_client.dart';
import '../../../database/transaction_query.dart';
import '../../bills/data/bills_repository.dart';
import '../../goals/data/goals_repository.dart';
import '../../reports/data/financial_export_repository.dart';
import '../../sync/data/finance_repository.dart';
import '../models/dashboard_insights.dart';

/// Read-only summaries of the current owner's durable local data.
class DashboardInsightsRepository {
  final FinanceRepository source;
  const DashboardInsightsRepository(this.source);

  bool _covered(String key) {
    final coverage = source.state[key];
    return coverage is Map &&
        coverage['schema'] == 1 &&
        coverage['user_id'] == source.userId &&
        coverage['complete'] == true &&
        coverage['cursor'] == source.state['cursor'];
  }

  DashboardInsights read({
    DateTime? now,
    AppTimeZone timeZone = AppTimeZone.device,
  }) {
    if (source.isSyncing) return const DashboardInsights();
    final instant = (now ?? DateTime.now()).toUtc();
    SpendingInsight? spending;
    List<BudgetAttentionInsight>? budgets;
    if (source.hasTransactionSnapshot && source.hasCompleteInvestmentHistory) {
      try {
        final calendar = timeZone.at(instant);
        final currentMonth = DateTime.utc(calendar.year, calendar.month);
        final previousMonth = DateTime.utc(calendar.year, calendar.month - 1);
        final start = timeZone.fromCalendar(currentMonth);
        final previousStart = timeZone.fromCalendar(previousMonth);
        final previousDays = currentMonth.subtract(const Duration(days: 1)).day;
        final days = calendar.day < previousDays ? calendar.day : previousDays;
        // On a shorter prior month, compare the same completed calendar days.
        final currentEnd = days < calendar.day
            ? timeZone.fromCalendar(
                DateTime.utc(calendar.year, calendar.month, days + 1),
              )
            : instant.add(const Duration(microseconds: 1));
        final previousEnd = timeZone.fromCalendar(
          days < calendar.day
              ? DateTime.utc(previousMonth.year, previousMonth.month, days + 1)
              : DateTime.utc(
                  previousMonth.year,
                  previousMonth.month,
                  days,
                  calendar.hour,
                  calendar.minute,
                  calendar.second,
                  calendar.millisecond,
                  calendar.microsecond + 1,
                ),
        );
        final accounts = {
          for (final account in source.rows('accounts'))
            if (account['user_id'] == source.userId &&
                account['deleted_at'] == null &&
                account['currency'] == 'IDR')
              account['id'],
        };
        final investmentLedgerIds = {
          for (final trade in source.rows('investment_transactions'))
            if (trade['linked_transaction_id'] != null)
              trade['linked_transaction_id'],
        };
        final expenses = <Map<String, dynamic>>[];
        // Budgets retain their existing UTC calendar, independently of display.
        final budgetStart = DateTime.utc(instant.year, instant.month - 1);
        final queryStart = previousStart.isBefore(budgetStart)
            ? previousStart
            : budgetStart;
        TransactionCursor? cursor;
        do {
          final page = source.transactionPage(
            TransactionQuery(
              start: queryStart,
              end: instant.add(const Duration(microseconds: 1)),
              type: 'EXPENSE',
              after: cursor,
            ),
          );
          expenses.addAll(
            page.rows.where(
              (row) =>
                  accounts.contains(row['account_id']) &&
                  row['investment_transaction_id'] == null &&
                  !investmentLedgerIds.contains(row['id']),
            ),
          );
          cursor = page.next;
        } while (cursor != null);
        var current = BigInt.zero, previous = BigInt.zero;
        var previousEntries = false;
        for (final row in expenses) {
          final date = DateTime.parse(row['transacted_at'] as String).toUtc();
          final amount = financialMinor('${row['amount']}').abs();
          if (!date.isBefore(start) && date.isBefore(currentEnd)) {
            current += amount;
          }
          if (!date.isBefore(previousStart) && date.isBefore(previousEnd)) {
            previous += amount;
            previousEntries = true;
          }
        }
        spending = SpendingInsight(
          current: current,
          previous: previous,
          currentStart: currentMonth,
          previousStart: previousMonth,
          comparedDays: days,
          hasPreviousEntries: previousEntries,
        );
        budgets = _budgets(instant, expenses);
      } on ApiFailure {
        spending = null;
        budgets = null;
      } on FormatException {
        spending = null;
        budgets = null;
      }
    }
    UpcomingBillsInsight? bills;
    if (source.hasTransactionSnapshot && _covered('bill_history_coverage')) {
      try {
        bills = _bills(instant);
      } on ApiFailure {
        // Keep the other summaries available when schedule evidence is invalid.
      } on FormatException {
        // Never replace an invalid schedule with a fabricated zero total.
      }
    }
    return DashboardInsights(
      spending: spending,
      budgets: budgets,
      bills: bills,
      provisional: source.outbox.isNotEmpty,
    );
  }

  List<BudgetAttentionInsight> _budgets(
    DateTime now,
    List<Map<String, dynamic>> expenses,
  ) {
    final result = <BudgetAttentionInsight>[];
    for (final budget in source.rows('budgets')) {
      if (budget['deleted_at'] != null ||
          budget['period_type'] != 'MONTHLY' ||
          (budget['user_id'] != null && budget['user_id'] != source.userId)) {
        continue;
      }
      final category = source.row('categories', '${budget['category_id']}');
      if (category == null ||
          category['deleted_at'] != null ||
          category['user_id'] != source.userId ||
          category['type'] != 'EXPENSE') {
        continue;
      }
      final anchor = goalDate('${budget['anchor_date']}');
      var period = formatPeriodKey(now, 'MONTHLY');
      var range = budgetPeriodRange(anchor, 'MONTHLY', period);
      if (now.isBefore(range.start)) {
        period = formatPeriodKey(
          DateTime.utc(now.year, now.month - 1),
          'MONTHLY',
        );
        range = budgetPeriodRange(anchor, 'MONTHLY', period);
      }
      if (now.isBefore(anchor) || !range.contains(now)) continue;
      // Only this period's allowance may override the local budget. Cached
      // spending can be stale after an offline edit, so always read the ledger.
      final progress = source.state['progress:${budget['id']}:$period'];
      final allowance = financialMinor(
        '${budget['sync_status'] != 'pending' && progress is Map ? progress['allowance'] ?? budget['current_amount'] : budget['current_amount']}',
      );
      if (allowance <= BigInt.zero) continue;
      var spent = BigInt.zero;
      for (final row in expenses) {
        if (row['category_id'] == budget['category_id'] &&
            range.contains(DateTime.parse(row['transacted_at'] as String))) {
          spent += financialMinor('${row['amount']}').abs();
        }
      }
      if (spent * BigInt.from(100) >= allowance * BigInt.from(80)) {
        result.add(
          BudgetAttentionInsight(
            '${category['name']}',
            allowance,
            spent,
            isEstimated: progress is! Map || budget['sync_status'] == 'pending',
          ),
        );
      }
    }
    result.sort((a, b) {
      final ratio = (b.spent * a.allowance).compareTo(a.spent * b.allowance);
      return ratio != 0 ? ratio : a.name.compareTo(b.name);
    });
    return result;
  }

  UpcomingBillsInsight _bills(DateTime now) {
    final repository = BillsRepository(source, activate: false);
    final seen = <String, BillDueItem>{};
    var needsReview = false;
    for (final item in repository.occurrences(now: now, horizonDays: 6)) {
      if (item.overdue) continue;
      final bill = item.bill;
      if (bill['obligation_id'] != null) {
        final debt = source.row('obligations', '${bill['obligation_id']}');
        if (!_covered('obligation_history_coverage') || debt == null) {
          needsReview = true;
          continue;
        }
        if (debt['user_id'] != source.userId || debt['kind'] != 'PAYABLE') {
          continue;
        }
      } else if (bill['transaction_type'] != 'EXPENSE') {
        continue;
      }
      final account = source.row('accounts', '${bill['account_id']}');
      if (account?['user_id'] != source.userId ||
          account?['currency'] != 'IDR' ||
          account?['deleted_at'] != null) {
        needsReview = true;
        continue;
      }
      final key = bill['obligation_id'] != null
          ? '${bill['obligation_id']}:${item.date}'
          : item.id;
      final earlier = seen[key];
      if (earlier != null &&
          (earlier.amount != item.amount ||
              earlier.status != item.status ||
              earlier.bill['account_id'] != bill['account_id'])) {
        needsReview = true;
      }
      seen[key] = item;
      if (item.status == 'NEEDS_REVIEW') needsReview = true;
    }
    final open = seen.values.where((item) => item.status == 'PENDING').toList();
    return UpcomingBillsInsight(
      count: open.length,
      estimatedCount: open
          .where((item) => item.bill['amount_type'] == 'ESTIMATED')
          .length,
      total: open.fold(
        BigInt.zero,
        (sum, item) => sum + goalMinor(item.amount),
      ),
      nextTitle: open.firstOrNull?.bill['title'] as String?,
      needsReview: needsReview,
    );
  }
}
