import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vesper_mobile/app/app.dart';
import 'package:vesper_mobile/features/auth/pages/login_page.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  testWidgets('VesperApp smoke test', (WidgetTester tester) async {
    // Set screen size for consistent test rendering
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    FlutterSecureStorage.setMockInitialValues({});

    // Build VesperApp and trigger a frame.
    await tester.pumpWidget(const VesperApp());
    await tester.pumpAndSettle();

    // Verify key UI elements appear
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.text('Vesper Finance'), findsOneWidget);
    expect(find.text('Masuk ke Akun'), findsOneWidget);
    expect(find.text('Total Kekayaan'), findsNothing);
    expect(find.text('Keluarga Mafazi'), findsNothing);
    expect(find.text('Beranda'), findsNothing);
    expect(find.text('Masuk Cepat (Akun Demo)'), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
