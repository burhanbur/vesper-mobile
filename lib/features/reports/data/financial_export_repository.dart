import 'dart:convert';
import 'dart:typed_data';

import 'money_manager_backup.dart';
import 'money_manager_excel.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/app_time_zone.dart';
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
  final List<Map<String, dynamic>> accounts, categories, transactions;
  final AppTimeZone timeZone;
  final DateTime start, end;
  final int count;
  final BigInt credits, debits;
  final String currency;
  const FinancialExport(
    this.count,
    this.credits,
    this.debits,
    this.currency,
    this.accounts,
    this.categories,
    this.transactions,
    this.timeZone,
    this.start,
    this.end,
  );
  String get xls => moneyManagerExcel(this);
  int get excelRowCount => moneyManagerExcelRows(this).length;
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

  /// Inclusive date-picker range in the chosen calendar. Construct the next
  /// calendar midnight before converting; a device day may be 23 or 25 hours.
  FinancialExport exportCalendar({
    required DateTime startDate,
    required DateTime endDate,
    required AppTimeZone timeZone,
    required String currency,
    String? accountId,
  }) => export(
    start: timeZone.fromCalendar(
      DateTime.utc(startDate.year, startDate.month, startDate.day),
    ),
    end: timeZone.fromCalendar(
      DateTime.utc(endDate.year, endDate.month, endDate.day + 1),
    ),
    currency: currency,
    accountId: accountId,
    timeZone: timeZone,
  );

  FinancialExport export({
    required DateTime start,
    required DateTime end,
    required String currency,
    String? accountId,
    AppTimeZone timeZone = AppTimeZone.device,
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
    final exportedTransactions = <Map<String, dynamic>>[];
    final ownedAccounts = {for (final a in accounts) a['id']: a};
    Map<String, List<Map<String, dynamic>>>? transferLegs;
    String? peerAccount(Map<String, dynamic> row) {
      if (row['type'] != 'TRANSFER' || row['transfer_id'] == null) return null;
      final transfer = source.row('transfers', '${row['transfer_id']}');
      final direct =
          transfer?[row['account_id'] == transfer['from_account_id']
              ? 'to_account_id'
              : 'from_account_id'];
      if (ownedAccounts.containsKey(direct)) return direct as String;
      transferLegs ??= () {
        final result = <String, List<Map<String, dynamic>>>{};
        for (final leg in source.rows('transactions')) {
          if (leg['deleted_at'] == null &&
              leg['transfer_id'] != null &&
              ownedAccounts.containsKey(leg['account_id'])) {
            result.putIfAbsent('${leg['transfer_id']}', () => []).add(leg);
          }
        }
        return result;
      }();
      return transferLegs!['${row['transfer_id']}']
              ?.where((leg) => leg['id'] != row['id'])
              .firstOrNull?['account_id']
          as String?;
    }

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
        exportedTransactions.add({
          ...row,
          if (row['type'] == 'TRANSFER')
            'export_peer_account_id': peerAccount(row),
          'export_sync_status':
              queued['${row['id']}'] ??
              (row['version'] == '0' ? 'pending' : 'synced'),
        });
        count++;
      }
      cursor = page.next;
    } while (cursor != null);
    return FinancialExport(
      count,
      credits,
      debits,
      currency,
      ownedAccounts.values
          .where((a) => a['currency'] == currency)
          .map(
            (a) => <String, dynamic>{
              ...a,
              'export_account_category': source.row(
                'account_types',
                '${a['account_type_id']}',
              )?['category'],
            },
          )
          .toList(),
      source
          .rows('categories')
          .where(
            (c) =>
                c['user_id'] == source.userId &&
                (c['deleted_at'] == null ||
                    exportedTransactions.any(
                      (t) => t['category_id'] == c['id'],
                    )),
          )
          .map((c) => Map<String, dynamic>.from(c))
          .toList(),
      exportedTransactions,
      timeZone,
      start,
      end,
    );
  }

  Future<Uint8List> backup({required AppTimeZone timeZone, String? currency}) {
    if (!source.hasTransactionSnapshot || source.isSyncing) {
      throw const ApiFailure('Selesaikan sinkronisasi awal sebelum ekspor.');
    }
    if (accounts.isEmpty) {
      throw const ApiFailure('Belum ada akun untuk diekspor.');
    }
    if (currency != null && !accounts.any((a) => a['currency'] == currency)) {
      throw const ApiFailure('Tidak ada akun dalam mata uang yang dipilih.');
    }
    return createMoneyManagerBackup([
      for (final code in accounts.map((a) => '${a['currency']}').toSet())
        if (currency == null || code == currency)
          export(
            start: DateTime.utc(1),
            end: DateTime.utc(9999, 12, 31),
            currency: code,
            timeZone: timeZone,
          ),
    ]);
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
