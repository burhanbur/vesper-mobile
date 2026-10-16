import 'package:vesper_mobile/core/network/api_client.dart';

class RecoveryClient extends ApiClient {
  static const cash = '22222222-2222-4222-8222-222222222222';
  static const portfolio = '11111111-1111-4111-8111-111111111111';
  RecoveryClient({this.userId = 'actor'});
  final String userId;
  bool refuseRequest = false;
  int refusalCode = 409;
  Map? receipt;
  String decision = 'PENDING';
  bool loseResponse = false,
      failFinalPage = false,
      omitCash = false,
      invalidTrade = false;
  int pushes = 0, requests = 0;
  Map? command;
  Map<String, dynamic>? wrongReceipt;
  void Function()? beforeFinalCommit;
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
    if (path.startsWith('/sync/investment-recoveries')) {
      if (method == 'GET') {
        if (receipt == null) throw const ApiFailure('Missing', statusCode: 404);
        return {
          ...receipt!,
          'status': decision,
          'reviewed_at': decision == 'PENDING'
              ? null
              : '2026-10-16T01:00:00.000Z',
          ...?wrongReceipt,
        };
      }
      requests++;
      if (refuseRequest) {
        throw ApiFailure('Request refused', statusCode: refusalCode);
      }
      command = Map.from(body!['command'] as Map);
      receipt = {
        'user_id': userId,
        'trade_id': command!['entity_id'],
        'linked_transaction_id': command!['payload']['linked_transaction_id'],
        'command_sha256': body['command_sha256'],
        'status': decision,
        'requested_at': '2026-10-16T00:00:00.000Z',
        'reviewed_at': decision == 'PENDING'
            ? null
            : '2026-10-16T01:00:00.000Z',
      };
      if (loseResponse) throw const ApiFailure('Response lost');
      return receipt;
    }
    if (path == '/sync/push') {
      pushes++;
      return {'results': []};
    }
    if (path == '/sync/pull') {
      if (query!['since_version'] == '2') {
        return {'next_version': '2', 'has_more': false, 'changes': <dynamic>[]};
      }
      final second = query['since_version'] == '1';
      if (second && failFinalPage) throw const ApiFailure('Interrupted replay');
      if (second) beforeFinalCommit?.call();
      final cancelled = decision == 'CANCELLED';
      return {
        'next_version': second ? '2' : '1',
        'has_more': !second,
        'changes': !cancelled
            ? <dynamic>[]
            : second
            ? [
                {
                  'entity_type': 'investment_transactions',
                  'entity_id': command!['entity_id'],
                  'operation': invalidTrade ? 'CREATE' : 'DELETE',
                  'payload': invalidTrade
                      ? {...command!['payload'], 'id': command!['entity_id']}
                      : null,
                },
                {
                  'entity_type': 'transactions',
                  'entity_id': command!['payload']['linked_transaction_id'],
                  'operation': 'DELETE',
                  'payload': null,
                },
              ]
            : [
                for (final id in [portfolio, if (!omitCash) cash])
                  {
                    'entity_type': 'accounts',
                    'entity_id': id,
                    'operation': 'UPDATE',
                    'payload': {
                      'id': id,
                      'user_id': userId,
                      'account_type_id': id == cash ? 'cashType' : 'investType',
                      'currency': 'IDR',
                      'balance': id == cash ? '123.45' : '0.00',
                      'version': '7',
                    },
                  },
              ],
      };
    }
    throw StateError(path);
  }
}
