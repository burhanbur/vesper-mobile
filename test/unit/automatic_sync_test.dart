import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/core/network/api_client.dart';

import '../fixtures/cached_finance.dart';

class SyncClient extends ApiClient {
  int registrations = 0;
  bool failing = false;
  Completer<void>? gate;
  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    bool authenticated = true,
    bool retry = true,
  }) async {
    if (path == '/devices') {
      registrations++;
      await gate?.future;
      if (failing) throw const ApiFailure('Unavailable');
      return body;
    }
    if (path == '/sync/pull') {
      return {'changes': [], 'next_version': '0', 'has_more': false};
    }
    throw StateError('Unexpected request $path');
  }

  @override
  Future<List<Map<String, dynamic>>> list(
    String path, {
    Map<String, dynamic>? query,
  }) async => [];
}

void main() {
  testWidgets(
    'resume and connectivity trigger sync, none and manual offline do not',
    (tester) async {
      final client = SyncClient();
      final state = cachedFinanceState(client: client);
      final events = StreamController<bool>();
      state.startAutomaticSync(events.stream);
      await state.login(userId: 'user');
      expect(client.registrations, 1);
      events.add(false);
      await tester.pump();
      expect(client.registrations, 1);
      events.add(true);
      await tester.pump();
      expect(client.registrations, 2);
      state.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();
      expect(client.registrations, 3);
      state.toggleOfflineMode();
      events.add(true);
      state.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();
      expect(client.registrations, 3);
      state.toggleOfflineMode();
      await tester.pump();
      expect(client.registrations, 4);
      state.dispose();
      events.add(true);
      await tester.pump();
      expect(client.registrations, 4);
      unawaited(events.close());
      await tester.pump();
    },
  );

  testWidgets(
    'failures retry at 2, 4, 8 seconds then stop; fresh trigger recovers',
    (tester) async {
      final client = SyncClient()..failing = true;
      final state = cachedFinanceState(client: client);
      await state.login(userId: 'user');
      expect(client.registrations, 1);
      for (final seconds in [2, 4, 8]) {
        await tester.pump(Duration(seconds: seconds));
      }
      expect(client.registrations, 4);
      await tester.pump(const Duration(minutes: 1));
      expect(client.registrations, 4);
      client.failing = false;
      state.requestAutomaticSync();
      await tester.pump();
      expect(client.registrations, 5);
      expect(state.dataError, isNull);
      state.dispose();
      await tester.pump();
    },
  );

  testWidgets('offline and dispose cancel scheduled retries', (tester) async {
    final client = SyncClient()..failing = true;
    final state = cachedFinanceState(client: client);
    await state.login(userId: 'user');
    state.toggleOfflineMode();
    await tester.pump(const Duration(seconds: 30));
    expect(client.registrations, 1);
    state.toggleOfflineMode();
    await tester.pump();
    expect(client.registrations, 2);
    state.dispose();
    await tester.pump(const Duration(seconds: 30));
    expect(client.registrations, 2);
  });

  testWidgets(
    'overlapping triggers coalesce and disposal stops further requests',
    (tester) async {
      final client = SyncClient();
      final state = cachedFinanceState(client: client);
      await state.login(userId: 'user');
      client.gate = Completer<void>();
      state.requestAutomaticSync();
      state.requestAutomaticSync();
      state.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();
      expect(client.registrations, 2);
      state.dispose();
      client.gate!.complete();
      await tester.pump();
      expect(client.registrations, 2);
      expect(tester.takeException(), isNull);
    },
  );
}
