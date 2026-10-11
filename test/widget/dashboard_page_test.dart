import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/app/widgets/main_shell.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/database/local_store.dart';
import 'package:vesper_mobile/features/accounts/pages/account_detail_page.dart';
import 'package:vesper_mobile/features/accounts/widgets/account_card.dart';
import 'package:vesper_mobile/features/dashboard/pages/dashboard_page.dart';
import 'package:vesper_mobile/features/sync/data/finance_repository.dart';

class _LocalClient extends ApiClient {
  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    bool authenticated = true,
    bool retry = true,
  }) async => throw StateError('No network in dashboard tests');
}

Future<AppState> _pump(
  WidgetTester tester, {
  double scale = 1,
  bool hidden = false,
  bool shell = false,
  bool empty = false,
}) async {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final store = LocalStore(sqlite3.openInMemory());
  final repo = FinanceRepository(_LocalClient(), store, 'user');
  repo.atomic(() {
    repo.entities['accounts'] = {
      for (final id in empty ? <String>[] : ['first', 'second'])
        id: {
          'id': id,
          'name': 'Account $id',
          'user_id': 'user',
          'balance': id == 'first' ? '12345678.00' : '9000.00',
        },
    };
  });
  final state = AppState(repository: repo)..currentUserId = 'user';
  state.toggleOfflineMode();
  if (hidden) state.toggleHideBalance();
  addTearDown(state.dispose);
  addTearDown(store.close);
  await tester.pumpWidget(
    AppStateScope(
      state: state,
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: shell
            ? const MainShell()
            : DashboardPage(
                onNavigateToTransactions: () {},
                onNavigateToInvestments: () {},
                onNavigateToReports: () {},
                onNavigateToHousehold: () {},
              ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return state;
}

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('Dashboard fits 320px at text scale $scale', (tester) async {
      await _pump(tester, scale: scale);
      expect(tester.takeException(), isNull);
      expect(
        tester
            .getSize(find.byKey(const ValueKey('dashboard_month_balance')))
            .width,
        280,
        reason: 'The monthly balance fills the width inside the page margins.',
      );
      final card = find.byKey(const ValueKey('dashboard_account_first'));
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getSize(card).width, 200);
      if (scale == 1) expect(tester.getSize(card).height, lessThan(150));
      final strip = find.ancestor(
        of: card,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is SingleChildScrollView &&
              widget.scrollDirection == Axis.horizontal,
        ),
      );
      expect(strip, findsOneWidget);
      expect(
        tester.getSize(strip).height,
        closeTo(tester.getSize(card).height + 8, 1),
        reason: 'The account strip must size to its content, not a tall slot.',
      );
      expect(
        tester.getTopLeft(find.text('Transaksi Terbaru')).dy -
            tester.getBottomLeft(card).dy,
        lessThan(40),
        reason: 'Recent transactions should follow the compact account strip.',
      );
      expect(find.descendant(of: card, matching: find.text('')), findsNothing);
      expect(
        find.descendant(of: card, matching: find.text('Rp 12.345.678')),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Belum ada transaksi'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Privacy hides account and summary balances', (tester) async {
    await _pump(tester, hidden: true);
    expect(find.text('Rp 12.345.678'), findsNothing);
    expect(find.text('Rp 9.000'), findsNothing);
    expect(find.text('•••••••'), findsNWidgets(2));
    expect(find.text('Rp •••••••••'), findsOneWidget);
    expect(find.text('••••••'), findsNWidgets(3));
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text && RegExp(r'Rp\s*[\d]').hasMatch(widget.data ?? ''),
      ),
      findsNothing,
    );
    await tester.tap(find.byIcon(Icons.visibility_off_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Rp 12.345.678'), findsOneWidget);
    expect(find.text('Rp 9.000'), findsOneWidget);
    expect(find.text('•••••••'), findsNothing);
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Rp 12.345.678'), findsNothing);
    expect(find.text('•••••••'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
  testWidgets('Empty dashboard stays compact on a small screen', (
    tester,
  ) async {
    await _pump(tester, empty: true, scale: 2);
    expect(find.byType(AccountCard), findsNothing);
    expect(find.text('Belum ada akun'), findsOneWidget);
    await tester.ensureVisible(find.text('Belum ada transaksi'));
    await tester.pumpAndSettle();
    expect(find.text('Belum ada transaksi').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Second account opens its exact detail and retains shell', (
    tester,
  ) async {
    await _pump(tester, hidden: true, shell: true);
    final card = find.byKey(const ValueKey('dashboard_account_second'));
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AccountDetailPage>(find.byType(AccountDetailPage))
          .accountId,
      'second',
    );
    for (final label in ['Beranda', 'Transaksi', 'Grup', 'Lainnya']) {
      expect(find.text(label).hitTestable(), findsOneWidget);
    }
    expect(
      find.byKey(const ValueKey('shell_quick_action')).hitTestable(),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Pengaturan & Sharing'));
    await tester.pumpAndSettle();
    expect(find.text('Bagikan ke Ruang Grup Bersama'), findsOneWidget);
    expect(find.text('Rp 9.000'), findsNothing);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(AccountCard), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
