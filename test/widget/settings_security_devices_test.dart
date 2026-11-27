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
  final List<(String, String, Map<String, dynamic>?)> calls = [];
  dynamic Function(String method, String path, Map<String, dynamic>? body)?
      onRequest;
  Completer<List<Map<String, dynamic>>> response = Completer();

  @override
  Future<void> saveSession(Map<String, dynamic> value, {bool? persist}) async {
    persisted = persist;
    session = value;
  }

  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    bool authenticated = true,
    bool retry = true,
  }) async {
    calls.add((method, path, body));
    if (onRequest != null) {
      return onRequest!(method, path, body);
    }
    return null;
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

  testWidgets(
    'devices page revokes another device with confirmation and refreshes list',
    (tester) async {
      final client = TestClient();
      var devices = [
        {
          'id': 'current',
          'name': 'Browser saya',
          'platform': 'Web',
          'app_version': '1.0.0',
        },
        {
          'id': 'other',
          'name': 'Telepon lama',
          'platform': 'Android',
          'app_version': '1.0.0',
        },
      ];
      client.onRequest = (method, path, body) {
        if (method == 'DELETE' && path == '/devices/other') {
          devices = devices.where((d) => d['id'] != 'other').toList();
          client.response = Completer()..complete(devices);
          return {'id': 'other', 'revoked_sessions': 1};
        }
        return null;
      };

      await tester.pumpWidget(
        MaterialApp(
          home: DevicesPage(
            repository: DevicesRepository(client: client),
            currentDeviceId: 'current',
          ),
        ),
      );
      client.response.complete(devices);
      await tester.pumpAndSettle();

      // Current device must NOT have a revoke button; other device must have one.
      expect(find.byKey(const ValueKey('revoke_device_current')), findsNothing);
      final revokeButton = find.byKey(const ValueKey('revoke_device_other'));
      await tester.scrollUntilVisible(revokeButton, 200);
      await tester.ensureVisible(revokeButton);
      await tester.pumpAndSettle();
      await tester.tap(revokeButton);
      await tester.pumpAndSettle();

      expect(find.text('Cabut akses perangkat?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Cabut Akses'));
      await tester.pumpAndSettle();

      expect(
        client.calls.any((c) => c.$1 == 'DELETE' && c.$2 == '/devices/other'),
        isTrue,
      );
      expect(find.text('Telepon lama'), findsNothing);
      expect(find.textContaining('berhasil dicabut'), findsOneWidget);
    },
  );

  testWidgets(
    'security page change password validates input and submits to backend',
    (tester) async {
      final client = TestClient()
        ..session = {
          'user': {'id': 'user'},
        }
        ..onRequest = (method, path, body) {
          if (method == 'POST' && path == '/auth/change-password') {
            return {'revoked_other_sessions': 2};
          }
          return null;
        };
      final auth = AuthRepository(client: client);
      await tester.pumpWidget(
        MaterialApp(
          home: SecurityPage(auth: auth, onLogout: () async {}),
        ),
      );

      final tile = find.byKey(const ValueKey('change_password_tile'));
      await tester.scrollUntilVisible(tile, 200);
      await tester.tap(tile);
      await tester.pumpAndSettle();

      // Mismatched confirmation shows inline error
      await tester.enterText(
        find.byKey(const ValueKey('current_password_field')),
        'sandi-lama',
      );
      await tester.enterText(
        find.byKey(const ValueKey('new_password_field')),
        'sandi-baru-123',
      );
      await tester.enterText(
        find.byKey(const ValueKey('confirm_password_field')),
        'tidak-sama',
      );
      await tester.tap(
        find.byKey(const ValueKey('submit_change_password_button')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Konfirmasi kata sandi tidak sama.'), findsOneWidget);

      // Fix confirmation and submit
      await tester.enterText(
        find.byKey(const ValueKey('confirm_password_field')),
        'sandi-baru-123',
      );
      await tester.tap(
        find.byKey(const ValueKey('submit_change_password_button')),
      );
      await tester.pumpAndSettle();

      expect(
        client.calls.any(
          (c) =>
              c.$1 == 'POST' &&
              c.$2 == '/auth/change-password' &&
              c.$3?['current_password'] == 'sandi-lama' &&
              c.$3?['new_password'] == 'sandi-baru-123',
        ),
        isTrue,
      );
      expect(
        find.text('Kata sandi diubah. 2 sesi perangkat lain dicabut.'),
        findsOneWidget,
      );
    },
  );
}
