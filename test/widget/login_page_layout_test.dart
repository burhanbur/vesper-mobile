import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/features/auth/pages/login_page.dart';

void main() {
  testWidgets('Auth tabs fill their segments and switch forms', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));

    final tabs = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabs.indicatorSize, TabBarIndicatorSize.tab);
    expect(find.text('Masuk'), findsOneWidget);
    expect(find.text('Daftar'), findsOneWidget);
    expect(
      find.text('Arsitektur Offline-First & Enkripsi Lokal'),
      findsNothing,
    );
    expect(find.text('Nama Lengkap'), findsNothing);

    await tester.tap(find.text('Daftar'));
    await tester.pumpAndSettle();
    expect(find.text('Nama Lengkap'), findsOneWidget);

    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();
    expect(find.text('Nama Lengkap'), findsNothing);
  });

  testWidgets(
    'LoginPage configures keyboard actions and shows/clears inline validation errors',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginPage()));

      final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
      expect(fields, hasLength(2));
      expect(fields[0].textInputAction, TextInputAction.next);
      expect(fields[1].textInputAction, TextInputAction.done);

      // Submit empty form -> inline field errors appear
      await tester.tap(find.text('Masuk ke Akun'));
      await tester.pumpAndSettle();
      expect(find.text('Masukkan format email yang valid'), findsOneWidget);
      expect(find.text('Kata sandi wajib diisi'), findsOneWidget);

      // Typing in email clears email inline error immediately
      await tester.enterText(find.byType(TextField).first, 'user@example.com');
      await tester.pumpAndSettle();
      expect(find.text('Masukkan format email yang valid'), findsNothing);
      expect(find.text('Kata sandi wajib diisi'), findsOneWidget);
    },
  );
}
