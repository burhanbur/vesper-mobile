import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/database/local_store.dart';
import 'package:vesper_mobile/features/goals/data/goals_repository.dart';
import 'package:vesper_mobile/features/goals/data/goals_controller.dart';
import 'package:vesper_mobile/features/sync/data/finance_repository.dart';

class GoalClient extends ApiClient {
  Completer<void>? pullGate, pullEntered;
  bool loseResponse = false;
  int version = 0;
  final received = <String>{};
  final changes = <Map<String, dynamic>>[];
  final rows = <String, Map<String, dynamic>>{};
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
      final results = <Map<String, dynamic>>[];
      for (final item in body!['items'] as List) {
        final key = '${item['entity_type']}:${item['entity_id']}';
        final receipt = '$key:${item['client_version']}:${item['operation']}';
        if (received.add(receipt)) {
          final old = rows[key];
          final row = <String, dynamic>{
            ...?old,
            ...?item['payload'] as Map?,
            'id': item['entity_id'],
            'user_id': 'owner',
            'status': 'ACTIVE',
            'version': '${int.parse('${old?['version'] ?? '0'}') + 1}',
            'created_at': old?['created_at'] ?? '2026-10-21T00:00:00Z',
          };
          rows[key] = row;
          changes.add({
            'entity_type': item['entity_type'],
            'entity_id': item['entity_id'],
            'operation': item['operation'],
            'payload': row,
            'version': '${++version}',
          });
        }
        results.add({
          'index': results.length,
          'entity_id': item['entity_id'],
          'status': 'applied',
          'server_data': rows[key],
        });
      }
      if (loseResponse) {
        loseResponse = false;
        throw const ApiFailure('Lost response');
      }
      return {'results': results};
    }
    if (path == '/sync/pull') {
      pullEntered?.complete();
      await pullGate?.future;
      return {
        'changes': changes
            .where(
              (c) =>
                  int.parse('${c['version']}') >
                  int.parse('${query!['since_version']}'),
            )
            .toList(),
        'next_version': '$version',
        'has_more': false,
      };
    }
    throw const ApiFailure('Unsupported test endpoint');
  }
}

void seedGoals(FinanceRepository source) {
  source.atomic(() {
    source.entities['account_types'] = <String, dynamic>{
      'cash': <String, dynamic>{
        'id': 'cash',
        'user_id': 'owner',
        'category': 'CASH',
      },
    };
    source.entities['accounts'] = <String, dynamic>{
      'cash': <String, dynamic>{
        'id': 'cash',
        'user_id': 'owner',
        'account_type_id': 'cash',
        'currency': 'IDR',
        'name': 'Cash',
        'balance': '1000.00',
        'version': '1',
      },
    };
    source.entities['groups'] = <String, dynamic>{
      'house': <String, dynamic>{
        'id': 'house',
        'name': 'House',
        'is_active': true,
      },
    };
    source.state['goal_history_coverage'] = {
      'schema': 1,
      'user_id': 'owner',
      'complete': true,
    };
  });
}

void acceptGoals(FinanceRepository source) {
  source.atomic(() {
    source.outbox.clear();
    for (final type in ['goals', 'goal_allocations']) {
      source.entities[type] = <String, dynamic>{
        for (final row in source.rows(type))
          row['id'] as String: {...row, 'version': '1'},
      };
    }
  });
}

