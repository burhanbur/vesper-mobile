import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/core/utils/currency_formatter.dart';
import 'package:vesper_mobile/features/household/data/group_pocket_repository.dart';
import 'package:vesper_mobile/features/household/state/group_pocket_state.dart';

import '../fixtures/cached_finance.dart';

class PocketClient extends ApiClient {
  dynamic result = <dynamic>[];
  Completer<dynamic>? pending;
  ApiFailure? failure;
  final calls = <(String, String, Map<String, dynamic>?)>[];
  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    bool authenticated = true,
    bool retry = true,
  }) async {
    calls.add((method, path, body));
    if (failure != null) throw failure!;
    return pending != null ? pending!.future : result;
  }
}

Map<String, dynamic> snapshot() => {
  'id': 'pocket',
  'name': 'Liburan',
  'description': null,
  'balances': [
    {'currency': 'USD', 'balance': '-9007199254740993.01'},
  ],
  'accounts': [
    {
      'account_id': 'leaf',
      'name': 'Bank - Anak',
      'owner_user_id': 'other',
      'owner_name': 'Anggota',
      'currency': 'USD',
      'balance': '-9007199254740993.01',
    },
  ],
};
void main() {
  test(
    'array contract keeps transparent owners, hierarchy and exact money',
    () async {
      final client = PocketClient()..result = [snapshot()];
      final rows = await GroupPocketRepository(client).read('group');
      expect(rows.single.accounts.single.name, 'Bank - Anak');
      expect(rows.single.accounts.single.ownerName, 'Anggota');
      expect(
        CurrencyFormatter.formatCurrency(
          rows.single.balances.single.balance,
          currency: 'USD',
        ),
        '-USD 9.007.199.254.740.993,01',
      );
      client.result = [
        snapshot()
          ..['balances'] = [
            {'currency': 'IDR', 'balance': 1.5},
          ],
      ];
      await expectLater(
        GroupPocketRepository(client).read('group'),
        throwsA(isA<ApiFailure>()),
      );
    },
  );
  test(
    'writes use exact methods, trimmed body and DELETE account body',
    () async {
      final client = PocketClient();
      final repo = GroupPocketRepository(client);
      await repo.create('g', '  Tujuan  ', ' Catatan ');
      await repo.update('g', 'p', '  Baru  ', ' Catatan Baru ');
      await repo.delete('g', 'p');
      await repo.assign('g', 'p', 'a', remove: false);
      await repo.assign('g', 'p', 'a', remove: true);
      expect(client.calls.map((call) => (call.$1, call.$2)), [
        ('POST', '/groups/g/pockets'),
        ('PATCH', '/groups/g/pockets/p'),
        ('DELETE', '/groups/g/pockets/p'),
        ('POST', '/groups/g/pockets/p/accounts'),
        ('DELETE', '/groups/g/pockets/p/accounts'),
      ]);
      expect(client.calls[0].$3, {'name': 'Tujuan', 'description': 'Catatan'});
      expect(client.calls[1].$3, {
        'name': 'Baru',
        'description': 'Catatan Baru',
      });
      expect(client.calls[2].$3, null);
      expect(client.calls[3].$3, {'account_id': 'a'});
      expect(client.calls[4].$3, {'account_id': 'a'});
    },
  );
  test(
    'candidate filtering excludes foreign, parent, deleted and invalid types',
    () {
      Map<String, dynamic> account(
        String id, {
        String? parent,
        String owner = 'u',
        String type = 't',
        String? deleted,
      }) => {
        'id': id,
        'name': id,
        'user_id': owner,
        'account_type_id': type,
        'parent_account_id': parent,
        'deleted_at': deleted,
        'currency': 'IDR',
        'balance': '1.01',
      };
      final rows = pocketCandidates(
        'u',
        [
          account('Bank'),
          account('Anak', parent: 'Bank'),
          account('solo'),
          account('foreign', owner: 'x'),
          account('bad', type: 'x'),
          account('deleted', deleted: 'now'),
          account('orphan', parent: 'missing'),
        ],
        [
          {'id': 't', 'user_id': 'u'},
        ],
      );
      expect(rows.map((r) => r.name), ['Bank - Anak', 'solo']);
    },
  );
  test(
    'offline and lifecycle clear data and ignore in-flight results',
    () async {
      final client = PocketClient()..result = [snapshot()];
      final app = cachedFinanceState(client: client);
      app.repository!.atomic(
        () => app.repository!.entities['groups'] = {
          'g': {'id': 'g', 'name': 'Group', 'role': 'MEMBER'},
        },
      );
      final state = GroupPocketState(app, 'g');
      await state.load();
      expect(state.fresh, isTrue);
      state.suspend(true);
      expect(state.pockets, isEmpty);
      expect(state.canWrite, isFalse);
      client.pending = Completer<dynamic>();
      state.suspend(false);
      app.toggleOfflineMode();
      client.pending!.complete([snapshot()]);
      await Future<void>.delayed(Duration.zero);
      expect(state.pockets, isEmpty);
      expect(state.fresh, isFalse);
      state.dispose();
      app.dispose();
    },
  );
  test('revocation clears previous snapshot and prevents writes', () async {
    final client = PocketClient()..result = [snapshot()];
    final app = cachedFinanceState(client: client);
    app.repository!.atomic(
      () => app.repository!.entities['groups'] = {
        'g': {'id': 'g', 'name': 'Group', 'role': 'MEMBER'},
      },
    );
    final state = GroupPocketState(app, 'g');
    await state.load();
    client.failure = const ApiFailure('Akses dicabut.', statusCode: 403);
    await state.load();
    expect(state.pockets, isEmpty);
    expect(state.error, 'Akses dicabut.');
    expect(await state.create('Nama', ''), isFalse);
    expect(client.calls.where((call) => call.$1 == 'POST'), isEmpty);
    state.dispose();
    app.dispose();
  });
}
