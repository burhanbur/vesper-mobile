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

Future<_AccountsState> _pumpPage(
  WidgetTester tester, {
  Map<String, Map<String, dynamic>>? extraAccounts,
}) async {
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
        'Hutang & Piutang',
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
      ...?extraAccounts,
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
  Map<String, Map<String, dynamic>> emptyCard() => {
    'card-mistake': {
      'id': 'card-mistake',
      'name': 'Kartu salah',
      'user_id': 'user',
      'account_type_id': 'E-wallet',
      'balance': '0.00',
      'version': '1',
      'currency': 'IDR',
      'is_credit_card': true,
      'credit_limit': '9000000.00',
    },
  };
  testWidgets(
    'card label hides storage type and personal name edits do not change sharing',
    (tester) async {
      final state = await _pumpPage(tester, extraAccounts: emptyCard());
      expect(state.getAccountById('card-mistake')!.institution, 'Kartu Kredit');
      await tester.longPress(find.text('Kartu salah'));
      await tester.pumpAndSettle();
      expect(
        find.text('Kartu Kredit (identitas jenis akun terkunci)'),
        findsNothing,
      );
      expect(find.text('Jenis akun: Kartu Kredit'), findsOneWidget);
      expect(find.text('Bagikan ke Ruang Grup Bersama'), findsNothing);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nama Rekening / Akun'),
        'Kartu Mandiri',
      );
      await tester.ensureVisible(find.text('Simpan Pengaturan Rekening'));
      await tester.tap(find.text('Simpan Pengaturan Rekening'));
      await tester.pumpAndSettle();
      expect(state.getAccountById('card-mistake')!.name, 'Kartu Mandiri');
      expect(state.repository!.outbox.single['payload'], {
        'name': 'Kartu Mandiri',
      });
      expect(find.byType(BottomSheet), findsNothing);
      await tester.pump(const Duration(seconds: 4));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('corrects a mistakenly created empty card to a bank account', (
    tester,
  ) async {
    final state = await _pumpPage(tester, extraAccounts: emptyCard());
    await tester.longPress(find.text('Kartu salah'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kartu kredit'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(DropdownButtonFormField<String>, 'Jenis Rekening'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rekening Bank').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Simpan Pengaturan Rekening'));
    await tester.tap(find.text('Simpan Pengaturan Rekening'));
    await tester.pumpAndSettle();
    final row = state.repository!.row('accounts', 'card-mistake')!;
    expect(row['is_credit_card'], isFalse);
    expect(row['credit_limit'], isNull);
    expect(row['account_type_id'], 'Rekening Bank');
    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'deletes a confirmed empty card without deleting financial history',
    (tester) async {
      final state = await _pumpPage(tester, extraAccounts: emptyCard());
      await tester.longPress(find.text('Kartu salah'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Hapus akun'));
      await tester.tap(find.text('Hapus akun'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Hapus akun'));
      await tester.pumpAndSettle();
      expect(state.repository!.row('accounts', 'card-mistake'), isNull);
      expect(state.repository!.outbox.single['operation'], 'DELETE');
      await tester.pump(const Duration(seconds: 4));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'creates a credit card with a nine million limit without technical type selection',
    (tester) async {
      final state = await _pumpPage(tester);
      await tester.tap(find.byIcon(Icons.add_circle_outline_rounded));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ChoiceChip, 'Hutang & Piutang'), findsNothing);
      await tester.tap(find.text('Kartu kredit'));
      await tester.pumpAndSettle();
      expect(find.text('Tipe Akun'), findsNothing);
      expect(find.text('Saldo Awal (Rp)'), findsNothing);
      await tester.enterText(
        find.widgetWithText(TextField, 'Limit kartu (Rp)'),
        '9000000',
      );
      expect(
        tester
            .widget<TextField>(
              find.widgetWithText(TextField, 'Limit kartu (Rp)'),
            )
            .controller!
            .text,
        '9.000.000',
      );
      await tester.enterText(find.byType(TextField).last, 'BCA Credit Card');
      await tester.ensureVisible(find.text('Simpan Akun'));
      await tester.tap(find.text('Simpan Akun'));
      await tester.pumpAndSettle();
      final card = state.accounts.singleWhere(
        (a) => a.name == 'BCA Credit Card',
      );
      expect(card.isCreditCard, isTrue);
      expect(card.creditLimit, '9000000.00');
      expect(card.balance, 0);
      expect(tester.takeException(), isNull);
    },
  );

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

  testWidgets(
    'Tapping parent account tile automatically toggles pockets instead of opening detail',
    (tester) async {
      await _pumpPage(tester);
      expect(find.text('Nested pocket'), findsNothing);

      // Tapping parent card title expands pockets
      await tester.tap(find.text('Bank parent'));
      await tester.pumpAndSettle();
      expect(find.text('Nested pocket'), findsOneWidget);

      // Tapping parent card again collapses pockets
      await tester.tap(find.text('Bank parent'));
      await tester.pumpAndSettle();
      expect(find.text('Nested pocket'), findsNothing);
    },
  );

  testWidgets(
    'Excluded debt account (is_include_total: false) does not reduce Net Worth on AccountsPage',
    (tester) async {
      final state = await _pumpPage(
        tester,
        extraAccounts: {
          'debt-excluded': {
            'id': 'debt-excluded',
            'name': 'Hutang',
            'account_type_id': 'Hutang & Piutang',
            'balance': '1000000.00',
            'is_include_total': false,
            'user_id': 'user',
            'is_visible': true,
          },
        },
      );

      // Verify that state.totalDebt is 0 because the debt account is excluded from total
      expect(state.totalDebt, 0);
      expect(state.totalNetWorth, greaterThan(0));

      // The accounts page shows "Kekayaan Bersih" metric card
      expect(find.text('Kekayaan Bersih'), findsOneWidget);
      // Hutang & Kewajiban should have badge 'Bebas Hutang' since totalDebt == 0
      expect(find.text('Bebas Hutang'), findsOneWidget);
    },
  );

  testWidgets(
    'Add account modal allows selecting parent account to create child pocket',
    (tester) async {
      await _pumpPage(tester);

      // Open add account modal
      final addAccountButton = find.byIcon(Icons.add_circle_outline_rounded).first;
      await tester.tap(addAccountButton);
      await tester.pumpAndSettle();

      expect(find.text('Tambah Akun / Rekening Baru'), findsOneWidget);
      // Verify parent selector is visible
      expect(find.text('Jadikan Kantong (Child Pocket)?'), findsOneWidget);
      expect(find.text('Bukan Kantong (Akun Utama Terpisah)'), findsWidgets);

      // Tap on another chip, e.g., 'E-wallet'
      await tester.tap(find.text('E-wallet'));
      await tester.pumpAndSettle();

      // Parent selector must remain visible even after choosing a different cash/wallet chip
      expect(find.text('Jadikan Kantong (Child Pocket)?'), findsOneWidget);

      // Tap on investment chip, e.g. 'Saham'
      await tester.tap(find.text('Saham'));
      await tester.pumpAndSettle();

      // Parent selector must also remain visible for investment accounts
      expect(find.text('Jadikan Kantong (Child Pocket)?'), findsOneWidget);
    },
  );
}
