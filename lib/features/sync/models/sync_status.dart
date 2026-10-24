class SyncStatusEntry {
  final String title, status, message;
  final String id, entityType, entityId;
  final bool waiting, needsReview, isRejected;
  const SyncStatusEntry(
    this.title,
    this.status,
    this.message, {
    this.id = '',
    this.entityType = '',
    this.entityId = '',
    this.waiting = false,
    this.needsReview = false,
    this.isRejected = false,
  });

  factory SyncStatusEntry.fromRow(Map row) {
    final status = '${row['status']}';
    final waiting =
        status == 'acknowledged' ||
        status == 'cancellation_approved' ||
        (status == 'pending' && row['recovery_requested'] == true);
    final review =
        status == 'rejected' ||
        status == 'conflict' ||
        (status != 'pending' && !waiting);
    final title = switch (row['entity_type']) {
      'transactions' => 'Transaksi',
      'transfers' => 'Transfer',
      'investment_transactions' => 'Transaksi investasi',
      'obligation_commands' => 'Perubahan utang/piutang',
      'bill_commands' || 'bill_schedules' => 'Tagihan',
      'accounts' => 'Akun',
      'categories' => 'Kategori',
      'goals' || 'goal_allocations' => 'Tujuan keuangan',
      _ => 'Perubahan keuangan',
    };
    return SyncStatusEntry(
      title,
      status == 'conflict'
          ? 'Konflik data'
          : status == 'rejected'
          ? 'Ditolak server'
          : review
          ? 'Perlu diperiksa'
          : waiting
          ? 'Menunggu konfirmasi'
          : 'Menunggu dikirim',
      row['error']?.toString() ??
          (review
              ? 'Perubahan perlu ditinjau sebelum dapat diselesaikan.'
              : waiting
              ? 'Data lokal dipertahankan sampai konfirmasi server lengkap.'
              : 'Perubahan tersimpan di perangkat dan menunggu pengiriman.'),
      id: row['id']?.toString() ?? '',
      entityType: row['entity_type']?.toString() ?? '',
      entityId: row['entity_id']?.toString() ?? '',
      waiting: waiting,
      needsReview: review,
      isRejected: status == 'rejected',
    );
  }
}

class SyncStatusSummary {
  final List<SyncStatusEntry> entries;
  const SyncStatusSummary([this.entries = const []]);
  int get reviewCount => entries.where((e) => e.needsReview).length;
  int get waitingCount => entries.where((e) => e.waiting).length;
  int get pendingCount => entries.length - reviewCount - waitingCount;
}
