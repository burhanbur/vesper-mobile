import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/app.dart';
import 'package:vesper_mobile/features/auth/pages/login_page.dart';

void main() {
  group('Auth & Session Flow Tests', () {
    testWidgets('Starts at LoginPage when unauthenticated', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(const VesperApp(initialAuthenticated: false));
      await tester.pumpAndSettle();

      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.text('Vesper Finance'), findsOneWidget);
      expect(find.text('Personal & Household Wealth Management'), findsOneWidget);
      expect(find.text('Masuk Cepat (Akun Demo)'), findsOneWidget);
      expect(find.text('Burhan Mafazi'), findsOneWidget);
      expect(find.text('Sarah Mafazi'), findsOneWidget);
      expect(find.text('Masuk ke Akun'), findsOneWidget);
    });

    testWidgets('Quick demo login switches to MainShell and back via Logout', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Start unauthenticated
      await tester.pumpWidget(const VesperApp(initialAuthenticated: false));
      await tester.pumpAndSettle();

      // Tap Sarah Mafazi demo persona
      await tester.tap(find.text('Sarah Mafazi'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Should now be on MainShell
      expect(find.text('Total Kekayaan'), findsOneWidget);

      // Navigate to Settings
      await tester.tap(find.text('Lainnya'));
      await tester.pumpAndSettle();

      // Verify Sarah's name shows in Settings profile
      expect(find.text('Sarah Mafazi'), findsOneWidget);

      // Scroll down to Logout tile
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -600));
      await tester.pumpAndSettle();

      // Tap Logout tile
      await tester.tap(find.byIcon(Icons.logout_rounded));
      await tester.pumpAndSettle();

      // Confirm dialog appears
      expect(find.text('Logout?'), findsOneWidget);

      // Tap Logout button in dialog
      await tester.tap(find.widgetWithText(TextButton, 'Logout'));
      await tester.pumpAndSettle();

      // Should now be returned to LoginPage
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.text('Vesper Finance'), findsOneWidget);
    });
  });
}
