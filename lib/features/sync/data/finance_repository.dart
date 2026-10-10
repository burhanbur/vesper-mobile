import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/api_client.dart';
import '../../../database/local_store.dart';

/// Raw contracts stay lossless (decimal/version strings) in the durable cache.
class FinanceRepository {
  final ApiClient client;
  final LocalStore store;
  final String userId;
  late Map<String, dynamic> state;
  Future<void>? _syncing;
  bool offline = false;
  FinanceRepository(this.client, this.store, this.userId) { state = store.read(); }

  Map<String, dynamic> get entities => state['entities'] as Map<String, dynamic>;
  List<dynamic> get outbox => state['outbox'] as List<dynamic>;
  List<Map<String, dynamic>> rows(String type) =>
      ((entities[type] as Map?)?.values ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  Map<String, dynamic>? row(String type, String id) {
    final value = (entities[type] as Map?)?[id];
    return value == null ? null : Map<String, dynamic>.from(value as Map);
  }
  void _save() => store.write(state);
  void _put(String type, String id, dynamic payload) {
    final table = entities.putIfAbsent(type, () => <String, dynamic>{}) as Map;
    if (payload == null) { table.remove(id); } else { table[id] = payload; }
  }

  /// Roll back the in-memory snapshot as well if the atomic SQLite commit fails.
  void atomic(void Function() action) {
    final previous = jsonEncode(state);
    try { action(); _save(); } catch (_) { state = Map<String, dynamic>.from(jsonDecode(previous) as Map); rethrow; }
  }

  Future<void> waitForSync() async { await _syncing; }

  String mutate(String type, String operation, Map<String, dynamic>? payload, {String? id, Map<String, dynamic>? local, Map<String, int> balanceDelta = const {}}) {
    final entityId = id ?? const Uuid().v4();
    final old = row(type, entityId);
    if (outbox.any((e) => e['entity_type'] == type && e['entity_id'] == entityId)) {
      throw const ApiFailure('Sinkronkan perubahan sebelumnya terlebih dahulu.');
    }
    if (operation != 'CREATE' && old == null) throw const ApiFailure('Data tidak ditemukan.');
    atomic(() {
      outbox.add({
        'id': const Uuid().v4(), 'entity_type': type, 'entity_id': entityId,
        'operation': operation, 'payload': payload,
        'client_version': operation == 'CREATE' ? '0' : old!['version'],
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'attempts': 0, 'status': 'pending', 'before': old,
      });
      _put(type, entityId, operation == 'DELETE' ? null : {
        ...?old, ...?payload, ...?local, 'id': entityId,
        'user_id': old?['user_id'] ?? userId, 'version': old?['version'] ?? '0',
      });
      for (final entry in balanceDelta.entries) {
        final account = row('accounts', entry.key)!;
        final parts = (account['balance'] as String).split('.');
        if (parts.length > 1 && int.parse(parts[1]) != 0) {
          throw const ApiFailure('Saldo pecahan Rupiah belum didukung.');
        }
        _put('accounts', entry.key, {...account, 'balance': '${int.parse(parts[0]) + entry.value}.00'});
      }
    });
    return entityId;
  }

  Future<void> requireOnline() async {
    if (offline) throw const ApiFailure('Tindakan ini membutuhkan koneksi internet.');
  }
  Future<dynamic> writeOnline(String method, String path, Map<String, dynamic> body) async {
    await requireOnline();
    return client.request(method, path, body: body);
  }

  Future<void> sync() {
    if (_syncing != null) return _syncing!;
    final future = _runSync();
    _syncing = future;
    return future.whenComplete(() { _syncing = null; });
  }

  Future<void> _runSync() async {
    await requireOnline();
    var deviceId = state['device_id'] as String?;
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      atomic(() { state['device_id'] = deviceId; });
    }
    // Idempotent registration, including recovery after a lost response.
    await client.request('POST', '/devices', body: {
      'id': deviceId, 'name': 'Vesper mobile',
      'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'iOS' : 'Android',
      'app_version': '1.0.0',
    });
    final pending = outbox.where((e) => e['status'] == 'pending').take(100).toList();
    if (pending.isNotEmpty) {
      dynamic response;
      try {
        response = await client.request('POST', '/sync/push', body: {
          'device_id': deviceId,
          'items': pending.map((e) => {
            'entity_type': e['entity_type'], 'entity_id': e['entity_id'],
            'operation': e['operation'], 'payload': e['payload'],
            'client_version': e['client_version'],
          }).toList(),
        });
      } catch (error) {
        atomic(() { for (final item in pending) { item['attempts'] = (item['attempts'] as int) + 1; item['error'] = error.toString(); } });
        rethrow;
      }
      atomic(() {
        for (final result in response['results'] as List) {
          final index = result['index'] as int;
          if (index < 0 || index >= pending.length) throw const ApiFailure('Respons sinkronisasi tidak valid.');
          final item = pending[index] as Map;
          if (result['status'] == 'applied') { outbox.remove(item); }
          else {
            item['status'] = result['status']; item['server_data'] = result['server_data'];
            item['error'] = result['message'] ?? 'Perubahan ditolak.';
            item['attempts'] = (item['attempts'] as int) + 1;
          }
        }
      });
    }
    while (true) {
      final response = await client.request('GET', '/sync/pull', query: {
        'device_id': deviceId, 'since_version': state['cursor'], 'limit': 100,
      });
      atomic(() {
        for (final change in response['changes'] as List) {
          // Never overwrite an unacknowledged local edit with a remote snapshot.
          if (outbox.any((e) => e['entity_type'] == change['entity_type'] && e['entity_id'] == change['entity_id'])) continue;
          _put(change['entity_type'] as String, change['entity_id'] as String, change['operation'] == 'DELETE' ? null : change['payload']);
        }
        state['cursor'] = response['next_version'];
      });
      if (response['has_more'] != true) break;
    }
  }

  void resolve(String queueId, {required bool useMine}) {
    final item = outbox.firstWhere((e) => e['id'] == queueId) as Map;
    final server = item['server_data'] as Map?;
    if (useMine && (server == null || server['version'] == null)) throw const ApiFailure('Versi server tidak tersedia; muat ulang data.');
    atomic(() {
      if (useMine) { item['client_version'] = server!['version']; item['status'] = 'pending'; item.remove('error'); }
      else { _put(item['entity_type'] as String, item['entity_id'] as String, server); outbox.remove(item); }
    });
  }

  Future<void> refreshList(String type, String path, {Map<String, dynamic>? query}) async {
    await requireOnline();
    final rows = await client.list(path, query: query);
    atomic(() {
      final table = <String, dynamic>{for (final row in rows) (row['id'] ?? row['user_id']) as String: row};
      // Preserve local edits across online refreshes.
      for (final item in outbox.where((e) => e['entity_type'] == type)) {
        final id = item['entity_id'] as String;
        final local = row(type, id);
        if (local == null) { table.remove(id); } else { table[id] = local; }
      }
      entities[type] = table;
    });
  }

  Future<void> cacheValue(String key, Future<dynamic> Function() load) async {
    await requireOnline();
    final value = await load();
    atomic(() { state[key] = value; });
  }
}
