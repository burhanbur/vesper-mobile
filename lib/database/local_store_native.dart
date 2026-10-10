import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

/// A user-scoped SQLite snapshot and transactional outbox. No credentials.
class LocalStore {
  final Database database;
  LocalStore(this.database) {
    database.execute('PRAGMA journal_mode=WAL');
    database.execute(
      'CREATE TABLE IF NOT EXISTS state (id INTEGER PRIMARY KEY CHECK(id=1), payload TEXT NOT NULL)',
    );
  }

  static Future<LocalStore> open(String userId) async {
    if (!RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(userId)) {
      throw ArgumentError('Invalid user ID');
    }
    final directory = await getApplicationSupportDirectory();
    await Directory(directory.path).create(recursive: true);
    return LocalStore(
      sqlite3.open(p.join(directory.path, 'vesper-$userId.sqlite')),
    );
  }

  Map<String, dynamic> read() {
    final rows = database.select('SELECT payload FROM state WHERE id=1');
    if (rows.isEmpty) {
      return {
        'entities': <String, dynamic>{},
        'outbox': <dynamic>[],
        'cursor': '0',
      };
    }
    return Map<String, dynamic>.from(
      jsonDecode(rows.first['payload'] as String) as Map,
    );
  }

  void write(Map<String, dynamic> state) {
    final payload = jsonEncode(state);
    database.execute('BEGIN IMMEDIATE');
    try {
      database.execute(
        'INSERT INTO state(id,payload) VALUES(1,?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload',
        [payload],
      );
      database.execute('COMMIT');
    } catch (_) {
      database.execute('ROLLBACK');
      rethrow;
    }
  }

  void close() => database.close();
}
