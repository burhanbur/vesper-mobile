import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:vesper_mobile/app/app.dart';
import 'package:vesper_mobile/features/auth/pages/login_page.dart';
import 'package:vesper_mobile/features/auth/pages/onboarding_page.dart';
import 'package:vesper_mobile/features/auth/pages/splash_page.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  group('Splash and Onboarding Flow Tests', () {
    testWidgets('Splash restores login; guide slides return to unauthenticated login', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Start app with Splash screen enabled
      await tester.pumpWidget(
        const VesperApp(
          initialShowSplash: true,
          initialAuthenticated: false,
        ),
      );
      await tester.pump();

      // 1. Verify Splash Screen
      expect(find.byType(SplashPage), findsOneWidget);
      expect(find.text('VESPER'), findsOneWidget);
      expect(find.text('Personal & Household Finance'), findsOneWidget);
      expect(find.text('⚡ 100% Offline-First Engine Active'), findsOneWidget);
      expect(find.text('Sentuh layar untuk lewati'), findsOneWidget);

      // Tap screen to skip splash
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();

      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(OnboardingPage), findsNothing);
      await tester.tap(find.text('✦ Lihat Panduan & Pengenalan Fitur Vesper'));
      await tester.pumpAndSettle();

      // The guide is explicitly requested, never an authentication shortcut.
      expect(find.byType(OnboardingPage), findsOneWidget);
      expect(find.text('👥 Ruang Grup & Kolaborasi Pasangan'), findsOneWidget);
      expect(find.text('Kelola Keuangan Bersama Pasangan & Grup'), findsOneWidget);
      expect(find.text('Keluarga Mafazi'), findsOneWidget);
      expect(find.text('Lanjutkan'), findsOneWidget);

      // Advance to Slide 2 (Offline-First)
      await tester.tap(find.text('Lanjutkan'));
      await tester.pumpAndSettle();

      expect(find.text('⚡ 100% Offline-First Engine'), findsOneWidget);
      expect(find.text('Catat Mutasi Kapan Saja, Bahkan Tanpa Sinyal'), findsOneWidget);
      expect(find.text('2. Local Database SQLite / Drift'), findsOneWidget);

      // Advance to Slide 3 (Accounts & Net Worth)
      await tester.tap(find.text('Lanjutkan'));
      await tester.pumpAndSettle();

      expect(find.text('💎 Manajemen Kekayaan Terpadu'), findsOneWidget);
      expect(find.text('Pantau Kas, Bank, & Portofolio Investasi'), findsOneWidget);
      expect(find.text('TOTAL KEKAYAAN BERSIH'), findsOneWidget);
      expect(find.text('Mulai Sekarang'), findsOneWidget);

      // Tap "Mulai Sekarang" to transition to LoginPage
      await tester.tap(find.text('Mulai Sekarang'));
      await tester.pumpAndSettle();

      // 3. Verify LoginPage
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.text('✦ Lihat Panduan & Pengenalan Fitur Vesper'), findsOneWidget);

      // Tap "Lihat Panduan & Pengenalan Fitur Vesper" to reopen Onboarding
      await tester.tap(find.text('✦ Lihat Panduan & Pengenalan Fitur Vesper'));
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingPage), findsOneWidget);

      // Tap "Lewati" to go back to LoginPage
      await tester.tap(find.text('Lewati'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginPage), findsOneWidget);

      expect(find.text('Masuk ke Akun'), findsOneWidget);
      expect(find.text('Masuk Cepat (Akun Demo)'), findsNothing);
      expect(find.text('Total Kekayaan'), findsNothing);
      expect(await const FlutterSecureStorage().read(key: 'vesper.session'), isNull);
      expect(tester.takeException(), isNull);
    });
  });
}
