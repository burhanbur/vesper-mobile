import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/core/network/api_client.dart';

import '../fixtures/cached_finance.dart';

class MappingClient extends ApiClient {
  final methods = <String>[];
  bool fail = false;
  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    bool authenticated = true,
    bool retry = true,
  }) async {
    if (method == 'GET') {
      if (path == '/groups/group/category-mappings') {
        return <Map<String, dynamic>>[];
      }
      throw const ApiFailure('Laporan belum tersedia.');
    }
    methods.add(method);
    expect(path, '/groups/group/categories/shared/mapping');
    expect(body, {'user_category_id': 'food'});
    if (fail) throw const ApiFailure('Pemetaan bertentangan.', statusCode: 409);
    return null;
  }
}

void main() {
  test(
    'member maps and unmaps without changing personal history or outbox',
    () async {
      final client = MappingClient();
      final state = cachedFinanceState(client: client);
      final repo = state.repository!;
      repo.atomic(() {
        repo.entities['groups'] = <String, dynamic>{
          'group': {'id': 'group', 'name': 'Group', 'role': 'MEMBER'},
        };
        repo.entities['group_categories:group'] = <String, dynamic>{
          'shared': {
            'id': 'shared',
            'group_id': 'group',
            'name': 'Shared',
            'type': 'EXPENSE',
          },
        };
      });
      for (final remove in [false, true]) {
        await state.mapGroupCategory(
          groupId: 'group',
          groupCategoryId: 'shared',
          personalCategoryId: 'food',
          remove: remove,
        );
      }
      expect(client.methods, ['POST', 'DELETE']);
      expect(repo.rows('categories').length, 2);
      expect(repo.row('accounts', 'cash')?['balance'], '100000.00');
      expect(repo.outbox, isEmpty);
      await expectLater(
        state.mapGroupCategory(
          groupId: 'other',
          groupCategoryId: 'shared',
          personalCategoryId: 'food',
        ),
        throwsA(isA<ApiFailure>()),
      );
      await expectLater(
        state.mapGroupCategory(
          groupId: 'group',
          groupCategoryId: 'shared',
          personalCategoryId: 'salary',
        ),
        throwsA(isA<ApiFailure>()),
      );
      repo.atomic(
        () => repo.entities['categories']['food']['user_id'] = 'other',
      );
      await expectLater(
        state.mapGroupCategory(
          groupId: 'group',
          groupCategoryId: 'shared',
          personalCategoryId: 'food',
        ),
        throwsA(isA<ApiFailure>()),
      );
      expect(client.methods.length, 2);
      state.dispose();
    },
  );

  test('conflict and offline preserve cache', () async {
    final client = MappingClient()..fail = true;
    final state = cachedFinanceState(client: client);
    final repo = state.repository!;
    repo.atomic(() {
      repo.entities['groups'] = <String, dynamic>{
        'group': {'id': 'group', 'name': 'Group', 'role': 'MEMBER'},
      };
      repo.entities['group_categories:group'] = <String, dynamic>{
        'shared': {
          'id': 'shared',
          'group_id': 'group',
          'name': 'Shared',
          'type': 'EXPENSE',
        },
      };
    });
    final before = repo.store.read();
    await expectLater(
      state.mapGroupCategory(
        groupId: 'group',
        groupCategoryId: 'shared',
        personalCategoryId: 'food',
      ),
      throwsA(isA<ApiFailure>()),
    );
    expect(repo.store.read(), before);
    state.toggleOfflineMode();
    await expectLater(
      state.mapGroupCategory(
        groupId: 'group',
        groupCategoryId: 'shared',
        personalCategoryId: 'food',
      ),
      throwsA(isA<ApiFailure>()),
    );
    expect(client.methods.length, 1);
    state.dispose();
  });
}
