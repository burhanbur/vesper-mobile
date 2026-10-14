import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/core/network/api_client.dart';

import '../fixtures/cached_finance.dart';

class CategoryCreationClient extends ApiClient {
  int posts = 0;
  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    bool authenticated = true,
    bool retry = true,
  }) async {
    if (method != 'POST') throw const ApiFailure('Rapport indisponible');
    posts++;
    expect(path, '/groups/group/categories');
    expect(body, {'name': 'Food group', 'type': 'EXPENSE'});
    return {'id': 'new', 'group_id': 'group', ...body!};
  }
}

void main() {
  test(
    'owner creates server category without personal mutations or outbox',
    () async {
      final client = CategoryCreationClient();
      final state = cachedFinanceState(client: client);
      final repo = state.repository!;
      repo.atomic(
        () => repo.entities['groups'] = <String, dynamic>{
          'group': {'id': 'group', 'name': 'Group', 'role': 'OWNER'},
        },
      );
      await state.createGroupCategory(name: ' Food group ', type: 'EXPENSE');
      expect(client.posts, 1);
      expect(repo.row('group_categories:group', 'new')?['name'], 'Food group');
      expect(
        repo.store.read()['entities']['group_categories:group']['new']['type'],
        'EXPENSE',
      );
      expect(repo.rows('categories').length, 2);
      expect(repo.outbox, isEmpty);
      state.dispose();
    },
  );

  test(
    'member, invalid input and offline requests do not write remotely',
    () async {
      final client = CategoryCreationClient();
      final state = cachedFinanceState(client: client);
      final repo = state.repository!;
      repo.atomic(
        () => repo.entities['groups'] = <String, dynamic>{
          'group': {'id': 'group', 'name': 'Group', 'role': 'MEMBER'},
        },
      );
      await expectLater(
        state.createGroupCategory(name: 'Food group', type: 'EXPENSE'),
        throwsA(isA<ApiFailure>()),
      );
      repo.atomic(() => repo.entities['groups']['group']['role'] = 'OWNER');
      await expectLater(
        state.createGroupCategory(name: ' ', type: 'EXPENSE'),
        throwsA(isA<ApiFailure>()),
      );
      await expectLater(
        state.createGroupCategory(name: 'Food group', type: 'TRANSFER'),
        throwsA(isA<ApiFailure>()),
      );
      state.toggleOfflineMode();
      await expectLater(
        state.createGroupCategory(name: 'Food group', type: 'EXPENSE'),
        throwsA(isA<ApiFailure>()),
      );
      expect(client.posts, 0);
      expect(repo.outbox, isEmpty);
      state.dispose();
    },
  );
}
