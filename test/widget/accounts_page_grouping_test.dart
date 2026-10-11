import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/features/accounts/models/account.dart';
import 'package:vesper_mobile/features/accounts/pages/accounts_page.dart';
import 'package:vesper_mobile/features/household/models/household.dart';

class _AccountsState extends AppState {
  @override
  List<Account> get accounts => const [
    Account(
      id: 'stock',
      name: 'Stock account',
      type: AccountType.investment,
      institution: 'Saham',
      balance: 500,
      accountNumber: '',
    ),
    Account(
      id: 'fund',
      name: 'Fund account',
      type: AccountType.investment,
      institution: 'Reksadana',
      balance: 400,
      accountNumber: '',
    ),
    Account(
      id: 'wallet',
      name: 'Wallet account',
      type: AccountType.wallet,
      institution: 'E-wallet',
      balance: 300,
      accountNumber: '',
    ),
    Account(
      id: 'acc-jago',
      name: 'Bank parent',
      type: AccountType.bank,
      institution: 'Rekening Bank',
      balance: 200,
      accountNumber: '',
      isShared: true,
      householdId: 'hh-1',
    ),
    Account(
      id: 'pocket',
      name: 'Nested pocket',
      type: AccountType.bank,
      institution: 'Rekening Bank',
      balance: 100,
      accountNumber: '',
      parentAccountId: 'acc-jago',
      isShared: true,
      householdId: 'hh-1',
    ),
    Account(
      id: 'cash',
      name: 'Cash account',
      type: AccountType.cash,
      institution: 'Cash',
      balance: 50,
      accountNumber: '',
    ),
    Account(
      id: 'hidden',
      name: 'Hidden account',
      type: AccountType.cash,
      balance: 0,
      accountNumber: '',
      isVisible: false,
    ),
  ];

  @override
  List<Household> get households => const [
    Household(id: 'hh-1', name: 'Family', members: [], sharedBalance: 300),
  ];

  @override
  Household get household => households.first;

  @override
  String get activeHouseholdId => 'hh-1';

  String? selectedHousehold;
  String? savedAccount;
  bool? savedSharing;

  @override
  void switchHousehold(String id) {
    selectedHousehold = id;
  }

  @override
  Future<void> updateAccountSharing({
    required String accountId,
    required bool isShared,
    String? householdId,
  }) async {
    savedAccount = accountId;
    savedSharing = isShared;
  }
}

Future<_AccountsState> _pumpPage(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final state = _AccountsState();
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
    expect(state.selectedHousehold, 'hh-1');
    expect(find.text('Bank parent'), findsOneWidget);
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
      await tester.tap(find.text('Nested pocket'));
      await tester.pumpAndSettle();
      expect(find.text('Saldo Rekening'), findsOneWidget);
      await tester.tap(find.byTooltip('Pengaturan & Sharing'));
      await tester.pumpAndSettle();
      expect(find.text('Pilih Grup yang Dapat Mengakses'), findsOneWidget);
      await tester.tap(find.text('Simpan Pengaturan Rekening'));
      await tester.pumpAndSettle();
      expect(state.savedAccount, 'pocket');
      expect(state.savedSharing, isTrue);
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
