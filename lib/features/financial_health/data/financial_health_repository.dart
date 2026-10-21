import '../../../core/network/api_client.dart';
import '../../../database/transaction_query.dart';
import '../../emergency_funds/data/emergency_fund_repository.dart';
import '../../goals/data/goals_repository.dart';
import '../../reports/data/financial_export_repository.dart';
import '../../sync/data/finance_repository.dart';

String healthDecimal(BigInt value) => financialDecimal(value);
BigInt? healthRatio(BigInt? numerator, BigInt? denominator) =>
    numerator == null || denominator == null || denominator <= BigInt.zero
    ? null
    : numerator * BigInt.from(10000) ~/ denominator;

class HealthAssessment {
  final DateTime start, end, assessedAt;
  final int months, incomeMonths, expenseMonths, transactionCount;
  final List<String> accountNames, warnings;
  final BigInt? income, expenses, debtService, debtPrincipal, freeCash;
  final BigInt? savingPercent, debtPercent, liquidityMonths, emergencyMonths;
  final EmergencyAssessment? emergency;
  const HealthAssessment({
    required this.start,
    required this.end,
    required this.assessedAt,
    required this.months,
    required this.incomeMonths,
    required this.expenseMonths,
    required this.transactionCount,
    required this.accountNames,
    required this.warnings,
    required this.income,
    required this.expenses,
    required this.debtService,
    required this.debtPrincipal,
    required this.freeCash,
    required this.savingPercent,
    required this.debtPercent,
    required this.liquidityMonths,
    required this.emergencyMonths,
    required this.emergency,
  });
}

class FinancialHealthRepository {
  final FinanceRepository source;
  late final EmergencyFundRepository emergency;
  GoalsRepository get goals => emergency.goals;
  FinancialHealthRepository(this.source) {
    // Reuse the existing initial-history bootstrap, including cross-device plans.
    emergency = EmergencyFundRepository(source);
  }

  List<Map<String, dynamic>> get accounts => goals.cashAccounts.where((a) {
    final type = source.row('account_types', '${a['account_type_id']}');
    return a['currency'] == 'IDR' && type?['user_id'] == source.userId;
  }).toList();

  Map<String, dynamic> get assumptions {
    final saved = source.state['financial_health_assumptions'];
    if (saved is Map &&
        saved['schema'] == 1 &&
        saved['user_id'] == source.userId) {
      return Map<String, dynamic>.from(saved);
    }
    return {
      'schema': 1,
      'user_id': source.userId,
      'months': 3,
      'include_dividends': false,
      'account_ids': accounts.map((a) => a['id']).toList(),
    };
  }

  void saveAssumptions({
    required int months,
    required bool includeDividends,
    required List<String> accountIds,
  }) {
    if (source.isSyncing) {
      throw const ApiFailure('Tunggu sinkronisasi selesai.');
    }
    if (![3, 6, 12].contains(months) ||
        accountIds.isEmpty ||
        accountIds.length != accountIds.toSet().length ||
        !accountIds.every((id) => accounts.any((a) => a['id'] == id))) {
      throw const ApiFailure(
        'Pilih periode dan minimal satu akun kas IDR milik sendiri.',
      );
    }
    source.atomic(() {
      source.state['financial_health_assumptions'] = {
        'schema': 1,
        'user_id': source.userId,
        'months': months,
        'include_dividends': includeDividends,
        'account_ids': accountIds,
      };
    });
  }

  bool _covered(String name) {
    final c = source.state[name];
    return c is Map &&
        c['schema'] == 1 &&
        c['user_id'] == source.userId &&
        c['complete'] == true &&
        c['cursor'] == source.state['cursor'];
  }

