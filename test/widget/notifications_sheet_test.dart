import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/database/local_store.dart';
import 'package:vesper_mobile/features/notifications/widgets/notifications_sheet.dart';
import 'package:vesper_mobile/features/sync/data/finance_repository.dart';

class _NotificationsClient extends ApiClient {
  final List<(String, String)> calls = [];
  bool failRequests = false;

  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    bool authenticated = true,
    bool retry = true,
  }) async {
    calls.add((method, path));
    if (failRequests) {
      throw const ApiFailure('Backend tidak dapat dihubungi.');
    }
    if (path == '/notifications/read-all') {
      return {'marked_count': 2};
    }
    if (path == '/devices') return {};
    if (path == '/sync/pull') {
      return {'changes': [], 'next_version': '0', 'has_more': false};
    }
    return {};
  }

  @override
  Future<List<Map<String, dynamic>>> list(
    String path, {
    Map<String, dynamic>? query,
  }) async => [];
}

void main() {
  testWidgets(
    'NotificationsSheet marks unread notifications read offline without crashing',
    (tester) async {
      final store = LocalStore(sqlite3.openInMemory());
      final client = _NotificationsClient()..failRequests = true;
      final repo = FinanceRepository(client, store, 'user')..offline = true;
      repo.atomic(() {
        repo.entities['notifications'] = {
          'n1': {
            'id': 'n1',
            'type': 'info',
            'title': 'Perangkat baru terdaftar',
            'body': 'Pixel 9 (Android) telah terhubung.',
            'created_at': '2026-11-27T10:00:00.000Z',
            'is_read': false,
          },
        };
      });
      final state = AppState(repository: repo)..currentUserId = 'user';
      state.toggleOfflineMode();
      addTearDown(state.dispose);
      addTearDown(store.close);

      expect(state.unreadNotificationCount, 1);

      await tester.pumpWidget(
        AppStateScope(
          state: state,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => NotificationsSheet.show(context),
                  child: const Text('Buka Notif'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Buka Notif'));
      await tester.pumpAndSettle();

      expect(find.text('Notifikasi & Aktivitas'), findsOneWidget);
      expect(find.text('Perangkat baru terdaftar'), findsOneWidget);
      expect(state.unreadNotificationCount, 0);
      expect(client.calls, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'NotificationsSheet calls POST /notifications/read-all once when online',
    (tester) async {
      final store = LocalStore(sqlite3.openInMemory());
      final client = _NotificationsClient();
      final repo = FinanceRepository(client, store, 'user');
      repo.atomic(() {
        repo.entities['notifications'] = {
          'n1': {
            'id': 'n1',
            'type': 'warning',
            'title': 'Kata sandi diubah',
            'body': 'Sesi perangkat lain dicabut.',
            'created_at': '2026-11-27T10:00:00.000Z',
            'is_read': false,
          },
          'n2': {
            'id': 'n2',
            'type': 'info',
            'title': 'Bergabung ke grup',
            'body': 'Anda telah bergabung ke grup Keluarga.',
            'created_at': '2026-11-27T11:00:00.000Z',
            'is_read': false,
          },
        };
      });
      final state = AppState(repository: repo)..currentUserId = 'user';
      addTearDown(state.dispose);
      addTearDown(store.close);

      await tester.pumpWidget(
        AppStateScope(
          state: state,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => NotificationsSheet.show(context),
                  child: const Text('Buka Notif'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Buka Notif'));
      await tester.pumpAndSettle();

      expect(
        client.calls
            .where((c) => c.$1 == 'POST' && c.$2 == '/notifications/read-all'),
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
