import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/database/local_store.dart';
import 'package:vesper_mobile/features/emergency_funds/data/emergency_fund_repository.dart';
import 'package:vesper_mobile/features/emergency_funds/data/emergency_fund_controller.dart';
import 'package:vesper_mobile/features/goals/data/goals_repository.dart';
import 'package:vesper_mobile/features/sync/data/finance_repository.dart';

import 'goals_test.dart' show GoalClient, seedGoals;

void seedEmergency(FinanceRepository source) {
  seedGoals(source);
  source.atomic(() {
    source.entities['transactions'] = <String, dynamic>{};
    source.entities['categories'] = <String, dynamic>{
      'food': <String, dynamic>{
        'id': 'food',
        'user_id': 'owner',
        'name': 'Food',
        'type': 'EXPENSE',
        'version': '1',
      },
      'other': <String, dynamic>{
        'id': 'other',
        'user_id': 'owner',
        'name': 'Other',
        'type': 'EXPENSE',
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

Map<String, dynamic> emergencyConfig({
  String mode = 'MANUAL',
  String baseline = '300.00',
  int months = 6,
  List<String> accounts = const ['cash'],
  String? goal,
}) => {
  'currency': 'IDR',
  'baseline_mode': mode,
  'manual_baseline': mode == 'MANUAL' ? baseline : null,
  'coverage_months': months,
  'history_months': 3,
  'account_ids': accounts,
  'category_ids': ['food'],
  'goal_id': goal,
};

void main() {
  for (final indexed in [false, true]) {
    group(indexed ? 'indexed emergency fund' : 'snapshot emergency fund', () {
      late LocalStore store;
      late FinanceRepository source;
      late GoalClient client;
      late EmergencyFundRepository repo;
      Directory? temporary;
      setUp(() {
        if (indexed) {
          temporary = Directory.systemTemp.createTempSync(
            'vesper-emergency-test-',
          );
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
        seedEmergency(source);
        repo = EmergencyFundRepository(source);
      });
      tearDown(() {
        store.close();
        if (temporary != null) {
          final directory = temporary!.absolute;
          if (directory.parent.path != Directory.systemTemp.absolute.path ||
              !directory.path.contains('vesper-emergency-test-')) {
            throw StateError('Unsafe cleanup');
          }
          directory.deleteSync(recursive: true);
          temporary = null;
        }
      });
      void save({
        String mode = 'MANUAL',
        String baseline = '300',
        List<String> accounts = const ['cash'],
      }) => repo.save(
        mode: mode,
        manualBaseline: baseline,
        coverageMonths: 6,
        historyMonths: 3,
        accountIds: accounts,
        categoryIds: ['food'],
      );

      test('manual target and coverage use exact cents and never round up coverage', () {
        final r = repo.assess(emergencyConfig());
        expect(r.baseline, goalMinor('300'));
        expect(r.target, goalMinor('1800'));
        expect(r.liquid, goalMinor('1000'));
        expect(r.remaining, goalMinor('800'));
        expect(r.coverageHundredths, BigInt.from(333));
        final zero = repo.assess(emergencyConfig(baseline: '0.00'));
        expect(zero.coverageHundredths, isNull);
        expect(zero.target, isNull);
      });
      test('linked goal includes backing once and other reservations stay excluded', () {
        source.atomic(() {
          source.entities['goals'] = <String, dynamic>{
            for (final id in ['other', 'emergency'])
              id: <String, dynamic>{
                'id': id,
                'user_id': 'owner',
                'group_id': null,
                'currency': 'IDR',
                'target_amount': '5000.00',
                'target_date': '2030-01-01',
                'start_date': '2026-01-01',
              },
          };
          source.entities['goal_allocations'] = <String, dynamic>{
            for (final id in ['other', 'emergency'])
              id: <String, dynamic>{
                'id': id,
                'user_id': 'owner',
                'goal_id': id,
                'account_id': 'cash',
                'amount': id == 'other' ? '600.00' : '400.00',
                'created_at': id == 'other'
                    ? '2026-01-01T00:00:00Z'
                    : '2026-02-01T00:00:00Z',
              },
          };
        });
        expect(repo.assess(emergencyConfig()).liquid, BigInt.zero);
        expect(
          repo.assess(emergencyConfig(goal: 'emergency')).liquid,
          goalMinor('400'),
        );
        source.atomic(() {
          (source.entities['accounts'] as Map)['cash'] = {
            ...source.row('accounts', 'cash')!,
            'balance': '250.00',
          };
        });
        expect(
          repo.assess(emergencyConfig(goal: 'emergency')).liquid,
          BigInt.zero,
        );
        source.atomic(() {
          (source.entities['accounts'] as Map)['cash'] = {
            ...source.row('accounts', 'cash')!,
            'balance': '2000.00',
          };
        });
        expect(
          repo.assess(emergencyConfig(goal: 'emergency')).liquid,
          goalMinor('1400'),
        );
        expect(source.row('goals', 'emergency')!['target_amount'], '5000.00');
        expect(source.rows('transactions'), isEmpty);
      });
      test('history uses full UTC months, includes zero months and excludes transfers/current month', () {
        source.atomic(() {
          source.entities['transactions'] = <String, dynamic>{
            for (final data in [
              ['start', 'EXPENSE', '100.00', '2025-10-01T00:00:00Z', 'food'],
              [
                'last',
                'EXPENSE',
                '200.00',
                '2026-01-01T06:59:59+07:00',
                'food',
              ],
              ['current', 'EXPENSE', '999.00', '2026-01-01T00:00:00Z', 'food'],
              ['before', 'EXPENSE', '999.00', '2025-09-30T23:59:59Z', 'food'],
              [
                'transfer',
                'TRANSFER',
                '999.00',
                '2025-11-01T00:00:00Z',
                'food',
              ],
              [
                'optional',
                'EXPENSE',
                '999.00',
                '2025-11-01T00:00:00Z',
                'other',
              ],
              ['investment', 'EXPENSE', '999.00', '2025-11-01T00:00:00Z', ''],
            ])
              data[0]: <String, dynamic>{
                'id': data[0],
                'account_id': 'cash',
                'type': data[1],
                'amount': data[2],
                'transacted_at': data[3],
                'category_id': data[4],
                'version': '1',
              },
          };
        });
        final r = repo.assess(
          emergencyConfig(mode: 'HISTORY'),
          now: DateTime.utc(2026, 1, 15),
        );
        expect(r.historyStart, DateTime.utc(2025, 10, 1));
        expect(r.historyEnd, DateTime.utc(2026, 1, 1));
        expect(r.baseline, goalMinor('100'));
        expect(r.monthsWithExpenses, 2);
        expect(
          r.warnings.join(' '),
          contains('bulan tanpa transaksi dihitung nol'),
        );
      });
      test(
        'history pagination sums beyond 100 rows and ceiling preserves cents',
        () {
          source.atomic(() {
            source.entities['transactions'] = <String, dynamic>{
              for (var i = 0; i < 137; i++)
                '$i': <String, dynamic>{
                  'id': '$i',
                  'account_id': 'cash',
                  'type': 'EXPENSE',
                  'amount': '1.01',
                  'category_id': 'food',
                  'version': '0',
                  'transacted_at': '2025-12-15T00:00:00Z',
                },
            };
          });
          expect(
            repo
                .assess(
                  emergencyConfig(mode: 'HISTORY'),
                  now: DateTime.utc(2026, 1, 1),
                )
                .baseline,
            goalMinor('46.13'),
          );
        },
      );
      test('empty/incomplete history stays unknown and manual fallback remains available', () {
        final r = repo.assess(emergencyConfig(mode: 'HISTORY'));
        expect(r.baseline, isNull);
        expect(r.coverageHundredths, isNull);
        source.atomic(() {
          source.state.remove('transaction_snapshot_coverage');
        });
        expect(
          repo.assess(emergencyConfig(mode: 'HISTORY')).warnings.join(' '),
          contains('belum lengkap'),
        );
        expect(repo.assess(emergencyConfig()).baseline, goalMinor('300'));
        source.atomic(() {
          source.state['goal_history_coverage'] = {'complete': false};
        });
        expect(repo.assess(emergencyConfig()).liquid, isNull);
      });
      test('foreign, noncash, parent, mapped and currency-mismatched accounts are excluded', () {
        source.atomic(() {
          (source.entities['account_types']
              as Map)['investment'] = <String, dynamic>{
            'id': 'investment',
            'category': 'INVESTMENT',
            'user_id': 'owner',
          };
          for (final id in [
            'foreign',
            'stock',
            'usd',
            'parent',
            'pocket',
            'mapped',
          ]) {
            (source.entities['accounts'] as Map)[id] = <String, dynamic>{
              ...source.row('accounts', 'cash')!,
              'id': id,
              'user_id': id == 'foreign' ? 'other' : 'owner',
              'currency': id == 'usd' ? 'USD' : 'IDR',
              'account_type_id': id == 'stock' ? 'investment' : 'cash',
              if (id == 'pocket') 'parent_account_id': 'parent',
            };
          }
          source.entities['obligations'] = <String, dynamic>{
            'loan': <String, dynamic>{
              'id': 'loan',
              'user_id': 'owner',
              'linked_account_id': 'mapped',
            },
          };
        });
        final invalid = ['foreign', 'stock', 'usd', 'parent', 'mapped'];
        final r = repo.assess(emergencyConfig(accounts: invalid));
        expect(r.liquid, BigInt.zero);
        expect(r.accounts, isEmpty);
        expect(() => save(accounts: invalid), throwsA(isA<ApiFailure>()));
        source.atomic(() {
          (source.entities['accounts'] as Map)['cash'] = {
            ...source.row('accounts', 'cash')!,
            'balance': '-10.00',
          };
        });
        expect(repo.assess(emergencyConfig()).liquid, BigInt.zero);
      });
      test('settings persist atomically and invalid values cannot alter financial data', () {
        final before = source.row('accounts', 'cash');
        save();
        final restored = FinanceRepository(client, store, 'owner');
        expect(
          restored.rows('emergency_plans').single['manual_baseline'],
          '300.00',
        );
        expect(restored.outbox.single['entity_type'], 'emergency_plans');
        expect(source.row('accounts', 'cash'), before);
        expect(source.rows('transactions'), isEmpty);
        expect(() => save(baseline: '0'), throwsA(isA<ApiFailure>()));
        expect(() => save(baseline: '1.001'), throwsA(isA<ApiFailure>()));
      });
      test('lost acknowledgement and initial bootstrap during sync retain exact plan identity', () async {
        save();
        source.offline = false;
        client.loseResponse = true;
        await expectLater(source.sync(), throwsA(isA<ApiFailure>()));
        await source.sync();
        expect(source.outbox, isEmpty);
        expect(client.received, hasLength(1));
        expect(repo.complete, true);
        source.atomic(() {
          source.state.remove('emergency_plan_coverage');
        });
        client.pullGate = Completer<void>();
        client.pullEntered = Completer<void>();
        final syncing = source.sync();
        await client.pullEntered!.future;
        final opened = EmergencyFundRepository(source);
        client.pullGate!.complete();
        await syncing;
        expect(opened.complete, false);
        client.pullGate = null;
        client.pullEntered = null;
        await source.sync();
        expect(opened.complete, true);
      });
      test('session guard, rejection recovery and failed persistence leave no partial plan', () {
        final controller = EmergencyFundController(repo, () => false, () {});
        expect(controller.save(() => save()), false);
        controller.dispose();
        expect(repo.plan, isNull);
        final before = jsonEncode(source.state);
        final table = indexed ? 'entity_records' : 'state';
        store.database.execute(
          "CREATE TRIGGER fail_plan BEFORE INSERT ON $table BEGIN SELECT RAISE(ABORT, 'fail'); END",
        );
        store.database.execute(
          "CREATE TRIGGER fail_plan_update BEFORE UPDATE ON $table BEGIN SELECT RAISE(ABORT, 'fail'); END",
        );
        expect(() => save(), throwsA(anything));
        expect(jsonEncode(source.state), before);
        store.database.execute('DROP TRIGGER fail_plan');
        store.database.execute('DROP TRIGGER fail_plan_update');
        save();
        final id = source.outbox.single['id'] as String;
        expect(
          () => repo.recover(id, discard: true),
          throwsA(isA<ApiFailure>()),
        );
        source.atomic(() {
          source.outbox.single['status'] = 'rejected';
        });
        repo.recover(id);
        expect(source.outbox.single['status'], 'pending');
        source.atomic(() {
          source.outbox.single['status'] = 'rejected';
        });
        repo.recover(id, discard: true);
        expect(repo.plan, isNull);
      });
    });
  }
}
