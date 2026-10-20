import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/database/local_store.dart';
import 'package:vesper_mobile/features/obligations/data/obligations_repository.dart';
import 'package:vesper_mobile/features/sync/data/finance_repository.dart';

const cashId = '11111111-1111-4111-8111-111111111111';
const mappedId = '22222222-2222-4222-8222-222222222222';

class ObligationClient extends ApiClient {
  bool lose = false, interruptPull = false;
  final deliveries = <String>[];
  List<Map<String, dynamic>> changes = [];
  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    bool authenticated = true,
    bool retry = true,
  }) async {
    if (path == '/devices') return {};
    if (path == '/sync/push') {
      final command = (body!['items'] as List).single as Map;
      deliveries.add(jsonEncode(command));
      if (lose) throw const ApiFailure('Lost response');
      return {
        'results': [
          {'index': 0, 'entity_id': command['entity_id'], 'status': 'applied'},
        ],
      };
    }
    if (path == '/sync/pull') {
      final first = query!['since_version'] == '0';
      if (!first && interruptPull) throw const ApiFailure('Interrupted pull');
      return {
        'changes': first ? changes.take(1).toList() : changes.skip(1).toList(),
        'next_version': first ? '1' : '2',
        'has_more': first,
      };
    }
    throw StateError(path);
  }
}

void seedObligations(FinanceRepository source) {
  source.atomic(() {
    source.entities['account_types'] = {
      'cashType': {'id': 'cashType', 'user_id': 'owner', 'category': 'CASH'},
    };
    source.entities['accounts'] = {
      cashId: {
        'id': cashId,
        'user_id': 'owner',
        'name': 'Cash',
        'currency': 'IDR',
        'balance': '1000.00',
        'account_type_id': 'cashType',
        'version': '1',
      },
    };
    source.entities['categories'] = {
      'cost': {
        'id': 'cost',
        'user_id': 'owner',
        'type': 'EXPENSE',
        'version': '1',
      },
      'interest': {
        'id': 'interest',
        'user_id': 'owner',
        'type': 'INCOME',
        'version': '1',
      },
    };
    for (final key in [
      'obligation_history_coverage',
      'investment_history_coverage',
    ]) {
      source.state[key] = {
        'schema': 1,
        'user_id': 'owner',
        'complete': true,
        'cursor': source.state['cursor'],
      };
    }
  });
}

// Used only by pure projection tests; transport reconciliation is tested below.
void acceptProjection(FinanceRepository source) {
  source.atomic(() {
    source.outbox.clear();
    for (final type in ['obligations', 'obligation_events', 'transactions']) {
      source.entities[type] = {
        for (final row in source.rows(type))
          row['id'] as String: {...row, 'version': '1'},
      };
    }
  });
}

