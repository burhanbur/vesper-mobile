import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/database/local_store.dart';
import 'package:vesper_mobile/features/sync/data/finance_repository.dart';

const portfolio = '11111111-1111-4111-8111-111111111111';
const cash = '22222222-2222-4222-8222-222222222222';
const instrument = '33333333-3333-4333-8333-333333333333';

class TradeClient extends ApiClient {
  bool lose = false;
  bool failSecondPage = false;
  bool omitCashLeg = false;
  String status = 'applied';
  final deliveries = <String>[];
  Map? command;
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
      command = (body!['items'] as List).single as Map;
      deliveries.add(jsonEncode(command));
      if (lose) throw const ApiFailure('Lost acknowledgement');
      return {
        'results': [
          {'index': 0, 'entity_id': command!['entity_id'], 'status': status},
        ],
      };
    }
    if (path == '/sync/pull') {
      final p = command!['payload'] as Map;
      final second = query!['since_version'] == '1';
      if (second && failSecondPage) throw const ApiFailure('Interrupted pull');
      return {
        'changes': second
            ? [
                {
                  'entity_type': 'investment_transactions',
                  'entity_id': command!['entity_id'],
                  'operation': 'CREATE',
                  'payload': {
                    ...p,
                    'id': command!['entity_id'],
                    'version': '1',
                  },
                },
                if (!omitCashLeg)
                  {
                    'entity_type': 'transactions',
                    'entity_id': p['linked_transaction_id'],
                    'operation': 'CREATE',
                    'payload': {
                      'id': p['linked_transaction_id'],
                      'account_id': cash,
                      'category_id': null,
                      'type': p['type'] == 'DIVIDEND' ? 'INCOME' : 'EXPENSE',
                      'amount': '10.01',
                      'version': '1',
                    },
                  },
              ]
            : [
                {
                  'entity_type': 'accounts',
                  'entity_id': cash,
                  'operation': 'UPDATE',
                  'payload': {
                    'id': cash,
                    'user_id': 'actor',
                    'account_type_id': 'cashType',
                    'currency': 'IDR',
                    'balance': p['type'] == 'DIVIDEND' ? '110.01' : '89.99',
                    'version': '2',
                  },
                },
              ],
        'next_version': second ? '2' : '1',
        'has_more': !second,
      };
    }
    throw StateError(path);
  }
}

