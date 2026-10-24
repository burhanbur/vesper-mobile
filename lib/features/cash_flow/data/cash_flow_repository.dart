import '../../../core/network/api_client.dart';
import '../../settings/data/time_zone_preferences_repository.dart';
import '../../bills/data/bills_repository.dart';
import '../../goals/data/goals_repository.dart';
import '../../reports/data/financial_export_repository.dart';
import '../../sync/data/finance_repository.dart';

class ForecastEntry {
  final String id, accountId, title, dueDate, date, source;
  final BigInt amount;
  final bool income, overdue, assumption;
  const ForecastEntry(
    this.id,
    this.accountId,
    this.title,
    this.dueDate,
    this.date,
    this.source,
    this.amount,
    this.income,
    this.overdue,
    this.assumption,
  );
}

class ForecastDay {
  final String date;
  final BigInt opening, inflow, outflow, low, closing;
  const ForecastDay(
    this.date,
    this.opening,
    this.inflow,
    this.outflow,
    this.low,
    this.closing,
  );
}

class ForecastAccount {
  final String id, name;
  final BigInt actual, reserved;
  final List<ForecastDay> days;
  const ForecastAccount(
    this.id,
    this.name,
    this.actual,
    this.reserved,
    this.days,
  );
  BigInt get available => actual - reserved;
  ForecastDay? get firstShortfall =>
      days.where((d) => d.low < BigInt.zero).firstOrNull;
}

class CashFlowForecast {
  final DateTime assessedAt;
  final String start, end;
  final List<ForecastEntry> entries;
  final List<ForecastAccount> accounts;
  final List<ForecastDay> days;
  final List<String> warnings;
  final int paidExcluded, skippedExcluded;
  const CashFlowForecast(
    this.assessedAt,
    this.start,
    this.end,
    this.entries,
    this.accounts,
    this.days,
    this.warnings,
    this.paidExcluded,
    this.skippedExcluded,
  );
  BigInt get actual => accounts.fold(BigInt.zero, (v, a) => v + a.actual);
  BigInt get reserved => accounts.fold(BigInt.zero, (v, a) => v + a.reserved);
  BigInt get available => actual - reserved;
  BigInt get closing => days.last.closing;
  BigInt get minimum => days.map((d) => d.low).reduce((a, b) => a < b ? a : b);
  ForecastDay? get firstShortfall =>
      days.where((d) => d.low < BigInt.zero).firstOrNull;
}

class CashFlowRepository {
  final FinanceRepository source;
  late final BillsRepository bills;
  late final GoalsRepository goals;
  CashFlowRepository(this.source) {
    bills = BillsRepository(source);
    goals = GoalsRepository(source);
  }
  List<Map<String, dynamic>> get accounts => bills.accounts;
  List<Map<String, dynamic>> get debts => source
      .rows('obligations')
      .where(
        (d) =>
            d['user_id'] == source.userId &&
            d['deleted_at'] == null &&
            goalMinor('${d['outstanding']}') > BigInt.zero,
      )
      .toList();
  Map<String, dynamic> get assumptions {
    final saved = source.state['cash_flow_assumptions'];
    if (saved is Map &&
        saved['schema'] == 1 &&
        saved['user_id'] == source.userId) {
      return Map<String, dynamic>.from(saved);
    }
    return {
      'schema': 1,
      'user_id': source.userId,
      'days': 30,
      'utc_offset_minutes': switch (TimeZonePreferencesRepository(source)
          .selected
          .offsetMinutesAt(DateTime.now())) {
        420 => 420,
        480 => 480,
        540 => 540,
        _ => 0,
      },
      'include_estimates': true,
      'include_overdue': true,
      'include_receivables': false,
      'reserve_goals': true,
      'account_ids': accounts.map((a) => a['id']).toList(),
      'debt_accounts': <String, String>{},
    };
  }

  void saveAssumptions(Map<String, dynamic> values) {
    if (source.isSyncing) {
      throw const ApiFailure('Tunggu sinkronisasi selesai.');
    }
    final ids = (values['account_ids'] as List).cast<String>();
    final mappings = Map<String, String>.from(values['debt_accounts'] as Map);
    if (![7, 30, 60, 90].contains(values['days']) ||
        ![0, 420, 480, 540].contains(values['utc_offset_minutes']) ||
        ids.isEmpty ||
        ids.toSet().length != ids.length ||
        !ids.every((id) => accounts.any((a) => a['id'] == id)) ||
        [
          'include_estimates',
          'include_overdue',
          'include_receivables',
          'reserve_goals',
        ].any((k) => values[k] is! bool) ||
        mappings.entries.any(
          (e) =>
              !accounts.any((a) => a['id'] == e.value) ||
              !debts.any((d) => d['id'] == e.key),
        )) {
      throw const ApiFailure(
        'Periksa periode, zona waktu, akun kas dan pemetaan pinjaman.',
      );
    }
    source.atomic(() {
      source.state['cash_flow_assumptions'] = {
        ...values,
        'schema': 1,
        'user_id': source.userId,
      };
    });
  }

