import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/core/network/api_client.dart';

import '../fixtures/cached_finance.dart';

class UpdateCategoryClient extends ApiClient {
  bool conflict = false;
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
    if (method != 'PATCH') throw const ApiFailure('Laporan belum tersedia.');
    writes++;
    expect(path, '/groups/group/categories');
    expect(body, {
      'group_category_id': 'category',
      'name': 'Updated',
      'type': 'INCOME',
    });
    if (conflict) {
      throw const ApiFailure('Kategori sudah dipetakan.', statusCode: 409);
    }
    return {
      'id': 'category',
      'group_id': 'group',
      'name': 'Updated',
      'type': 'INCOME',
    };
  }
}

void main() {
  for (final conflict in [false, true]) {
    test(
      'category PATCH preserves personal data; conflict=$conflict',
      () async {
        final client = UpdateCategoryClient()..conflict = conflict;
        final state = cachedFinanceState(client: client);
        final repo = state.repository!;
        repo.atomic(() {
          repo.entities['groups'] = <String, dynamic>{
            'group': {'id': 'group', 'name': 'Group', 'role': 'OWNER'},
          };
          repo.entities['group_categories:group'] = <String, dynamic>{
            'category': {
              'id': 'category',
              'group_id': 'group',
              'name': 'Old',
              'type': 'EXPENSE',
            },
          };
        });
        final operation = state.updateGroupCategory(
          categoryId: 'category',
          groupId: 'group',
          name: ' Updated ',
          type: 'INCOME',
        );
        if (conflict) {
          await expectLater(operation, throwsA(isA<ApiFailure>()));
        } else {
          await operation;
        }
        expect(
          repo.row('group_categories:group', 'category')?['name'],
          conflict ? 'Old' : 'Updated',
        );
        expect(
          repo.store
              .read()['entities']['group_categories:group']['category']['name'],
          conflict ? 'Old' : 'Updated',
        );
        expect(repo.rows('categories').length, 2);
        expect(repo.outbox, isEmpty);
        await expectLater(
          state.updateGroupCategory(
            categoryId: 'category',
            groupId: 'other',
            name: 'Updated',
            type: 'INCOME',
          ),
          throwsA(isA<ApiFailure>()),
        );
        await expectLater(
          state.updateGroupCategory(
            categoryId: 'missing',
            groupId: 'group',
            name: 'Updated',
            type: 'INCOME',
          ),
          throwsA(isA<ApiFailure>()),
        );
        expect(client.writes, 1);
        state.dispose();
      },
    );
  }
}
