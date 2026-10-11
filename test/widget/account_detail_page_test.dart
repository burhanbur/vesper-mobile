import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/app/widgets/main_shell.dart';
import 'package:vesper_mobile/features/accounts/widgets/account_picker_sheet.dart';
import 'package:vesper_mobile/features/transactions/widgets/add_transaction_modal.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/database/local_store.dart';
import 'package:vesper_mobile/features/accounts/pages/account_detail_page.dart';
import 'package:vesper_mobile/features/accounts/pages/accounts_page.dart';
import 'package:vesper_mobile/features/sync/data/finance_repository.dart';
import 'package:vesper_mobile/features/transactions/widgets/transaction_item_tile.dart';

class _NoNetworkClient extends ApiClient {
  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    bool authenticated = true,
    bool retry = true,
  }) async => throw StateError('Fixture must remain local');
}

AppState _fixture({bool empty = false, bool hidden = false}) {
  final store = LocalStore(sqlite3.openInMemory());
  final repo = FinanceRepository(_NoNetworkClient(), store, 'user');
  repo.atomic(() {
    repo.entities['accounts'] = {
      for (final id in ['acc-jago', 'pocket', 'other'])
        id: {
          'id': id,
          'name': id == 'acc-jago' ? 'Main account' : id,
          'balance': '9000.00',
          'user_id': 'user',
          if (id == 'pocket') 'parent_account_id': 'acc-jago',
        },
    };
    repo.entities['transactions'] = {
      if (!empty) ...{
        for (final row in [
          ['income', 'acc-jago', 'INCOME', '1000.00', '2026-01-01'],
          ['expense', 'acc-jago', 'EXPENSE', '200.00', '2026-01-02'],
          ['outgoing', 'acc-jago', 'TRANSFER', '-300.00', '2026-01-03'],
          ['incoming', 'acc-jago', 'TRANSFER', '400.00', '2026-01-04'],
          ['pocket-row', 'pocket', 'TRANSFER', '300.00', '2026-01-03'],
          ['other-row', 'other', 'TRANSFER', '-400.00', '2026-01-04'],
        ])
          row[0]: {
            'id': row[0],
            'account_id': row[1],
            'type': row[2],
            'amount': row[3],
            'transacted_at': '${row[4]}T12:00:00Z',
            'description': row[0],
            if (row[2] == 'TRANSFER')
              'transfer_id': row[3].contains('300') ? 'pair-1' : 'pair-2',
          },
      },
    };
  });
  final state = AppState(repository: repo)..currentUserId = 'user';
  state.toggleOfflineMode();
  if (hidden) state.toggleHideBalance();
  addTearDown(state.dispose);
  addTearDown(store.close);
  return state;
}

Future<void> _pump(WidgetTester tester, AppState state, Widget page) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    AppStateScope(
      state: state,
      child: MaterialApp(home: page),
    ),
  );
  await tester.pumpAndSettle();
}

Widget _detail(String id) =>
    AccountDetailPage(accountId: id, onSettings: () {});

