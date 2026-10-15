import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/features/household/data/collaboration_repository.dart';

class CollaborationClient extends ApiClient {
  dynamic result;
  Map<int, List<Map<String, dynamic>>>? pages;
  Map<String, dynamic>? lastBody;
  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    bool authenticated = true,
    bool retry = true,
  }) async {
    lastBody = body;
    if (pages != null) {
      return pages![query!['page']] ?? <Map<String, dynamic>>[];
    }
    return result;
  }
}

void main() {
  Map<String, dynamic> snapshot() => {
    'period': '2026-10',
    'page': 1,
    'limit': 20,
    'balances': [
      <String, dynamic>{'currency': 'IDR', 'balance': '9007199254740993.01'},
    ],
    'contributions': [],
    'feed': [],
  };
  test('decimal text above JS safe integer remains exact', () async {
    final client = CollaborationClient()..result = snapshot();
    final data = await CollaborationRepository(client)
        .read('group', '2026-10', 1);
    expect(data['balances'][0]['balance'], '9007199254740993.01');
  });
  test('rejects numeric money, wrong period and wrong page', () async {
    final client = CollaborationClient();
    final repository = CollaborationRepository(client);
    client.result = snapshot()..['period'] = '2026-09';
    await expectLater(
      repository.read('group', '2026-10', 1),
      throwsA(isA<ApiFailure>()),
    );
    client.result = snapshot()..['page'] = 2;
    await expectLater(
      repository.read('group', '2026-10', 1),
      throwsA(isA<ApiFailure>()),
    );
    client.result = snapshot();
    client.result['balances'][0]['balance'] = 1.5;
    await expectLater(
      repository.read('group', '2026-10', 1),
      throwsA(isA<ApiFailure>()),
    );
  });
  test(
    'rejects malformed feed, oversized pages and trailing-newline money',
    () async {
      final client = CollaborationClient();
      final repository = CollaborationRepository(client);
      client.result = snapshot();
      client.result['balances'][0]['balance'] = '1.00\n';
      await expectLater(
        repository.read('group', '2026-10', 1),
        throwsA(isA<ApiFailure>()),
      );
      client.result = snapshot()
        ..['feed'] = [
          <String, dynamic>{'currency': 'IDR', 'amount': '1.00'},
        ];
      await expectLater(
        repository.read('group', '2026-10', 1),
        throwsA(isA<ApiFailure>()),
      );
      client.result = snapshot()
        ..['contributions'] = List.generate(
          21,
          (_) => <String, dynamic>{
            'user_id': 'member',
            'currency': 'IDR',
            'income': '1.00',
            'expense': '0.00',
          },
        );
      await expectLater(
        repository.read('group', '2026-10', 1),
        throwsA(isA<ApiFailure>()),
      );
    },
  );
  test('membership uses explicit server-supported action only', () async {
    final client = CollaborationClient();
    final repository = CollaborationRepository(client);
    await repository.manage('group', 'member', 'REMOVE');
    expect(client.lastBody, {'user_id': 'member', 'action': 'REMOVE'});
    await expectLater(
      repository.manage('group', 'member', 'ADMIN'),
      throwsArgumentError,
    );
  });
  test(
    'actor role scans beyond the displayed member page and fails closed',
    () async {
      final first = List.generate(
        20,
        (i) => <String, dynamic>{
          'user_id': 'member$i',
          'name': 'Member',
          'role': 'MEMBER',
        },
      );
      final client = CollaborationClient()
        ..pages = {
          1: first,
          2: [
            <String, dynamic>{
              'user_id': 'owner',
              'name': 'Owner',
              'role': 'OWNER',
            },
          ],
        };
      final repository = CollaborationRepository(client);
      expect(await repository.actorRole('group', 'owner'), 'OWNER');
      expect(await repository.actorRole('group', 'absent'), isNull);
      client.pages = {1: first, 2: first};
      await expectLater(
        repository.actorRole('group', 'owner'),
        throwsA(isA<ApiFailure>()),
      );
    },
  );
  test('member records never fabricate unsupported roles', () async {
    final client = CollaborationClient()
      ..result = [
        {'user_id': 'member', 'name': 'Name', 'role': 'ADMIN'},
      ];
    await expectLater(
      CollaborationRepository(client).members('group', 1),
      throwsA(isA<ApiFailure>()),
    );
  });
}
