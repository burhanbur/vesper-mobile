import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/features/household/models/household.dart';

import '../fixtures/cached_finance.dart';

class _GroupClient extends ApiClient {
  final calls = <Map<String, dynamic>>[];
  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    bool authenticated = true,
    bool retry = true,
  }) async {
    calls.add({'method': method, 'path': path, 'body': body});
    if (method == 'POST' && path.endsWith('/join')) {
      return {'id': path.split('/')[2], 'name': 'Joined group'};
    }
    if (method != 'POST' || path != '/groups') {
      throw StateError('Unexpected request');
    }
    return {
      'id': 'created-group',
      'name': body!['name'],
      'code': 'SERVERCODE12',
    };
  }
}

void main() {
  group('Repository-backed groups', () {
    late AppState state;
    late _GroupClient client;
    setUp(() {
      client = _GroupClient();
      state = cachedFinanceState(client: client);
    });
    tearDown(() => state.dispose());
    void seed() {
      final repo = state.repository!;
      repo.atomic(() {
        repo.entities['groups'] = {
          'family': {
            'id': 'family',
            'name': 'Our family',
            'code': 'FAMILYCODE12',
          },
          'trip': {'id': 'trip', 'name': 'Our trip', 'code': 'TRIPCODE1234'},
        };
        repo.entities['members:family'] = {
          'user': {'user_id': 'user', 'name': 'Fixture Owner', 'role': 'OWNER'},
          'member': {
            'user_id': 'member',
            'name': 'Fixture Member',
            'role': 'MEMBER',
          },
        };
      });
    }

    test('Empty cache has no demo groups, members or financial snapshot', () {
      expect(state.households, isEmpty);
      expect(state.activeHousehold.id, isEmpty);
      expect(state.activeHousehold.name, 'Belum ada grup');
      expect(state.activeHousehold.members, isEmpty);
      expect(state.activeHousehold.inviteCode, isEmpty);
      expect(state.householdFinancialDataAvailable, isFalse);
      expect(state.activeHouseholdTransactions, isEmpty);
      expect(state.activeHouseholdContributions, isEmpty);
    });
    test('Loads persisted server groups and scoped members without fabricated types', () {
      seed();
      expect(state.households.map((h) => h.id), ['family', 'trip']);
      expect(
        state.households.map((h) => h.type),
        everyElement(GroupType.other),
      );
      expect(state.activeHousehold.name, 'Our family');
      expect(state.activeHousehold.inviteCode, 'FAMILYCODE12');
      expect(state.activeHousehold.members.map((m) => m.role), [
        MemberRole.admin,
        MemberRole.member,
      ]);
      expect(state.activeHousehold.members.last.avatarInitials, 'FM');
      expect(state.repository!.store.read(), state.repository!.state);
    });
    test(
      'Join persists the server group and normalizes the invitation code',
      () async {
        const id = '12345678-1234-4234-8234-123456789abc';
        await state.joinHousehold(groupId: id, code: 'abcd1234efgh');
        expect(client.calls.first, {
          'method': 'POST',
          'path': '/groups/$id/join',
          'body': {'code': 'ABCD1234EFGH'},
        });
        expect(state.activeHouseholdId, id);
        expect(state.activeHousehold.name, 'Joined group');
        expect(state.repository!.store.read(), state.repository!.state);
        expect(state.repository!.outbox, isEmpty);
      },
    );
    test(
      'Invalid invitation never mutates local data or calls the API',
      () async {
        seed();
        final before = state.repository!.store.read();
        await expectLater(
          state.joinHousehold(groupId: 'invalid', code: 'SHORT'),
          throwsA(isA<ApiFailure>()),
        );
        expect(client.calls, isEmpty);
        expect(state.repository!.store.read(), before);
      },
    );
    test(
      'Switches cached groups and falls back safely for an unknown group',
      () {
        seed();
        state.switchHousehold('trip');
        expect(state.activeHouseholdId, 'trip');
        expect(state.household.name, 'Our trip');
        expect(state.household.members, isEmpty);
        state.switchHousehold('missing');
        expect(state.activeHouseholdId, 'family');
        expect(state.households, hasLength(2));
      },
    );
    test('Creation awaits server identity and persists only supported group fields', () async {
      seed();
      await state.createHousehold(
        name: '  Project fund  ',
        type: GroupType.project,
        description: 'Not in server contract',
      );
      expect(client.calls.first, {
        'method': 'POST',
        'path': '/groups',
        'body': {'name': 'Project fund'},
      });
      expect(
        client.calls.where(
          (call) => call['path'] == '/groups' && call['method'] == 'POST',
        ),
        hasLength(1),
      );
      expect(state.households, hasLength(3));
      expect(state.activeHouseholdId, 'created-group');
      expect(state.activeHousehold.name, 'Project fund');
      expect(state.activeHousehold.type, GroupType.other);
      expect(state.activeHousehold.inviteCode, 'SERVERCODE12');
      expect(state.activeHousehold.members, isEmpty);
      expect(state.repository!.outbox, isEmpty);
      expect(state.repository!.store.read(), state.repository!.state);
    });
    test(
      'Offline creation does not fabricate a group or an invitation',
      () async {
        seed();
        state.toggleOfflineMode();
        final before = state.repository!.store.read();
        await expectLater(
          state.createHousehold(name: 'Offline group', type: GroupType.project),
          throwsA(
            isA<ApiFailure>().having(
              (e) => e.message,
              'message',
              contains('koneksi internet'),
            ),
          ),
        );
        expect(client.calls, isEmpty);
        expect(state.activeHouseholdId, 'family');
        expect(state.repository!.state, before);
        expect(state.repository!.store.read(), before);
      },
    );
    test('Unsupported joining, direct membership, edits and leaving preserve cached groups', () {
      seed();
      state.switchHousehold('trip');
      final repo = state.repository!;
      final before = repo.store.read();
      for (final action in <void Function()>[
        () => state.joinHouseholdWithCode('TRIPCODE1234'),
        () => state.joinHouseholdWithCode('EVT-5520'),
        () => state.addMemberToHousehold(
          householdId: 'trip',
          name: 'New Member',
          email: 'member@example.test',
          role: MemberRole.member,
          roleName: 'Anggota',
        ),
        () => state.updateHouseholdName('Changed'),
        () => state.updateActiveHousehold(
          name: 'Changed',
          type: GroupType.project,
        ),
        () => state.deleteOrLeaveHousehold('trip'),
      ]) {
        expect(action, throwsA(isA<ApiFailure>()));
        expect(state.activeHouseholdId, 'trip');
        expect(repo.state, before);
        expect(repo.store.read(), before);
      }
      expect(client.calls, isEmpty);
      expect(repo.outbox, isEmpty);
    });
  });
}
