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
        find.textContaining('PIN dan biometrik belum tersedia'),
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
