import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/core/network/api_client.dart';

import '../fixtures/cached_finance.dart';

class PageClient extends ApiClient {
  final dynamic Function(int) response;
  final queries = <Map<String, dynamic>>[];
  PageClient(this.response);

  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    bool authenticated = true,
    bool retry = true,
  }) async {
    queries.add(Map<String, dynamic>.from(query!));
    return response(query['page'] as int);
  }
}

List<Map<String, dynamic>> pageRows(int page) =>
    List.generate(100, (index) => {'id': '$page-$index', 'name': 'Record'});

void main() {
  test(
    'reads complete pages and preserves filters without modifying input',
    () async {
      final client = PageClient(
        (page) => page == 1
            ? pageRows(1)
            : [
                {'id': 'last'},
              ],
      );
      final query = <String, dynamic>{'period': '2026-10', 'page': 99};
      final rows = await client.list('/transactions', query: query);
      expect(rows.length, 101);
      expect(client.queries.map((q) => q['page']), [1, 2]);
      expect(
        client.queries.every(
          (q) => q['limit'] == 100 && q['period'] == '2026-10',
        ),
        isTrue,
      );
      expect(query['page'], 99);
    },
  );

  test('empty and member lists use valid identifiers', () async {
    expect(await PageClient((_) => []).list('/groups'), isEmpty);
    final rows = await PageClient(
      (_) => [
        {'user_id': 'member'},
      ],
    ).list('/members');
    expect(rows.single['user_id'], 'member');
  });

  test(
    'repeated pages fail promptly and preserve persisted repository cache',
    () async {
      final client = PageClient((_) => pageRows(1));
      final state = cachedFinanceState(client: client);
      final repo = state.repository!;
      final before = repo.store.read();
      await expectLater(
        repo.refreshList('accounts', '/accounts'),
        throwsA(isA<ApiFailure>()),
      );
      expect(client.queries.length, 2);
      expect(repo.rows('accounts').single['id'], 'cash');
      expect(repo.store.read(), before);
      state.dispose();
    },
  );

  test('malformed, oversized and duplicate responses are rejected', () async {
    for (final data in <dynamic>[
      {'unexpected': []},
      [42],
      [
        {1: 'invalid key'},
      ],
      [
        {'id': ''},
      ],
      [
        {'name': 'missing id'},
      ],
      [
        {'id': 'same'},
        {'id': 'same'},
      ],
      List.generate(101, (i) => {'id': '$i'}),
    ]) {
      await expectLater(
        PageClient((_) => data).list('/accounts'),
        throwsA(isA<ApiFailure>()),
      );
    }
  });

  test(
    'bounded requests reject incomplete snapshots instead of truncating',
    () async {
      final client = PageClient(pageRows);
      await expectLater(
        client.list('/transactions'),
        throwsA(isA<ApiFailure>()),
      );
      expect(client.queries.length, 1000);
    },
  );
}
