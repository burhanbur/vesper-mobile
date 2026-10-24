import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/features/dashboard/widgets/offline_banner.dart';
import 'package:vesper_mobile/features/sync/models/sync_status.dart';

class _QueueState extends AppState {
  final String? afterStatus;
  _QueueState(this.afterStatus);
  List<SyncStatusEntry> entries = [
    SyncStatusEntry.fromRow({
      'entity_type': 'transactions',
      'status': 'pending',
    }),
  ];
  @override
  int get pendingSyncCount => entries.length;
  @override
  SyncStatusSummary get syncStatus => SyncStatusSummary(entries);
  @override
  Future<void> syncPendingNow() async {
    entries = afterStatus == null
        ? []
        : [
            SyncStatusEntry.fromRow({
              'id': 'q-1',
              'entity_type': 'transactions',
              'status': afterStatus,
              'error': 'Kategori sudah dihapus',
            }),
          ];
    notifyListeners();
  }
}

void main() {
  for (final status in [
    'rejected',
    'conflict',
    'acknowledged',
    'pending',
    null,
  ]) {
    testWidgets('banner reports actual queue after sync: $status', (
      tester,
    ) async {
      final state = _QueueState(status);
      addTearDown(state.dispose);
      await tester.pumpWidget(
        AppStateScope(
          state: state,
          child: const MaterialApp(
            home: Scaffold(body: SingleChildScrollView(child: OfflineBanner())),
          ),
        ),
      );
      await tester.tap(find.text('Sinkronkan'));
      await tester.pumpAndSettle();
      expect(
        find.text('Data berhasil diperbarui.'),
        status == null ? findsOneWidget : findsNothing,
      );
      expect(state.pendingSyncCount, status == null ? 0 : 1);
      if (status == 'rejected' || status == 'conflict') {
        expect(find.text('1 perubahan perlu diperiksa'), findsOneWidget);
        await tester.tap(find.text('Periksa perubahan'));
        await tester.pumpAndSettle();
        expect(find.text('Kategori sudah dihapus'), findsOneWidget);
        if (status == 'rejected') {
          expect(find.text('Buang perubahan lokal'), findsOneWidget);
        }
        expect(state.pendingSyncCount, 1);
      }
      if (status == 'acknowledged') {
        expect(find.text('1 perubahan menunggu konfirmasi'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
