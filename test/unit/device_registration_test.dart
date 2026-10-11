import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/database/local_store.dart';
import 'package:vesper_mobile/features/sync/data/finance_repository.dart';

class RegistrationClient extends ApiClient {
  final List<String> paths = [];
  final List<Map<String, dynamic>> registrations = [];
  bool failRegistration = false;

  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    bool authenticated = true,
    bool retry = true,
  }) async {
    paths.add(path);
    if (path == '/devices') {
      registrations.add(Map<String, dynamic>.from(body!));
      if (failRegistration) throw const ApiFailure('Offline');
      return body;
    }
    if (path == '/sync/pull') {
      return {'changes': [], 'next_version': '0', 'has_more': false};
    }
    throw StateError('Unexpected request: $path');
  }
}

void main() {
  test(
    'registration uses only strict fields before sync and reuses persisted ID',
    () async {
      final store = LocalStore(sqlite3.openInMemory());
      addTearDown(store.close);
      final client = RegistrationClient()..failRegistration = true;
      final repo = FinanceRepository(client, store, 'user');
      await expectLater(repo.sync(), throwsA(isA<ApiFailure>()));
      final id = store.read()['device_id'];
      expect(id, isA<String>());
      expect(client.paths, ['/devices']);
      client.failRegistration = false;
      await repo.sync();
      expect(client.paths, ['/devices', '/devices', '/sync/pull']);
      expect(client.registrations.last.keys.toSet(), {
        'id',
        'name',
        'platform',
        'app_version',
      });
      expect(client.registrations.last['id'], id);
      expect(client.registrations.last['platform'], kIsWeb ? 'Web' : 'Android');
      expect(client.registrations.last['app_version'], isNotEmpty);
    },
  );

  test('iOS metadata is registered as iOS', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final store = LocalStore(sqlite3.openInMemory());
    addTearDown(store.close);
    final client = RegistrationClient();
    await FinanceRepository(client, store, 'user').sync();
    expect(client.registrations.single['platform'], kIsWeb ? 'Web' : 'iOS');
  });
}
