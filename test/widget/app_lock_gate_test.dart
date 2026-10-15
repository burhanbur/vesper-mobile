import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/widgets/app_lock_gate.dart';
import 'package:vesper_mobile/core/security/app_lock_controller.dart';

import '../fixtures/security_fakes.dart';

void main() {
  testWidgets('hardware back cannot dismiss a concealed draft route', (
    tester,
  ) async {
    final storage = MemorySecurityStorage()
      ..values[AppLockController.preferenceKey] = 'true';
    final lock = AppLockController(
      storage: storage,
      authenticator: FakeDeviceAuthenticator(),
    );
    final observer = AppLockRouteObserver(lock);
    final navigator = GlobalKey<NavigatorState>();
    final draft = TextEditingController(text: 'draft on another route');
    await lock.initialize();
    await lock.unlock();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [observer],
        builder: (_, child) => AppLockGate(controller: lock, child: child!),
        home: const Scaffold(body: Text('home')),
      ),
    );
    navigator.currentState!.push<void>(
      MaterialPageRoute(
        builder: (_) => Scaffold(body: TextField(controller: draft)),
      ),
    );
    await tester.pumpAndSettle();
    lock.lock();
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await lock.unlock();
    await tester.pumpAndSettle();
    expect(find.text('draft on another route'), findsOneWidget);
    expect(navigator.currentState!.canPop(), isTrue);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    observer.dispose();
    lock.dispose();
    draft.dispose();
  });

  testWidgets(
    'lock conceals routes, semantics and focus, preserves drafts on resume',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final storage = MemorySecurityStorage()
        ..values[AppLockController.preferenceKey] = 'true';
      final auth = FakeDeviceAuthenticator();
      final lock = AppLockController(storage: storage, authenticator: auth);
      final text = TextEditingController(text: 'unsaved financial draft');
      addTearDown(lock.dispose);
      addTearDown(text.dispose);
      await lock.initialize();
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) =>
              AppLockGate(controller: lock, child: child!),
          home: Scaffold(
            body: TextField(
              controller: text,
              decoration: const InputDecoration(labelText: 'Private amount'),
            ),
          ),
        ),
      );
      expect(find.text('Vesper terkunci'), findsOneWidget);
      expect(find.text('unsaved financial draft'), findsNothing);
      expect(find.bySemanticsLabel('Private amount'), findsNothing);
      await tester.tap(find.text('Buka aplikasi'));
      await tester.pumpAndSettle();
      expect(find.text('unsaved financial draft'), findsOneWidget);
      await tester.tap(find.byType(TextField));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.text('unsaved financial draft'), findsNothing);
      expect(
        tester.binding.focusManager.primaryFocus?.context?.widget
            is EditableText,
        isFalse,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text('Vesper terkunci'), findsOneWidget);
      expect(text.text, 'unsaved financial draft');
      final response = Completer<bool>();
      auth.response = () => response.future;
      await tester.tap(find.text('Buka aplikasi'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      response.complete(false);
      await tester.pumpAndSettle();
      expect(find.text('Vesper terkunci'), findsOneWidget);
      auth.response = null;
      await tester.tap(find.text('Buka aplikasi'));
      await tester.pumpAndSettle();
      expect(find.text('unsaved financial draft'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      semantics.dispose();
    },
  );
}
