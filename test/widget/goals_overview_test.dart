import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/features/goals/data/goals_repository.dart';
import 'package:vesper_mobile/features/goals/widgets/goals_overview.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('Empty goals offers creation at 320px, scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var creates = 0;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: GoalsOverview(
                progresses: const [],
                hidden: false,
                onCreate: () => creates++,
              ),
            ),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.ensureVisible(find.text('Buat goal pertama'));
      await tester.tap(find.text('Buat goal pertama'));
      expect(creates, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Overview charts achieved count, not mixed money totals', (
    tester,
  ) async {
    final progress = [
      GoalProgress(
        BigInt.from(100),
        BigInt.from(100),
        BigInt.from(100),
        BigInt.zero,
        BigInt.zero,
        false,
      ),
      GoalProgress(
        BigInt.from(1000),
        BigInt.zero,
        BigInt.zero,
        BigInt.zero,
        BigInt.zero,
        false,
      ),
    ];
    Future<void> mount(bool hidden) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GoalsOverview(
            progresses: progress,
            hidden: hidden,
            onCreate: () {},
          ),
        ),
      ),
    );
    await mount(false);
    expect(find.text('1 / 2'), findsOneWidget);
    expect(
      tester
          .widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator),
          )
          .value,
      0.5,
    );
    await mount(true);
    expect(find.text('1 / 2'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('••• / 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
