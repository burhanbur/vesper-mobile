import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/core/network/api_client.dart';

import '../fixtures/cached_finance.dart';

class GroupListsClient extends ApiClient {
  List<Map<String, dynamic>> rows = [];
  Completer<List<Map<String, dynamic>>>? pending;
  bool fail = false;
  final paths = <String>[];

  @override
  Future<List<Map<String, dynamic>>> list(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    paths.add(path);
    if (fail) throw const ApiFailure('Liste gagal.');
    return pending == null ? rows : await pending!.future;
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
    if (method == 'GET') throw const ApiFailure('Laporan gagal.');
    return null;
  }
}

Map<String, dynamic> accountRow([String group = 'group']) => {
  'id': 'link',
  'group_id': group,
  'account_id': 'cash',
  'name': 'Cash',
};

void main() {
  test(
    'complete actor lists persist and offline presentation retains cache',
    () async {
      final client = GroupListsClient()..rows = [accountRow()];
      final state = cachedFinanceState(client: client);
      final repo = state.repository!;
      repo.atomic(
        () => repo.entities['groups'] = {
          'group': {'id': 'group', 'name': 'Group', 'role': 'MEMBER'},
        },
      );
      expect(await state.loadGroupList('group'), isTrue);
      expect(state.groupListFresh('group'), isTrue);
      expect(
        repo.store.read()['entities']['group_accounts:group']['link'],
        accountRow(),
      );
      client.rows = [
        {
          'id': 'mapping',
          'group_id': 'group',
          'group_category_id': 'shared',
          'user_category_id': 'food',
        },
      ];
      expect(await state.loadGroupList('group', mappings: true), isTrue);
      expect(client.paths, [
        '/groups/group/accounts',
        '/groups/group/category-mappings',
      ]);
      state.toggleOfflineMode();
      expect(await state.loadGroupList('group'), isFalse);
      expect(state.groupListRows('group'), [accountRow()]);
      expect(state.groupListFresh('group'), isFalse);
      state.dispose();
    },
  );

  test(
    'invalid snapshots and fetch failures never replace persisted cache',
    () async {
      final client = GroupListsClient()..rows = [accountRow()];
      final state = cachedFinanceState(client: client);
      final repo = state.repository!;
      repo.atomic(
        () => repo.entities['groups'] = {
          'group': {'id': 'group', 'name': 'Group', 'role': 'OWNER'},
        },
      );
      await state.loadGroupList('group');
      final before = repo.store.read();
      for (final rows in [
        [accountRow('other')],
        [accountRow(), accountRow()],
        [
          {'id': 'bad', 'group_id': 'group', 'account_id': 'cash'},
        ],
      ]) {
        client.rows = rows;
        expect(await state.loadGroupList('group'), isFalse);
        expect(repo.store.read(), before);
        expect(state.groupListError('group'), isNotNull);
      }
      client.fail = true;
      expect(await state.loadGroupList('group'), isFalse);
      expect(repo.store.read(), before);
      await expectLater(
        state.shareGroupAccount(
          groupId: 'group',
          accountId: 'cash',
          remove: true,
        ),
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.message,
            'message',
            contains('belum dapat diverifikasi'),
          ),
        ),
      );
      expect(state.groupListCached('group'), isFalse);
      expect(repo.row('accounts', 'cash')?['balance'], '100000.00');
      state.dispose();
    },
  );

  test('group switches, offline changes and repository replacement reject late lists', () async {
    for (final transition in ['group', 'offline', 'repository']) {
      final client = GroupListsClient()..pending = Completer();
      final state = cachedFinanceState(client: client);
      final repo = state.repository!;
      repo.atomic(
        () => repo.entities['groups'] = {
          'group': {'id': 'group', 'name': 'Group', 'role': 'MEMBER'},
          'other': {'id': 'other', 'name': 'Other', 'role': 'MEMBER'},
        },
      );
      final task = state.loadGroupList('group');
      if (transition == 'group') state.switchHousehold('other');
      if (transition == 'offline') state.toggleOfflineMode();
      if (transition == 'repository') state.repository = null;
      client.pending!.complete([accountRow()]);
      expect(await task, isFalse);
      expect(repo.entities.containsKey('group_accounts:group'), isFalse);
      await Future<void>.delayed(Duration.zero);
      state.dispose();
      if (transition == 'repository') repo.store.close();
    }
  });

  test(
    'inactive membership prevents requests and hides cached relationships',
    () async {
      final client = GroupListsClient();
      final state = cachedFinanceState(client: client);
      state.repository!.atomic(() {
        state.repository!.entities['groups'] = {
          'group': {'id': 'group', 'name': 'Group', 'role': 'REMOVED'},
        };
        state.repository!.entities['group_accounts:group'] = {
          'link': accountRow(),
        };
      });
      expect(await state.loadGroupList('group'), isFalse);
      expect(state.groupListRows('group'), isEmpty);
      expect(client.paths, isEmpty);
      state.dispose();
    },
  );
}
