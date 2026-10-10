import 'dart:convert';

import 'package:web/web.dart' as web;

/// Browser snapshot and outbox, isolated by user. Never stores credentials.
/// A single setItem commits the complete snapshot atomically; storage failures
/// propagate so the repository can roll back the optimistic mutation.
class LocalStore {
  final String _key;

  LocalStore._(this._key);

  static Future<LocalStore> open(String userId) async {
    if (!RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(userId)) {
      throw ArgumentError('Invalid user ID');
    }
    return LocalStore._('vesper-state-$userId');
  }

  Map<String, dynamic> read() {
    final payload = web.window.localStorage.getItem(_key);
    if (payload == null) {
      return {
        'entities': <String, dynamic>{},
        'outbox': <dynamic>[],
        'cursor': '0',
      };
    }
    return Map<String, dynamic>.from(jsonDecode(payload) as Map);
  }

  void write(Map<String, dynamic> state) {
    web.window.localStorage.setItem(_key, jsonEncode(state));
  }

  void close() {}
}
