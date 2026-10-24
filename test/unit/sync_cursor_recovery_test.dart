import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/features/sync/data/finance_repository.dart';

import '../fixtures/dashboard_insights.dart';

class _CursorClient extends ApiClient {
  final cursors = <String>[];
  bool failReplay = false;
  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    bool authenticated = true,
    bool retry = true,
  }) async {
    if (path == '/devices') return {};
    if (path == '/sync/pull') {
      final cursor = query!['since_version'] as String;
      cursors.add(cursor);
      if (cursor == '900' || failReplay) {
        throw const ApiFailure(
          'Cursor ahead',
          statusCode: 422,
          code: 'SYNC_CURSOR_AHEAD',
        );
      }
      return {'changes': [], 'next_version': '1', 'has_more': false};
    }
    return [];
  }
}

void seedCursor(FinanceRepository source) => source.atomic(() {
  source.state['cursor'] = '900';
  for (final key in [
    'investment_history_coverage',
    'obligation_history_coverage',
    'bill_history_coverage',
  ]) {
    source.state[key]['cursor'] = '900';
  }
  source.entities['transactions'] = <String, dynamic>{
    'local': insightExpense('local', '2026-10-24T00:00:00Z', '123.45'),
  };
  source.outbox.add({
    'id': 'retained',
    'entity_type': 'transactions',
    'entity_id': 'local',
    'operation': 'CREATE',
    'status': 'rejected',
    'payload': {'amount': '123.45'},
    'client_version': '0',
    'attempts': 1,
    'created_at': '2026-10-24T00:00:00Z',
  });
});

void main() {
  for (final indexed in [false, true]) {
    test(
      'ahead cursor replays pull without losing balances, local transactions or outbox ($indexed)',
      () async {
        final client = _CursorClient();
        final source = insightRepository(indexed: indexed, client: client);
        addTearDown(source.store.close);
        seedCursor(source);
        final transactions = jsonEncode(source.rows('transactions'));
        final accounts = jsonEncode(source.rows('accounts'));
        final queue = jsonEncode(source.outbox);
        await source.sync();
        expect(client.cursors, ['900', '0']);
        expect(source.state['cursor'], '1');
        expect(source.hasCompleteInvestmentHistory, isTrue);
        expect(source.state['bill_history_coverage']['complete'], isTrue);
        expect(jsonEncode(source.rows('transactions')), transactions);
        expect(jsonEncode(source.rows('accounts')), accounts);
        expect(jsonEncode(source.outbox), queue);
      },
    );
    test(
      'ahead-cursor recovery is bounded and interrupted replay keeps local data ($indexed)',
      () async {
        final client = _CursorClient()..failReplay = true;
        final source = insightRepository(indexed: indexed, client: client);
        addTearDown(source.store.close);
        seedCursor(source);
        final queue = jsonEncode(source.outbox);
        await expectLater(source.sync(), throwsA(isA<ApiFailure>()));
        expect(client.cursors, ['900', '0']);
        expect(source.state['cursor'], '0');
        expect(source.hasCompleteInvestmentHistory, isFalse);
        expect(source.row('transactions', 'local')!['amount'], '123.45');
        expect(jsonEncode(source.outbox), queue);
      },
    );
  }

  for (final scenario in [
    ('/sync/pull', 422, 'Cursor sinkronisasi melebihi versi server.', true),
    ('/sync/pull', 422, 'Unknown query field', false),
    ('/accounts', 422, 'Cursor sinkronisasi melebihi versi server.', false),
    ('/sync/pull', 500, 'Cursor sinkronisasi melebihi versi server.', false),
  ]) {
    test(
      'transport recognizes only exact sync cursor-ahead response: $scenario',
      () async {
        final (path, status, message, recognized) = scenario;
        final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));
        addTearDown(dio.close);
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.badResponse,
                  response: Response(
                    requestOptions: options,
                    statusCode: status,
                    data: {'success': false, 'message': message},
                  ),
                ),
              );
            },
          ),
        );
        await expectLater(
          ApiClient(dio: dio).request('GET', path),
          throwsA(
            isA<ApiFailure>().having(
              (e) => e.code,
              'code',
              recognized ? 'SYNC_CURSOR_AHEAD' : null,
            ),
          ),
        );
      },
    );
  }
}
