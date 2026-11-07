import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/database/local_store.dart';
import 'package:vesper_mobile/features/sync/data/finance_repository.dart';

// Transport contract only: the backend companion uses real HTTP/PostgreSQL.
class _CardSyncClient extends ApiClient {
  Map<String, dynamic>? command;

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
    if (path == '/sync/push') {
      command = Map<String, dynamic>.from((body!['items'] as List).single as Map);
      return {
        'results': [
          {'index': 0, 'entity_id': command!['entity_id'], 'status': 'applied'},
        ],
      };
    }
    if (path == '/sync/pull') {
      final payload = command!['payload'] as Map;
      return {
        'changes': [
          {
            'entity_type': 'accounts',
            'entity_id': 'card',
            'operation': 'UPDATE',
            'payload': {
              'id': 'card', 'user_id': 'user', 'currency': 'IDR',
              'balance': '500000.00', 'version': '9007199254740993',
              'is_credit_card': true, 'credit_limit': null,
            },
          },
          for (final incoming in [false, true])
            {
              'entity_type': 'transactions',
              'entity_id': payload[incoming ? 'to_transaction_id' : 'from_transaction_id'],
              'operation': 'CREATE',
              'payload': {
                'id': payload[incoming ? 'to_transaction_id' : 'from_transaction_id'],
                'account_id': incoming ? 'card' : 'bank',
                'type': 'TRANSFER', 'amount': incoming ? '2500000.00' : '-2500000.00',
                'transfer_id': command!['entity_id'],
                'transacted_at': payload['transacted_at'], 'version': '1',
              },
            },
        ],
        'next_version': '9007199254740994', 'has_more': false,
      };
    }
    throw StateError(path);
  }

  @override
  Future<List<Map<String, dynamic>>> list(String path, {Map<String, dynamic>? query}) async => [];
}

void main() {
  test('card repayment sync keeps command/leg IDs, metadata and credit after restart', () async {
    final store = LocalStore(sqlite3.openInMemory());
    addTearDown(store.close);
    final client = _CardSyncClient();
    var repo = FinanceRepository(client, store, 'user');
    repo.atomic(() {
      repo.entities['account_types'] = {
        'cash': {'id': 'cash', 'user_id': 'user', 'name': 'Cash', 'category': 'CASH'},
      };
      repo.entities['accounts'] = {
        // Repayment requires an explicitly classified personal cash source.
        'bank': {'id': 'bank', 'account_type_id': 'cash', 'user_id': 'user', 'currency': 'IDR', 'balance': '5000000.00', 'version': '1', 'is_credit_card': false},
        'card': {'id': 'card', 'account_type_id': 'cash', 'user_id': 'user', 'currency': 'IDR', 'balance': '-2000000.00', 'version': '1', 'is_credit_card': true, 'credit_limit': '1000000.23'},
      };
    });
    final commandId = repo.createTransfer(fromAccountId: 'bank', toAccountId: 'card', amount: 2500000, date: DateTime.utc(2026, 11, 6));
    final queued = Map<String, dynamic>.from(repo.outbox.single);
    repo = FinanceRepository(client, store, 'user');
    await repo.sync();
    expect(client.command, {
      for (final key in ['entity_type', 'entity_id', 'operation', 'payload', 'client_version'])
        key: queued[key],
    });
    expect(client.command!['entity_id'], commandId);
    expect(repo.outbox, isEmpty);
    final payload = queued['payload'] as Map;
    expect(repo.rows('transactions').map((row) => row['id']).toSet(), {
      payload['from_transaction_id'], payload['to_transaction_id'],
    });
    repo = FinanceRepository(client, store, 'user');
    expect(repo.row('accounts', 'card'), containsPair('balance', '500000.00'));
    expect(repo.row('accounts', 'card'), containsPair('is_credit_card', true));
    expect(repo.row('accounts', 'card'), containsPair('credit_limit', null));
    expect(repo.row('accounts', 'card'), containsPair('version', '9007199254740993'));
    for (final amount in [200000, 400000]) {
      repo.mutate('transactions', 'CREATE', {'account_id': 'card', 'type': 'EXPENSE', 'amount': '$amount.00'}, balanceDelta: {'card': -amount});
    }
    expect(repo.row('accounts', 'card')!['balance'], '-100000.00');
    expect(repo.outbox, hasLength(2));
  });
}
