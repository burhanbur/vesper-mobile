import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/core/network/api_client.dart';

import '../fixtures/cached_finance.dart';

class SharingClient extends ApiClient {
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
      if (path == '/groups/group/accounts') return <Map<String, dynamic>>[];
      throw const ApiFailure('Laporan belum tersedia.');
    }
    methods.add(method);
    expect(path, '/groups/group/accounts');
    expect(body, {'account_id': 'cash'});
    if (fail) throw const ApiFailure('Tidak diizinkan.', statusCode: 403);
    return null;
  }
}

void main() {
  test(
    'members share/unshare own accounts without altering financial records',
    () async {
      final client = SharingClient();
      final state = cachedFinanceState(client: client);
      final repo = state.repository!;
      repo.atomic(
        () => repo.entities['groups'] = <String, dynamic>{
          'group': {'id': 'group', 'name': 'Group', 'role': 'MEMBER'},
        },
      );
      await state.shareGroupAccount(groupId: 'group', accountId: 'cash');
      await state.shareGroupAccount(
        groupId: 'group',
        accountId: 'cash',
        remove: true,
      );
      expect(client.methods, ['POST', 'DELETE']);
      expect(repo.row('accounts', 'cash')?['balance'], '100000.00');
      expect(repo.outbox, isEmpty);
      expect(repo.rows('categories').length, 2);
      await expectLater(
        state.shareGroupAccount(groupId: 'other', accountId: 'cash'),
        throwsA(isA<ApiFailure>()),
      );
      repo.atomic(() => repo.entities['accounts']['cash']['user_id'] = 'other');
      await expectLater(
        state.shareGroupAccount(groupId: 'group', accountId: 'cash'),
        throwsA(isA<ApiFailure>()),
      );
      expect(client.methods.length, 2);
      state.dispose();
    },
  );

  test('failed and offline sharing preserve persisted account', () async {
    final client = SharingClient()..fail = true;
    final state = cachedFinanceState(client: client);
    final repo = state.repository!;
    repo.atomic(
      () => repo.entities['groups'] = <String, dynamic>{
        'group': {'id': 'group', 'name': 'Group', 'role': 'OWNER'},
      },
    );
    await expectLater(
      state.shareGroupAccount(groupId: 'group', accountId: 'cash'),
      throwsA(isA<ApiFailure>()),
    );
    state.toggleOfflineMode();
    await expectLater(
      state.shareGroupAccount(groupId: 'group', accountId: 'cash'),
      throwsA(isA<ApiFailure>()),
    );
    expect(client.methods, ['POST']);
    expect(
      repo.store.read()['entities']['accounts']['cash']['balance'],
      '100000.00',
    );
    expect(repo.outbox, isEmpty);
    state.dispose();
  });

  test(
    'pending account or account type blocks sharing before network',
    () async {
      final client = SharingClient();
      final state = cachedFinanceState(client: client);
      final repo = state.repository!;
      repo.atomic(() {
        repo.entities['groups'] = <String, dynamic>{
          'group': {'id': 'group', 'name': 'Group', 'role': 'MEMBER'},
        };
        repo.entities['accounts']['cash']['account_type_id'] = 'type';
      });
      for (final item in [
        {'entity_type': 'accounts', 'entity_id': 'cash'},
        {'entity_type': 'account_types', 'entity_id': 'type'},
      ]) {
        repo.outbox.add(item);
        await expectLater(
          state.shareGroupAccount(groupId: 'group', accountId: 'cash'),
          throwsA(isA<ApiFailure>()),
        );
        repo.outbox.clear();
      }
      expect(client.methods, isEmpty);
      state.dispose();
    },
  );
}
