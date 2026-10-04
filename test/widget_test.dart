import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vesper_mobile/app/app.dart';

void main() {
  testWidgets('VesperApp smoke test', (WidgetTester tester) async {
    // Set screen size for consistent test rendering
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    // Build VesperApp and trigger a frame.
    await tester.pumpWidget(const VesperApp());
    await tester.pumpAndSettle();

    // Verify key UI elements appear
    expect(find.text('Total Kekayaan'), findsOneWidget);
    expect(find.text('Keluarga Mafazi'), findsWidgets);
    expect(find.text('Beranda'), findsOneWidget);
    expect(find.text('Transaksi'), findsWidgets);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
