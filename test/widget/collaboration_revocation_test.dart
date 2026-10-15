import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/features/household/widgets/collaboration_panel.dart';

import '../fixtures/cached_finance.dart';

class RevocationClient extends ApiClient {
  bool revoked = false, absentActor = false;
  Completer<dynamic>? pendingRead;
  Completer<dynamic>? pendingMembership;
  int memberships = 0;

  Map<String, dynamic> snapshot(Map<String, dynamic> query) => {
    'period': query['period'],
    'page': query['page'],
    'limit': 20,
    'balances': [
      <String, dynamic>{'currency': 'IDR', 'balance': '12345.67'},
    ],
    'contributions': <dynamic>[],
    'feed': <dynamic>[],
  };

  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    bool authenticated = true,
    bool retry = true,
  }) async {
    if (method == 'POST') {
      memberships++;
      if (pendingMembership != null) return pendingMembership!.future;
    }
    if (revoked) throw const ApiFailure('Akses dicabut.', statusCode: 403);
    if (path.endsWith('/members')) {
      return [
        if (!absentActor)
          <String, dynamic>{
            'user_id': 'user',
            'name': 'Owner',
            'role': 'OWNER',
          },
        <String, dynamic>{
          'user_id': 'other',
          'name': 'Private member',
          'role': 'MEMBER',
        },
      ];
    }
    if (pendingRead != null) return pendingRead!.future;
    return snapshot(query!);
  }
}

void main() {
  Future<AppState> mount(WidgetTester tester, RevocationClient client) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final state = cachedFinanceState(client: client);
    state.repository!.atomic(() {
      state.repository!.entities['groups'] = {
        'group': <String, dynamic>{'id': 'group', 'name': 'Group'},
      };
    });
    addTearDown(state.dispose);
    await tester.pumpWidget(
      AppStateScope(
        state: state,
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: CollaborationPanel()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return state;
  }

  testWidgets(
    '403 during member management removes old private data and privileges',
    (tester) async {
      final client = RevocationClient();
      final state = await mount(tester, client);
      expect(find.text('IDR 12345.67'), findsOneWidget);
      expect(find.textContaining('Private member'), findsOneWidget);
      final original = state.repository!.store.read();
      client.pendingMembership = Completer<dynamic>();
      await tester.ensureVisible(find.byType(PopupMenuButton<String>));
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hapus / keluar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Konfirmasi'));
      await tester.pump();
      expect(client.memberships, 1);
      client.pendingMembership!.completeError(
        const ApiFailure('Akses dicabut.', statusCode: 403),
      );
      await tester.pumpAndSettle();
      expect(find.text('IDR 12345.67'), findsNothing);
      expect(find.textContaining('Private member'), findsNothing);
      expect(find.byType(PopupMenuButton<String>), findsNothing);
      expect(find.text('Akses dicabut.'), findsOneWidget);
      expect(state.repository!.store.read(), original);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'revocation during background discards in-flight pre-revocation response',
    (tester) async {
      final client = RevocationClient();
      await mount(tester, client);
      final stale = Completer<dynamic>();
      client.pendingRead = stale;
      await tester.tap(find.text('Muat ulang kolaborasi'));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      client.pendingRead = null;
      client.revoked = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      stale.complete(client.snapshot({'period': '2026-10', 'page': 1}));
      await tester.pumpAndSettle();
      expect(find.text('IDR 12345.67'), findsNothing);
      expect(find.textContaining('Private member'), findsNothing);
      expect(find.text('Akses dicabut.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'read followed by missing actor membership never publishes aggregates',
    (tester) async {
      await mount(tester, RevocationClient()..absentActor = true);
      expect(find.text('IDR 12345.67'), findsNothing);
      expect(find.byType(PopupMenuButton<String>), findsNothing);
      expect(
        find.text('Keanggotaan tidak dapat diverifikasi. Muat ulang grup.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
