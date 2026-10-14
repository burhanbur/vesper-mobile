import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/features/accounts/models/account.dart';
import 'package:vesper_mobile/features/accounts/pages/accounts_page.dart';
import 'package:vesper_mobile/features/sync/data/finance_repository.dart';

import '../fixtures/cached_finance.dart';

// Sharing snapshots are not integrated into the production account adapter yet.
// These overrides supply presentation-only sharing metadata, not fake writes.
class _AccountsState extends AppState {
  _AccountsState(FinanceRepository repository) : super(repository: repository);

  @override
  List<Account> get accounts => super.accounts
      .map(
        (account) => account.id == 'acc-jago' || account.id == 'pocket'
            ? account.copyWith(isShared: true, householdId: 'hh-1')
            : account,
      )
      .toList();
}

Future<_AccountsState> _pumpPage(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final base = cachedFinanceState();
  final repo = base.repository!;
  base.repository = null;
  base.dispose();
  repo.atomic(() {
    repo.entities['account_types'] = {
      for (final name in [
        'Cash',
        'Rekening Bank',
        'E-wallet',
        'Reksadana',
        'Saham',
      ])
        name: {
          'id': name,
          'name': name,
          'category': ['Reksadana', 'Saham'].contains(name)
              ? 'INVESTMENT'
              : 'CASH',
        },
    };
    repo.entities['accounts'] = {
      for (final row in [
        ['stock', 'Stock account', 'Saham', '500.00'],
        ['fund', 'Fund account', 'Reksadana', '400.00'],
        ['wallet', 'Wallet account', 'E-wallet', '300.00'],
        ['acc-jago', 'Bank parent', 'Rekening Bank', '200.00'],
        ['pocket', 'Nested pocket', 'Rekening Bank', '100.00'],
        ['cash', 'Cash account', 'Cash', '50.00'],
        ['hidden', 'Hidden account', 'Cash', '0.00'],
      ])
        row[0]: {
          'id': row[0],
          'name': row[1],
          'account_type_id': row[2],
          'balance': row[3],
          'user_id': 'user',
          'is_visible': row[0] != 'hidden',
          if (row[0] == 'pocket') 'parent_account_id': 'acc-jago',
        },
    };
    repo.entities['groups'] = {
      'hh-1': {'id': 'hh-1', 'name': 'Family'},
    };
  });
  final state = _AccountsState(repo)..currentUserId = 'user';
  state.toggleOfflineMode();
  addTearDown(state.dispose);
  await tester.pumpWidget(
    AppStateScope(
      state: state,
      child: const MaterialApp(home: AccountsPage()),
    ),
  );
  await tester.pumpAndSettle();
  return state;
}

void main() {
  testWidgets(
    'Uses picker category and subtype order, keeping pockets nested',
    (tester) async {
      await _pumpPage(tester);
      expect(find.text('Nested pocket'), findsNothing);
      await tester.tap(find.text('Lihat Kantong'));
      await tester.pumpAndSettle();
      final ordered = [
        find.text('Cash').first,
        find.text('Cash').last,
        find.text('Cash account'),
        find.text('Rekening Bank'),
        find.text('Bank parent'),
        find.text('Nested pocket'),
        find.text('E-wallet'),
        find.text('Wallet account'),
        find.text('Investasi'),
        find.text('Reksadana'),
        find.text('Fund account'),
        find.text('Saham'),
        find.text('Stock account'),
      ];
      for (var i = 1; i < ordered.length; i++) {
        expect(
          tester.getTopLeft(ordered[i - 1]).dy,
          lessThan(tester.getTopLeft(ordered[i]).dy),
        );
      }
      expect(find.text('Hidden account'), findsNothing);
      expect(find.text('5 Rekening'), findsOneWidget);
      expect(find.text('Nested pocket'), findsOneWidget);
      await tester.tap(find.text('Tutup'));
      await tester.pumpAndSettle();
      expect(find.text('Nested pocket'), findsNothing);
      await tester.tap(find.text('Lihat Kantong'));
      await tester.pumpAndSettle();
      expect(find.text('Nested pocket'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Preserves private/group filters and group selection action', (
    tester,
  ) async {
    final state = await _pumpPage(tester);
    await tester.tap(find.text('Akun Pribadi (5)'));
    await tester.pumpAndSettle();
    expect(find.text('Cash account'), findsOneWidget);
    expect(find.text('Investasi'), findsOneWidget);
    expect(find.text('Bank parent'), findsNothing);
    expect(find.text('Rekening Bank'), findsNothing);
    expect(find.text('4 Rekening'), findsOneWidget);
    await tester.tap(find.text('Family (1)'));
    await tester.pumpAndSettle();
    expect(state.activeHouseholdId, 'hh-1');
    expect(find.text('Bank parent'), findsOneWidget);
    expect(find.text('Nested pocket'), findsNothing);
    await tester.tap(find.text('Lihat Kantong'));
    await tester.pumpAndSettle();
    expect(find.text('Nested pocket'), findsOneWidget);
    expect(find.text('Investasi'), findsNothing);
    expect(find.text('E-wallet'), findsNothing);
    expect(find.text('1 Rekening'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Grouped cards retain balances, hiding and detail/sharing actions',
    (tester) async {
      final state = await _pumpPage(tester);
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pumpAndSettle();
      expect(state.isBalanceHidden, isTrue);
      expect(find.text('••••••'), findsWidgets);
      await tester.tap(find.text('Lihat Kantong'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nested pocket'));
      await tester.pumpAndSettle();
      expect(find.text('Saldo Rekening'), findsOneWidget);
      await tester.tap(find.byTooltip('Pengaturan & Sharing'));
      await tester.pumpAndSettle();
      expect(find.text('Pilih Grup yang Dapat Mengakses'), findsOneWidget);
      expect(find.textContaining('Rp'), findsNothing);
      expect(state.repository!.outbox, isEmpty);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.longPress(find.text('Bank parent'));
      await tester.pumpAndSettle();
      expect(find.text('Saldo Rekening'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cash account'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Pengaturan & Sharing'));
      await tester.pumpAndSettle();
      expect(find.text('Bagikan ke Ruang Grup Bersama'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
