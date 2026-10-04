import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/features/categories/pages/categories_page.dart';

void main() {
  group('CategoriesPage Widget Tests', () {
    testWidgets('Renders categories list, switches tabs, searches, and adds category', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final appState = AppState();
      await tester.pumpWidget(
        AppStateScope(
          state: appState,
          child: const MaterialApp(
            home: CategoriesPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify Expense tab is active by default
      expect(find.text('Kelola Kategori'), findsOneWidget);
      expect(find.text('Makanan & Minuman'), findsOneWidget);
      expect(find.text('Belanja Bulanan'), findsOneWidget);

      // 2. Switch to Income tab
      await tester.tap(find.textContaining('Pemasukan'));
      await tester.pumpAndSettle();

      expect(find.text('Gaji Pokok'), findsOneWidget);
      expect(find.text('Dividen & Investasi'), findsOneWidget);

      // 3. Search category
      await tester.enterText(find.byType(TextField).first, 'Dividen');
      await tester.pumpAndSettle();

      expect(find.text('Dividen & Investasi'), findsOneWidget);
      expect(find.text('Gaji Pokok'), findsNothing);

      // Clear search
      await tester.tap(find.byIcon(Icons.clear_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Gaji Pokok'), findsOneWidget);

      // 4. Tap "Kategori Baru" FAB
      await tester.tap(find.text('Kategori Baru'));
      await tester.pumpAndSettle();

      expect(find.text('Tambah Kategori Baru'), findsOneWidget);

      // Fill in category name
      await tester.enterText(find.widgetWithText(TextField, 'Nama Kategori'), 'Konsultasi IT');
      await tester.pumpAndSettle();

      // Tap submit
      await tester.tap(find.widgetWithText(ElevatedButton, 'Tambah Kategori'));
      await tester.pumpAndSettle();

      // Verify new category is in the list
      expect(find.text('Konsultasi IT'), findsOneWidget);
      expect(find.text('Kustom'), findsOneWidget);
    });
  });
}
