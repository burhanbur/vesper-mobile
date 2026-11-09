import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/core/utils/app_time_zone.dart';
import 'package:vesper_mobile/database/local_store.dart';
import 'package:vesper_mobile/features/reports/data/financial_export_repository.dart';
import 'package:vesper_mobile/features/sync/data/finance_repository.dart';

import 'financial_export_test.dart' show seedExport;

Database readBackup(Uint8List bytes) {
  final directory = Directory.systemTemp.createTempSync('vesper-export-test-');
  final file = File('${directory.path}/backup.mmbak')..writeAsBytesSync(bytes);
  final db = sqlite3.open(file.path, mode: OpenMode.readOnly);
  addTearDown(() {
    db.close();
    file.deleteSync();
    directory.deleteSync();
  });
  return db;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LocalStore store;
  late FinanceRepository source;
  late FinancialExportRepository repo;
  setUp(() {
    store = LocalStore(sqlite3.openInMemory());
    source = FinanceRepository(ApiClient(), store, 'owner')..offline = true;
    seedExport(source);
    source.atomic(() {
      (source.entities['accounts'] as Map).remove('usd');
      (source.entities['accounts'] as Map)['second'] = {
        ...source.row('accounts', 'second')!,
        'is_credit_card': true,
        'credit_limit': '9000000.00',
        'is_include_total': false,
        'balance': '-50.00',
      };
      source.entities['transactions'] = {
        for (final (id, account, type, amount) in [
          ('income', 'account', 'INCOME', '1200.00'),
          ('expense', 'account', 'EXPENSE', '100.00'),
          ('out', 'account', 'TRANSFER', '-50.00'),
          ('in', 'second', 'TRANSFER', '50.00'),
          ('card', 'second', 'EXPENSE', '200.00'),
          ('foreign', 'foreign', 'INCOME', '999.00'),
          ('deleted', 'deleted', 'INCOME', '999.00'),
        ])
          id: {
            'id': id,
            'account_id': account,
            'type': type,
            'amount': amount,
            'category_id': type == 'INCOME' ? 'income' : 'expense',
            'description': 'Catatan $id',
            'version': '1',
            'transacted_at': '2020-01-02T20:00:00Z',
            if (id == 'out' || id == 'in') 'transfer_id': 'pair',
          },
      };
    });
    repo = FinancialExportRepository(source);
    addTearDown(store.close);
  });

  test(
    'SQLite v19 backup preserves ownership, card, transfers and balances',
    () async {
      final before = jsonEncode(source.state);
      final bytes = await repo.backup(timeZone: AppTimeZone.wib);
      expect(ascii.decode(bytes.take(15).toList()), 'SQLite format 3');
      final db = readBackup(bytes);
      expect(db.select('PRAGMA integrity_check').single.values.single, 'ok');
      expect(db.userVersion, 19);
      final tables = db
          .select("SELECT name FROM sqlite_master WHERE type='table'")
          .map((r) => r['name']);
      expect(
        tables,
        containsAll([
          'ASSETS',
          'INOUTCOME',
          'ZCATEGORY',
          'CURRENCY',
          'ASSETGROUP',
          'ZETC',
        ]),
      );
      expect(db.select('SELECT uid FROM ASSETS').map((r) => r['uid']).toSet(), {
        'account',
        'second',
      });
      final card = db.select("SELECT * FROM ASSETS WHERE uid='second'").single;
      expect(card['groupUid'], 'vesper-group-2');
      expect(card['ZDATA'], '1');
      expect(card['ZDATA2'], '1');
      final out = db.select("SELECT * FROM INOUTCOME WHERE uid='out'").single;
      final incoming = db
          .select("SELECT * FROM INOUTCOME WHERE uid='in'")
          .single;
      expect(out['DO_TYPE'], '3');
      expect(incoming['DO_TYPE'], '4');
      expect(out['txUidTrans'], 'in');
      expect(incoming['txUidTrans'], 'out');
      expect(out['toAssetUid'], 'second');
      expect(out['WDATE'], '2020-01-03');
      expect(out['ZMONEY'], '50.00');
      // Sum decimal text independently, without SQL floating point arithmetic.
      for (final (id, expected) in [
        ('account', '1000.00'),
        ('second', '-50.00'),
      ]) {
        var total = BigInt.zero;
        for (final row in db.select(
          'SELECT DO_TYPE,ZMONEY FROM INOUTCOME WHERE assetUid=?',
          [id],
        )) {
          final amount = financialMinor(row['ZMONEY'] as String);
          total += ['1', '3'].contains(row['DO_TYPE']) ? -amount : amount;
        }
        expect(financialDecimal(total), expected);
      }
      final metadata = jsonDecode(
        db
                .select(
                  "SELECT payload FROM VESPER_EXPORT WHERE kind='account' AND uid='second'",
                )
                .single['payload']
            as String,
      ) as Map;
      expect(metadata['credit_limit'], '9000000.00');
      expect(jsonEncode(source.state), before);
      expect(source.outbox, isEmpty);
    },
  );

  test('Excel uses reference columns, one paired transfer and destination-only leg', () {
    FinancialExport export([String? account]) => repo.exportCalendar(
      startDate: DateTime.utc(2020, 1, 3),
      endDate: DateTime.utc(2020, 1, 3),
      timeZone: AppTimeZone.wib,
      currency: 'IDR',
      accountId: account,
    );
    final html = export().xls;
    final headers = RegExp(r'<th>(.*?)</th>')
        .allMatches(html)
        .map((m) => m[1])
        .toList();
    expect(headers, [
      'Date',
      'Account',
      'Category',
      'Subcategory',
      'Note',
      'IDR',
      'Income/Expense',
      'Description',
      'Amount',
      'Currency',
      'Account',
    ]);
    expect(RegExp('<tr>').allMatches(html), hasLength(5));
    expect(html, contains('Transfer-Out'));
    expect(html, isNot(contains('Transfer-In')));
    expect(html, contains('2020-01-03 03:00:00'));
    expect(export('second').xls, contains('Transfer-In'));
    expect(export('second').xls, isNot(contains('Transfer-Out')));
    final none = repo.exportCalendar(
      startDate: DateTime.utc(2026, 1, 1),
      endDate: DateTime.utc(2026, 1, 1),
      timeZone: AppTimeZone.wib,
      currency: 'IDR',
    );
    expect(RegExp('<tr>').allMatches(none.xls), hasLength(1));
  });

  test(
    'backup refuses invented exchange rates and unsafe Money Manager precision',
    () async {
      source.atomic(() {
        (source.entities['accounts'] as Map)['usd'] = {
          ...source.row('accounts', 'account')!,
          'id': 'usd',
          'currency': 'USD',
        };
      });
      await expectLater(
        repo.backup(timeZone: AppTimeZone.wib),
        throwsA(isA<ApiFailure>()),
      );
      source.atomic(() {
        (source.entities['accounts'] as Map).remove('usd');
        (source.entities['transactions'] as Map)['income']['amount'] =
            '90071992547409.91';
      });
      await expectLater(
        repo.backup(timeZone: AppTimeZone.wib),
        throwsA(isA<ApiFailure>()),
      );
      expect(source.outbox, isEmpty);
    },
  );
}
