import 'package:uuid/uuid.dart';

import '../../../core/network/api_client.dart';
import '../../goals/data/goals_repository.dart';
import '../../obligations/data/obligations_repository.dart';
import '../../notifications/models/notification_item.dart';
import '../../sync/data/finance_repository.dart';

String billOccurrenceId(String billId, String date) =>
    const Uuid().v5(billId, date);
DateTime billToday(Map<String, dynamic> bill, DateTime now) => goalDate(
  goalDay(
    now.toUtc().add(Duration(minutes: bill['utc_offset_minutes'] as int)),
  ),
);
String? billDue(Map<String, dynamic> bill, String date) {
  final at = goalDate(date), anchor = goalDate('${bill['anchor_date']}');
  if (at.isBefore(anchor) ||
      (bill['end_date'] != null &&
          at.isAfter(goalDate('${bill['end_date']}')))) {
    return null;
  }
  if (bill['frequency'] == 'INSTALLMENTS') {
    for (final row in bill['installments'] as List) {
      if (row['due_date'] == date) return '${row['principal']}';
    }
    return null;
  }
  if (bill['frequency'] == 'ONCE') {
    return at == anchor ? '${bill['amount']}' : null;
  }
  if (bill['frequency'] == 'WEEKLY') {
    return at.difference(anchor).inDays % 7 == 0 ? '${bill['amount']}' : null;
  }
  final last = DateTime.utc(at.year, at.month + 1, 0).day;
  if (at.day != (anchor.day < last ? anchor.day : last)) return null;
  if (bill['frequency'] == 'YEARLY' && at.month != anchor.month) return null;
  return '${bill['amount']}';
}

class BillDueItem {
  final Map<String, dynamic> bill;
  final String date, id, status, amount;
  final bool overdue;
  final Map<String, dynamic>? record;
  const BillDueItem(
    this.bill,
    this.date,
    this.id,
    this.status,
    this.amount,
    this.overdue,
    this.record,
  );
}

class BillsRepository {
  final FinanceRepository source;
  BillsRepository(this.source, {bool activate = true}) {
    if (activate && source.state['bill_history_coverage'] == null) {
      source.atomic(() {
        source.state['bill_history_coverage'] = {
          'schema': 1,
          'user_id': source.userId,
          'complete': false,
        };
        if (!source.isSyncing) source.state['cursor'] = '0';
      });
    }
  }
  bool get complete =>
      source.state['bill_history_coverage'] is Map &&
      source.state['bill_history_coverage']['complete'] == true;
  List<Map<String, dynamic>> get schedules => source
      .rows('bill_schedules')
      .where((b) => b['user_id'] == source.userId && b['deleted_at'] == null)
      .toList();
  List<Map<String, dynamic>> get records => source
      .rows('bill_occurrences')
      .where((o) => o['user_id'] == source.userId)
      .toList();
  List<Map<String, dynamic>> get accounts => source.rows('accounts').where((a) {
    final type = source.row('account_types', '${a['account_type_id']}');
    return a['user_id'] == source.userId &&
        a['currency'] == 'IDR' &&
        a['deleted_at'] == null &&
        type?['user_id'] == source.userId &&
        type?['category'] == 'CASH' &&
        type?['deleted_at'] == null &&
        !source.isMappedObligationAccount('${a['id']}') &&
        !source
            .rows('accounts')
            .any(
              (child) =>
                  child['parent_account_id'] == a['id'] &&
                  child['deleted_at'] == null,
            );
  }).toList();
  List<Map<String, dynamic>> categories(String type) => source
      .rows('categories')
      .where(
        (c) =>
            c['user_id'] == source.userId &&
            c['deleted_at'] == null &&
            c['type'] == type,
      )
      .toList();
  List<Map<String, dynamic>> get debts => source
      .rows('obligations')
      .where(
        (d) =>
            d['user_id'] == source.userId &&
            d['deleted_at'] == null &&
            (d['installments'] as List? ?? const []).isNotEmpty,
      )
      .toList();
  List<Map> get queue => source.outbox
      .where(
        (e) => ['bill_schedules', 'bill_commands'].contains(e['entity_type']),
      )
      .cast<Map>()
      .toList();
  void recoverSchedule(String queueId, {bool discard = false}) {
    if (source.isSyncing) {
      throw const ApiFailure('Tunggu sinkronisasi selesai.');
    }
    final item = queue.where((e) => e['id'] == queueId).firstOrNull;
    if (item == null ||
        item['entity_type'] != 'bill_schedules' ||
        !['rejected', 'conflict'].contains(item['status'])) {
      throw const ApiFailure(
        'Hanya jadwal yang ditolak/konflik dapat diselesaikan.',
      );
    }
    source.atomic(() {
      if (discard) {
        item['server_data'] ??= item['before'];
        source.resolve(queueId, useMine: false);
      } else if (item['status'] == 'conflict' &&
          (item['server_data'] as Map?)?['version'] != null) {
        if (item['operation'] == 'CREATE') {
          throw const ApiFailure(
            'Gunakan versi server sebelum mengubah jadwal.',
          );
        }
        source.resolve(queueId, useMine: true);
      } else {
        item['status'] = 'pending';
        item.remove('error');
      }
    });
  }

