import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/features/sync/models/sync_status.dart';
import 'package:vesper_mobile/features/transactions/models/transaction.dart';

import '../fixtures/dashboard_insights.dart';

void main() {
  for (final status in [
    'pending',
    'rejected',
    'conflict',
    'acknowledged',
    'cancellation_approved',
    'failed',
  ]) {
    test('refresh success does not imply queue completion for $status', () {
      final source = insightRepository();
      addTearDown(source.store.close);
      source.atomic(
        () => source.outbox.add({
          'id': 'queue',
          'entity_type': 'transactions',
          'entity_id': 'tx',
          'operation': 'CREATE',
          'status': status,
          'client_version': '0',
          'created_at': DateTime.utc(2026, 10, 24).toIso8601String(),
          'attempts': 1,
          'error': 'Kategori tidak tersedia',
          'payload': {'amount': '100.00'},
        }),
      );
      final state = AppState(repository: source)..currentUserId = 'user';
      addTearDown(state.dispose);
      final before = jsonEncode(source.state);
      expect(state.pendingSyncCount, 1);
      expect(state.syncFeedbackMessage, isNot('Data berhasil diperbarui.'));
      expect(
        state.syncStatus.entries.single.message,
        'Kategori tidak tersedia',
      );
      expect(jsonEncode(source.state), before);
    });
  }
  test('recovery-requested pending commands wait for confirmation', () {
    final entry = SyncStatusEntry.fromRow({
      'entity_type': 'investment_transactions',
      'status': 'pending',
      'recovery_requested': true,
    });
    expect(entry.waiting, isTrue);
    expect(entry.needsReview, isFalse);
    final status = SyncStatusSummary([entry]);
    expect(status.pendingCount, 0);
    expect(status.waitingCount, 1);
  });

  test('rejected local transaction can be deleted directly and reverts balance', () {
    final source = insightRepository();
    addTearDown(source.store.close);
    final state = AppState(repository: source)..currentUserId = 'user';
    addTearDown(state.dispose);

    // Initial account setup with 100,000 balance
    source.atomic(() {
      source.entities['accounts'] = {
        'acc-1': {
          'id': 'acc-1',
          'user_id': 'user',
          'type': 'CASH',
          'name': 'Kas',
          'balance': '100000.00',
          'currency': 'IDR',
          'version': '1',
          'is_active': true,
        },
      };
      source.entities['categories'] = {
        'cat-1': {
          'id': 'cat-1',
          'user_id': 'user',
          'name': 'Makan',
          'type': 'EXPENSE',
          'version': '1',
        },
      };
    });

    // Add a 50,000 expense
    state.addTransaction(
      type: TransactionType.expense,
      amount: 50000,
      accountId: 'acc-1',
      categoryName: 'Makan',
      date: DateTime.utc(2026, 10, 24),
    );

    expect(source.outbox.length, 1);
    expect(source.row('accounts', 'acc-1')!['balance'], '50000.00');
    final txId = source.outbox.first['entity_id'] as String;

    // Simulate server rejection
    source.atomic(() {
      (source.outbox.first as Map)['status'] = 'rejected';
      (source.outbox.first as Map)['error'] = 'Data perubahan tidak valid.';
    });

    expect(state.syncStatus.entries.single.isRejected, isTrue);

    // Deleting the rejected transaction should succeed and revert account balance
    expect(state.deleteTransaction(txId), isTrue);
    expect(source.outbox, isEmpty);
    expect(source.row('transactions', txId), isNull);
    expect(source.row('accounts', 'acc-1')!['balance'], '100000.00');
    expect(state.pendingSyncCount, 0);
  });

  test('discardOutboxEntry cleans up rejected creation and reverts balance', () {
    final source = insightRepository();
    addTearDown(source.store.close);
    final state = AppState(repository: source)..currentUserId = 'user';
    addTearDown(state.dispose);

    source.atomic(() {
      source.entities['accounts'] = {
        'acc-1': {
          'id': 'acc-1',
          'user_id': 'user',
          'type': 'CASH',
          'name': 'Kas',
          'balance': '100000.00',
          'currency': 'IDR',
          'version': '1',
          'is_active': true,
        },
      };
      source.entities['categories'] = {
        'cat-1': {
          'id': 'cat-1',
          'user_id': 'user',
          'name': 'Makan',
          'type': 'EXPENSE',
          'version': '1',
        },
      };
    });

    state.addTransaction(
      type: TransactionType.expense,
      amount: 50000,
      accountId: 'acc-1',
      categoryName: 'Makan',
      date: DateTime.utc(2026, 10, 24),
    );

    final txId = source.outbox.first['entity_id'] as String;
    source.atomic(() {
      (source.outbox.first as Map)['status'] = 'rejected';
    });

    final entry = state.syncStatus.entries.single;
    expect(entry.isRejected, isTrue);
    state.discardOutboxEntry(entry);

    expect(source.outbox, isEmpty);
    expect(source.row('transactions', txId), isNull);
    expect(source.row('accounts', 'acc-1')!['balance'], '100000.00');
  });
}