void main() {
  for (final indexed in [false, true]) {
    group(indexed ? 'encrypted indexed obligations' : 'snapshot obligations', () {
      late LocalStore store;
      late ObligationClient client;
      late FinanceRepository source;
      late ObligationsRepository repo;
      Directory? temporary;
      setUp(() {
        if (indexed) {
          temporary = Directory.systemTemp.createTempSync(
            'vesper-obligation-test-',
          );
          store = LocalStore.indexed(
            sqlite3.open(
              '${temporary!.path}${Platform.pathSeparator}finance.sqlite',
            ),
            key: List.generate(32, (i) => i),
            userId: 'owner',
          );
        } else {
          store = LocalStore(sqlite3.openInMemory());
        }
        client = ObligationClient();
        source = FinanceRepository(client, store, 'owner');
        repo = ObligationsRepository(source);
        seedObligations(source);
      });
      tearDown(() {
        store.close();
        if (temporary != null) {
          final dir = temporary!;
          if (dir.parent.absolute.path != Directory.systemTemp.absolute.path ||
              !dir.path.contains('vesper-obligation-test-')) {
            throw StateError('Invalid test cleanup');
          }
          dir.deleteSync(recursive: true);
        }
      });
      String open({
        String kind = 'PAYABLE',
        String? mapped,
        bool fund = true,
      }) => repo.open(
        kind: kind,
        counterparty: 'Person',
        principal: '100',
        dueDate: '2026-12-20',
        installments: '2026-11-20=40\n2026-12-20=60',
        cashAccountId: fund ? cashId : null,
        linkedAccountId: mapped,
      );
      void serverProjection() {
        final keys = (source.outbox.single['required_snapshots'] as List)
            .cast<String>();
        client.changes = keys.map((key) {
          final colon = key.indexOf(':');
          final type = key.substring(0, colon), id = key.substring(colon + 1);
          final row = source.row(type, id)!;
          return <String, dynamic>{
            'entity_type': type,
            'entity_id': id,
            'operation': row['deleted_at'] == null ? 'UPDATE' : 'DELETE',
            'payload': row['deleted_at'] == null
                ? {...row, 'version': '1'}
                : null,
          };
        }).toList();
      }

      test('funding and payments persist exact principal, costs, cash and installment allocation', () {
        open();
        final id = repo.records.single['id'] as String;
        expect(source.row('accounts', cashId)!['balance'], '1100.00');
        expect(source.rows('transactions').single['type'], 'TRANSFER');
        acceptProjection(source);
        repo.repay(
          id,
          cashAccountId: cashId,
          principal: '40',
          interest: '2.01',
          fee: '1.02',
          interestCategoryId: 'cost',
          feeCategoryId: 'cost',
        );
        expect(source.row('accounts', cashId)!['balance'], '1056.97');
        expect(repo.records.single['outstanding'], '60.00');
        expect(repo.schedule(id).map((r) => r['remaining']), ['0.00', '60.00']);
        final state = AppState(repository: source);
        expect(
          state.totalNetWorth,
          996,
        ); // Whole-Rupiah rendering of exact 996.97.
        source.atomic(
          () =>
              (source.state['obligation_history_coverage'] as Map)['complete'] =
                  false,
        );
        expect(
          state.totalNetWorth,
          996,
        ); // Re-sync must retain known obligations.
        state.dispose();
        final reload = FinanceRepository(client, store, 'owner');
        expect(reload.outbox.single['payload']['principal'], '40.00');
        expect(reload.row('accounts', cashId)!['balance'], '1056.97');
      });
      test('receivable repayments increase cash by principal plus interest less fees', () {
        open(kind: 'RECEIVABLE');
        final id = repo.records.single['id'] as String;
        expect(source.row('accounts', cashId)!['balance'], '900.00');
        acceptProjection(source);
        repo.repay(
          id,
          cashAccountId: cashId,
          principal: '100',
          interest: '3',
          fee: '1',
          interestCategoryId: 'interest',
          feeCategoryId: 'cost',
        );
        expect(source.row('accounts', cashId)!['balance'], '1002.00');
        expect(repo.records.single['outstanding'], '0.00');
      });
      test('mapped balances are replaced in net worth and protected against ordinary edits', () {
        source.atomic(
          () => source.entities['accounts'] = {
            ...source.entities['accounts'] as Map,
            mappedId: {
              'id': mappedId,
              'user_id': 'owner',
              'currency': 'IDR',
              'balance': '-100.00',
              'account_type_id': 'cashType',
              'version': '1',
            },
          },
        );
        open(fund: false, mapped: mappedId);
        final id = repo.records.single['id'] as String;
        acceptProjection(source);
        expect(
          () =>
              source.mutate('transactions', 'CREATE', {'account_id': mappedId}),
          throwsA(isA<ApiFailure>()),
        );
        repo.repay(id, cashAccountId: cashId, principal: '40');
        expect(source.row('accounts', cashId)!['balance'], '960.00');
        expect(source.row('accounts', mappedId)!['balance'], '-60.00');
        final state = AppState(repository: source);
        expect(state.totalNetWorth, 900);
        state.dispose();
      });
      test('repayment correction restores all related rows and untouched deletion reverses funding', () {
        open();
        final id = repo.records.single['id'] as String;
        acceptProjection(source);
        final pay = repo.repay(
          id,
          cashAccountId: cashId,
          principal: '40',
          interest: '2',
          fee: '1',
          interestCategoryId: 'cost',
          feeCategoryId: 'cost',
        );
        acceptProjection(source);
        repo.reverse(id, pay);
        expect(repo.records.single['outstanding'], '100.00');
        expect(source.row('accounts', cashId)!['balance'], '1100.00');
        expect(source.row('obligation_events', pay)!['reversed_at'], isNotNull);
        acceptProjection(source);
        repo.delete(id);
        expect(repo.records, isEmpty);
        expect(source.row('accounts', cashId)!['balance'], '1000.00');
      });
      test('lost acknowledgement reuses original envelope and split pull reconciles once', () async {
        open();
        serverProjection();
        client.lose = true;
        await expectLater(source.sync(), throwsA(isA<ApiFailure>()));
        final envelope = client.deliveries.single;
        source = FinanceRepository(client, store, 'owner');
        client.lose = false;
        client.interruptPull = true;
        await expectLater(source.sync(), throwsA(isA<ApiFailure>()));
        expect(source.outbox.single['status'], 'acknowledged');
        source = FinanceRepository(client, store, 'owner');
        client.interruptPull = false;
        await source.sync();
        expect(client.deliveries.last, envelope);
        expect(source.outbox, isEmpty);
        expect(source.row('accounts', cashId)!['balance'], '1100.00');
        expect(source.rows('obligations').single['outstanding'], '100.00');
      });
      test('cancellation waits for authoritative absence before removing optimistic cash', () async {
        final eventId = open();
        final debtId = repo.records.single['id'] as String;
        final queue = source.outbox.single;
        source.retryObligationCommand(queue['id'] as String, cancel: true);
        final keys = (queue['required_snapshots'] as List).cast<String>();
        client.changes = keys.map((key) {
          final i = key.indexOf(':');
          final type = key.substring(0, i), id = key.substring(i + 1);
          return <String, dynamic>{
            'entity_type': type,
            'entity_id': id,
            'operation': type == 'accounts' || type == 'obligation_events'
                ? 'UPDATE'
                : 'DELETE',
            'payload': type == 'accounts'
                ? {...source.row(type, id)!, 'balance': '1000.00'}
                : type == 'obligation_events'
                ? {...source.row(type, id)!, 'operation': 'CANCEL'}
                : null,
          };
        }).toList();
        expect(source.row('accounts', cashId)!['balance'], '1100.00');
        await source.sync();
        expect(source.outbox, isEmpty);
        expect(source.row('accounts', cashId)!['balance'], '1000.00');
        expect(source.row('obligations', debtId), isNull);
        expect(
          source.row('obligation_events', eventId)!['operation'],
          'CANCEL',
        );
      });
      test('commit failure rolls back obligation, ledger, outbox and cash together', () {
        store.database.execute(
          "CREATE TRIGGER fail_obligation BEFORE UPDATE ON ${indexed ? 'store_info' : 'state'} BEGIN SELECT RAISE(ABORT, 'disk'); END",
        );
        expect(open, throwsA(isA<SqliteException>()));
        expect(repo.records, isEmpty);
        expect(source.outbox, isEmpty);
        expect(source.row('accounts', cashId)!['balance'], '1000.00');
      });
      test('invalid precision, schedule, oversettlement and duplicate offline submission are rejected', () {
        expect(
          () =>
              repo.open(kind: 'PAYABLE', counterparty: 'A', principal: '0.001'),
          throwsA(isA<ApiFailure>()),
        );
        expect(
          () => repo.open(
            kind: 'PAYABLE',
            counterparty: 'A',
            principal: '100',
            installments: '2026-11-20=40',
          ),
          throwsA(isA<ApiFailure>()),
        );
        open();
        expect(open, throwsA(isA<ApiFailure>()));
        acceptProjection(source);
        final id = repo.records.single['id'] as String;
        expect(
          () => repo.repay(id, cashAccountId: cashId, principal: '101'),
          throwsA(isA<ApiFailure>()),
        );
        expect(source.outbox, isEmpty);
      });
    });
  }
}