  String status(Map<String, dynamic>? o, Map<String, dynamic> bill) {
    if (o == null) return 'PENDING';
    if (o['status'] != 'PAID') return '${o['status']}';
    if (o['transaction_id'] != null) {
      final t = source.row('transactions', '${o['transaction_id']}');
      if (t == null ||
          t['deleted_at'] != null ||
          t['account_id'] != bill['account_id'] ||
          t['category_id'] != bill['category_id'] ||
          t['type'] != bill['transaction_type'] ||
          goalMinor('${t['amount']}') != goalMinor('${o['amount']}')) {
        return 'NEEDS_REVIEW';
      }
    } else {
      final e = source.row('obligation_events', '${o['obligation_event_id']}');
      if (e == null ||
          e['operation'] != 'REPAY' ||
          e['reversed_at'] != null ||
          e['deleted_at'] != null ||
          e['obligation_id'] != bill['obligation_id'] ||
          e['cash_account_id'] != bill['account_id'] ||
          goalMinor('${e['principal']}') < goalMinor('${o['amount']}')) {
        return 'NEEDS_REVIEW';
      }
    }
    return 'PAID';
  }

  List<BillDueItem> occurrences({
    DateTime? now,
    bool older = false,
    int horizonDays = 60,
  }) {
    if (horizonDays < 0 || horizonDays > 366) {
      throw const ApiFailure('Rentang jadwal tidak valid.');
    }
    final instant = now ?? DateTime.now();
    final result = <BillDueItem>[];
    for (final bill in schedules.where((b) => b['active'] == true)) {
      final today = billToday(bill, instant),
          anchor = goalDate('${bill['anchor_date']}');
      final start = older ? anchor : today.subtract(const Duration(days: 365));
      final end = today.add(Duration(days: horizonDays));
      final candidates = <String>{};
      if (bill['frequency'] == 'INSTALLMENTS') {
        for (final r in bill['installments'] as List) {
          candidates.add('${r['due_date']}');
        }
      } else if (bill['frequency'] == 'ONCE') {
        candidates.add(goalDay(anchor));
      } else if (bill['frequency'] == 'WEEKLY') {
        final skip = start.isAfter(anchor)
            ? (start.difference(anchor).inDays + 6) ~/ 7
            : 0;
        for (
          var day = anchor.add(Duration(days: skip * 7));
          !day.isAfter(end);
          day = day.add(const Duration(days: 7))
        ) {
          if (candidates.length >= 10000) {
            throw const ApiFailure(
              'Terlalu banyak kejadian. Batasi tampilan ke 12 bulan terakhir.',
            );
          }
          candidates.add(goalDay(day));
        }
      } else {
        final first = start.isAfter(anchor) ? start : anchor;
        for (
          var n = first.year * 12 + first.month - 1;
          n <= end.year * 12 + end.month - 1;
          n++
        ) {
          final year = n ~/ 12,
              month = n % 12 + 1,
              last = DateTime.utc(year, month + 1, 0).day;
          if (bill['frequency'] == 'YEARLY' && month != anchor.month) continue;
          candidates.add(
            goalDay(
              DateTime.utc(year, month, anchor.day < last ? anchor.day : last),
            ),
          );
          if (candidates.length > 10000) {
            throw const ApiFailure('Terlalu banyak kejadian. Batasi tampilan.');
          }
        }
      }
      for (final date in candidates) {
        final day = goalDate(date), amount = billDue(bill, date);
        if (amount == null ||
            day.isAfter(end) ||
            (!older && day.isBefore(start) && bill['frequency'] != 'ONCE')) {
          continue;
        }
        final id = billOccurrenceId(bill['id'] as String, date),
            record = source.row('bill_occurrences', id);
        result.add(
          BillDueItem(
            bill,
            date,
            id,
            status(record, bill),
            amount,
            day.isBefore(today),
            record,
          ),
        );
        if (result.length > 10000) {
          throw const ApiFailure('Terlalu banyak kejadian. Batasi tampilan.');
        }
      }
    }
    result.sort((a, b) => '${a.date}:${a.id}'.compareTo('${b.date}:${b.id}'));
    return result;
  }

