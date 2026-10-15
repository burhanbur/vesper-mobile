import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/widgets/lifecycle_privacy_shield.dart';

void main() {
  testWidgets(
    'inactive content is obscured without destroying local UI state',
    (tester) async {
      final controller = TextEditingController(text: 'unsaved draft');
      addTearDown(controller.dispose);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(
        MaterialApp(
          home: LifecyclePrivacyShield(
            child: Scaffold(body: TextField(controller: controller)),
          ),
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
      final ignorePointers = tester.widgetList<IgnorePointer>(
        find.descendant(
          of: find.byType(LifecyclePrivacyShield),
          matching: find.byType(IgnorePointer),
        ),
      );
      expect(ignorePointers.any((w) => w.ignoring), isTrue);
      expect(controller.text, 'unsaved draft');
      expect(
        tester.binding.focusManager.primaryFocus?.context?.widget
            is EditableText,
        isFalse,
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
      expect(controller.text, 'unsaved draft');

      // Resume via valid transition: paused → hidden → inactive → resumed
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.byIcon(Icons.shield_outlined), findsNothing);
      expect(find.text('unsaved draft'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
