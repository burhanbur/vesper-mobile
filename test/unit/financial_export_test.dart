import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/database/local_store.dart';
import 'package:vesper_mobile/features/reports/data/financial_export_controller.dart';
import 'package:vesper_mobile/features/reports/data/financial_export_repository.dart';
import 'package:vesper_mobile/features/sync/data/finance_repository.dart';

void seedExport(FinanceRepository source) {
  source.atomic(() {
    source.entities['account_types'] = {
      'cash': {'id': 'cash', 'user_id': 'owner', 'category': 'CASH'},
      'investment': {
        'id': 'investment',
        'user_id': 'owner',
        'category': 'INVESTMENT',
      },
    };
    source.entities['accounts'] = <String, dynamic>{
      for (final id in ['account', 'second', 'foreign', 'usd', 'deleted'])
        id: <String, dynamic>{
          'id': id,
          'name': id == 'account' ? '=SUM(1,2)' : id,
          'user_id': id == 'foreign' ? 'other' : 'owner',
          'account_type_id': 'cash',
          'balance': '1000.00',
          'currency': id == 'usd' ? 'USD' : 'IDR',
          'version': '1',
          if (id == 'deleted') 'deleted_at': '2026-10-01T00:00:00Z',
        },
    };
    source.entities['categories'] = {
      'income': {
        'id': 'income',
        'name': 'Lainnya',
        'type': 'INCOME',
        'user_id': 'owner',
        'version': '1',
      },
      'expense': {
        'id': 'expense',
        'name': 'Lain-lain',
        'type': 'EXPENSE',
        'user_id': 'owner',
        'version': '1',
      },
    };
    source.state['transaction_snapshot_coverage'] = {
      'schema': 1,
      'user_id': 'owner',
      'complete': true,
    };
  });
}

// Parse independently so quoting, embedded newlines and escaped cells are checked.
List<List<String>> parseCsv(String csv) {
  final result = <List<String>>[];
  final text = csv.replaceFirst('\uFEFF', '');
  var row = <String>[];
  var field = StringBuffer();
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    if (char == '"') {
      if (quoted && i + 1 < text.length && text[i + 1] == '"') {
        field.write('"');
        i++;
      } else {
        quoted = !quoted;
      }
    } else if (char == ',' && !quoted) {
      row.add(field.toString());
      field = StringBuffer();
    } else if (char == '\r' && !quoted && text[i + 1] == '\n') {
      row.add(field.toString());
      result.add(row);
      row = [];
      field = StringBuffer();
      i++;
    } else {
      field.write(char);
    }
  }
  expect(quoted, false);
  return result;
}

