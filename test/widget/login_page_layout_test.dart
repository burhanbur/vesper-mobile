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
}
