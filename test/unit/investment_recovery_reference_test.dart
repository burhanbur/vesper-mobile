import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/database/local_store.dart';
import 'package:vesper_mobile/features/sync/data/finance_repository.dart';

void main() {
  test('support reference redacts financial details and keeps stable fingerprint across retry/restart', () {
    final store = LocalStore(sqlite3.openInMemory());
    addTearDown(store.close);
    final repo = FinanceRepository(ApiClient(), store, 'owner');
    repo.atomic(() {
      repo.outbox.add({
        'id': 'queue',
        'entity_id': 'trade',
        'entity_type': 'investment_transactions',
        'operation': 'CREATE',
        'client_version': '1',
        'status': 'rejected',
        'error': 'Sensitive amount 999.00',
        'server_data': {'secret': 'private-server-data'},
        'payload': {
          'account_id': 'investment',
          'cash_account_id': 'cash',
          'instrument_id': 'instrument',
          'linked_transaction_id': 'ledger',
          'quantity': '999.00000001',
          'description': 'private financial note',
          'access_token': 'must-never-be-exported',
        },
      });
    });
    final before = store.read();
    final original = repo.investmentRecoveryReference('queue');
    final encoded = jsonEncode(original);
    expect(encoded, isNot(contains('999.00000001')));
    expect(encoded, isNot(contains('999.00')));
    expect(encoded, isNot(contains('private financial note')));
    expect(encoded, isNot(contains('must-never-be-exported')));
    expect(encoded, isNot(contains('private-server-data')));
    expect(original['user_id'], 'owner');
    expect(original['linked_transaction_id'], 'ledger');
    expect(original['command_sha256'], matches(RegExp(r'^[a-f0-9]{64}$')));
    expect(store.read(), before);
    expect(() => original['status'] = 'changed', throwsUnsupportedError);
    repo.retryInvestmentTrade('queue');
    final restarted = FinanceRepository(ApiClient(), store, 'owner');
    expect(
      restarted.investmentRecoveryReference('queue')['command_sha256'],
      original['command_sha256'],
    );
    expect(restarted.investmentRecoveryReference('queue')['status'], 'pending');
    // Property order cannot change the cross-runtime fingerprint.
    final payload = restarted.outbox.single['payload'] as Map;
    restarted.outbox.single['payload'] = Map.fromEntries(
      payload.entries.toList().reversed,
    );
    expect(
      restarted.investmentRecoveryReference('queue')['command_sha256'],
      original['command_sha256'],
    );
    restarted.outbox.single['payload']['quantity'] = '2.00000000';
    expect(
      restarted.investmentRecoveryReference('queue')['command_sha256'],
      isNot(original['command_sha256']),
    );
    expect(
      () => restarted.investmentRecoveryReference('missing'),
      throwsA(isA<ApiFailure>()),
    );
  });
}
