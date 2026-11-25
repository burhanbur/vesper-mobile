import '../../../core/network/api_client.dart';

class RegisteredDevice {
  final String id;
  final String name;
  final String platform;
  final String appVersion;
  final String? lastSyncVersion;
  final DateTime? lastSeenAt;
  final DateTime? lastSyncAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const RegisteredDevice({
    required this.id,
    required this.name,
    required this.platform,
    required this.appVersion,
    this.lastSyncVersion,
    this.lastSeenAt,
    this.lastSyncAt,
    this.createdAt,
    this.updatedAt,
  });

  /// Primary device model/name without the appended OS suffix.
  String get displayName {
    final sep = name.indexOf(' • ');
    if (sep > 0) {
      final head = name.substring(0, sep).trim();
      if (head.isNotEmpty) return head;
    }
    return name;
  }

  /// Optional OS/environment detail parsed from structured names like
  /// "Samsung Galaxy S10 • Android 12" or "Chrome • Windows".
  String? get osDetail {
    final sep = name.indexOf(' • ');
    if (sep > 0 && sep + 3 < name.length) {
      final tail = name.substring(sep + 3).trim();
      if (tail.isNotEmpty) return tail;
    }
    return null;
  }

  /// Most recent login/activity timestamp known for this device.
  DateTime? get lastActiveAt => lastSeenAt ?? lastSyncAt ?? updatedAt ?? createdAt;

  /// Compact identifier for display (e.g. "a1b2c3d4…90ef").
  String get shortId {
    if (id.length <= 14) return id;
    return '${id.substring(0, 8)}…${id.substring(id.length - 4)}';
  }

  factory RegisteredDevice.fromJson(Map<String, dynamic> value) {
    if (value['id'] is! String ||
        value['name'] is! String ||
        value['platform'] is! String ||
        value['app_version'] is! String) {
      throw const ApiFailure('Respons perangkat tidak valid.');
    }
    return RegisteredDevice(
      id: value['id'] as String,
      name: value['name'] as String,
      platform: value['platform'] as String,
      appVersion: value['app_version'] as String,
      lastSyncVersion: value['last_sync_version'] is String
          ? value['last_sync_version'] as String
          : null,
      lastSeenAt: _parseDate(value['last_seen_at']),
      lastSyncAt: _parseDate(value['last_sync_at']),
      createdAt: _parseDate(value['created_at']),
      updatedAt: _parseDate(value['updated_at']),
    );
  }

  static DateTime? _parseDate(Object? raw) {
    if (raw is! String || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw.trim());
  }
}

class DevicesRepository {
  final ApiClient client;
  DevicesRepository({ApiClient? client}) : client = client ?? ApiClient.shared;

  Future<List<RegisteredDevice>> list() async {
    try {
      final rows = await client.list('/devices');
      return rows.map(RegisteredDevice.fromJson).toList(growable: false);
    } on TypeError {
      throw const ApiFailure('Respons perangkat tidak valid.');
    }
  }
}
