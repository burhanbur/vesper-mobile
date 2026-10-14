import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/features/categories/pages/categories_page.dart';

import '../fixtures/cached_finance.dart';

void main() {
  group('CategoriesPage Widget Tests', () {
    testWidgets(
      'Renders categories list, switches tabs, searches, and adds category',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final appState = cachedFinanceState()..currentUserId = 'user';
        appState.toggleOfflineMode();
        addTearDown(appState.dispose);
        appState.repository!.atomic(() {
          (appState.repository!.entities['categories'] as Map)['dividend'] = {
            'id': 'dividend',
            'user_id': 'user',
            'name': 'Dividends',
            'type': 'INCOME',
            'version': '1',
          };
        });
        await tester.pumpWidget(
          AppStateScope(
            state: appState,
            child: const MaterialApp(home: CategoriesPage()),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Verify Expense tab is active by default
        expect(find.text('Kelola Kategori'), findsOneWidget);
        expect(find.text('Food'), findsOneWidget);
        expect(find.text('Salary'), findsNothing);

        // 2. Switch to Income tab
        await tester.tap(find.textContaining('Pemasukan'));
        await tester.pumpAndSettle();

        expect(find.text('Salary'), findsOneWidget);
        expect(find.text('Dividends'), findsOneWidget);
        expect(find.text('Food'), findsNothing);

        // Search and clear the persisted income categories.
        await tester.enterText(find.byType(TextField).first, 'Dividends');
        await tester.pumpAndSettle();
        expect(
          find.text('Dividends', skipOffstage: true).hitTestable(),
          findsNWidgets(2),
        );
        expect(find.text('Salary'), findsNothing);
        await tester.tap(find.byIcon(Icons.clear_rounded));
        await tester.pumpAndSettle();
        expect(find.text('Salary'), findsOneWidget);

        // 4. Tap "Kategori Baru" FAB
        await tester.tap(find.text('Kategori Baru'));
        await tester.pumpAndSettle();

        expect(find.text('Tambah Kategori Baru'), findsOneWidget);

        // Fill in category name
        await tester.enterText(
          find.widgetWithText(TextField, 'Nama Kategori'),
          'Konsultasi IT',
        );
        await tester.pumpAndSettle();

        // Tap submit
        await tester.tap(
          find.widgetWithText(ElevatedButton, 'Tambah Kategori'),
        );
        await tester.pumpAndSettle();

        // Verify new category is in the list
        expect(find.text('Konsultasi IT'), findsOneWidget);
        final repo = appState.repository!;
        expect(repo.outbox, hasLength(1));
        expect(repo.outbox.single['entity_type'], 'categories');
        expect(repo.outbox.single['operation'], 'CREATE');
        expect(repo.outbox.single['payload'], {
          'name': 'Konsultasi IT',
          'type': 'INCOME',
        });
        expect(repo.store.read(), repo.state);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