  bool _covered(String key) {
    final row = source.state[key];
    return row is Map &&
        row['schema'] == 1 &&
        row['user_id'] == source.userId &&
        row['complete'] == true &&
        row['cursor'] == source.state['cursor'];
  }

  CashFlowForecast forecast({DateTime? now}) {
    final config = assumptions, at = (now ?? DateTime.now()).toUtc();
    final offset = config['utc_offset_minutes'] as int,
        count = config['days'] as int;
    if (![7, 30, 60, 90].contains(count) ||
        ![0, 420, 480, 540].contains(offset)) {
      throw const ApiFailure('Asumsi periode tidak valid.');
    }
    if (source.isSyncing ||
        !source.hasTransactionSnapshot ||
        !source.hasCompleteObligationHistory ||
        !_covered('bill_history_coverage') ||
        (config['reserve_goals'] == true &&
            !_covered('goal_history_coverage'))) {
      throw const ApiFailure(
        'Selesaikan sinkronisasi transaksi, tagihan, utang dan alokasi goal sebelum membuat proyeksi.',
      );
    }
    final ids = (config['account_ids'] as List).cast<String>().toSet();
    final selected = accounts.where((a) => ids.contains(a['id'])).toList();
    if (selected.isEmpty || selected.length != ids.length) {
      throw const ApiFailure(
        'Pilih ulang akun kas IDR milik sendiri yang masih aktif.',
      );
    }
    final start = goalDate(goalDay(at.add(Duration(minutes: offset)))),
        end = start.add(Duration(days: count));
    final warnings = <String>[
      'Skenario dari saldo lokal saat ini, bukan jaminan saldo bank atau prediksi semua pengeluaran. Transaksi aktual sudah tercermin dalam saldo pembuka.',
      'Hari diproyeksikan dengan pengeluaran sebelum pemasukan pada hari yang sama; minimum harian adalah skenario konservatif tanpa waktu pembayaran pasti.',
      'Tidak ada transfer otomatis antar akun. Saldo gabungan positif dapat tetap menyembunyikan kekurangan pada satu akun.',
    ];
    if (source.outbox.isNotEmpty) {
      warnings.add(
        '${source.outbox.length} perubahan lokal belum selesai tersinkron; hasil termasuk perubahan sementara/konflik.',
      );
    }
    if (source.offline) {
      warnings.add(
        'Offline: snapshot lokal dapat tertinggal dari perubahan perangkat lain.',
      );
    }
    final entries = <ForecastEntry>[];
    var paidExcluded = 0, skippedExcluded = 0;
    String? projectedDate(String due) {
      final date = goalDate(due);
      if (!date.isBefore(end)) return null;
      if (date.isBefore(start)) {
        return config['include_overdue'] == true ? goalDay(start) : null;
      }
      return due;
    }

    String billDate(Map<String, dynamic> bill, String due) => goalDay(
      goalDate(due)
          .subtract(Duration(minutes: bill['utc_offset_minutes'] as int))
          .add(Duration(minutes: offset)),
    );
    void append(
      String id,
      String account,
      String title,
      String due,
      String kind,
      BigInt amount,
      bool income,
      bool assumed,
    ) {
      final day = projectedDate(due);
      if (day == null || !ids.contains(account) || amount <= BigInt.zero) {
        return;
      }
      entries.add(
        ForecastEntry(
          id,
          account,
          title,
          due,
          day,
          kind,
          amount,
          income,
          goalDate(due).isBefore(start),
          assumed,
        ),
      );
      if (entries.length > 10000) {
        throw const ApiFailure(
          'Terlalu banyak komitmen untuk proyeksi; arsipkan jadwal lama atau kecualikan tunggakan.',
        );
      }
    }

    final occurrences = bills.occurrences(
      now: at,
      older: config['include_overdue'] == true,
      horizonDays: count + 2,
    );
    for (final o in occurrences.where(
      (o) =>
          o.bill['obligation_id'] == null && ids.contains(o.bill['account_id']),
    )) {
      final due = billDate(o.bill, o.date);
      if (projectedDate(due) == null) continue;
      if (o.status == 'PAID') {
        paidExcluded++;
        continue;
      }
      if (o.status == 'SKIPPED') {
        skippedExcluded++;
        continue;
      }
      if (o.status != 'PENDING') {
        throw const ApiFailure(
          'Ada pembayaran perlu ditinjau. Selesaikan NEEDS_REVIEW di Tagihan & Jadwal sebelum memproyeksikan ulang.',
        );
      }
      final estimated = o.bill['amount_type'] == 'ESTIMATED';
      if (estimated && config['include_estimates'] != true) continue;
      append(
        o.id,
        '${o.bill['account_id']}',
        '${o.bill['title']}',
        due,
        estimated ? 'Perkiraan tagihan' : 'Tagihan tetap',
        goalMinor(o.amount),
        o.bill['transaction_type'] == 'INCOME',
        estimated,
      );
    }
    final allBills = {
      for (final b in source.rows('bill_schedules'))
        if (b['user_id'] == source.userId) b['id']: b,
    };
    final mappings = Map<String, String>.from(config['debt_accounts'] as Map);
    if (mappings.entries.any(
      (e) =>
          debts.any((d) => d['id'] == e.key) &&
          !accounts.any((a) => a['id'] == e.value),
    )) {
      throw const ApiFailure(
        'Pemetaan pinjaman memakai akun yang tidak lagi tersedia. Tinjau asumsi.',
      );
    }
    for (final debt in debts) {
      final receivable = debt['kind'] == 'RECEIVABLE';
      if (receivable && config['include_receivables'] != true) {
        warnings.add(
          'Piutang ${debt['counterparty']} tidak diasumsikan masuk.',
        );
        continue;
      }
      final installments = (debt['installments'] as List? ?? const [])
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
      if (installments.isEmpty && debt['due_date'] != null) {
        installments.add({
          'due_date': debt['due_date'],
          'principal': debt['principal'],
        });
      }
      if (installments.isEmpty) {
        warnings.add(
          'Pinjaman ${debt['counterparty']} belum punya tanggal/cicilan; saldo terutangnya tidak masuk timeline.',
        );
        continue;
      }
      installments.sort(
        (a, b) => '${a['due_date']}'.compareTo('${b['due_date']}'),
      );
      final remaining = <String, BigInt>{};
      var scheduled = BigInt.zero;
      for (final row in installments) {
        final date = '${row['due_date']}';
        goalDate(date);
        final amount = goalMinor('${row['principal']}');
        if (remaining.containsKey(date) || amount <= BigInt.zero) {
          throw const ApiFailure('Jadwal cicilan tidak valid.');
        }
        remaining[date] = amount;
        scheduled += amount;
      }
      final principal = goalMinor('${debt['principal']}'),
          outstanding = goalMinor('${debt['outstanding']}');
      if (scheduled != principal || outstanding > principal) {
        throw const ApiFailure('Pokok dan jadwal pinjaman tidak selaras.');
      }
      var unallocated = principal - outstanding;
      final eventAllocations = <String, BigInt>{};
      for (final record in bills.records) {
        final bill = allBills[record['bill_id']];
        final event = source.row(
          'obligation_events',
          '${record['obligation_event_id']}',
        );
        if (bill?['obligation_id'] != debt['id'] &&
            event?['obligation_id'] != debt['id']) {
          continue;
        }
        if (!['PAID', 'NEEDS_REVIEW'].contains(record['status'])) continue;
        if (record['status'] == 'NEEDS_REVIEW' ||
            bill == null ||
            bills.status(record, bill) != 'PAID' ||
            event?['user_id'] != source.userId) {
          throw const ApiFailure(
            'Bukti pembayaran cicilan perlu ditinjau di Tagihan & Jadwal.',
          );
        }
        final date = '${record['due_date']}',
            amount = goalMinor('${record['amount']}');
        if (!remaining.containsKey(date) || remaining[date]! < amount) {
          throw const ApiFailure(
            'Alokasi tanggal cicilan bertumpuk/tidak sesuai. Tinjau tagihan pinjaman.',
          );
        }
        final eventId = '${event!['id']}';
        eventAllocations[eventId] =
            (eventAllocations[eventId] ?? BigInt.zero) + amount;
        if (eventAllocations[eventId]! > goalMinor('${event['principal']}')) {
          throw const ApiFailure(
            'Bukti pokok cicilan dipakai melebihi pembayarannya.',
          );
        }
        remaining[date] = remaining[date]! - amount;
        unallocated -= amount;
      }
      if (unallocated < BigInt.zero) {
        throw const ApiFailure(
          'Bukti pembayaran melebihi pokok yang telah lunas.',
        );
      }
      for (final date in remaining.keys) {
        final applied = remaining[date]! < unallocated
            ? remaining[date]!
            : unallocated;
        remaining[date] = remaining[date]! - applied;
        unallocated -= applied;
      }
      var added = false;
      for (final row in remaining.entries) {
        final active = bills.schedules
            .where(
              (b) =>
                  b['active'] == true &&
                  b['obligation_id'] == debt['id'] &&
                  billDue(b, row.key) != null,
            )
            .toList();
        final due = active.isEmpty ? row.key : billDate(active.first, row.key);
        if (projectedDate(due) == null) continue;
        final states = active
            .map(
              (b) => bills.status(
                source.row(
                  'bill_occurrences',
                  billOccurrenceId('${b['id']}', row.key),
                ),
                b,
              ),
            )
            .toSet();
        if (row.value == BigInt.zero) {
          paidExcluded++;
          continue;
        }
        if (states.contains('NEEDS_REVIEW')) {
          throw const ApiFailure('Pembayaran cicilan perlu ditinjau.');
        }
        if (states.contains('SKIPPED')) {
          if (states.contains('PENDING') || states.contains('PAID')) {
            throw const ApiFailure(
              'Jadwal cicilan ganda memiliki status berbeda; arsipkan duplikatnya.',
            );
          }
          skippedExcluded++;
          warnings.add(
            'Cicilan ${debt['counterparty']} ${row.key} dilewati; pokok utang tetap ada.',
          );
          continue;
        }
        final accountsForDate = active.map((b) => '${b['account_id']}').toSet();
        if (accountsForDate.length > 1) {
          throw const ApiFailure(
            'Cicilan ganda memakai akun berbeda; tinjau jadwal pinjaman.',
          );
        }
        final account =
            accountsForDate.firstOrNull ?? mappings['${debt['id']}'];
        if (account == null) {
          throw ApiFailure(
            'Pilih asumsi akun kas untuk pinjaman ${debt['counterparty']}.',
          );
        }
        if (!ids.contains(account)) continue;
        append(
          'debt:${debt['id']}:${row.key}',
          account,
          '${debt['counterparty']}',
          due,
          (debt['installments'] as List? ?? const []).isEmpty
              ? 'Pokok jatuh tempo'
              : 'Pokok cicilan',
          row.value,
          receivable,
          receivable || active.isEmpty,
        );
        added = true;
      }
      if (added) {
        warnings.add(
          'Pinjaman ${debt['counterparty']}: hanya pokok tersisa; bunga/biaya masa depan tanpa jadwal tidak diasumsikan.',
        );
      }
    }
    entries.sort((a, b) => '${a.date}:${a.id}'.compareTo('${b.date}:${b.id}'));
    List<ForecastDay> timeline(BigInt opening, Iterable<ForecastEntry> events) {
      final list = <ForecastDay>[];
      final inflows = <String, BigInt>{}, outflows = <String, BigInt>{};
      for (final event in events) {
        final bucket = event.income ? inflows : outflows;
        bucket[event.date] = (bucket[event.date] ?? BigInt.zero) + event.amount;
      }
      for (var i = 0; i < count; i++) {
        final day = goalDay(start.add(Duration(days: i)));
        final incoming = inflows[day] ?? BigInt.zero,
            outgoing = outflows[day] ?? BigInt.zero;
        final low = opening - outgoing, closing = low + incoming;
        list.add(ForecastDay(day, opening, incoming, outgoing, low, closing));
        opening = closing;
      }
      return list;
    }

    final backing = config['reserve_goals'] == true
        ? goals.backing()
        : <String, BigInt>{};
    final result = <ForecastAccount>[];
    for (final account in selected) {
      final id = '${account['id']}',
          actual = financialMinor('${account['balance']}');
      final reserved = goals.allocations
          .where((a) => a['user_id'] == source.userId && a['account_id'] == id)
          .fold(
            BigInt.zero,
            (sum, a) => sum + (backing[a['id']] ?? BigInt.zero),
          );
      result.add(
        ForecastAccount(
          id,
          '${account['name']}',
          actual,
          reserved,
          timeline(actual - reserved, entries.where((e) => e.accountId == id)),
        ),
      );
    }
    final opening = result.fold(BigInt.zero, (sum, a) => sum + a.available);
    return CashFlowForecast(
      at,
      goalDay(start),
      goalDay(end.subtract(const Duration(days: 1))),
      entries,
      result,
      timeline(opening, entries),
      warnings.toSet().toList(),
      paidExcluded,
      skippedExcluded,
    );
  }
}
