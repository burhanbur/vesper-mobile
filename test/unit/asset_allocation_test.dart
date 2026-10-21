import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/database/local_store.dart';
import 'package:vesper_mobile/features/asset_allocation/data/asset_allocation_repository.dart';
import 'package:vesper_mobile/features/asset_allocation/data/asset_allocation_controller.dart';
import 'package:vesper_mobile/features/sync/data/finance_repository.dart';

const allocationInstrumentId = '11111111-1111-4111-8111-111111111111';
Map<String, dynamic> allocationFixture({
  bool partial = false,
  bool zero = false,
}) => {
  'scope': 'owner',
  'currency': 'IDR',
  'balance_basis': 'current_recorded_ledger',
  'denominator': 'gross_positive_supported_assets',
  'status': partial ? 'partial' : 'complete',
  'snapshot_date': '2026-10-21',
  'observed_at': '2026-10-21T00:00:00.000Z',
  'known_assets': zero
      ? '0.00'
      : partial
      ? '50.00'
      : '100.00',
  'total_assets': partial
      ? null
      : zero
      ? '0.00'
      : '100.00',
  'excluded_liabilities': '25.00',
  'excluded_account_count': 1,
  'warnings': partial
      ? ['allocation_incomplete_percentages_unavailable']
      : ['stale_prices_provisional'],
  'classes': [
    for (final kind in allocationClasses)
      <String, dynamic>{
        'asset_class': kind,
        'known_amount': !zero && (kind == 'CASH' || kind == 'GOLD' && !partial)
            ? '50.00'
            : '0.00',
        'market_value': partial && kind == 'GOLD'
            ? null
            : !zero && (kind == 'CASH' || kind == 'GOLD')
            ? '50.00'
            : '0.00',
        'weight_percent': partial || zero
            ? null
            : kind == 'CASH' || kind == 'GOLD'
            ? '50.00'
            : '0.00',
        'unavailable_count': partial && kind == 'GOLD' ? 1 : 0,
      },
  ],
  'instruments': zero
      ? <Map<String, dynamic>>[]
      : [
          <String, dynamic>{
            'instrument_id': allocationInstrumentId,
            'code': 'GOLD',
            'name': 'Gold',
            'asset_class': 'GOLD',
            'quantity': '2.00000000',
            'account_count': 2,
            'known_amount': partial ? '0.00' : '50.00',
            'market_value': partial ? null : '50.00',
            'weight_percent': partial ? null : '50.00',
            'price_date': partial ? null : '2026-10-20',
            'price_source': partial ? null : 'MANUAL',
            'stale': partial ? null : true,
            'unavailable_reasons': partial ? ['price_missing'] : [],
          },
        ],
};
Map<String, String> allocationTargets() => {
  for (final kind in allocationClasses)
    kind: kind == 'CASH'
        ? '60.00'
        : kind == 'GOLD'
        ? '40.00'
        : '0.00',
};

class AllocationClient extends ApiClient {
  dynamic result = allocationFixture();
  ApiFailure? failure;
  Completer<void>? gate;
  int calls = 0;
  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    bool authenticated = true,
    bool retry = true,
  }) async {
    calls++;
    expect(method, 'GET');
    expect(path, '/net-worth/allocation');
    expect(query, {'currency': 'IDR'});
    await gate?.future;
    if (failure != null) throw failure!;
    return result;
  }
}

