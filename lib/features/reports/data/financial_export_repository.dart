import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../database/transaction_query.dart';
import '../../sync/data/finance_repository.dart';

BigInt financialMinor(String value) {
  if (!RegExp(r'^-?\d{1,18}(?:\.\d{1,2})?$').hasMatch(value)) {
    throw const ApiFailure('Nominal keuangan tidak valid.');
  }
  final parts = value.replaceFirst('-', '').split('.');
  final amount =
      BigInt.parse(parts.first) * BigInt.from(100) +
      BigInt.parse(parts.length == 1 ? '0' : parts[1].padRight(2, '0'));
  return value.startsWith('-') ? -amount : amount;
}

String financialDecimal(BigInt value) =>
    '${value.isNegative ? '-' : ''}${value.abs() ~/ BigInt.from(100)}.${(value.abs() % BigInt.from(100)).toString().padLeft(2, '0')}';

class FinancialExport {
  final String csv;
  final int count;
  final BigInt credits, debits;
  final String currency;
  const FinancialExport(
    this.csv,
    this.count,
    this.credits,
    this.debits,
    this.currency,
  );
}

class BalanceReconciliation {
  final String accountId, currency, reference;
  final BigInt recorded, statement;
  BigInt get difference => statement - recorded;
  const BalanceReconciliation(
    this.accountId,
    this.currency,
    this.reference,
    this.recorded,
    this.statement,
  );
  String get description =>
      'Rekonsiliasi saldo: ${jsonEncode({'schema': 1, 'recorded': financialDecimal(recorded), 'statement': financialDecimal(statement), 'difference': financialDecimal(difference), 'currency': currency, 'reference': reference, 'compared_at': DateTime.now().toUtc().toIso8601String()})}';
}

class FinancialExportRepository {
  final FinanceRepository source;
  FinancialExportRepository(this.source);

  List<Map<String, dynamic>> get accounts =>
      source
          .rows('accounts')
          .where(
            (a) => a['user_id'] == source.userId && a['deleted_at'] == null,
          )
          .toList()
        ..sort((a, b) => '${a['name']}'.compareTo('${b['name']}'));

  List<Map<String, dynamic>> get reconciliationAccounts => accounts.where((a) {
    final type = source.row('account_types', '${a['account_type_id']}');
    return a['currency'] == 'IDR' &&
        type?['category'] == 'CASH' &&
        !source.isMappedObligationAccount('${a['id']}') &&
        !accounts.any((child) => child['parent_account_id'] == a['id']);
  }).toList();

  // Quote every field; text that could become a spreadsheet formula is literal.
  String _cell(Object? value, {bool numeric = false}) {
    var text = value?.toString() ?? '';
    if (!numeric &&
        (RegExp(r'^[\s\u0000-\u001f]*[=+@-]').hasMatch(text) ||
            RegExp(r'^[\t\r\n]').hasMatch(text))) {
      text = "'$text";
    }
    return '"${text.replaceAll('"', '""')}"';
  }

