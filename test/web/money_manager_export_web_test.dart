@TestOn('browser')
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/common.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/core/utils/app_time_zone.dart';
import 'package:vesper_mobile/database/local_store.dart';
import 'package:vesper_mobile/features/reports/data/export_sqlite_web.dart';
import 'package:vesper_mobile/features/reports/data/financial_export_repository.dart';
import 'package:vesper_mobile/features/sync/data/finance_repository.dart';
import 'package:web/web.dart' as web;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'real browser generates and reopens Money Manager SQLite and Excel',
    () async {
      const user = 'export-browser-test';
      web.window.localStorage.removeItem('vesper-state-$user');
      addTearDown(
        () => web.window.localStorage.removeItem('vesper-state-$user'),
      );
      final store = await LocalStore.open(user);
      final source = FinanceRepository(ApiClient(), store, user)
        ..offline = true;
      source.atomic(() {
        source.entities['account_types'] = {
          'cash': {'id': 'cash', 'user_id': user, 'category': 'CASH'},
        };
        source.entities['accounts'] = {
          for (final id in ['cash', 'card', 'foreign', 'deleted'])
            id: {
              'id': id,
              'user_id': id == 'foreign' ? 'other' : user,
              'account_type_id': 'cash',
              'name': id,
              'balance': id == 'card' ? '-50.00' : '1000.00',
              'currency': 'IDR',
              'is_credit_card': id == 'card',
              'credit_limit': id == 'card' ? '9000000.00' : null,
              if (id == 'deleted') 'deleted_at': '2026-01-01T00:00:00Z',
            },
        };
        source.entities['categories'] = {
          'income': {
            'id': 'income',
            'user_id': user,
            'name': 'Gaji',
            'type': 'INCOME',
          },
        };
        source.entities['transactions'] = {
          for (final (id, account, type, amount) in [
            ('income', 'cash', 'INCOME', '1200.00'),
            ('expense', 'cash', 'EXPENSE', '100.00'),
            ('out', 'cash', 'TRANSFER', '-50.00'),
            ('in', 'card', 'TRANSFER', '50.00'),
            ('card-expense', 'card', 'EXPENSE', '200.00'),
            ('foreign', 'foreign', 'INCOME', '999.00'),
          ])
            id: {
              'id': id,
              'account_id': account,
              'type': type,
              'amount': amount,
              'category_id': 'income',
              'description': '<script> & =SUM(1,2)',
              'transacted_at': '2020-01-02T20:00:00Z',
              'version': '1',
              if (id == 'out' || id == 'in') 'transfer_id': 'pair',
            },
        };
        source.state['transaction_snapshot_coverage'] = {
          'schema': 1,
          'user_id': user,
          'complete': true,
        };
      });
      final repo = FinancialExportRepository(source);
      final snapshot = repo.exportCalendar(
        startDate: DateTime.utc(2020, 1, 3),
        endDate: DateTime.utc(2020, 1, 3),
        timeZone: AppTimeZone.wib,
        currency: 'IDR',
      );
      final before = jsonEncode(source.state);
      final html = snapshot.xls;
      expect(RegExp('<th>').allMatches(html), hasLength(11));
      expect(RegExp('<tr>').allMatches(html), hasLength(5));
      expect(html, contains('Transfer-Out'));
      expect(html, isNot(contains('Transfer-In')));
      expect(html, contains('&lt;script&gt; &amp;'));
      expect(html, contains('2020-01-03 03:00:00'));
      final transferRow = RegExp(r'<tr>.*?Transfer-Out.*?</tr>')
          .allMatches(html)
          .last
          .group(0)!;
      expect(transferRow, contains('x:str>card</td>'));
      expect(html, contains('class="amount">50.00</td>'));
      expect(snapshot.excelRowCount, 4);
      final destination = repo.exportCalendar(
        startDate: DateTime.utc(2020, 1, 3),
        endDate: DateTime.utc(2020, 1, 3),
        timeZone: AppTimeZone.wib,
        currency: 'IDR',
        accountId: 'card',
      );
      expect(destination.xls, contains('Transfer-In'));
      expect(destination.xls, contains('x:str>cash</td>'));
      final bytes = await repo.backup(timeZone: AppTimeZone.wib);
      expect(ascii.decode(bytes.take(15).toList()), 'SQLite format 3');
      final engine = await exportSqlite();
      final vfs = InMemoryFileSystem(name: 'export-browser-verify');
      engine.registerVirtualFileSystem(vfs);
      addTearDown(() => engine.unregisterVirtualFileSystem(vfs));
      engine.open('/restored.mmbak', vfs: vfs.name).close();
      vfs.fileData['/restored.mmbak']!
        ..clear()
        ..addAll(bytes);
      final db = engine.open('/restored.mmbak', vfs: vfs.name);
      addTearDown(db.close);
      expect(db.select('PRAGMA integrity_check').single.values.single, 'ok');
      expect(db.userVersion, 19);
      expect(db.select('SELECT uid FROM ASSETS').map((r) => r['uid']).toSet(), {
        'cash',
        'card',
      });
      expect(
        db
            .select("SELECT groupUid FROM ASSETS WHERE uid='card'")
            .single['groupUid'],
        'vesper-group-2',
      );
      expect(
        db
            .select("SELECT txUidTrans FROM INOUTCOME WHERE uid='out'")
            .single['txUidTrans'],
        'in',
      );
      for (final (id, expected) in [('cash', '1000.00'), ('card', '-50.00')]) {
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
      expect(jsonEncode(source.state), before);
      expect(source.outbox, isEmpty);
    },
  );
}
