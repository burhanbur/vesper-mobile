import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../../core/network/api_client.dart';
import '../../sync/data/finance_repository.dart';

BigInt obligationMinor(String value, {bool signed = false}) {
  final pattern = RegExp(
    signed
        ? r'^-?(0|[1-9]\d{0,17})(\.\d{1,2})?$'
        : r'^(0|[1-9]\d{0,17})(\.\d{1,2})?$',
  );
  final match = pattern.firstMatch(value);
  if (match == null || match.end != value.length) {
    throw const ApiFailure('Nominal harus angka dengan maksimal 2 desimal.');
  }
  final parts = value.replaceFirst('-', '').split('.');
  final amount =
      BigInt.parse(parts[0]) * BigInt.from(100) +
      BigInt.parse(parts.length == 1 ? '0' : parts[1].padRight(2, '0'));
  return value.startsWith('-') ? -amount : amount;
}

String obligationMoney(BigInt amount) =>
    '${amount.isNegative ? '-' : ''}${amount.abs() ~/ BigInt.from(100)}.${(amount.abs() % BigInt.from(100)).toString().padLeft(2, '0')}';
String obligationDate(String value) {
  final date = DateTime.tryParse('${value}T00:00:00Z');
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) ||
      date == null ||
      date.year < 1 ||
      date.toIso8601String().substring(0, 10) != value) {
    throw const ApiFailure('Tanggal harus YYYY-MM-DD yang valid.');
  }
  return value;
}

class ObligationsRepository {
  final FinanceRepository source;
  ObligationsRepository(this.source);
  void validateMobileEntry(List<String> amounts) {
    for (final amount in amounts) {
      if (obligationMinor(amount) % BigInt.from(100) != BigInt.zero) {
        throw const ApiFailure(
          'Form ini mendukung Rupiah bulat. Pecahan tidak dibulatkan atau disimpan.',
        );
      }
    }
  }

  void validateMobileAccounts(List<String> ids) {
    for (final id in ids) {
      final balance = source.row('accounts', id)?['balance'];
      if (balance != null &&
          obligationMinor('$balance', signed: true) % BigInt.from(100) !=
              BigInt.zero) {
        throw const ApiFailure(
          'Pilih akun dengan saldo Rupiah bulat untuk formulir ini.',
        );
      }
    }
  }

  List<Map<String, dynamic>> get records => source
      .rows('obligations')
      .where((r) => r['user_id'] == source.userId && r['deleted_at'] == null)
      .toList();
  List<Map<String, dynamic>> events(String id) =>
      source
          .rows('obligation_events')
          .where(
            (r) => r['user_id'] == source.userId && r['obligation_id'] == id,
          )
          .toList()
        ..sort(
          (a, b) => '${a['transacted_at']}:${a['id']}'.compareTo(
            '${b['transacted_at']}:${b['id']}',
          ),
        );
  List<Map<String, dynamic>> get cashAccounts =>
      source.rows('accounts').where((r) => _ownsAccount('${r['id']}')).toList();
  bool _ownsAccount(String id) {
    final row = source.row('accounts', id);
    final type = source.row('account_types', '${row?['account_type_id']}');
    return row != null &&
        row['user_id'] == source.userId &&
        row['deleted_at'] == null &&
        row['is_visible'] != false &&
        row['currency'] == 'IDR' &&
        type?['user_id'] == source.userId &&
        type?['deleted_at'] == null &&
        type?['category'] == 'CASH' &&
        !source
            .rows('accounts')
            .any(
              (a) => a['parent_account_id'] == id && a['deleted_at'] == null,
            );
  }

  List<Map<String, String>> parseInstallments(
    String input,
    String principal,
    String? dueDate,
  ) {
    final rows = <Map<String, String>>[];
    var total = BigInt.zero;
    for (final line in input.split('\n').where((s) => s.trim().isNotEmpty)) {
      final parts = line.trim().split('=');
      if (parts.length != 2) {
        throw const ApiFailure('Jadwal: satu baris YYYY-MM-DD=nominal pokok.');
      }
      final date = obligationDate(parts[0].trim());
      final amount = obligationMinor(parts[1].trim());
      if (amount <= BigInt.zero ||
          (rows.isNotEmpty && date.compareTo(rows.last['due_date']!) <= 0)) {
        throw const ApiFailure(
          'Tanggal cicilan harus berurutan dan pokok positif.',
        );
      }
      rows.add({'due_date': date, 'principal': obligationMoney(amount)});
      total += amount;
    }
    if (rows.length > 360 ||
        (rows.isNotEmpty &&
            (total != obligationMinor(principal) ||
                (dueDate != null && rows.last['due_date'] != dueDate)))) {
      throw const ApiFailure(
        'Total jadwal harus sama dengan pokok; jatuh tempo sama dengan cicilan terakhir.',
      );
    }
    return rows;
  }