  FinancialExport export({
    required DateTime start,
    required DateTime end,
    required String currency,
    String? accountId,
  }) {
    if (!start.isBefore(end)) throw const ApiFailure('Periode tidak valid.');
    if (!source.hasTransactionSnapshot || source.isSyncing) {
      throw const ApiFailure('Selesaikan sinkronisasi awal sebelum ekspor.');
    }
    final selected = {
      for (final a in accounts)
        if (a['currency'] == currency &&
            (accountId == null || a['id'] == accountId))
          a['id'] as String: a,
    };
    if (selected.isEmpty) {
      throw const ApiFailure('Pilih akun milik sendiri yang valid.');
    }
    final generated = DateTime.now().toUtc().toIso8601String();
    final lines = <String>[
      [
        'transaction_id',
        'account_id',
        'account_name',
        'currency',
        'type',
        'amount',
        'signed_amount',
        'transacted_at_utc',
        'category_name',
        'description',
        'transfer_id',
        'sync_status',
        'version',
        'scope',
        'period_start_utc',
        'period_end_exclusive_utc',
        'exported_at_utc',
      ].map((v) => _cell(v)).join(','),
    ];
    final queued = <String, String>{};
    for (final item in source.outbox) {
      if (item['entity_type'] == 'transactions') {
        queued['${item['entity_id']}'] = '${item['status']}';
      }
      final p = item['payload'] as Map?;
      for (final key in [
        'from_transaction_id',
        'to_transaction_id',
        'linked_transaction_id',
      ]) {
        if (p?[key] != null) queued['${p![key]}'] = '${item['status']}';
      }
      for (final key in (item['required_snapshots'] as List? ?? const [])) {
        if ('$key'.startsWith('transactions:')) {
          queued['$key'.substring('transactions:'.length)] =
              '${item['status']}';
        }
      }
    }
    var credits = BigInt.zero, debits = BigInt.zero;
    var count = 0;
    TransactionCursor? cursor;
    do {
      final page = source.transactionPage(
        TransactionQuery(
          start: start.toUtc(),
          end: end.toUtc(),
          accountId: accountId,
          after: cursor,
          limit: 100,
        ),
      );
      for (final row in page.rows) {
        final account = selected[row['account_id']];
        if (account == null || row['deleted_at'] != null) continue;
        final amount = financialMinor('${row['amount']}');
        final type = '${row['type']}';
        final signed = switch (type) {
          'EXPENSE' || 'INVESTMENT_BUY' => -amount.abs(),
          'INCOME' || 'INVESTMENT_SELL' => amount.abs(),
          'TRANSFER' => amount,
          _ => throw const ApiFailure('Jenis transaksi tidak dikenal.'),
        };
        if (signed > BigInt.zero) credits += signed;
        if (signed < BigInt.zero) debits += signed.abs();
        final category = source.row('categories', '${row['category_id']}');
        final fields = <Object?>[
          row['id'],
          account['id'],
          account['name'],
          currency,
          type,
          financialDecimal(amount),
          financialDecimal(signed),
          DateTime.parse('${row['transacted_at']}').toUtc().toIso8601String(),
          category?['user_id'] == source.userId ? (category?['name']) : null,
          row['description'],
          row['transfer_id'],
          queued['${row['id']}'] ??
              (row['version'] == '0' ? 'pending' : 'synced'),
          row['version'],
          'owned_local_ledger',
          start.toUtc().toIso8601String(),
          end.toUtc().toIso8601String(),
          generated,
        ];
        lines.add(
          [
            for (var i = 0; i < fields.length; i++)
              _cell(fields[i], numeric: i == 5 || i == 6),
          ].join(','),
        );
        count++;
      }
      cursor = page.next;
    } while (cursor != null);
    return FinancialExport(
      '\uFEFF${lines.join('\r\n')}\r\n',
      count,
      credits,
      debits,
      currency,
    );
  }

  BalanceReconciliation compare(String id, String statement, String reference) {
    final account = reconciliationAccounts
        .where((a) => a['id'] == id)
        .firstOrNull;
    if (account == null) {
      throw const ApiFailure('Pilih akun kas IDR milik sendiri.');
    }
    if (reference.trim().isEmpty || reference.trim().length > 500) {
      throw const ApiFailure(
        'Isi referensi rekening koran, maksimal 500 karakter.',
      );
    }
    final recorded = financialMinor('${account['balance']}');
    final target = financialMinor(statement.trim());
    const safe = 9007199254740991;
    if (recorded % BigInt.from(100) != BigInt.zero ||
        target % BigInt.from(100) != BigInt.zero ||
        recorded.abs() > BigInt.from(safe) * BigInt.from(100) ||
        target.abs() > BigInt.from(safe) * BigInt.from(100) ||
        (target - recorded).abs() > BigInt.from(safe) * BigInt.from(100)) {
      throw const ApiFailure(
        'Rekonsiliasi mendukung Rupiah bulat dalam batas presisi aman.',
      );
    }
    return BalanceReconciliation(id, 'IDR', reference.trim(), recorded, target);
  }
}