  List<AppNotificationItem> reminders({DateTime? now}) {
    final reads = source.state['bill_reminder_reads'] as Map? ?? const {};
    final result = <AppNotificationItem>[];
    final seen = <String>{};
    List<BillDueItem> due;
    try {
      due = occurrences(now: now);
    } catch (_) {
      return result;
    }
    for (final o in due) {
      if (o.bill['reminder_enabled'] != true ||
          ['PAID', 'SKIPPED'].contains(o.status) ||
          seen.contains(o.bill['id'])) {
        continue;
      }
      final today = billToday(o.bill, now ?? DateTime.now());
      if (goalDate(o.date)
          .isAfter(today.add(Duration(days: o.bill['reminder_days'] as int)))) {
        continue;
      }
      seen.add(o.bill['id'] as String);
      final id = 'bill:${o.id}';
      result.add(
        AppNotificationItem(
          id: id,
          type: NotificationType.warning,
          title: o.overdue ? 'Tagihan lewat jatuh tempo' : 'Pengingat tagihan',
          body:
              '${o.bill['title']} • ${o.date}. Buka Tagihan & Jadwal untuk meninjau; tidak ada pembayaran otomatis.',
          createdAt: goalDate(o.date),
          isRead: reads[id] == true,
        ),
      );
    }
    return result;
  }

