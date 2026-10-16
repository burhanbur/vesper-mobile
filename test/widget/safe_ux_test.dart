import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/features/dashboard/pages/dashboard_page.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/features/household/pages/household_page.dart';
import 'package:vesper_mobile/features/reports/pages/reports_page.dart';
import 'package:vesper_mobile/features/transactions/models/transaction.dart';
import 'package:vesper_mobile/features/transactions/pages/transactions_page.dart';
import 'package:vesper_mobile/features/transactions/widgets/add_transaction_modal.dart';

import '../fixtures/cached_finance.dart';

class GroupListClient extends ApiClient {
  String? code;
  @override
  Future<List<Map<String, dynamic>>> list(
    String path, {
    Map<String, dynamic>? query,
  }) async => [
    {'id': 'group', 'name': 'Our group', if (code != null) 'code': code},
  ];
}

void main() {
  Widget host(AppState state, Widget page) => AppStateScope(
    state: state,
    child: MaterialApp(home: page),
  );

  testWidgets('derived cash opens explanation instead of an editable form', (
    tester,
  ) async {
    final state = cachedFinanceState();
    addTearDown(state.dispose);
    state.repository!.atomic(() {
      state.repository!.entities['transactions'] = <String, dynamic>{
        'settlement': {
          'id': 'settlement',
          'category_id': null,
          'transfer_id': null,
        },
      };
    });
    final transaction = TransactionItem(
      id: 'settlement',
      type: TransactionType.expense,
      amount: 21,
      accountId: 'cash',
      categoryName: '',
      date: DateTime(2026, 10, 15),
      householdId: '',
    );
    await tester.pumpWidget(
      host(
        state,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => AddTransactionModal.show(
                context,
                transactionToEdit: transaction,
              ),
              child: const Text('Edit'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Transaksi turunan tidak dapat diubah'), findsOneWidget);
    expect(find.byType(AddTransactionModal), findsNothing);
    expect(state.repository!.outbox, isEmpty);
    expect(tester.takeException(), isNull);
  });

  void seed(AppState state) {
    final now = DateTime.now();
    state.repository!.atomic(() {
      state.repository!.entities['transactions'] = {
        'current': {
          'id': 'current',
          'account_id': 'cash',
          'category_id': 'food',
          'type': 'EXPENSE',
          'amount': '123.00',
          'transacted_at': DateTime(
            now.year,
            now.month,
            2,
          ).toUtc().toIso8601String(),
          'description': 'Current expense',
        },
        'previous': {
          'id': 'previous',
          'account_id': 'cash',
          'category_id': 'salary',
          'type': 'INCOME',
          'amount': '456.00',
          'transacted_at': DateTime(
            now.year,
            now.month - 1,
            2,
          ).toUtc().toIso8601String(),
          'description': 'Previous salary',
        },
        'transfer': {
          'id': 'transfer',
          'account_id': 'cash',
          'type': 'TRANSFER',
          'amount': '999.00',
          'transacted_at': DateTime(
            now.year,
            now.month - 1,
            2,
          ).toUtc().toIso8601String(),
        },
      };
    });
  }

  testWidgets(
    'reports navigation changes summary and category totals, excluding transfers',
    (tester) async {
      final state = cachedFinanceState();
      seed(state);
      await tester.pumpWidget(host(state, const ReportsPage()));
      expect(find.text('Rp 123'), findsNWidgets(3));
      expect(find.text('Rp 456'), findsNothing);
      await tester.tap(find.byTooltip('Bulan sebelumnya'));
      await tester.pump();
      expect(find.text('Rp 456'), findsNWidgets(2));
      expect(find.text('Rp 999'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('reports_tab_2')));
      await tester.pump();
      expect(find.text('Salary'), findsOneWidget);
      state.toggleHideBalance();
      await tester.pump();
      expect(find.text('Rp 456'), findsNothing);
      state.dispose();
      await tester.pump();
    },
  );

  testWidgets(
    'history filters the selected period and uses a single lazy list',
    (tester) async {
      final state = cachedFinanceState();
      seed(state);
      await tester.pumpWidget(host(state, const TransactionsPage()));
      expect(find.text('1 Transaksi'), findsOneWidget);
      expect(find.byType(CustomScrollView), findsOneWidget);
      expect(find.byType(SliverList), findsOneWidget);
      await tester.tap(find.byTooltip('Bulan sebelumnya'));
      await tester.pump();
      expect(find.text('2 Transaksi'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Pemasukan'));
      await tester.pump();
      expect(find.text('1 Transaksi'), findsOneWidget);
      state.dispose();
      await tester.pump();
    },
  );

  testWidgets(
    'household distinguishes unavailable financial and membership data from zeros',
    (tester) async {
      final state = cachedFinanceState();
      state.repository!.atomic(() {
        state.repository!.entities['groups'] = {
          'group': {'id': 'group', 'name': 'Our group', 'code': 'INVITE123456'},
        };
      });
      await tester.pumpWidget(host(state, const HouseholdPage()));
      expect(find.textContaining('bukan saldo nol'), findsOneWidget);
      expect(
        find.text('Daftar anggota belum tersedia di perangkat.'),
        findsOneWidget,
      );
      expect(find.text('INVITE123456'), findsOneWidget);
      expect(find.text('Rp 0'), findsNothing);
      expect(find.text('Simpan & Kirim Undangan'), findsNothing);
      state.dispose();
      await tester.pump();
    },
  );

  testWidgets(
    'transfer entry opens local-first creation form without creating rows',
    (tester) async {
      final state = cachedFinanceState();
      state.toggleOfflineMode();
      state.repository!.atomic(() {
        state.repository!.entities['accounts'] = {
          for (final id in ['cash', 'savings'])
            id: {
              'id': id,
              'name': id,
              'user_id': 'user',
              'currency': 'IDR',
              'balance': '100000.00',
              'version': '1',
            },
        };
      });
      await tester.pumpWidget(
        host(
          state,
          DashboardPage(
            onNavigateToTransactions: () {},
            onNavigateToInvestments: () {},
            onNavigateToReports: () {},
            onNavigateToHousehold: () {},
          ),
        ),
      );
      await tester.tap(find.text('Transfer'));
      await tester.pumpAndSettle();
      expect(find.byType(AddTransactionModal), findsOneWidget);
      expect(
        tester
            .widget<AddTransactionModal>(find.byType(AddTransactionModal))
            .initialType,
        TransactionType.transfer,
      );
      expect(find.byType(TextField), findsWidgets);
      expect(state.repository!.outbox, isEmpty);
      await tester.enterText(find.byType(TextField).first, '25000');
      await tester.ensureVisible(find.text('Simpan Transaksi'));
      await tester.tap(find.text('Simpan Transaksi'));
      await tester.pumpAndSettle();
      expect(state.repository!.outbox.single['entity_type'], 'transfers');
      expect(state.repository!.rows('transactions'), hasLength(2));
      expect(state.getAccountById('cash')!.balance, 75000);
      expect(state.getAccountById('savings')!.balance, 125000);
      state.dispose();
      await tester.pump();
    },
  );

  test('group list refresh preserves omitted invite code and accepts replacement code', () async {
    final client = GroupListClient();
    final state = cachedFinanceState(client: client);
    final repo = state.repository!;
    repo.atomic(() {
      repo.entities['groups'] = {
        'group': {'id': 'group', 'name': 'Old', 'code': 'INVITE123456'},
      };
    });
    await repo.refreshList('groups', '/groups');
    expect(state.activeHousehold.inviteCode, 'INVITE123456');
    client.code = 'REPLACEMENT12';
    await repo.refreshList('groups', '/groups');
    expect(state.activeHousehold.inviteCode, 'REPLACEMENT12');
    state.dispose();
  });
}
