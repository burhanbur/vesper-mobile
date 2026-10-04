enum TransactionType {
  income,
  expense,
  transfer,
  investmentBuy,
  investmentSell,
}

enum SyncStatus {
  pending,
  synced,
  failed,
}

class TransactionItem {
  final String id;
  final TransactionType type;
  final int amount; // in integer Rupiah
  final String accountId;
  final String? toAccountId; // only for transfer
  final String categoryName;
  final String? note;
  final DateTime date;
  final String householdId;
  final SyncStatus syncStatus;
  final String createdByUserId;
  final String createdByName;
  final String? transferId;
  final int version;
  final bool isDebt; // shortcut "Catat Utang"
  final bool isReceivable; // shortcut "Catat Piutang"

  const TransactionItem({
    required this.id,
    required this.type,
    required this.amount,
    required this.accountId,
    this.toAccountId,
    required this.categoryName,
    this.note,
    required this.date,
    required this.householdId,
    this.syncStatus = SyncStatus.synced,
    this.createdByUserId = 'u-1',
    this.createdByName = 'Burhan Mafazi',
    this.transferId,
    this.version = 1,
    this.isDebt = false,
    this.isReceivable = false,
  });

  TransactionItem copyWith({
    String? id,
    TransactionType? type,
    int? amount,
    String? accountId,
    String? toAccountId,
    String? categoryName,
    String? note,
    DateTime? date,
    String? householdId,
    SyncStatus? syncStatus,
    String? createdByUserId,
    String? createdByName,
    String? transferId,
    int? version,
    bool? isDebt,
    bool? isReceivable,
  }) {
    return TransactionItem(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      accountId: accountId ?? this.accountId,
      toAccountId: toAccountId ?? this.toAccountId,
      categoryName: categoryName ?? this.categoryName,
      note: note ?? this.note,
      date: date ?? this.date,
      householdId: householdId ?? this.householdId,
      syncStatus: syncStatus ?? this.syncStatus,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      createdByName: createdByName ?? this.createdByName,
      transferId: transferId ?? this.transferId,
      version: version ?? this.version,
      isDebt: isDebt ?? this.isDebt,
      isReceivable: isReceivable ?? this.isReceivable,
    );
  }
}
