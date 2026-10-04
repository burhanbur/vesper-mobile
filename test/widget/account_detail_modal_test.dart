import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/features/accounts/pages/accounts_page.dart';

void main() {
  group('Accounts Page Detail Modal & Dropdown Verification', () {
    testWidgets('Opens account detail for Kas Tunai Dompet without error', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final appState = AppState();
      await tester.pumpWidget(
        AppStateScope(
          state: appState,
          child: const MaterialApp(
            home: AccountsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kas Tunai Dompet'), findsOneWidget);

      // Tap on Kas Tunai Dompet to open detail modal
      await tester.tap(find.text('Kas Tunai Dompet'));
      await tester.pumpAndSettle();

      // Verify modal opened
      expect(find.text('Saldo Rekening'), findsOneWidget);
      expect(find.text('Bagikan ke Ruang Grup Bersama'), findsOneWidget);

      // Toggle switch to share with a group (opens the dropdown)
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      // Dropdown should render safely without assertion errors
      expect(find.text('Pilih Grup yang Dapat Mengakses'), findsOneWidget);

      // Close modal by clicking save
      await tester.tap(find.text('Simpan Pengaturan Rekening'));
      await tester.pumpAndSettle();

      // Tap on a shared account like BCA Utama
      await tester.tap(find.text('BCA Utama'));
      await tester.pumpAndSettle();

      expect(find.text('Saldo Rekening'), findsOneWidget);
      expect(find.text('Pilih Grup yang Dapat Mengakses'), findsOneWidget);

      // Close modal
      await tester.tap(find.text('Simpan Pengaturan Rekening'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