  String open({
    required String kind,
    required String counterparty,
    required String principal,
    String? dueDate,
    String installments = '',
    String? cashAccountId,
    String? linkedAccountId,
  }) {
    if (!['PAYABLE', 'RECEIVABLE'].contains(kind) ||
        counterparty.trim().isEmpty ||
        counterparty.trim().length > 255 ||
        (cashAccountId != null && linkedAccountId != null)) {
      throw const ApiFailure('Pilih jenis dan nama pihak dengan benar.');
    }
    final amount = obligationMinor(principal);
    if (amount <= BigInt.zero) throw const ApiFailure('Pokok harus positif.');
    final due = dueDate == null || dueDate.isEmpty
        ? null
        : obligationDate(dueDate);
    return _save({
      'action': 'OPEN',
      'obligation_id': const Uuid().v4(),
      'kind': kind,
      'counterparty': counterparty.trim(),
      'currency': 'IDR',
      'principal': obligationMoney(amount),
      'due_date': due,
      'installments': parseInstallments(installments, principal, due),
      'cash_account_id': cashAccountId,
      'linked_account_id': linkedAccountId,
    });
  }

  String repay(
    String id, {
    required String cashAccountId,
    required String principal,
    String interest = '0',
    String fee = '0',
    String? interestCategoryId,
    String? feeCategoryId,
  }) => _save({
    'action': 'REPAY',
    'obligation_id': id,
    'expected_version': _record(id)['version'],
    'cash_account_id': cashAccountId,
    'principal': obligationMoney(obligationMinor(principal)),
    'interest': obligationMoney(obligationMinor(interest)),
    'fee': obligationMoney(obligationMinor(fee)),
    'interest_category_id': interestCategoryId,
    'fee_category_id': feeCategoryId,
  });
  String reverse(String id, String eventId) => _save({
    'action': 'REVERSE',
    'obligation_id': id,
    'expected_version': _record(id)['version'],
    'target_event_id': eventId,
  });
  String delete(String id) => _save({
    'action': 'DELETE',
    'obligation_id': id,
    'expected_version': _record(id)['version'],
  });
  Map<String, dynamic> _record(String id) =>
      records.where((r) => r['id'] == id).firstOrNull ??
      (throw const ApiFailure('Pinjaman tidak tersedia.'));

