import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:sqlite3/common.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/api_client.dart';
import 'export_sqlite_native.dart'
    if (dart.library.js_interop) 'export_sqlite_web.dart';
import 'financial_export_repository.dart';

/// A fresh v19 Money Manager database, using only the supplied file's schema.
/// Never copies the application database, encryption keys, WALs or credentials.
Future<Uint8List> createMoneyManagerBackup(
  List<FinancialExport> snapshots,
) async {
  // Vesper has no exchange-rate source. Inventing rates would change totals.
  if (snapshots.length > 1) {
    throw const ApiFailure(
      'Backup Money Manager memerlukan satu mata uang karena kurs belum tersedia. Ekspor Excel per mata uang untuk menyimpan semua nominal asli.',
    );
  }
  final schema = await rootBundle.loadString('assets/money_manager_schema.sql');
  final engine = await exportSqlite();
  final vfs = InMemoryFileSystem(name: 'export-${const Uuid().v4()}');
  engine.registerVirtualFileSystem(vfs);
  CommonDatabase? db;
  try {
    db = engine.open('/backup.mmbak', vfs: vfs.name);
    db.execute(schema);
    db.execute('BEGIN');
    void insert(String table, Map<String, Object?> values) {
      final statement = db!.prepare(
        'INSERT INTO $table (${values.keys.join(',')}) VALUES (${List.filled(values.length, '?').join(',')})',
      );
      try {
        statement.execute(values.values.toList());
      } finally {
        statement.close();
      }
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    insert('android_metadata', {'locale': 'en_US'});
    for (final (type, name) in [
      (1, 'Accounts'),
      (2, 'Card'),
      (8, 'Investments'),
    ]) {
      insert('ASSETGROUP', {
        'uid': 'vesper-group-$type',
        'IS_DEL': 0,
        'USETIME': now,
        'ACC_GROUP_NAME': name,
        'TYPE': type,
        'ORDERSEQ': type,
        'isSynced': 0,
      });
    }
    final categories = <String, Map<String, dynamic>>{};
    for (final snapshot in snapshots) {
      for (final c in snapshot.categories) {
        categories['${c['id']}'] = c;
      }
    }
    for (final c in categories.values) {
      insert('ZCATEGORY', {
        'uid': c['id'],
        'C_IS_DEL': c['deleted_at'] == null ? 0 : 1,
        'C_UTIME': now,
        'NAME': c['name'],
        'ORDERSEQ': 0,
        'TYPE': c['type'] == 'INCOME' ? 0 : 1,
        'STATUS': 0,
        'pUid': '0',
        'isSynced': 0,
      });
    }
    for (final type in [0, 1]) {
      insert('ZCATEGORY', {
        'uid': 'vesper-opening-$type',
        'C_IS_DEL': 0,
        'NAME': 'Saldo awal',
        'TYPE': type,
        'STATUS': 0,
        'pUid': '0',
        'isSynced': 0,
      });
    }
    // Keep exact original card limits and transaction types in a separate table.
    // Money Manager ignores Vesper-specific data; this is not a Vesper restore.
    db.execute(
      'CREATE TABLE VESPER_EXPORT (kind TEXT NOT NULL, uid TEXT NOT NULL, payload TEXT NOT NULL, PRIMARY KEY(kind,uid))',
    );
    for (final snapshot in snapshots) {
      final currency = snapshot.currency;
      insert('CURRENCY', {
        'uid': 'vesper-$currency',
        'NAME': currency,
        'ISO': currency,
        'MAIN_ISO': currency,
        'IS_DEL': 0,
        'ORDER_SEQ': 0,
        'RATE': 1,
        'SYMBOL': currency == 'IDR' ? 'Rp' : currency,
        'INSERT_TYPE': 'I',
        'SYMBOL_POSITION': 'P',
        'IS_MAIN_CURRENCY': 1,
        'IS_SHOW': 1,
        'MODIFY_DATE': now,
        'DECIMAL_POINT':
            currency == 'IDR' &&
                !snapshot.transactions.any(
                  (t) =>
                      financialMinor('${t['amount']}') % BigInt.from(100) !=
                      BigInt.zero,
                ) &&
                !snapshot.accounts.any(
                  (a) =>
                      financialMinor('${a['balance']}') % BigInt.from(100) !=
                      BigInt.zero,
                )
            ? 0
            : 2,
        'isSynced': 0,
      });
      final accounts = {for (final a in snapshot.accounts) a['id']: a};
      final sums = <String, BigInt>{};
      final pairs = <String, List<Map<String, dynamic>>>{};
      for (final t in snapshot.transactions) {
        if (t['type'] == 'TRANSFER' && t['transfer_id'] != null) {
          pairs.putIfAbsent('${t['transfer_id']}', () => []).add(t);
        }
      }
      for (final a in snapshot.accounts) {
        final group = a['is_credit_card'] == true
            ? 2
            : a['export_account_category'] == 'INVESTMENT'
            ? 8
            : 1;
        insert('ASSETS', {
          'uid': a['id'],
          'currencyUid': 'vesper-$currency',
          'groupUid': 'vesper-group-$group',
          'NIC_NAME': a['name'],
          'CARD_DAY_FIN': '1',
          'CARD_DAY_PAY': '1',
          'ORDERSEQ': 0,
          'ZDATA': a['is_credit_card'] == true ? '1' : '0',
          'ZDATA1': '',
          'ZDATA2': a['is_include_total'] == false ? '1' : '0',
          'IS_TRANS_EXPENSE': 0,
          'IS_CARD_AUTO_PAY': 0,
          'CARD_USAGE_HURDLE_TYPE': 1,
          'CARD_USAGE_HURDLE_AMOUNT': 0,
          'cardAssetUid': '',
          'A_UTIME': now,
          'isSynced': 0,
        });
        insert('VESPER_EXPORT', {
          'kind': 'account',
          'uid': a['id'],
          'payload': jsonEncode(a),
        });
      }
      void transaction(
        Map<String, dynamic> t,
        BigInt signed, {
        bool opening = false,
      }) {
        final amount = signed.abs();
        // AMOUNT_ACCOUNT has REAL affinity in the reference format. Avoid
        // silently damaging amounts beyond its reliable decimal precision.
        if (amount.toString().length > 15) {
          throw const ApiFailure(
            'Nominal terlalu besar untuk format angka Money Manager. Gunakan Excel agar nominal tetap utuh.',
          );
        }
        final instant = DateTime.parse('${t['transacted_at']}');
        final local = snapshot.timeZone.at(instant);
        final date =
            '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
        final transfer = t['type'] == 'TRANSFER';
        final peer = (pairs['${t['transfer_id']}'] ?? [])
            .where(
              (p) =>
                  p['id'] != t['id'] &&
                  financialMinor('${p['amount']}').isNegative !=
                      signed.isNegative,
            )
            .firstOrNull;
        final type = transfer
            ? (signed.isNegative ? '3' : '4')
            : (t['type'] == 'EXPENSE' ||
                      t['type'] == 'INVESTMENT_BUY' ||
                      signed.isNegative
                  ? '1'
                  : '0');
        final category = categories['${t['category_id']}'];
        final decimal = financialDecimal(amount);
        insert('INOUTCOME', {
          'uid': t['id'],
          'assetUid': t['account_id'],
          'ctgUid': opening ? 'vesper-opening-$type' : category?['id'] ?? '',
          'toAssetUid': peer?['account_id'] ?? '',
          'txUidTrans': peer?['id'] ?? '',
          'ZCONTENT': t['description'] ?? '',
          'ZDATE': '${instant.millisecondsSinceEpoch}',
          'WDATE': date,
          'DO_TYPE': type,
          'ZMONEY': decimal,
          'IN_ZMONEY': decimal,
          'AMOUNT_ACCOUNT': decimal,
          'ZDATA': accounts[t['account_id']]?['name'] ?? '',
          'ASSET_NIC': accounts[t['account_id']]?['name'] ?? '',
          'CATEGORY_NAME': opening ? 'Saldo awal' : category?['name'] ?? '',
          'currencyUid': 'vesper-$currency',
          'IS_DEL': 0,
          'UTIME': now,
          'CARDDIVIDMONTH': '0',
          'cardDivideUid': '',
          'CARD_DIVIDE_MONTH_STR': '',
          'MARK': 0,
          'isSynced': 0,
          'syncVersion': 0,
        });
      }

      for (final t in snapshot.transactions) {
        final amount = financialMinor('${t['amount']}');
        final signed = switch (t['type']) {
          'EXPENSE' || 'INVESTMENT_BUY' => -amount.abs(),
          'INCOME' || 'INVESTMENT_SELL' => amount.abs(),
          _ => amount,
        };
        sums.update(
          '${t['account_id']}',
          (value) => value + signed,
          ifAbsent: () => signed,
        );
        transaction(t, signed);
        insert('VESPER_EXPORT', {
          'kind': 'transaction',
          'uid': t['id'],
          'payload': jsonEncode(t),
        });
      }
      for (final a in snapshot.accounts) {
        // Parent account balances summarize their children in Vesper. Export
        // no artificial opening balance for those containers.
        if (snapshot.accounts.any(
          (child) => child['parent_account_id'] == a['id'],
        )) {
          continue;
        }
        final opening =
            financialMinor('${a['balance']}') -
            (sums['${a['id']}'] ?? BigInt.zero);
        if (opening == BigInt.zero) continue;
        final dates =
            snapshot.transactions
                .where((t) => t['account_id'] == a['id'])
                .map((t) => DateTime.parse('${t['transacted_at']}'))
                .toList()
              ..sort();
        transaction(
          {
            'id': 'vesper-opening-${a['id']}',
            'account_id': a['id'],
            'transacted_at':
                (dates.isEmpty
                        ? DateTime.now()
                        : dates.first.subtract(const Duration(milliseconds: 1)))
                    .toUtc()
                    .toIso8601String(),
            'description': 'Saldo awal',
          },
          opening,
          opening: true,
        );
      }
    }
    db.execute('COMMIT');
    db.close();
    db = null;
    return Uint8List.fromList(vfs.fileData['/backup.mmbak']!);
  } finally {
    db?.close();
    engine.unregisterVirtualFileSystem(vfs);
  }
}
