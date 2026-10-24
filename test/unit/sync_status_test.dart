import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/features/sync/models/sync_status.dart';

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
}
