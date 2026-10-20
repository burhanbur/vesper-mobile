import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/core/network/api_client.dart';

import '../fixtures/cached_finance.dart';

class _FakeBudgetClient extends ApiClient {
  bool failWrites = false;
  final List<String> requestedPaths = [];
  final List<Map<String, dynamic>> requestedPayloads = [];

  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    bool authenticated = true,
    bool retry = true,
  }) async {
    requestedPaths.add('$method $path');
    if (failWrites) throw const ApiFailure('Server tidak tersedia.');
    if (body != null) {
      requestedPayloads.add(body);
    }
    return {
      'id': 'b-synced-123',
      'category_id': body?['category_id'] ?? 'food',
      'amount': '${body?['amount'] ?? 1000000}.00',
      'period_type': body?['period_type'] ?? 'MONTHLY',
      'anchor_date': body?['anchor_date'] ?? '2026-01-01',
    };
  }
}

void main() {
  group('WM-04 Durable Budget Save & Feedback Contracts', () {
    test('remote failure keeps durable pending budget', () async {
      final state = cachedFinanceState(
        client: _FakeBudgetClient()..failWrites = true,
      );
      addTearDown(state.dispose);
      final result = await state.setCategoryBudget(
        categoryName: 'Food',
        allocatedAmount: 1000,
      );
      expect(result.isDurableLocal, isTrue);
      expect(result.isSyncedOnline, isFalse);
      expect(result.syncError, isNotNull);
      expect(
        state.repository!.rows('budgets').single['sync_status'],
        'pending',
      );
    });
    test('failed SQLite commit cannot report successful save', () async {
      final state = cachedFinanceState();
      addTearDown(state.dispose);
      final repo = state.repository!..offline = true;
      repo.store.database.execute(
        "CREATE TRIGGER fail_save BEFORE INSERT ON state BEGIN SELECT RAISE(ABORT, 'disk failure'); END",
      );
      await expectLater(
        state.setCategoryBudget(categoryName: 'Food', allocatedAmount: 1000),
        throwsA(anything),
      );
      expect(repo.rows('budgets'), isEmpty);
    });
    test('repeated offline saves retain one budget', () async {
      final state = cachedFinanceState();
      addTearDown(state.dispose);
      state.repository!.offline = true;
      await Future.wait(
        List.generate(
          2,
          (_) => state.setCategoryBudget(
            categoryName: 'Food',
            allocatedAmount: 1000,
          ),
        ),
      );
      expect(state.repository!.rows('budgets'), hasLength(1));
    });
    test(
      'local budget save persists to SQLite and updates state immediately',
      () async {
        final state = cachedFinanceState();
        addTearDown(state.dispose);
        final repo = state.repository!;
        repo.offline = true;

        final result = await state.setCategoryBudget(
          categoryName: 'Food',
          allocatedAmount: 2500000,
        );

        expect(result.isDurableLocal, isTrue);
        expect(result.isSyncedOnline, isFalse);
        expect(result.categoryName, 'Food');
        expect(result.allocatedAmount, 2500000);
        expect(
          result.feedbackMessage,
          'Budget untuk "Food" tersimpan di perangkat (antre sinkronisasi saat online)',
        );

        // Verify SQLite persistence
        final rows = repo.rows('budgets');
        expect(rows.length, 1);
        final row = rows.first;
        expect(row['category_id'], 'food');
        expect(row['current_amount'], '2500000.00');
        expect(row['period_type'], 'MONTHLY');
        expect(row['sync_status'], 'pending');

        // Verify state was notified and updated
        final budget = state.budgets.firstWhere((b) => b.categoryId == 'food');
        expect(budget.allocatedAmount, 2500000);
        expect(budget.categoryName, 'Food');
      },
    );

    test(
      'updating existing budget mutates SQLite in place with pending sync',
      () async {
        final state = cachedFinanceState();
        addTearDown(state.dispose);
        final repo = state.repository!;
        repo.offline = true;

        // Seed an initial budget
        repo.saveBudgetLocal(
          id: 'budget-initial',
          categoryId: 'food',
          allocatedAmount: 1000000,
          periodType: 'MONTHLY',
          anchorDate: '2026-01-01',
        );
        repo.markBudgetSynced('budget-initial');
        expect(repo.row('budgets', 'budget-initial')?['sync_status'], 'synced');

        // Update budget
        final result = await state.setCategoryBudget(
          categoryName: 'Food',
          allocatedAmount: 1750000,
        );

        expect(result.isDurableLocal, isTrue);
        expect(result.isSyncedOnline, isFalse);

        final row = repo.row('budgets', 'budget-initial');
        expect(row, isNotNull);
        expect(row!['current_amount'], '1750000.00');
        expect(row['anchor_date'], '2026-01-01');
        expect(row['sync_status'], 'pending');

        // Only one budget row exists (updated in place)
        expect(repo.rows('budgets').length, 1);
      },
    );

    test(
      'rejects zero or negative budget amounts without altering storage',
      () async {
        final state = cachedFinanceState();
        addTearDown(state.dispose);
        final repo = state.repository!;
        repo.offline = true;

        expect(
          () =>
              state.setCategoryBudget(categoryName: 'Food', allocatedAmount: 0),
          throwsA(isA<ApiFailure>()),
        );
        expect(
          () => state.setCategoryBudget(
            categoryName: 'Food',
            allocatedAmount: -500,
          ),
          throwsA(isA<ApiFailure>()),
        );

        expect(repo.rows('budgets'), isEmpty);
        expect(state.budgets, isEmpty);
      },
    );

    test('rejects unknown category without altering storage', () async {
      final state = cachedFinanceState();
      addTearDown(state.dispose);
      final repo = state.repository!;

      expect(
        () => state.setCategoryBudget(
          categoryName: 'NonExistentCategory',
          allocatedAmount: 500000,
        ),
        throwsA(isA<ApiFailure>()),
      );

      expect(repo.rows('budgets'), isEmpty);
    });

    test(
      'syncPendingBudgets pushes pending budgets to API when online',
      () async {
        final client = _FakeBudgetClient();
        final state = cachedFinanceState(client: client);
        addTearDown(state.dispose);
        final repo = state.repository!;

        // Save offline
        repo.saveBudgetLocal(
          id: 'budget-offline-1',
          categoryId: 'food',
          allocatedAmount: 3000000,
          anchorDate: '2026-01-15',
        );
        expect(
          repo.row('budgets', 'budget-offline-1')?['sync_status'],
          'pending',
        );

        // Now sync online
        await repo.syncPendingBudgets();

        expect(client.requestedPaths, ['POST /budgets']);
        expect(client.requestedPayloads.length, 1);
        expect(client.requestedPayloads.first['category_id'], 'food');
        expect(client.requestedPayloads.first['amount'], 3000000);
        expect(client.requestedPayloads.first['period_type'], 'MONTHLY');
        expect(client.requestedPayloads.first['anchor_date'], '2026-01-15');

        // Budget marked as synced
        expect(
          repo.row('budgets', 'budget-offline-1')?['sync_status'],
          'synced',
        );
      },
    );

    test('online setCategoryBudget confirms synchronous API write and provides success feedback', () async {
      final client = _FakeBudgetClient();
      final state = cachedFinanceState(client: client);
      addTearDown(state.dispose);
      final repo = state.repository!;

      final result = await state.setCategoryBudget(
        categoryName: 'Food',
        allocatedAmount: 1500000,
      );

      expect(result.isDurableLocal, isTrue);
      expect(result.isSyncedOnline, isTrue);
      expect(result.syncError, isNull);
      expect(
        result.feedbackMessage,
        'Budget untuk "Food" berhasil ditetapkan Rp 1.500.000/bulan!',
      );

      final budgetRow = repo.rows('budgets').first;
      expect(budgetRow['sync_status'], 'synced');
    });
  });
}