void main() {
  for (final indexed in [false, true]) {
    group(indexed ? 'indexed v3' : 'legacy snapshot', () {
      Directory? temporary;
      late LocalStore store;
      late TradeClient client;
      late FinanceRepository repo;
      setUp(() {
        if (indexed) {
          temporary = Directory.systemTemp.createTempSync(
            'vesper-finance-test-',
          );
          store = LocalStore.indexed(
            sqlite3.open(
              '${temporary!.path}${Platform.pathSeparator}finance.sqlite',
            ),
            key: List.generate(32, (index) => index),
            userId: 'actor',
          );
        } else {
          store = LocalStore(sqlite3.openInMemory());
        }
        client = TradeClient();
        repo = FinanceRepository(client, store, 'actor');
        repo.atomic(() {
          repo.entities['accounts'] = {
            portfolio: {
              'id': portfolio,
              'user_id': 'actor',
              'account_type_id': 'investType',
              'currency': 'IDR',
              'balance': '0.00',
            },
            cash: {
              'id': cash,
              'user_id': 'actor',
              'account_type_id': 'cashType',
              'currency': 'IDR',
              'balance': '100.00',
            },
          };
          repo.entities['account_types'] = {
            'investType': {
              'id': 'investType',
              'user_id': 'actor',
              'category': 'INVESTMENT',
            },
            'cashType': {
              'id': 'cashType',
              'user_id': 'actor',
              'category': 'CASH',
            },
          };
          repo.entities['instruments'] = {
            instrument: {'id': instrument, 'currency': 'IDR'},
          };
          repo.state['investment_history_coverage'] = {
            'schema': 1,
            'user_id': 'actor',
            'complete': true,
            'cursor': repo.state['cursor'],
          };
        });
      });
      tearDown(() {
        store.close();
        if (temporary != null) {
          final directory = temporary!;
          if (directory.parent.absolute.path !=
                  Directory.systemTemp.absolute.path ||
              !directory.path.contains('vesper-finance-test-')) {
            throw StateError('Unexpected test directory');
          }
          directory.deleteSync(recursive: true);
          temporary = null;
        }
      });
      String buy() => repo.createInvestmentTrade(
        accountId: portfolio,
        cashAccountId: cash,
        instrumentId: instrument,
        type: 'BUY',
        quantity: '1',
        pricePerUnit: '10.005',
        at: DateTime.utc(2026, 10, 15),
      );

      test(
        'DIVIDEND survives lost acknowledgement without doubling cash or units',
        () async {
          repo.createInvestmentTrade(
            accountId: portfolio,
            cashAccountId: cash,
            instrumentId: instrument,
            type: 'DIVIDEND',
            quantity: '1',
            pricePerUnit: '10.005',
            at: DateTime.utc(2026, 10, 15),
          );
          expect(repo.row('accounts', cash)!['balance'], '110.01');
          expect(
            repo.investmentHistory(portfolio).position(instrument).quantity,
            '0.00000000',
          );
          client.lose = true;
          await expectLater(repo.sync(), throwsA(isA<ApiFailure>()));
          final envelope = client.deliveries.single;
          repo = FinanceRepository(client, store, 'actor');
          client.lose = false;
          await repo.sync();
          expect(client.deliveries.last, envelope);
          expect(repo.outbox, isEmpty);
          expect(repo.row('accounts', cash)!['balance'], '110.01');
          expect(repo.rows('transactions'), hasLength(1));
          expect(
            repo.investmentHistory(portfolio).position(instrument).quantity,
            '0.00000000',
          );
        },
      );

      test(
        'atomic projection survives restart and split feed replaces cash once',
        () async {
          final id = buy();
          expect(repo.row('accounts', cash)!['balance'], '89.99');
          expect(
            repo.investmentHistory(portfolio).position(instrument).quantity,
            '1.00000000',
          );
          repo = FinanceRepository(client, store, 'actor');
          expect(repo.row('investment_transactions', id), isNotNull);
          client.lose = true;
          await expectLater(repo.sync(), throwsA(isA<ApiFailure>()));
          final envelope = client.deliveries.single;
          repo = FinanceRepository(client, store, 'actor');
          client.lose = false;
          await repo.sync();
          expect(client.deliveries.last, envelope);
          expect(repo.outbox, isEmpty);
          expect(repo.row('accounts', cash)!['balance'], '89.99');
          expect(repo.rows('transactions'), hasLength(1));
          expect(
            repo.investmentHistory(portfolio).position(instrument).quantity,
            '1.00000000',
          );
        },
      );

      test(
        'acknowledged command stays durable through interrupted pull restart',
        () async {
          final id = buy();
          client.failSecondPage = true;
          await expectLater(repo.sync(), throwsA(isA<ApiFailure>()));
          repo = FinanceRepository(client, store, 'actor');
          expect(repo.outbox.single['status'], 'acknowledged');
          expect(repo.row('investment_transactions', id)!['version'], '0');
          expect(repo.hasCompleteInvestmentHistory, false);
          client.failSecondPage = false;
          await repo.sync();
          expect(client.deliveries, hasLength(1));
          expect(repo.outbox, isEmpty);
          expect(repo.row('investment_transactions', id)!['version'], '1');
          expect(repo.row('accounts', cash)!['balance'], '89.99');
        },
      );

      test(
        'missing settlement row never discards acknowledged command',
        () async {
          final id = buy();
          client.omitCashLeg = true;
          await repo.sync();
          repo = FinanceRepository(client, store, 'actor');
          expect(repo.outbox.single['status'], 'acknowledged');
          expect(repo.row('investment_transactions', id)!['version'], '0');
          expect(repo.row('accounts', cash)!['balance'], '89.99');
          expect(buy, throwsA(isA<ApiFailure>()));
        },
      );

      test('rejection retains original envelope and blocks unsafe rebase and edits', () async {
        buy();
        client.status = 'rejected';
        await repo.sync();
        expect(repo.outbox.single['status'], 'rejected');
        expect(
          () => repo.resolve(repo.outbox.single['id'] as String, useMine: true),
          throwsA(isA<ApiFailure>()),
        );
        expect(buy, throwsA(isA<ApiFailure>()));
        expect(
          () => repo.mutate('accounts', 'UPDATE', {'name': 'edited'}, id: cash),
          throwsA(isA<ApiFailure>()),
        );
        expect(repo.row('accounts', cash)!['balance'], '89.99');
      });

      test('SELL projects exact remaining position and cash after restart', () {
        repo.entities['investment_transactions'] = {
          'prior': {
            'id': 'prior',
            'account_id': portfolio,
            'instrument_id': instrument,
            'type': 'BUY',
            'quantity': '2.00000000',
            'price_per_unit': '10.00000000',
            'transacted_at': '2026-10-14T00:00:00.000Z',
          },
        };
        repo.createInvestmentTrade(
          accountId: portfolio,
          cashAccountId: cash,
          instrumentId: instrument,
          type: 'SELL',
          quantity: '0.5',
          pricePerUnit: '20.01',
          fee: '0.01',
          at: DateTime.utc(2026, 10, 15),
        );
        repo = FinanceRepository(client, store, 'actor');
        expect(repo.row('accounts', cash)!['balance'], '110.00');
        final position = repo.investmentHistory(portfolio).position(instrument);
        expect(position.quantity, '1.50000000');
        expect(position.average, '10.00000000');
        expect(repo.outbox.single['payload']['type'], 'SELL');
      });

      test('failed atomic commit leaves no trade cash or outbox after restart', () {
        store.database.execute(
          "CREATE TRIGGER fail_trade BEFORE UPDATE ON ${indexed ? 'store_info' : 'state'} BEGIN SELECT RAISE(ABORT, 'disk'); END",
        );
        expect(buy, throwsA(isA<SqliteException>()));
        expect(repo.row('accounts', cash)!['balance'], '100.00');
        expect(repo.outbox, isEmpty);
        repo = FinanceRepository(client, store, 'actor');
        expect(repo.rows('investment_transactions'), isEmpty);
        expect(repo.rows('transactions'), isEmpty);
        expect(repo.outbox, isEmpty);
      });

      test(
        'instrument and account type dependencies block creation and edits',
        () {
          for (final dependency in [
            {'entity_type': 'instruments', 'entity_id': instrument},
            {'entity_type': 'account_types', 'entity_id': 'cashType'},
          ]) {
            repo.outbox.add(dependency);
            expect(buy, throwsA(isA<ApiFailure>()));
            repo.outbox.clear();
          }
          buy();
          expect(
            () => repo.mutate('instruments', 'DELETE', null, id: instrument),
            throwsA(isA<ApiFailure>()),
          );
          expect(
            () => repo.mutate('account_types', 'DELETE', null, id: 'cashType'),
            throwsA(isA<ApiFailure>()),
          );
          repo.entities['transactions'] = {
            'existing': {
              'id': 'existing',
              'account_id': cash,
              'category_id': 'category',
              'version': '1',
            },
          };
          expect(
            () => repo.mutate('transactions', 'UPDATE', {
              'account_id': 'elsewhere',
            }, id: 'existing'),
            throwsA(isA<ApiFailure>()),
          );
        },
      );

      test('oversell and hidden accounts fail without mutation', () {
        expect(
          () => repo.createInvestmentTrade(
            accountId: portfolio,
            cashAccountId: cash,
            instrumentId: instrument,
            type: 'SELL',
            quantity: '1',
            pricePerUnit: '1',
            at: DateTime.utc(2026, 10, 15),
          ),
          throwsA(isA<FormatException>()),
        );
        repo.entities['accounts'] = <String, dynamic>{
          ...repo.entities['accounts'] as Map,
          cash: <String, dynamic>{
            ...repo.row('accounts', cash)!,
            'is_visible': false,
          },
        };
        expect(buy, throwsA(isA<ApiFailure>()));
        expect(repo.outbox, isEmpty);
        expect(repo.row('accounts', cash)!['balance'], '100.00');
      });

      test(
        'conflict preserves stable command and optimistic rows after restart',
        () async {
          final id = buy();
          client.status = 'conflict';
          await repo.sync();
          repo = FinanceRepository(client, store, 'actor');
          expect(repo.outbox.single['status'], 'conflict');
          expect(repo.outbox.single['entity_id'], id);
          expect(repo.row('accounts', cash)!['balance'], '89.99');
          expect(
            () => repo.resolve(
              repo.outbox.single['id'] as String,
              useMine: false,
            ),
            throwsA(isA<ApiFailure>()),
          );
        },
      );

      test(
        'rejected command recovery retries original IDs after restart',
        () async {
          final id = buy();
          client.status = 'rejected';
          await repo.sync();
          final original = client.deliveries.single;
          repo = FinanceRepository(client, store, 'actor');
          repo.retryInvestmentTrade(repo.outbox.single['id'] as String);
          repo = FinanceRepository(client, store, 'actor');
          expect(repo.outbox.single['status'], 'pending');
          expect(repo.outbox.single['entity_id'], id);
          expect(repo.row('accounts', cash)!['balance'], '89.99');
          client.status = 'applied';
          await repo.sync();
          expect(client.deliveries.last, original);
          expect(repo.outbox, isEmpty);
          expect(repo.row('accounts', cash)!['balance'], '89.99');
        },
      );

      test('failed recovery commit keeps rejected command durable', () async {
        buy();
        client.status = 'conflict';
        await repo.sync();
        final queueId = repo.outbox.single['id'] as String;
        store.database.execute(
          "CREATE TRIGGER fail_retry BEFORE UPDATE ON ${indexed ? 'store_info' : 'state'} BEGIN SELECT RAISE(ABORT, 'disk'); END",
        );
        expect(
          () => repo.retryInvestmentTrade(queueId),
          throwsA(isA<SqliteException>()),
        );
        repo = FinanceRepository(client, store, 'actor');
        expect(repo.outbox.single['status'], 'conflict');
        expect(repo.row('accounts', cash)!['balance'], '89.99');
        expect(
          () => repo.retryInvestmentTrade('missing'),
          throwsA(isA<ApiFailure>()),
        );
      });

      test('ownership and incomplete history fail without writing', () {
        repo.entities['accounts'][cash]['user_id'] = 'other';
        expect(buy, throwsA(isA<ApiFailure>()));
        expect(repo.outbox, isEmpty);
        repo.entities['accounts'][cash]['user_id'] = 'actor';
        repo.state.remove('investment_history_coverage');
        expect(buy, throwsA(isA<ApiFailure>()));
        expect(repo.outbox, isEmpty);
      });
    });
  }
}