  HealthAssessment assess({DateTime? now}) {
    final at = (now ?? DateTime.now()).toUtc(), config = assumptions;
    final months = config['months'] as int;
    if (![3, 6, 12].contains(months)) {
      throw const ApiFailure('Periode tidak valid.');
    }
    final end = DateTime.utc(at.year, at.month, 1);
    final start = DateTime.utc(end.year, end.month - months, 1);
    final ids = (config['account_ids'] as List).cast<String>().toSet();
    final selected = accounts.where((a) => ids.contains(a['id'])).toList();
    final eligible = selected.map((a) => a['id']).toSet();
    final warnings = <String>[
      'Estimasi pribadi dari catatan lokal IDR. Snapshot tersinkron bukan bukti seluruh transaksi bank sudah dicatat.',
      'Saldo memakai kondisi sekarang; arus kas memakai bulan UTC yang sudah selesai. Akun historis yang kini dihapus, menjadi induk atau dipetakan ke utang tidak disertakan.',
    ];
    final scopeValid = selected.isNotEmpty && selected.length == ids.length;
    if (!scopeValid) {
      warnings.add(
        'Pilihan akun kosong atau tidak lagi memenuhi syarat. Tinjau asumsi sebelum menilai hasil.',
      );
    }
    if (source.outbox.isNotEmpty) {
      warnings.add(
        '${source.outbox.length} perubahan lokal belum selesai disinkronkan; hasil masih sementara, termasuk konflik/penolakan.',
      );
    }
    if (source.isSyncing) {
      warnings.add('Sinkronisasi berjalan; tunggu snapshot selesai.');
    }
    final debtReady = source.hasCompleteObligationHistory;
    final flowsReady =
        scopeValid &&
        source.hasTransactionSnapshot &&
        source.hasCompleteInvestmentHistory &&
        debtReady &&
        !source.isSyncing;
    if (!flowsReady) {
      warnings.add(
        'Perhitungan arus kas memerlukan snapshot transaksi, investasi dan utang yang lengkap pada perangkat.',
      );
    }
    var income = BigInt.zero,
        expenses = BigInt.zero,
        principal = BigInt.zero,
        service = BigInt.zero;
    var evidenceValid = true, count = 0;
    final incomeMonths = <String>{}, expenseMonths = <String>{};
    if (flowsReady) {
      final investmentRows = {
        for (final trade in source.rows('investment_transactions'))
          if (trade['linked_transaction_id'] != null)
            '${trade['linked_transaction_id']}': trade,
      };
      final ownDebtLedgerIds = {
        for (final e in source.rows('obligation_events'))
          if (e['user_id'] == source.userId && e['cash_principal_id'] != null)
            e['cash_principal_id'],
      };
      TransactionCursor? cursor;
      do {
        final page = source.transactionPage(
          TransactionQuery(start: start, end: end, after: cursor),
        );
        for (final t in page.rows) {
          if (!eligible.contains(t['account_id']) || t['deleted_at'] != null) {
            continue;
          }
          final kind = t['type'];
          if (kind == 'TRANSFER' &&
              t['is_obligation_settlement'] == true &&
              financialMinor('${t['amount']}') < BigInt.zero &&
              !ownDebtLedgerIds.contains(t['id'])) {
            evidenceValid = false;
          }
          if (kind == 'TRANSFER' ||
              kind == 'INVESTMENT_BUY' ||
              kind == 'INVESTMENT_SELL') {
            continue;
          }
          final trade = investmentRows[t['id']];
          if (trade == null &&
              (t['investment_transaction_id'] != null ||
                  t['category_id'] == null)) {
            evidenceValid = false;
            continue;
          }
          if (trade != null &&
              (trade['deleted_at'] != null ||
                  trade['type'] != 'DIVIDEND' ||
                  config['include_dividends'] != true)) {
            continue;
          }
          if (kind != 'INCOME' && kind != 'EXPENSE') {
            evidenceValid = false;
            continue;
          }
          final value = financialMinor('${t['amount']}');
          if (value < BigInt.zero) {
            evidenceValid = false;
            continue;
          }
          final month = DateTime.parse('${t['transacted_at']}')
              .toUtc()
              .toIso8601String()
              .substring(0, 7);
          if (kind == 'INCOME') {
            income += value;
            if (value > BigInt.zero) incomeMonths.add(month);
          } else {
            expenses += value;
            if (value > BigInt.zero) expenseMonths.add(month);
          }
          count++;
        }
        cursor = page.next;
      } while (cursor != null);
      for (final event in source.rows('obligation_events')) {
        if (event['user_id'] != source.userId ||
            event['operation'] != 'REPAY' ||
            event['deleted_at'] != null ||
            event['reversed_at'] != null ||
            !eligible.contains(event['cash_account_id'])) {
          continue;
        }
        final date = DateTime.parse('${event['transacted_at']}').toUtc();
        if (date.isBefore(start) || !date.isBefore(end)) continue;
        final debt = source.row('obligations', '${event['obligation_id']}');
        if (debt == null || debt['user_id'] != source.userId) {
          evidenceValid = false;
          continue;
        }
        if (debt['kind'] == 'RECEIVABLE') continue;
        if (debt['kind'] != 'PAYABLE') {
          evidenceValid = false;
          continue;
        }
        final p = goalMinor('${event['principal']}'),
            interest = goalMinor('${event['interest']}'),
            fee = goalMinor('${event['fee']}');
        for (final part in [
          ('cash_principal', p),
          ('interest', interest),
          ('fee', fee),
        ]) {
          if (part.$2 == BigInt.zero) continue;
          final row = source.row('transactions', '${event['${part.$1}_id']}');
          if (row == null ||
              row['deleted_at'] != null ||
              row['account_id'] != event['cash_account_id'] ||
              row['type'] !=
                  (part.$1 == 'cash_principal' ? 'TRANSFER' : 'EXPENSE') ||
              financialMinor('${row['amount']}') !=
                  (part.$1 == 'cash_principal' ? -part.$2 : part.$2)) {
            evidenceValid = false;
          }
        }
        principal += p;
        service += p + interest + fee;
      }
      warnings.add(
        'Pemasukan tercatat pada ${incomeMonths.length}/$months bulan; pengeluaran pada ${expenseMonths.length}/$months bulan. Bulan tanpa catatan tetap masuk pembagi rata-rata.',
      );
      if (incomeMonths.length < months || expenseMonths.length < months) {
        warnings.add(
          'Bukti bulanan terbatas; bulan kosong dapat berarti belum dicatat.',
        );
      }
    }
    if (!evidenceValid) {
      warnings.add(
        'Ada jenis transaksi atau bukti pelunasan yang tidak lengkap/tidak sesuai; indikator arus kas belum tersedia.',
      );
    }
    BigInt? cash;
    if (scopeValid &&
        debtReady &&
        _covered('goal_history_coverage') &&
        !source.isSyncing) {
      cash = selected.fold<BigInt>(
        BigInt.zero,
        (total, a) => total + goals.available('${a['id']}'),
      );
      if (selected.any(
        (a) => financialMinor('${a['balance']}') < BigInt.zero,
      )) {
        warnings.add(
          'Saldo akun negatif dihitung nol untuk kas tersedia; kekurangan saldo tidak dianggap dana likuid.',
        );
      }
    } else {
      warnings.add(
        'Kas bebas memerlukan pilihan akun valid serta snapshot utang dan alokasi goal lengkap.',
      );
    }
    EmergencyAssessment? emergencyResult;
    if (_covered('emergency_plan_coverage') &&
        _covered('goal_history_coverage') &&
        debtReady &&
        !source.isSyncing) {
      final plan = emergency.plan;
      if (plan != null) {
        emergencyResult = emergency.assess(plan, now: at);
        warnings.addAll(emergencyResult.warnings);
      } else {
        warnings.add('Atur rencana Dana Darurat untuk melihat cakupannya.');
      }
    } else {
      warnings.add(
        'Cakupan dana darurat menunggu snapshot rencana, goal dan utang lengkap.',
      );
    }
    final valid = flowsReady && evidenceValid;
    return HealthAssessment(
      start: start,
      end: end,
      assessedAt: at,
      months: months,
      incomeMonths: incomeMonths.length,
      expenseMonths: expenseMonths.length,
      transactionCount: count,
      accountNames: selected.map((a) => '${a['name']}').toList(),
      warnings: warnings,
      income: valid ? income : null,
      expenses: valid ? expenses : null,
      debtService: valid ? service : null,
      debtPrincipal: valid ? principal : null,
      freeCash: cash,
      savingPercent: valid ? healthRatio(income - expenses, income) : null,
      debtPercent: valid ? healthRatio(service, income) : null,
      liquidityMonths:
          valid && cash != null && expenses + principal > BigInt.zero
          ? cash * BigInt.from(months * 100) ~/ (expenses + principal)
          : null,
      emergencyMonths: emergencyResult?.accounts.isNotEmpty == true
          ? emergencyResult?.coverageHundredths
          : null,
      emergency: emergencyResult,
    );
  }
}
