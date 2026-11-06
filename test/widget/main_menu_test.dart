import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/features/dashboard/widgets/main_menu_card.dart';

void main() {
  testWidgets('MainMenuCard fits 320px at text scale 2.0', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2.0)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: MainMenuCard(
              onNavigateToInvestments: () {},
              onNavigateToReports: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final exception = tester.takeException();
    if (exception is FlutterError) {
      // ignore: avoid_print
      for (final d in exception.diagnostics) {
        // ignore: avoid_print
        print('DIAGNOSTIC: ${d.name} -> ${d.toDescription()}');
      }
    }
    expect(exception, isNull);
  });
}
