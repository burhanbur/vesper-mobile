import 'dart:convert';

import 'package:web/web.dart' as web;

import 'transaction_query.dart';

/// Browser snapshot and outbox, isolated by user. Never stores credentials.
/// A single setItem commits the complete snapshot atomically; storage failures
/// propagate so the repository can roll back the optimistic mutation.
class LocalStore {
  bool get isIndexed => false;
  int _revision = 0;
  int get revision => _revision;
  void atomicState(void Function() action) =>
      throw UnsupportedError('Indexed native transactions unavailable');
  TransactionPage transactionPage(TransactionQuery query) =>
      throw UnsupportedError('Indexed native queries unavailable');
  TransactionSummary transactionSummary(DateTime start, DateTime end) =>
      throw UnsupportedError('Indexed native queries unavailable');
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
    _revision++;
  }

  void close() {}
}
