import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/core/network/api_client.dart';

import '../fixtures/cached_finance.dart';

class DeleteCategoryClient extends ApiClient {
  bool fail = false;
  int writes = 0;
  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    bool authenticated = true,
    bool retry = true,
  }) async {
    if (method != 'DELETE') throw const ApiFailure('Laporan belum tersedia.');
    writes++;
    expect(path, '/groups/group/categories');
    expect(body, {'group_category_id': 'category'});
    if (fail) throw const ApiFailure('Tidak diizinkan.', statusCode: 403);
    return null;
  }
}

void main() {
  for (final fail in [false, true]) {
    test(
      'group category deletion preserves personal data; failure=$fail',
      () async {
        final client = DeleteCategoryClient()..fail = fail;
        final state = cachedFinanceState(client: client);
        final repo = state.repository!;
        repo.atomic(() {
          repo.entities['groups'] = <String, dynamic>{
            'group': <String, dynamic>{
              'id': 'group',
              'name': 'Group',
              'role': 'OWNER',
            },
          };
          repo.entities['group_categories:group'] = <String, dynamic>{
            'category': <String, dynamic>{
              'id': 'category',
              'group_id': 'group',
              'name': 'Shared',
              'type': 'EXPENSE',
            },
          };
        });
        final operation = state.deleteGroupCategory(
          groupId: 'group',
          categoryId: 'category',
        );
        if (fail) {
          await expectLater(operation, throwsA(isA<ApiFailure>()));
        } else {
          await operation;
        }
        expect(repo.row('group_categories:group', 'category') != null, fail);
        expect(
          repo.store.read()['entities']['group_categories:group'].containsKey(
            'category',
          ),
          fail,
        );
        expect(repo.rows('categories').length, 2);
        expect(repo.row('accounts', 'cash')?['balance'], '100000.00');
        expect(repo.outbox, isEmpty);
        await expectLater(
          state.deleteGroupCategory(groupId: 'other', categoryId: 'category'),
          throwsA(isA<ApiFailure>()),
        );
        repo.atomic(() => repo.entities['groups']['group']['role'] = 'MEMBER');
        await expectLater(
          state.deleteGroupCategory(groupId: 'group', categoryId: 'category'),
          throwsA(isA<ApiFailure>()),
        );
        expect(client.writes, 1);
        state.dispose();
      },
    );
  }
}
