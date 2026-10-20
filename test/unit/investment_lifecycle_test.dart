import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/database/local_store.dart';
import 'package:vesper_mobile/features/sync/data/finance_repository.dart';
import 'package:vesper_mobile/features/investments/data/investment_lifecycle_repository.dart';

class CatalogClient extends ApiClient {
  bool fail = false;
  final deliveries = <String>[];
  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    bool authenticated = true,
    bool retry = true,
  }) async {
    deliveries.add(jsonEncode(body));
    if (fail) throw const ApiFailure('Lost response');
    return {...body!, 'id': body['id'] ?? 'server-price'};
  }
}

void main() {
  test(
    'catalog queue commits and restores through encrypted indexed storage',
    () async {
      final directory = Directory.systemTemp.createTempSync(
        'vesper-wm05-test-',
      );
      final indexed = LocalStore.indexed(
        sqlite3.open(
          '${directory.path}${Platform.pathSeparator}catalog.sqlite',
        ),
        key: List.generate(32, (i) => i),
        userId: 'owner',
      );
      addTearDown(() {
        indexed.close();
        if (directory.parent.absolute.path !=
                Directory.systemTemp.absolute.path ||
            !directory.path.contains('vesper-wm05-test-')) {
          throw StateError('Invalid catalog test cleanup');
        }
        directory.deleteSync(recursive: true);
      });
      final api = CatalogClient();
      var repo = FinanceRepository(api, indexed, 'owner');
      final id = repo.saveInstrumentLocal(
        code: 'INDEXED',
        name: 'Asset',
        type: 'STOCK',
      );
      repo.saveInvestmentPriceLocal(id, '2026-10-01', '10.01');
      repo = FinanceRepository(api, indexed, 'owner');
      expect(repo.pendingInvestmentCatalog, hasLength(2));
      await repo.syncInvestmentCatalog();
      repo = FinanceRepository(api, indexed, 'owner');
      expect(repo.pendingInvestmentCatalog, isEmpty);
      expect(repo.row('instruments', id)!['code'], 'INDEXED');
      expect(
        repo.row('instrument_prices', '$id:2026-10-01')!['close_price'],
        '10.01',
      );
    },
  );
  late LocalStore store;
  late CatalogClient client;
  late FinanceRepository source;
  late InvestmentLifecycleRepository repo;
  setUp(() {
    store = LocalStore(sqlite3.openInMemory());
    client = CatalogClient();
    source = FinanceRepository(client, store, 'owner');
    repo = InvestmentLifecycleRepository(source);
    source.atomic(() {
      source.entities['account_types'] = {
        'invest': {
          'id': 'invest',
          'user_id': 'owner',
          'category': 'INVESTMENT',
        },
      };
      source.entities['accounts'] = {
        for (final id in ['one', 'two', 'foreign'])
          id: {
            'id': id,
            'user_id': id == 'foreign' ? 'other' : 'owner',
            'currency': 'IDR',
            'account_type_id': 'invest',
          },
      };
      source.state['investment_history_coverage'] = {
        'schema': 1,
        'user_id': 'owner',
        'complete': true,
        'cursor': source.state['cursor'],
      };
    });
  });
  tearDown(() => store.close());

  void history() {
    source.atomic(() {
      source.entities['investment_transactions'] = {
        for (final row in [
          ['a', 'one', 'BUY', '2', '10', '1'],
          ['b', 'one', 'SELL', '1', '15', '0.5'],
          ['c', 'one', 'DIVIDEND', '1', '2', '0.1'],
          ['d', 'two', 'BUY', '1', '20', '0'],
          ['e', 'foreign', 'BUY', '100', '999', '0'],
        ])
          row[0]: {
            'id': row[0],
            'account_id': row[1],
            'type': row[2],
            'quantity': row[3],
            'price_per_unit': row[4],
            'fee': row[5],
            'instrument_id': 'stock',
            'transacted_at':
                '2026-10-0${row[0].codeUnitAt(0) - 96}T00:00:00.000Z',
          },
      };
      source.entities['instrument_prices'] = {
        'quote': {
          'instrument_id': 'stock',
          'price_date': '2026-10-01',
          'close_price': '30',
        },
      };
    });
  }

  test(
    'owner cross-account totals separate purchases, sales, P/L and dividends',
    () {
      history();
      final value = repo.overview();
      expect(value.contributed, '41.00');
      expect(value.proceeds, '14.50');
      expect(value.realized, '4.50');
      expect(value.buyFees, '1.00');
      expect(value.dividends, '1.90');
      expect(value.marketValue, '60.00');
      expect(value.unrealized, '30.00');
      expect(repo.history('one'), hasLength(3));
      expect(repo.history('foreign'), isEmpty);
    },
  );

  test('missing prices and incomplete histories never masquerade as zero', () {
    history();
    source.atomic(
      () => source.entities['instrument_prices'] = <String, dynamic>{},
    );
    expect(repo.overview().marketValue, isNull);
    expect(repo.overview().missingPrices, 2);
    source.atomic(() => source.state.remove('investment_history_coverage'));
    expect(repo.overview, throwsA(isA<ApiFailure>()));
  });

  test('local catalog survives restart and lost response reuses exact UUID payload', () async {
    final id = source.saveInstrumentLocal(
      code: 'TEST',
      name: 'Asset',
      type: 'STOCK',
    );
    source.saveInvestmentPriceLocal(id, '2026-10-01', '10.12345678');
    expect(source.pendingInvestmentCatalog, hasLength(2));
    final reloaded = FinanceRepository(client, store, 'owner');
    expect(reloaded.row('instruments', id)!['pending_catalog'], true);
    client.fail = true;
    await expectLater(
      reloaded.syncInvestmentCatalog(),
      throwsA(isA<ApiFailure>()),
    );
    expect(reloaded.pendingInvestmentCatalog, hasLength(2));
    client.fail = false;
    await reloaded.syncInvestmentCatalog();
    expect(client.deliveries[0], client.deliveries[1]);
    expect(reloaded.pendingInvestmentCatalog, isEmpty);
    expect(reloaded.row('instruments', id)!['pending_catalog'], isNull);
    expect(
      reloaded.row('instrument_prices', '$id:2026-10-01')!['close_price'],
      '10.12345678',
    );
  });

  test(
    'failed durable catalog commit leaves no optimistic row or pending write',
    () {
      store.close();
      expect(
        () => source.saveInstrumentLocal(
          code: 'FAIL',
          name: 'Asset',
          type: 'STOCK',
        ),
        throwsA(anything),
      );
      expect(source.rows('instruments'), isEmpty);
      expect(source.pendingInvestmentCatalog, isEmpty);
      store = LocalStore(sqlite3.openInMemory());
    },
  );

  test('invalid metadata and precision produce no queue entry', () {
    expect(
      () => source.saveInstrumentLocal(
        code: 'bad code',
        name: 'A',
        type: 'STOCK',
      ),
      throwsA(isA<ApiFailure>()),
    );
    final id = source.saveInstrumentLocal(
      code: 'TEST',
      name: 'Asset',
      type: 'STOCK',
    );
    for (final price in ['0', '1e3', '0.000000001', '-1', '1\n']) {
      expect(
        () => source.saveInvestmentPriceLocal(id, '2026-10-01', price),
        throwsA(isA<ApiFailure>()),
      );
    }
    expect(
      () => source.saveInvestmentPriceLocal(id, '2026-02-30', '10'),
      throwsA(isA<ApiFailure>()),
    );
    expect(source.pendingInvestmentCatalog, hasLength(1));
  });

  test('stopping failed instrument delivery removes dependent speculative quotes only', () {
    final id = source.saveInstrumentLocal(
      code: 'PENDING',
      name: 'Asset',
      type: 'STOCK',
    );
    source.saveInvestmentPriceLocal(id, '2026-10-01', '1');
    final other = source.saveInstrumentLocal(
      code: 'OTHER',
      name: 'Other',
      type: 'GOLD',
    );
    source.discardInvestmentCatalog(id);
    expect(source.row('instruments', id), isNull);
    expect(source.rows('instrument_prices'), isEmpty);
    expect(source.pendingInvestmentCatalog.single['id'], other);
  });
}