void main() {
  testWidgets('Adjustment validates, previews and saves local history', (
    tester,
  ) async {
    final state = _fixture(empty: true);
    await _pump(tester, state, _detail('acc-jago'));
    await tester.tap(find.text('Ubah Saldo'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1.5');
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.enterText(find.byType(TextField), '10000');
    await tester.pumpAndSettle();
    expect(find.text('Pemasukan: +Rp 1.000'), findsOneWidget);
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(
      find.byType(AlertDialog),
      findsNothing,
      reason: tester
          .widgetList<Text>(find.byType(Text))
          .map((text) => text.data)
          .join('\n'),
    );
    expect(state.getAccountById('acc-jago')!.balance, 10000);
    expect(state.repository!.store.read(), state.repository!.state);
    expect(state.repository!.outbox.map((item) => item['entity_type']), [
      'categories',
      'transactions',
    ]);
    expect(find.text('Rp 10.000'), findsOneWidget);
    expect(find.byType(TransactionItemTile), findsOneWidget);
    expect(state.transactions.single.categoryName, 'Lainnya');
  });
  testWidgets('Hidden adjustment obscures input and preview', (tester) async {
    await _pump(tester, _fixture(hidden: true), _detail('acc-jago'));
    await tester.tap(find.text('Ubah Saldo'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '10000');
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).obscureText,
      isTrue,
    );
    expect(find.text('Pemasukan: ••••••'), findsOneWidget);
    expect(find.textContaining('Rp'), findsNothing);
  });
  testWidgets(
    'Local exact-account ledger retains signs, pairs and newest order',
    (tester) async {
      final state = _fixture();
      await _pump(tester, state, _detail('acc-jago'));
      final tiles = tester
          .widgetList<TransactionItemTile>(find.byType(TransactionItemTile))
          .toList();
      expect(tiles.map((tile) => tile.transaction.id), [
        'incoming',
        'outgoing',
        'expense',
        'income',
      ]);
      expect(tiles.take(2).map((tile) => tile.transaction.ledgerAmount), [
        400,
        -300,
      ]);
      expect(tiles.take(2).map((tile) => tile.transaction.transferId), [
        'pair-2',
        'pair-1',
      ]);
      expect(find.text('Transfer Masuk'), findsOneWidget);
      expect(find.text('Transfer Keluar'), findsOneWidget);
      expect(find.text('+Rp 400'), findsOneWidget);
      expect(find.text('-Rp 300'), findsOneWidget);
      expect(find.text('-Rp 200'), findsOneWidget);
      expect(find.text('+Rp 1.000'), findsOneWidget);
      expect(find.text('pocket-row'), findsNothing);
      expect(find.text('other-row'), findsNothing);
      await tester.tap(find.text('outgoing'));
      await tester.pumpAndSettle();
      expect(find.text('Detail Transaksi'), findsOneWidget);
      expect(find.text('Dibuat oleh'), findsOneWidget);
      expect(find.text('Pelaku (Created By)'), findsNothing);
      expect(find.text('-Rp 300'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Hidden balance also hides amounts in transaction details', (
    tester,
  ) async {
    await _pump(tester, _fixture(hidden: true), _detail('acc-jago'));
    expect(find.text('••••••'), findsNWidgets(5));
    expect(find.textContaining('Rp'), findsNothing);
    await tester.tap(find.text('incoming'));
    await tester.pumpAndSettle();
    expect(find.text('Detail Transaksi'), findsOneWidget);
    expect(find.text('••••••'), findsNWidgets(6));
    expect(find.textContaining('Rp'), findsNothing);
  });

  testWidgets('Empty account history is available offline', (tester) async {
    await _pump(tester, _fixture(empty: true), _detail('acc-jago'));
    expect(find.text('Belum ada transaksi pada akun ini.'), findsOneWidget);
    expect(find.byType(TransactionItemTile), findsNothing);
    expect(find.text('Rp 9.000'), findsOneWidget);
    expect(find.text('Main account'), findsOneWidget);
  });

  testWidgets('Pocket title includes its parent account name', (tester) async {
    await _pump(tester, _fixture(), _detail('pocket'));
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect((appBar.title! as Text).data, 'Main account - pocket');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Account and pocket details keep shell; back and tabs clear routes',
    (tester) async {
      final state = _fixture(hidden: true);
      await _pump(tester, state, const MainShell());
      await tester.tap(find.text('Lainnya'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Kelola Akun & Kantong (Pockets)'));
      await tester.tap(find.text('Kelola Akun & Kantong (Pockets)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Main account'));
      await tester.pumpAndSettle();
      expect(find.byType(AccountDetailPage), findsOneWidget);
      expect(find.text('Lainnya').hitTestable(), findsOneWidget);
      expect(
        find.byKey(const ValueKey('shell_quick_action')).hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Pengaturan & Sharing'));
      await tester.pumpAndSettle();
      expect(find.text('Bagikan ke Ruang Grup Bersama'), findsOneWidget);
      expect(find.textContaining('Rp'), findsNothing);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Lainnya').hitTestable(), findsOneWidget);
      expect(find.byType(AccountsPage), findsOneWidget);
      await tester.tap(find.text('pocket'));
      await tester.pumpAndSettle();
      expect(find.byType(AccountDetailPage), findsOneWidget);
      expect(
        tester
            .widgetList<TransactionItemTile>(find.byType(TransactionItemTile))
            .single
            .transaction
            .id,
        'pocket-row',
      );
      expect(find.text('Lainnya').hitTestable(), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(AccountsPage), findsOneWidget);
      await tester.tap(find.text('pocket'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Beranda'));
      await tester.pumpAndSettle();
      expect(find.byType(AccountDetailPage, skipOffstage: false), findsNothing);
      expect(find.byType(AccountsPage, skipOffstage: false), findsNothing);
      await tester.tap(find.text('Lainnya'));
      await tester.pumpAndSettle();
      expect(find.byType(AccountDetailPage, skipOffstage: false), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Pocket transfer prefills source and rejects unsupported save safely',
    (tester) async {
      final state = _fixture(empty: true);
      await _pump(tester, state, _detail('pocket'));
      await tester.tap(find.text('Transfer Saldo'));
      await tester.pumpAndSettle();
      final selectors = tester
          .widgetList<AccountSelectorTile>(find.byType(AccountSelectorTile))
          .toList();
      expect(selectors[0].account!.id, 'pocket');
      expect(selectors[1].account!.id, 'other');
      await tester.enterText(find.byType(TextField).first, '100');
      await tester.ensureVisible(find.text('Simpan Transaksi'));
      await tester.tap(find.text('Simpan Transaksi'));
      await tester.pumpAndSettle();
      expect(find.byType(AddTransactionModal), findsOneWidget);
      expect(
        find.textContaining('belum mendukung antrean offline'),
        findsOneWidget,
      );
      expect(state.repository!.outbox, isEmpty);
      expect(state.getAccountById('pocket')!.balance, 9000);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Parent with pockets cannot be a transfer source', (
    tester,
  ) async {
    await _pump(tester, _fixture(), _detail('acc-jago'));
    final button = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Transfer Saldo'),
    );
    expect(button.onPressed, isNull);
  });
}