void main() {
  for (final indexed in [false, true]) {
    group(indexed ? 'indexed goals' : 'snapshot goals', () {
      late LocalStore store;
      late FinanceRepository source;
      late GoalsRepository repo;
      late GoalClient client;
      Directory? temporary;
      setUp(() {
        if (indexed) {
          temporary = Directory.systemTemp.createTempSync('vesper-goals-test-');
        }
        store = indexed
            ? LocalStore.indexed(
                sqlite3.open('${temporary!.path}/finance.sqlite'),
                key: List.generate(32, (i) => i),
                userId: 'owner',
              )
            : LocalStore(sqlite3.openInMemory());
        client = GoalClient();
        source = FinanceRepository(client, store, 'owner')..offline = true;
        seedGoals(source);
        repo = GoalsRepository(source);
      });
      tearDown(() {
        store.close();
        if (temporary != null) {
          final directory = temporary!.absolute;
          if (directory.parent.path != Directory.systemTemp.absolute.path ||
              !directory.path.contains('vesper-goals-test-')) {
            throw StateError('Unsafe cleanup');
          }
          directory.deleteSync(recursive: true);
          temporary = null;
        }
      });
      String create({String target = '1000', String? group}) => repo.create(
        name: 'Emergency',
        target: target,
        currency: 'IDR',
        targetDate: '2030-12-31',
        groupId: group,
      );
      test('creation and allocation never create expenses or move cash', () {
        final id = create();
        acceptGoals(source);
        repo.allocate(id, 'cash', '600.25');
        expect(source.row('accounts', 'cash')!['balance'], '1000.00');
        expect(source.rows('transactions'), isEmpty);
        expect(repo.progress(repo.goals.single).funded, goalMinor('600.25'));
        expect(repo.available('cash'), goalMinor('399.75'));
        expect(source.outbox.single['entity_type'], 'goal_allocations');
        final restored = FinanceRepository(client, store, 'owner');
        expect(restored.rows('goal_allocations').single['amount'], '600.25');
      });
      test('one cash balance cannot fund two goals twice; withdrawal releases capacity', () {
        final first = create(), second = create();
        acceptGoals(source);
        repo.allocate(first, 'cash', '800');
        acceptGoals(source);
        expect(
          () => repo.allocate(second, 'cash', '200.01'),
          throwsA(isA<ApiFailure>()),
        );
        repo.allocate(first, 'cash', '500');
        acceptGoals(source);
        repo.allocate(second, 'cash', '500');
        expect(repo.available('cash'), BigInt.zero);
        expect(
          repo.backing().values.fold(BigInt.zero, (sum, a) => sum + a),
          goalMinor('1000'),
        );
      });
      test('cash spending reduces backed progress oldest-first', () {
        final first = create(), second = create();
        acceptGoals(source);
        repo.allocate(first, 'cash', '600');
        acceptGoals(source);
        repo.allocate(second, 'cash', '400');
        acceptGoals(source);
        final a = repo.allocations.first;
        source.atomic(() {
          final entries = source.rows('goal_allocations');
          source.entities['goal_allocations'] = <String, dynamic>{
            for (final e in entries)
              e['id'] as String: {
                ...e,
                'created_at': e['id'] == a['id']
                    ? '2026-01-01T00:00:00Z'
                    : '2026-02-01T00:00:00Z',
              },
          };
          (source.entities['accounts'] as Map)['cash'] = {
            ...source.row('accounts', 'cash')!,
            'balance': '400.00',
          };
        });
        expect(
          repo.progress(repo.goals.firstWhere((g) => g['id'] == first)).funded,
          goalMinor('400'),
        );
        expect(
          repo.progress(repo.goals.firstWhere((g) => g['id'] == second)).funded,
          BigInt.zero,
        );
        expect(
          repo
              .progress(repo.goals.firstWhere((g) => g['id'] == first))
              .shortfall,
          goalMinor('200'),
        );
      });
      test('completion checks funding and keeps reservation until explicitly withdrawn', () {
        final id = create();
        acceptGoals(source);
        void finish() => repo.update(
          id,
          name: 'Done',
          target: '1000',
          targetDate: '2030-12-31',
          status: 'COMPLETED',
        );
        expect(finish, throwsA(isA<ApiFailure>()));
        repo.allocate(id, 'cash', '1000');
        acceptGoals(source);
        finish();
        expect(repo.goals.single['status'], 'COMPLETED');
        expect(repo.available('cash'), BigInt.zero);
        acceptGoals(source);
        repo.allocate(id, 'cash', '0');
        expect(repo.available('cash'), goalMinor('1000'));
      });
      test(
        'UTC linear pace and rounded-up monthly contribution are deterministic',
        () {
          final goal = <String, dynamic>{
            'id': 'g',
            'target_amount': '100.00',
            'start_date': '2026-01-01',
            'target_date': '2026-01-11',
          };
          final p = repo.progress(goal, now: DateTime.utc(2026, 1, 6));
          expect(p.expected, goalMinor('50'));
          expect(p.monthly, goalMinor('100'));
          expect(p.onTrack, false);
          expect(
            repo.progress(goal, now: DateTime.utc(2026, 1, 12)).overdue,
            true,
          );
          goal['target_date'] = '2026-03-11';
          expect(
            repo.progress(goal, now: DateTime.utc(2026, 1, 1)).monthly,
            goalMinor('33.34'),
          );
        },
      );
      test(
        'household sharing never grants owner edits or foreign cash allocation',
        () {
          final id = create(group: 'house');
          acceptGoals(source);
          source.atomic(() {
            (source.entities['goals'] as Map)[id] = {
              ...source.row('goals', id)!,
              'user_id': 'other',
            };
            source.entities['goal_allocations'] = <String, dynamic>{
              'foreign': <String, dynamic>{
                'id': 'foreign',
                'goal_id': id,
                'user_id': 'other',
                'account_id': null,
                'amount': '50.00',
                'backed_amount': '40.00',
                'created_at': '2026-01-01T00:00:00Z',
              },
            };
          });
          expect(repo.progress(repo.goals.single).funded, goalMinor('40'));
          expect(() => repo.remove(id), throwsA(isA<ApiFailure>()));
          expect(
            () => repo.allocate(id, 'foreign', '10'),
            throwsA(isA<ApiFailure>()),
          );
          repo.allocate(id, 'cash', '10');
          acceptGoals(source);
          source.atomic(() {
            source.entities['groups'] = <String, dynamic>{};
          });
          expect(repo.goals, isEmpty);
          repo.allocate(id, 'cash', '0');
          expect(repo.available('cash'), goalMinor('1000'));
        },
      );
      test(
        'invalid precision/dates and uninitialized allocation history reject',
        () {
          expect(() => create(target: '0.001'), throwsA(isA<ApiFailure>()));
          expect(() => goalDate('2026-02-30'), throwsA(isA<ApiFailure>()));
          final id = create();
          acceptGoals(source);
          source.atomic(() {
            source.state['goal_history_coverage'] = {'complete': false};
          });
          expect(
            () => repo.allocate(id, 'cash', '10'),
            throwsA(isA<ApiFailure>()),
          );
        },
      );
      test('opening goals during an existing sync requires its own history bootstrap', () async {
        source.atomic(() {
          source.state.remove('goal_history_coverage');
        });
        client.pullGate = Completer<void>();
        client.pullEntered = Completer<void>();
        source.offline = false;
        final syncing = source.sync();
        await client.pullEntered!.future;
        final opened = GoalsRepository(source);
        client.pullGate!.complete();
        await syncing;
        expect(opened.complete, false);
        client.pullEntered = null;
        client.pullGate = null;
        await source.sync();
        expect(opened.complete, true);
      });
      test('rejected changes can retry or discard while pending delivery stays protected', () {
        final id = create();
        final queueId = source.outbox.single['id'] as String;
        expect(
          () => repo.recover(queueId, discard: true),
          throwsA(isA<ApiFailure>()),
        );
        source.atomic(() {
          source.outbox.single['status'] = 'rejected';
        });
        repo.recover(queueId);
        expect(source.outbox.single['status'], 'pending');
        source.atomic(() {
          source.outbox.single['status'] = 'rejected';
        });
        repo.recover(queueId, discard: true);
        expect(source.outbox, isEmpty);
        expect(source.row('goals', id), isNull);
      });
      test(
        'lost push response retries immutable identity without duplicate goals',
        () async {
          final id = create();
          source.offline = false;
          client.loseResponse = true;
          await expectLater(source.sync(), throwsA(isA<ApiFailure>()));
          expect(source.outbox, hasLength(1));
          await source.sync();
          expect(client.received, hasLength(1));
          expect(source.outbox, isEmpty);
          expect(source.row('goals', id)!['version'], '1');
          expect(repo.complete, true);
        },
      );
      test('session switch and persistence failure cannot partially allocate', () {
        final id = create();
        acceptGoals(source);
        final state = AppState(repository: source)..currentUserId = 'other';
        final controller = GoalsController(
          repo,
          () => state.currentUserId == 'owner',
          () {},
        );
        expect(controller.save(() => repo.allocate(id, 'cash', '100')), false);
        controller.dispose();
        state.dispose();
        final before = jsonEncode(source.state);
        final table = indexed ? 'entity_records' : 'state';
        store.database.execute(
          "CREATE TRIGGER fail_goal_save BEFORE UPDATE ON $table BEGIN SELECT RAISE(ABORT, 'fail'); END",
        );
        store.database.execute(
          "CREATE TRIGGER fail_goal_insert BEFORE INSERT ON $table BEGIN SELECT RAISE(ABORT, 'fail'); END",
        );
        expect(() => repo.allocate(id, 'cash', '100'), throwsA(anything));
        expect(jsonEncode(source.state), before);
        expect(jsonEncode(store.read()), before);
      });
    });
  }
}