void main() {
  for (final indexed in [false, true]) {
    group(indexed ? 'indexed allocation' : 'snapshot allocation', () {
      late LocalStore store;
      late FinanceRepository source;
      late AssetAllocationRepository repo;
      late AllocationClient client;
      Directory? temporary;
      setUp(() {
        if (indexed) {
          temporary = Directory.systemTemp.createTempSync(
            'vesper-allocation-test-',
          );
        }
        store = indexed
            ? LocalStore.indexed(
                sqlite3.open('${temporary!.path}/data.sqlite'),
                key: List.generate(32, (i) => i),
                userId: 'owner',
              )
            : LocalStore(sqlite3.openInMemory());
        client = AllocationClient();
        source = FinanceRepository(client, store, 'owner');
        repo = AssetAllocationRepository(source);
      });
      tearDown(() {
        store.close();
        final d = temporary?.absolute;
        if (d != null) {
          if (d.parent.path != Directory.systemTemp.absolute.path ||
              !d.path.contains('vesper-allocation-test-')) {
            throw StateError('Unsafe test cleanup');
          }
          d.deleteSync(recursive: true);
          temporary = null;
        }
      });
      test('validates exact class/instrument totals and zero/partial denominator contracts', () {
        final data = AllocationSnapshot.fromJson(allocationFixture());
        expect(data.total, BigInt.from(10000));
        expect(
          AllocationSnapshot.fromJson(allocationFixture(partial: true)).total,
          isNull,
        );
        expect(
          AllocationSnapshot.fromJson(allocationFixture(zero: true)).total,
          BigInt.zero,
        );
        expect(
          allocationWeight(
            BigInt.parse('900719925474099301'),
            BigInt.parse('900719925474099302'),
          ),
          '99.99',
        );
      });
      test('rejects fabricated complete totals, weights, duplicate instruments and foreign scope', () {
        final invalid = <Map<String, dynamic>>[
          {...allocationFixture(), 'total_assets': '101.00'},
          {...allocationFixture(), 'scope': 'household'},
          {...allocationFixture(), 'currency': 'USD'},
          {
            ...allocationFixture(),
            'classes': [
              {
                ...(allocationFixture()['classes'] as List).first,
                'weight_percent': '100.00',
              },
              ...(allocationFixture()['classes'] as List).skip(1),
            ],
          },
          {
            ...allocationFixture(),
            'instruments': [
              ...(allocationFixture()['instruments'] as List),
              ...(allocationFixture()['instruments'] as List),
            ],
          },
        ];
        for (final json in invalid) {
          expect(
            () => AllocationSnapshot.fromJson(json),
            throwsA(isA<ApiFailure>()),
          );
        }
      });
      test('targets require exact 100 percent; deviations have signed percentage points', () {
        final before = jsonEncode(source.entities);
        expect(
          () => repo.saveTargets({
            for (final kind in allocationClasses) kind: '0',
          }),
          throwsA(isA<ApiFailure>()),
        );
        expect(
          () => repo.saveTargets({...allocationTargets(), 'CASH': '60.001'}),
          throwsA(isA<ApiFailure>()),
        );
        expect(
          () => repo.saveTargets({...allocationTargets(), 'GOLD': '-1'}),
          throwsA(isA<ApiFailure>()),
        );
        repo.saveTargets(allocationTargets());
        final data = AllocationSnapshot.fromJson(allocationFixture());
        expect(repo.deviation(data, 'CASH'), '-10.00');
        expect(repo.deviation(data, 'GOLD'), '10.00');
        expect(
          repo.deviation(
            AllocationSnapshot.fromJson(allocationFixture(partial: true)),
            'CASH',
          ),
          isNull,
        );
        expect(source.outbox, isEmpty);
        expect(jsonEncode(source.entities), before);
        repo.saveTargets(null);
        expect(repo.targets, isNull);
      });
      test('persisted snapshot and targets survive repository restart without changing money', () async {
        final before = jsonEncode(source.entities);
        repo.saveTargets(allocationTargets());
        await repo.fetch(isCurrent: () => true);
        final restarted = AssetAllocationRepository(
          FinanceRepository(client, store, 'owner'),
        );
        expect(restarted.cached!.total, BigInt.from(10000));
        expect(restarted.targets, allocationTargets());
        expect(jsonEncode(source.entities), before);
        expect(source.outbox, isEmpty);
      });
      test('failed local target save rolls back atomically', () {
        final before = jsonEncode(source.state);
        store.database.execute('PRAGMA query_only = ON');
        expect(() => repo.saveTargets(allocationTargets()), throwsA(anything));
        store.database.execute('PRAGMA query_only = OFF');
        expect(jsonEncode(source.state), before);
      });
      test('late results after session change never cache; disposed controller never publishes', () async {
        var current = true;
        client.gate = Completer<void>();
        final controller = AssetAllocationController(repo, () => current);
        final pending = controller.refresh();
        await Future<void>.delayed(Duration.zero);
        current = false;
        controller.dispose();
        client.gate!.complete();
        await pending;
        expect(repo.cached, isNull);
        expect(controller.snapshot, isNull);
      });
      test('offline uses labelled cache and authorization failure removes previous snapshot', () async {
        await repo.fetch(isCurrent: () => true);
        final controller = AssetAllocationController(repo, () => true);
        addTearDown(controller.dispose);
        source.offline = true;
        await controller.refresh();
        expect(controller.cached, isTrue);
        expect(controller.snapshot, isNotNull);
        expect(client.calls, 1);
        source.offline = false;
        client.failure = const ApiFailure('Session expired', statusCode: 401);
        await controller.refresh();
        expect(controller.snapshot, isNull);
        expect(repo.cached, isNull);
      });
      test('other-owner cache and settings are ignored and stale dialogs cannot save', () {
        source.atomic(() {
          source.state['asset_allocation_cache'] = {
            'schema': 1,
            'user_id': 'other',
            'snapshot': allocationFixture(),
          };
          source.state['asset_allocation_targets'] = {
            'schema': 1,
            'user_id': 'other',
            'values': allocationTargets(),
          };
        });
        expect(repo.cached, isNull);
        expect(repo.targets, isNull);
        final controller = AssetAllocationController(repo, () => false);
        expect(controller.saveTargets(allocationTargets()), isFalse);
        expect(controller.error, contains('Sesi telah berubah'));
        controller.dispose();
      });
    });
  }
}