void main() {
  for (final indexed in [false, true]) {
    group(indexed ? 'indexed WM07' : 'snapshot WM07', () {
      late LocalStore store;
      late FinanceRepository source;
      late FinancialExportRepository repo;
      late AppState state;
      late FinancialExportController controller;
      Directory? temporary;
      setUp(() {
        if (indexed) {
          temporary = Directory.systemTemp.createTempSync('vesper-wm07-');
        }
        store = indexed
            ? LocalStore.indexed(
                sqlite3.open('${temporary!.path}/finance.sqlite'),
                key: List.generate(32, (i) => i),
                userId: 'owner',
              )
            : LocalStore(sqlite3.openInMemory());
        source = FinanceRepository(ApiClient(), store, 'owner')..offline = true;
        seedExport(source);
        repo = FinancialExportRepository(source);
        state = AppState(repository: source)..currentUserId = 'owner';
        state.toggleOfflineMode();
        controller = FinancialExportController(state, repo);
      });
      tearDown(() {
        controller.dispose();
        state.dispose();
        store.close();
        if (temporary != null) {
          final directory = temporary!.absolute;
          if (directory.parent.path != Directory.systemTemp.absolute.path ||
              !directory.uri.pathSegments
                  .where((part) => part.isNotEmpty)
                  .last
                  .startsWith('vesper-wm07-')) {
            throw StateError('Invalid WM07 test cleanup directory');
          }
          directory.deleteSync(recursive: true);
          temporary = null;
        }
      });
      void transactions(List<Map<String, dynamic>> rows) => source.atomic(() {
        source.entities['transactions'] = {
          for (final row in rows) row['id'] as String: row,
        };
      });
      Map<String, dynamic> tx(
        String id, {
        String account = 'account',
        String amount = '1.00',
        String type = 'INCOME',
        String at = '2026-10-20T00:00:00Z',
        String? note,
      }) => {
        'id': id,
        'account_id': account,
        'amount': amount,
        'type': type,
        'transacted_at': at,
        'description': note,
        'category_id': 'income',
        'version': '1',
        'created_by': 'owner',
      };
      FinancialExport export({String? account, String currency = 'IDR'}) =>
          repo.export(
            start: DateTime.utc(2026, 10, 20),
            end: DateTime.utc(2026, 10, 21),
            accountId: account,
            currency: currency,
          );

      test('exact cents, ledger directions and owner/currency scope', () {
        transactions([
          tx('income', amount: '90071992547409.91'),
          tx('expense', type: 'EXPENSE', amount: '0.12'),
          tx('transfer-out', type: 'TRANSFER', amount: '-15.75'),
          tx(
            'transfer-in',
            type: 'TRANSFER',
            amount: '15.75',
            account: 'second',
          ),
          tx(
            'foreign',
            account: 'foreign',
            amount: '999.00',
            note: 'FOREIGN_SECRET',
          ),
          tx('usd', account: 'usd'),
          tx('deleted', account: 'deleted'),
        ]);
        final result = export();
        expect(result.count, 4);
        expect(financialDecimal(result.credits), '90071992547425.66');
        expect(financialDecimal(result.debits), '15.87');
        expect(
          financialDecimal(result.credits - result.debits),
          '90071992547409.79',
        );
        expect(result.csv, isNot(contains('FOREIGN_SECRET')));
        expect(export(account: 'account').count, 3);
        expect(export(currency: 'USD').count, 1);
        expect(() => export(account: 'foreign'), throwsA(isA<ApiFailure>()));
      });

      test(
        'UTF-8 BOM, CRLF, CSV quotes/newlines and spreadsheet injection',
        () {
          final notes = [
            '猫, café "quoted"\nbaris kedua',
            '=HYPERLINK("x")',
            ' +SUM(1,2)',
            '\t@SUM(1,2)',
            '-2+3',
            '@x',
            'normal',
          ];
          transactions([
            for (var i = 0; i < notes.length; i++) tx('row-$i', note: notes[i]),
          ]);
          final result = export();
          expect(utf8.encode(result.csv).take(3), [239, 187, 191]);
          expect(result.csv.endsWith('\r\n'), true);
          final rows = parseCsv(result.csv);
          expect(rows, hasLength(8));
          expect(rows.every((row) => row.length == 17), true);
          final byId = {for (final row in rows.skip(1)) row[0]: row};
          expect(byId['row-0']![9], notes[0]);
          expect(byId['row-0']![2], "'=SUM(1,2)");
          for (var i = 1; i <= 5; i++) {
            expect(byId['row-$i']![9], "'${notes[i]}");
          }
          expect(byId['row-6']![9], 'normal');
          expect(byId['row-0']![6], '1.00');
        },
      );

      test('half-open UTC boundaries, offset timestamps and tombstones', () {
        transactions([
          tx('start', at: '2026-10-20T07:00:00+07:00'),
          tx('last', at: '2026-10-20T23:59:59.999Z'),
          tx('before', at: '2026-10-19T23:59:59.999Z'),
          tx('end', at: '2026-10-21T00:00:00Z'),
          {...tx('tombstone'), 'deleted_at': '2026-10-20T12:00:00Z'},
        ]);
        final rows = parseCsv(export().csv).skip(1).toList();
        expect(rows.map((r) => r[0]).toSet(), {'start', 'last'});
        expect(rows.first[14], '2026-10-20T00:00:00.000Z');
        expect(rows.first[15], '2026-10-21T00:00:00.000Z');
      });

      test(
        'pagination exports more than 100 identical timestamps exactly once',
        () {
          transactions([
            for (var i = 0; i < 237; i++)
              tx('row-${i.toString().padLeft(3, '0')}'),
          ]);
          final result = export();
          final rows = parseCsv(result.csv).skip(1).toList();
          expect(result.count, 237);
          expect(rows.map((r) => r[0]).toSet(), hasLength(237));
          expect(financialDecimal(result.credits), '237.00');
        },
      );

      test(
        'pending/rejected and protected settlement commands retain status',
        () {
          transactions([
            tx('manual'),
            tx('transfer', type: 'TRANSFER', amount: '-1.00'),
            tx('obligation'),
          ]);
          source.atomic(() {
            source.outbox.addAll([
              {
                'id': 'queue-manual',
                'entity_type': 'transactions',
                'entity_id': 'manual',
                'status': 'rejected',
              },
              {
                'id': 'queue-transfer',
                'entity_type': 'transfers',
                'status': 'pending',
                'payload': {'from_transaction_id': 'transfer'},
              },
              {
                'id': 'queue-obligation',
                'entity_type': 'obligation_commands',
                'status': 'conflict',
                'required_snapshots': ['transactions:obligation'],
              },
            ]);
          });
          final rows = {
            for (final row in parseCsv(export().csv).skip(1)) row[0]: row[11],
          };
          expect(rows, {
            'manual': 'rejected',
            'transfer': 'pending',
            'obligation': 'conflict',
          });
        },
      );

      test(
        'empty export is header-only and incomplete coverage refuses export',
        () {
          transactions([]);
          expect(export().count, 0);
          expect(parseCsv(export().csv), hasLength(1));
          source.atomic(() {
            source.state.remove('transaction_snapshot_coverage');
          });
          expect(() => export(), throwsA(isA<ApiFailure>()));
        },
      );

      test('reconciliation appends audited ledger and durable queue, no history rewrite', () {
        transactions([tx('existing', amount: '1000.00')]);
        final before = source.row('transactions', 'existing');
        final preview = repo.compare(
          'account',
          '1250',
          'Statement 20 Oct / ref 42',
        );
        expect(preview.difference, BigInt.from(25000));
        expect(controller.confirm(preview), true);
        final row = source
            .rows('transactions')
            .where((r) => r['id'] != 'existing')
            .single;
        expect(row['type'], 'INCOME');
        expect(row['amount'], '250.00');
        final audit = jsonDecode(
          (row['description'] as String).split('Rekonsiliasi saldo: ').last,
        ) as Map;
        expect(audit['recorded'], '1000.00');
        expect(audit['statement'], '1250.00');
        expect(audit['difference'], '250.00');
        expect(audit['reference'], 'Statement 20 Oct / ref 42');
        expect(source.row('accounts', 'account')!['balance'], '1250.00');
        expect(source.row('transactions', 'existing'), before);
        expect(
          source.outbox.last['payload']['description'],
          row['description'],
        );
        final reloaded = FinanceRepository(ApiClient(), store, 'owner');
        expect(reloaded.rows('transactions'), hasLength(2));
        expect(reloaded.outbox, hasLength(1));
        expect(controller.confirm(preview), false);
        expect(source.rows('transactions'), hasLength(2));
      });

      test('matching balance is no-op; negative statement becomes expense', () {
        final before = jsonEncode(source.state);
        expect(
          controller.confirm(repo.compare('account', '1000', 'matched')),
          true,
        );
        expect(jsonEncode(source.state), before);
        expect(
          controller.confirm(repo.compare('account', '-25', 'overdraft')),
          true,
        );
        expect(source.rows('transactions').single['type'], 'EXPENSE');
        expect(source.rows('transactions').single['amount'], '1025.00');
      });

      test(
        'invalid precision, overflow, references and non-owned accounts reject',
        () {
          for (final value in ['1.01', '1e3', '1,000', '9007199254740992']) {
            expect(
              () => repo.compare('account', value, 'ref'),
              throwsA(isA<ApiFailure>()),
            );
          }
          for (final id in ['foreign', 'usd', 'deleted', 'missing']) {
            expect(
              () => repo.compare(id, '100', 'ref'),
              throwsA(isA<ApiFailure>()),
            );
          }
          expect(
            () => repo.compare('account', '100', ''),
            throwsA(isA<ApiFailure>()),
          );
          expect(
            () => repo.compare('account', '100', 'x' * 501),
            throwsA(isA<ApiFailure>()),
          );
          expect(source.outbox, isEmpty);
        },
      );

      test(
        'mapped obligation, parent and investment accounts cannot reconcile',
        () {
          source.atomic(() {
            source.entities['obligations'] = {
              'loan': {
                'id': 'loan',
                'user_id': 'owner',
                'linked_account_id': 'account',
              },
            };
            (source.entities['accounts'] as Map)['second'] = {
              ...source.row('accounts', 'second')!,
              'parent_account_id': 'account',
            };
          });
          expect(
            () => repo.compare('account', '100', 'ref'),
            throwsA(isA<ApiFailure>()),
          );
          source.atomic(() {
            source.entities['obligations'] = <String, dynamic>{};
          });
          expect(
            () => repo.compare('account', '100', 'ref'),
            throwsA(isA<ApiFailure>()),
          );
          source.atomic(() {
            (source.entities['accounts'] as Map)['second'] = {
              ...source.row('accounts', 'second')!,
              'parent_account_id': null,
            };
            (source.entities['accounts'] as Map)['account'] = {
              ...source.row('accounts', 'account')!,
              'account_type_id': 'investment',
            };
          });
          expect(
            () => repo.compare('account', '100', 'ref'),
            throwsA(isA<ApiFailure>()),
          );
        },
      );

      test('stale preview and owner switch never mutate balances', () {
        final preview = repo.compare('account', '1200', 'ref');
        source.atomic(() {
          (source.entities['accounts'] as Map)['account'] = {
            ...source.row('accounts', 'account')!,
            'balance': '1100.00',
          };
        });
        expect(controller.confirm(preview), false);
        expect(controller.error, contains('Saldo berubah'));
        expect(source.outbox, isEmpty);
        state.currentUserId = 'other';
        expect(controller.confirm(preview), false);
        expect(source.outbox, isEmpty);
      });
    });
  }
}
