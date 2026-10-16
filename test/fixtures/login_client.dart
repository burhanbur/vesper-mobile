import 'dart:async';

import 'package:vesper_mobile/core/network/api_client.dart';

class LoginClient extends ApiClient {
  final coreReady = Completer<void>(), releaseSync = Completer<void>();
  final paths = <String>[];
  final cursors = <String>[];
  bool limited = true;
  int registrations = 0;
  static final account = {
    'id': 'cash',
    'name': 'Server cash',
    'user_id': 'user',
    'balance': '500.00',
  };
  static Map<String, dynamic> transaction(String id) => {
    'id': id,
    'account_id': 'cash',
    'type': 'INCOME',
    'amount': '100.00',
    'transacted_at': '2026-10-16T00:00:00.000Z',
  };
  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    bool authenticated = true,
    bool retry = true,
  }) async {
    paths.add(path);
    if (path == '/accounts') return [account];
    if (path == '/transactions') {
      return [transaction('one'), transaction('two')];
    }
    if (path == '/devices') {
      registrations++;
      if (!coreReady.isCompleted) coreReady.complete();
      await releaseSync.future;
      return body;
    }
    if (path == '/sync/pull') {
      final cursor = query!['since_version'] as String;
      cursors.add(cursor);
      if (cursor == '1' && limited) {
        limited = false;
        throw const ApiFailure(
          'Server rate limit',
          statusCode: 429,
          isTransient: true,
          retryAfter: Duration(seconds: 20),
        );
      }
      final id = cursor == '0' ? 'one' : 'two';
      return {
        'changes': [
          {
            'entity_type': 'transactions',
            'entity_id': id,
            'operation': 'CREATE',
            'payload': transaction(id),
          },
        ],
        'next_version': cursor == '0' ? '1' : '2',
        'has_more': cursor == '0',
      };
    }
    return [];
  }
}
