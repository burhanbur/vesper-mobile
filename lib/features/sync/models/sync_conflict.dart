class SyncConflictItem {
  final String id;
  final String entityType; // 'accounts', 'categories', 'transactions'
  final String entityName;
  final String fieldName;
  final String localValue;
  final String serverValue;
  final int localVersion;
  final int serverVersion;
  final DateTime conflictTimestamp;

  const SyncConflictItem({
    required this.id,
    required this.entityType,
    required this.entityName,
    required this.fieldName,
    required this.localValue,
    required this.serverValue,
    required this.localVersion,
    required this.serverVersion,
    required this.conflictTimestamp,
  });
}