  void markRemindersRead() => source.atomic(() {
    final reads = Map<String, dynamic>.from(
      source.state['bill_reminder_reads'] as Map? ?? const {},
    );
    for (final n in reminders()) {
      reads[n.id] = true;
    }
    source.state['bill_reminder_reads'] = reads;
  });
  void saveSchedule(Map<String, dynamic> data, {String? id}) {
    if (source.isSyncing) {
      throw const ApiFailure('Tunggu sinkronisasi selesai.');
    }
    final title = '${data['title']}'.trim();
    if (title.isEmpty ||
        title.length > 120 ||
        data['reminder_days'] is! int ||
        (data['reminder_days'] as int) < 0 ||
        (data['reminder_days'] as int) > 30) {
      throw const ApiFailure('Periksa judul dan hari pengingat (0–30).');
    }
    if (id != null) {
      if (!schedules.any((b) => b['id'] == id)) {
        throw const ApiFailure('Jadwal tidak tersedia.');
      }
      source.mutate('bill_schedules', 'UPDATE', {
        'title': title,
        'active': data['active'],
        'reminder_enabled': data['reminder_enabled'],
        'reminder_days': data['reminder_days'],
      }, id: id);
      return;
    }
    final at = goalDate('${data['anchor_date']}');
    if (data['end_date'] != null &&
        goalDate('${data['end_date']}').isBefore(at)) {
      throw const ApiFailure('Tanggal akhir mendahului awal.');
    }
    if (![
          'ONCE',
          'WEEKLY',
          'MONTHLY',
          'YEARLY',
          'INSTALLMENTS',
        ].contains(data['frequency']) ||
        ![0, 420, 480, 540].contains(data['utc_offset_minutes']) ||
        !accounts.any((a) => a['id'] == data['account_id'])) {
      throw const ApiFailure(
        'Pilih jadwal, zona waktu dan akun kas IDR yang valid.',
      );
    }
    final debt = data['obligation_id'] == null
        ? null
        : debts.where((d) => d['id'] == data['obligation_id']).firstOrNull;
    List<dynamic> installments = [];
    if (data['obligation_id'] != null) {
      if (debt == null || data['frequency'] != 'INSTALLMENTS') {
        throw const ApiFailure('Pilih pinjaman dengan cicilan eksplisit.');
      }
      installments = List<dynamic>.from(debt['installments'] as List);
      if (data['anchor_date'] != installments.first['due_date'] ||
          data['amount'] != installments.first['principal'] ||
          data['category_id'] != null ||
          data['amount_type'] != 'FIXED' ||
          data['transaction_type'] !=
              (debt['kind'] == 'PAYABLE' ? 'EXPENSE' : 'INCOME')) {
        throw const ApiFailure(
          'Gunakan pokok dan tanggal cicilan pertama dari pinjaman.',
        );
      }
    } else {
      if (!categories('${data['transaction_type']}')
              .any((c) => c['id'] == data['category_id']) ||
          data['frequency'] == 'INSTALLMENTS') {
        throw const ApiFailure('Pilih kategori dengan jenis yang sesuai.');
      }
      if (goalMinor('${data['amount']}') % BigInt.from(100) != BigInt.zero) {
        throw const ApiFailure('Form pembayaran mendukung Rupiah bulat.');
      }
    }
    if (goalMinor('${data['amount']}') <= BigInt.zero ||
        !['FIXED', 'ESTIMATED'].contains(data['amount_type'])) {
      throw const ApiFailure('Nominal harus positif.');
    }
    source.mutate(
      'bill_schedules',
      'CREATE',
      {
        ...data,
        'title': title,
        'amount': goalMoney(goalMinor('${data['amount']}')),
      },
      local: {
        'active': true,
        'installments': installments,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  List<Map<String, dynamic>> linkable(BillDueItem o) {
    if (o.bill['obligation_id'] != null) {
      return source.rows('obligation_events').where((e) {
        if (e['user_id'] != source.userId ||
            e['obligation_id'] != o.bill['obligation_id'] ||
            e['cash_account_id'] != o.bill['account_id'] ||
            e['operation'] != 'REPAY' ||
            e['reversed_at'] != null ||
            e['deleted_at'] != null) {
          return false;
        }
        final used = records
            .where(
              (r) =>
                  r['obligation_event_id'] == e['id'] &&
                  r['id'] != o.id &&
                  r['status'] == 'PAID',
            )
            .fold(BigInt.zero, (sum, r) => sum + goalMinor('${r['amount']}'));
        return goalMinor('${e['principal']}') >= used + goalMinor(o.amount);
      }).toList();
    }
    return source
        .rows('transactions')
        .where(
          (t) =>
              t['account_id'] == o.bill['account_id'] &&
              t['category_id'] == o.bill['category_id'] &&
              t['type'] == o.bill['transaction_type'] &&
              t['deleted_at'] == null &&
              !records.any(
                (r) => r['transaction_id'] == t['id'] && r['id'] != o.id,
              ) &&
              (o.bill['amount_type'] == 'ESTIMATED' ||
                  goalMinor('${t['amount']}') == goalMinor(o.amount)),
        )
        .toList();
  }

  void command(
    BillDueItem o,
    String action, {
    String? amount,
    String? recordId,
    String note = '',
  }) {
    final bill = schedules
        .where((b) => b['id'] == o.bill['id'] && b['active'] == true)
        .firstOrNull;
    if (bill == null || billDue(bill, o.date) == null) {
      throw const ApiFailure('Jadwal tidak aktif atau tanggal tidak valid.');
    }
    final current = source.row('bill_occurrences', o.id);
    if (status(current, bill) == 'PAID') {
      throw const ApiFailure('Kejadian sudah dibayar.');
    }
    if (action == 'SKIP' && note.trim().isEmpty) {
      throw const ApiFailure('Isi alasan melewati kejadian.');
    }
    if (note.trim().length > 500 ||
        ![
          'PAY',
          'SKIP',
          'REOPEN',
          'LINK_TRANSACTION',
          'LINK_OBLIGATION',
        ].contains(action)) {
      throw const ApiFailure('Periksa tindakan dan catatan.');
    }
    final id = const Uuid().v4(), ledger = const Uuid().v4();
    final now = DateTime.fromMillisecondsSinceEpoch(
      DateTime.now().millisecondsSinceEpoch,
      isUtc: true,
    ).toIso8601String();
    BigInt actual = BigInt.zero;
    String? transactionId, eventId;
    if (action == 'PAY') {
      if (bill['obligation_id'] != null) {
        throw const ApiFailure(
          'Gunakan pembayaran pinjaman, kemudian tautkan bukti.',
        );
      }
      actual = goalMinor(amount ?? '0');
      if (actual <= BigInt.zero ||
          actual % BigInt.from(100) != BigInt.zero ||
          (bill['amount_type'] == 'FIXED' && actual != goalMinor(o.amount))) {
        throw const ApiFailure(
          'Nominal aktual harus Rupiah bulat dan sesuai nilai tetap.',
        );
      }
      transactionId = ledger;
    } else if (action.startsWith('LINK_')) {
      final record = linkable(o).where((r) => r['id'] == recordId).firstOrNull;
      if (record == null ||
          (action == 'LINK_OBLIGATION') != (bill['obligation_id'] != null)) {
        throw const ApiFailure(
          'Pilih pembayaran yang sesuai dan belum dipakai.',
        );
      }
      actual = action == 'LINK_OBLIGATION'
          ? goalMinor(o.amount)
          : goalMinor('${record['amount']}');
      if (action == 'LINK_OBLIGATION') {
        eventId = recordId;
      } else {
        transactionId = recordId;
      }
    }
    final payload = {
      'bill_id': bill['id'],
      'due_date': o.date,
      'action': action,
      'expected_version': '${current?['version'] ?? '0'}',
      'amount': action == 'PAY' ? goalMoney(actual) : null,
      'record_id': recordId,
      'ledger_id': ledger,
      'transacted_at': now,
      'note': note.trim(),
    };
    final account = source.row('accounts', '${bill['account_id']}');
    if (account == null ||
        account['user_id'] != source.userId ||
        account['deleted_at'] != null) {
      throw const ApiFailure('Akun tidak tersedia.');
    }
    if (source.outbox.any(
      (e) =>
          e['entity_id'] == account['id'] ||
          e['entity_id'] == bill['category_id'] ||
          (e['payload'] as Map?)?['account_id'] == account['id'] ||
          (e['payload'] as Map?)?['from_account_id'] == account['id'] ||
          (e['payload'] as Map?)?['to_account_id'] == account['id'],
    )) {
      throw const ApiFailure('Sinkronkan perubahan akun/transaksi sebelumnya.');
    }
    if (source.outbox.any(
      (e) =>
          e['entity_type'] == 'bill_schedules' && e['entity_id'] == bill['id'],
    )) {
      throw const ApiFailure('Sinkronkan jadwal sebelum mencatat kejadian.');
    }
    final changes = <String, Map<String, dynamic>?>{
      'bill_occurrences:${o.id}': {
        ...?current,
        'id': o.id,
        'user_id': source.userId,
        'bill_id': bill['id'],
        'due_date': o.date,
        'status': action == 'SKIP'
            ? 'SKIPPED'
            : action == 'REOPEN'
            ? 'PENDING'
            : 'PAID',
        'amount': goalMoney(actual),
        'transaction_id': transactionId,
        'obligation_event_id': eventId,
        'note': note.trim(),
        'version': current?['version'] ?? '0',
        'created_at': current?['created_at'] ?? now,
      },
      'transactions:$ledger': null,
      'accounts:${bill['account_id']}': account,
    };
    if (action == 'PAY') {
      final balance = obligationMinor('${account['balance']}', signed: true);
      if (balance % BigInt.from(100) != BigInt.zero ||
          !accounts.any((a) => a['id'] == account['id'])) {
        throw const ApiFailure('Pilih akun kas IDR dengan saldo Rupiah bulat.');
      }
      final next =
          balance + (bill['transaction_type'] == 'EXPENSE' ? -actual : actual);
      if (actual > BigInt.from(9007199254740991) * BigInt.from(100) ||
          next.abs() > BigInt.from(9007199254740991) * BigInt.from(100)) {
        throw const ApiFailure('Saldo melampaui batas presisi aman tampilan.');
      }
      changes['accounts:${account['id']}'] = {
        ...account,
        'balance': obligationMoney(next),
      };
      changes['transactions:$ledger'] = {
        'id': ledger,
        'account_id': account['id'],
        'category_id': bill['category_id'],
        'type': bill['transaction_type'],
        'amount': goalMoney(actual),
        'transacted_at': now,
        'description':
            '${bill['title']}${note.trim().isEmpty ? '' : ': ${note.trim()}'}',
        'version': '0',
        'created_by': source.userId,
        'transfer_id': null,
      };
    }
    source.commitBillCommand(id, payload, changes);
  }
}