  String _save(Map<String, dynamic> fields) {
    source.requireObligationReady();
    final id = const Uuid().v4();
    final now = DateTime.fromMillisecondsSinceEpoch(
      DateTime.now().millisecondsSinceEpoch,
      isUtc: true,
    ).toIso8601String();
    final payload = {
      ...fields,
      'ledger_ids': {
        for (final role in [
          'cash_principal',
          'mapped_principal',
          'interest',
          'fee',
        ])
          role: const Uuid().v4(),
      },
      'transacted_at': now,
    };
    final action = fields['action'];
    final obligationId = fields['obligation_id'] as String;
    final debt = action == 'OPEN'
        ? <String, dynamic>{
            'id': obligationId,
            'user_id': source.userId,
            'kind': fields['kind'],
            'currency': 'IDR',
            'counterparty': fields['counterparty'],
            'principal': fields['principal'],
            'outstanding': fields['principal'],
            'due_date': fields['due_date'],
            'installments': fields['installments'],
            'linked_account_id': fields['linked_account_id'],
            'version': '0',
            'created_at': now,
            'updated_at': now,
            'deleted_at': null,
          }
        : Map<String, dynamic>.from(_record(obligationId));
    final target = action == 'REVERSE'
        ? events(obligationId)
              .where(
                (e) =>
                    e['id'] == fields['target_event_id'] &&
                    e['operation'] == 'REPAY' &&
                    e['reversed_at'] == null,
              )
              .firstOrNull
        : null;
    if (action == 'REVERSE' && target == null) {
      throw const ApiFailure('Pembayaran tidak tersedia untuk dikoreksi.');
    }
    var opening = <String, dynamic>{};
    if (action == 'DELETE' &&
        obligationMinor('${debt['outstanding']}') > BigInt.zero) {
      if (events(
            obligationId,
          ).any((e) => e['operation'] == 'REPAY' && e['reversed_at'] == null) ||
          debt['outstanding'] != debt['principal']) {
        throw const ApiFailure(
          'Balikkan pembayaran dahulu atau lunasi sebelum mengarsipkan.',
        );
      }
      opening = events(obligationId)
          .where((e) => e['operation'] == 'OPEN')
          .first;
    }
    final cashId =
        fields['cash_account_id'] as String? ??
        target?['cash_account_id'] as String? ??
        opening['cash_account_id'] as String?;
    final mappedId = debt['linked_account_id'] as String?;
    for (final accountId in [cashId, mappedId].whereType<String>()) {
      if (!_ownsAccount(accountId) ||
          source.outbox.any(
            (e) =>
                e['entity_id'] == accountId ||
                (e['payload'] as Map?)?['account_id'] == accountId,
          )) {
        throw const ApiFailure(
          'Pilih akun kas IDR milik sendiri tanpa perubahan tertunda.',
        );
      }
      if (records.any(
        (r) => r['linked_account_id'] == accountId && r['id'] != obligationId,
      )) {
        throw const ApiFailure('Akun terikat pinjaman lain.');
      }
    }
    if (cashId != null && cashId == mappedId) {
      throw const ApiFailure('Akun kas dan akun pinjaman harus berbeda.');
    }
    final sign = debt['kind'] == 'PAYABLE' ? BigInt.one : -BigInt.one;
    final principal = obligationMinor(
      '${fields['principal'] ?? target?['principal'] ?? '0'}',
    );
    final interest = obligationMinor('${fields['interest'] ?? '0'}');
    final fee = obligationMinor('${fields['fee'] ?? '0'}');
    if (action == 'OPEN' &&
        mappedId != null &&
        obligationMinor(
              '${source.row('accounts', mappedId)!['balance']}',
              signed: true,
            ) !=
            principal * -sign) {
      throw const ApiFailure(
        'Saldo akun lama harus sama dengan pokok: utang negatif, piutang positif.',
      );
    }
    if (action == 'REPAY' &&
        (principal <= BigInt.zero ||
            principal > obligationMinor('${debt['outstanding']}'))) {
      throw const ApiFailure(
        'Pokok pembayaran tidak valid atau melebihi sisa.',
      );
    }
    final changes = <String, Map<String, dynamic>?>{};
    final deltas = <String, BigInt>{};
    final ids = payload['ledger_ids'] as Map;
    final event = <String, dynamic>{
      'id': id,
      'user_id': source.userId,
      'obligation_id': obligationId,
      'operation': action,
      'principal': obligationMoney(principal),
      'interest': obligationMoney(interest),
      'fee': obligationMoney(fee),
      'cash_account_id': cashId,
      'cash_principal_id': null,
      'mapped_principal_id': null,
      'interest_id': null,
      'fee_id': null,
      'target_event_id': target?['id'],
      'transacted_at': now,
      'reversed_at': null,
      'version': '0',
      'created_at': now,
      'updated_at': now,
      'deleted_at': null,
    };
    void ledger(
      String role,
      String accountId,
      String type,
      BigInt amount, {
      String? category,
    }) {
      if (amount == BigInt.zero) return;
      event['${role}_id'] = ids[role];
      changes['transactions:${ids[role]}'] = {
        'id': ids[role],
        'account_id': accountId,
        'category_id': category,
        'transfer_id': null,
        'type': type,
        'amount': obligationMoney(amount),
        'transacted_at': now,
        'is_obligation_settlement': true,
        'description': 'Penyelesaian pinjaman',
        'created_by': source.userId,
        'version': '0',
      };
      deltas[accountId] =
          (deltas[accountId] ?? BigInt.zero) +
          (type == 'EXPENSE' ? -amount : amount);
    }

    if (action == 'OPEN' && cashId != null) {
      ledger('cash_principal', cashId, 'TRANSFER', principal * sign);
    }
    if (action == 'REPAY' && cashId != null) {
      ledger('cash_principal', cashId, 'TRANSFER', principal * -sign);
      if (mappedId != null) {
        ledger('mapped_principal', mappedId, 'TRANSFER', principal * sign);
      }
      for (final cost in [
        (
          'interest',
          interest,
          debt['kind'] == 'PAYABLE' ? 'EXPENSE' : 'INCOME',
        ),
        ('fee', fee, 'EXPENSE'),
      ]) {
        if (cost.$2 == BigInt.zero) continue;
        final categoryId = fields['${cost.$1}_category_id'] as String?;
        final category = source.row('categories', '$categoryId');
        if (category == null ||
            category['user_id'] != source.userId ||
            category['deleted_at'] != null ||
            category['type'] != cost.$3 ||
            source.outbox.any((e) => e['entity_id'] == categoryId)) {
          throw const ApiFailure(
            'Pilih kategori bunga/biaya aktif dengan jenis yang sesuai.',
          );
        }
        ledger(cost.$1, cashId, cost.$3, cost.$2, category: categoryId);
      }
      debt['outstanding'] = obligationMoney(
        obligationMinor('${debt['outstanding']}') - principal,
      );
    }
    final reverse = target ?? (opening.isEmpty ? null : opening);
    if (reverse != null) {
      for (final key in [
        'cash_principal_id',
        'mapped_principal_id',
        'interest_id',
        'fee_id',
      ]) {
        final ledgerId = reverse[key];
        if (ledgerId == null) continue;
        final row = source.row('transactions', '$ledgerId');
        if (row == null || row['deleted_at'] != null) {
          throw const ApiFailure(
            'Selesaikan sinkronisasi ledger sebelum koreksi.',
          );
        }
        final accountId = row['account_id'] as String;
        final amount = obligationMinor('${row['amount']}', signed: true);
        deltas[accountId] =
            (deltas[accountId] ?? BigInt.zero) -
            (row['type'] == 'EXPENSE' ? -amount : amount);
        changes['transactions:$ledgerId'] = {...row, 'deleted_at': now};
      }
      changes['obligation_events:${reverse['id']}'] = {
        ...reverse,
        'reversed_at': now,
      };
      if (target != null) {
        debt['outstanding'] = obligationMoney(
          obligationMinor('${debt['outstanding']}') + principal,
        );
      }
    }
    if (action == 'DELETE') debt['deleted_at'] = now;
    for (final delta in deltas.entries) {
      final account = source.row('accounts', delta.key)!;
      final next =
          obligationMinor('${account['balance']}', signed: true) + delta.value;
      if (next.abs() > BigInt.from(10).pow(20) - BigInt.one) {
        throw const ApiFailure('Saldo melampaui batas.');
      }
      changes['accounts:${delta.key}'] = {
        ...account,
        'balance': obligationMoney(next),
      };
    }
    changes['obligations:$obligationId'] = debt;
    changes['obligation_events:$id'] = event;
    source.commitObligationCommand(id, payload, changes);
    return id;
  }

  Map<String, String> totals() {
    var debt = BigInt.zero, receivable = BigInt.zero;
    for (final row in records) {
      final amount = obligationMinor('${row['outstanding']}');
      if (row['kind'] == 'PAYABLE') {
        debt += amount;
      } else {
        receivable += amount;
      }
    }
    return {
      'payable': obligationMoney(debt),
      'receivable': obligationMoney(receivable),
    };
  }

  List<Map<String, String>> schedule(String id) {
    final debt = _record(id);
    var paid =
        obligationMinor('${debt['principal']}') -
        obligationMinor('${debt['outstanding']}');
    return (debt['installments'] as List).map((value) {
      final row = Map<String, dynamic>.from(value as Map);
      final principal = obligationMinor('${row['principal']}');
      final applied = paid < principal ? paid : principal;
      paid -= applied;
      return {
        'due_date': row['due_date'] as String,
        'principal': obligationMoney(principal),
        'remaining': obligationMoney(principal - applied),
      };
    }).toList();
  }

  String recoveryReference(String queueId) =>
      jsonEncode(source.outbox.where((e) => e['id'] == queueId).single);
}
