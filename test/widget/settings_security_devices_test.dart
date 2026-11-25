import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/features/auth/data/auth_repository.dart';
import 'package:vesper_mobile/features/settings/data/devices_repository.dart';
import 'package:vesper_mobile/features/settings/pages/devices_page.dart';
import 'package:vesper_mobile/features/settings/pages/security_page.dart';

class TestClient extends ApiClient {
  bool? persisted;
  String? requestedPath;
  Completer<List<Map<String, dynamic>>> response = Completer();

  @override
  Future<void> saveSession(Map<String, dynamic> value, {bool? persist}) async {
    persisted = persist;
    session = value;
  }

  @override
  Future<List<Map<String, dynamic>>> list(
    String path, {
    Map<String, dynamic>? query,
  }) {
    requestedPath = path;
    return response.future;
  }
}

void main() {
  testWidgets(
    'devices load real repository results, retry errors and mark current ID',
    (tester) async {
      final client = TestClient();
      await tester.pumpWidget(
        MaterialApp(
          home: DevicesPage(
            repository: DevicesRepository(client: client),
            currentDeviceId: 'current',
          ),
        ),
      );
      expect(client.requestedPath, '/devices');
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      client.response.completeError(const ApiFailure('Tidak terhubung.'));
      await tester.pumpAndSettle();
      expect(find.text('Tidak terhubung.'), findsOneWidget);
      client.response = Completer();
      await tester.tap(find.text('Coba lagi'));
      await tester.pump();
      client.response.complete([
        {
          'id': 'current',
          'name': 'Browser saya',
          'platform': 'Web',
          'app_version': '1.0.0',
        },
        {
          'id': 'other',
          'name': 'Telepon',
          'platform': 'Android',
          'app_version': '1.0.0',
        },
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Browser saya'), findsOneWidget);
      expect(find.text('Telepon'), findsOneWidget);
      expect(find.text('Perangkat ini'), findsOneWidget);
      expect(find.byIcon(Icons.logout_rounded), findsNothing);
    },
  );

  testWidgets(
    'devices page renders rich device model, OS badge, and last login timestamps',
    (tester) async {
      final client = TestClient();
      await tester.pumpWidget(
        MaterialApp(
          home: DevicesPage(
            repository: DevicesRepository(client: client),
            currentDeviceId: 'dev-s10',
          ),
        ),
      );
      client.response.complete([
        {
          'id': 'dev-web',
          'name': 'Chrome • Windows',
          'platform': 'Web',
          'app_version': '1.0.0',
          'last_seen_at': '2026-11-20T08:30:00.000Z',
          'last_sync_at': '2026-11-20T08:31:00.000Z',
          'created_at': '2026-11-01T01:00:00.000Z',
        },
        {
          'id': 'dev-s10',
          'name': 'Samsung Galaxy S10 • Android 12',
          'platform': 'Android',
          'app_version': '1.2.0',
          'last_seen_at': '2026-11-25T14:00:00.000Z',
          'last_sync_at': '2026-11-25T14:05:00.000Z',
          'created_at': '2026-10-15T05:00:00.000Z',
        },
      ]);
      await tester.pumpAndSettle();

      expect(find.text('2 Perangkat Terdaftar'), findsOneWidget);
      expect(find.text('PERANGKAT SAAT INI'), findsOneWidget);
      expect(find.text('Samsung Galaxy S10'), findsOneWidget);
      expect(find.text('Android 12'), findsOneWidget);
      expect(find.text('Vesper v1.2.0'), findsOneWidget);
      expect(find.text('Perangkat ini'), findsOneWidget);
      expect(find.text('Terakhir login / aktif'), findsWidgets);
      expect(find.text('Sinkronisasi terakhir'), findsWidgets);
      expect(find.text('Pertama terdaftar'), findsWidgets);
      expect(find.text('Chrome'), findsOneWidget);
      expect(find.text('Web • Windows'), findsOneWidget);

      // Current device is pinned above other devices.
      final currentTop = tester.getTopLeft(find.text('Samsung Galaxy S10')).dy;
      final otherTop = tester.getTopLeft(find.text('Chrome')).dy;
      expect(currentTop, lessThan(otherTop));
    },
  );

  testWidgets(
    'security changes session persistence without ending active session',
    (tester) async {
      final client = TestClient()
        ..session = {
          'user': {'id': 'user'},
        };
      final auth = AuthRepository(client: client);
      await tester.pumpWidget(
        MaterialApp(
          home: SecurityPage(auth: auth, onLogout: () async {}),
        ),
      );
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(auth.rememberMe, isTrue);
      expect(client.persisted, isTrue);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(auth.rememberMe, isFalse);
      expect(client.persisted, isFalse);
      expect(client.session, isNotNull);
      expect(
        find.textContaining('Kunci perangkat tidak tersedia'),
        findsOneWidget,
      );
    },
  );

  test('remember preference requires an active session', () async {
    final auth = AuthRepository(client: TestClient());
    await expectLater(auth.setRememberMe(true), throwsA(isA<ApiFailure>()));
    expect(auth.rememberMe, isFalse);
  });
}
