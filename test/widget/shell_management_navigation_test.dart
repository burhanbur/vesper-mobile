import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/app/widgets/main_shell.dart';
import 'package:vesper_mobile/features/accounts/pages/accounts_page.dart';
import 'package:vesper_mobile/features/categories/pages/categories_page.dart';
import 'package:vesper_mobile/features/settings/pages/settings_page.dart';

Future<void> pumpShell(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1000, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  // Empty production state: no demo data, login, database, or network needed.
  final state = AppState();
  addTearDown(state.dispose);
  await tester.pumpWidget(
    AppStateScope(
      state: state,
      child: const MaterialApp(home: MainShell()),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Lainnya'));
  await tester.pumpAndSettle();
}

void expectBottomNav() {
  for (final label in ['Beranda', 'Transaksi', 'Grup', 'Lainnya']) {
    expect(find.text(label).hitTestable(), findsOneWidget);
  }
  expect(
    find.byKey(const ValueKey('shell_quick_action')).hitTestable(),
    findsOneWidget,
  );
}

Future<void> openManagement(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  for (final entry in {
    'Kelola Akun & Kantong (Pockets)': AccountsPage,
    'Kelola Kategori Transaksi': CategoriesPage,
  }.entries) {
    testWidgets(
      '${entry.value} keeps nav and returns via app bar and Android back',
      (tester) async {
        await pumpShell(tester);
        final settingsElement = tester.element(find.byType(SettingsPage));
        final scrollable = find
            .descendant(
              of: find.byType(SettingsPage),
              matching: find.byType(Scrollable),
            )
            .first;
        await openManagement(tester, entry.key);
        final scrollState = tester.state<ScrollableState>(
          find
              .descendant(
                of: find.byType(SettingsPage, skipOffstage: false),
                matching: find.byType(Scrollable, skipOffstage: false),
                skipOffstage: false,
              )
              .first,
        );
        final offset = scrollState.position.pixels;
        expect(find.byType(entry.value), findsOneWidget);
        expectBottomNav();
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.byType(entry.value), findsNothing);
        expect(
          tester.element(find.byType(SettingsPage)),
          same(settingsElement),
        );
        expect(
          tester.state<ScrollableState>(scrollable).position.pixels,
          offset,
        );

        await openManagement(tester, entry.key);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(entry.value), findsNothing);
        expect(find.byType(SettingsPage), findsOneWidget);
        expectBottomNav();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '${entry.value} tab switch clears management and quick action survives',
      (tester) async {
        await pumpShell(tester);
        await openManagement(tester, entry.key);
        await tester.tap(find.byKey(const ValueKey('shell_quick_action')));
        await tester.pumpAndSettle();
        expect(find.text('Aksi Cepat'), findsOneWidget);
        expect(find.text('Catat Pengeluaran'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(entry.value), findsOneWidget);
        expectBottomNav();

        await tester.tap(find.text('Beranda'));
        await tester.pumpAndSettle();
        expect(find.byType(entry.value, skipOffstage: false), findsNothing);
        expect(find.text('Akun & Rekening'), findsOneWidget);
        await tester.tap(find.text('Lainnya'));
        await tester.pumpAndSettle();
        expect(find.byType(SettingsPage), findsOneWidget);
        expect(find.byType(entry.value, skipOffstage: false), findsNothing);
        // Selecting the current tab also dismisses management.
        await openManagement(tester, entry.key);
        await tester.tap(find.text('Lainnya'));
        await tester.pumpAndSettle();
        expect(find.byType(entry.value, skipOffstage: false), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('ordinary settings routes remain fullscreen', (tester) async {
    await pumpShell(tester);
    await tester.tap(find.text('Aset & Portofolio Investasi'));
    await tester.pumpAndSettle();
    expect(find.text('Lainnya').hitTestable(), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
    expectBottomNav();
    expect(tester.takeException(), isNull);
  });
}
