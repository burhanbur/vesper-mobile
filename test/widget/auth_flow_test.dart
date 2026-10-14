import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/app.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/app/widgets/main_shell.dart';
import 'package:vesper_mobile/features/auth/pages/login_page.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  Future<void> pumpLogin(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const VesperApp());
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Unauthenticated startup requires credentials and offers no demo identity',
    (tester) async {
      await pumpLogin(tester);
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.text('Vesper Finance'), findsOneWidget);
      expect(
        find.text('Personal & Household Wealth Management'),
        findsOneWidget,
      );
      expect(find.text('Masuk ke Akun'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text('Masuk Cepat (Akun Demo)'), findsNothing);
      expect(find.text('Burhan Mafazi'), findsNothing);
      expect(find.text('Sarah Mafazi'), findsNothing);
      expect(find.byType(MainShell), findsNothing);
      final state = AppStateScope.of(tester.element(find.byType(LoginPage)));
      expect(state.isAuthenticated, isFalse);
      expect(state.currentUserId, isEmpty);
      expect(state.repository, isNull);
    },
  );
  testWidgets('Invalid login and registration cannot create a local session', (
    tester,
  ) async {
    await pumpLogin(tester);
    await tester.enterText(find.byType(TextField).first, 'invalid-email');
    await tester.enterText(find.byType(TextField).last, 'password');
    await tester.tap(find.text('Masuk ke Akun'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Masukkan email dan kata sandi yang valid.'),
      findsOneWidget,
    );
    final state = AppStateScope.of(tester.element(find.byType(LoginPage)));
    expect(state.isAuthenticated, isFalse);
    expect(state.currentFlow, AppFlowStep.auth);
    expect(state.repository, isNull);
    await tester.tap(find.text('Daftar'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(3));
    expect(find.byType(MainShell), findsNothing);
    expect(
      await const FlutterSecureStorage().read(key: 'vesper.session'),
      isNull,
    );
    expect(tester.takeException(), isNull);
  });
}
