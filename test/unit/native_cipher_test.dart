import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test(
    'bundled native cipher authenticates encrypted database pages and WAL',
    () {
      final directory = Directory.systemTemp.createTempSync(
        'vesper-native-cipher-',
      );
      if (directory.parent.absolute.path !=
          Directory.systemTemp.absolute.path) {
        throw StateError('Unexpected temporary directory');
      }
      addTearDown(() => directory.deleteSync(recursive: true));
      final path = '${directory.path}${Platform.pathSeparator}test.sqlite';
      final database = sqlite3.open(path);
      expect(database.select('PRAGMA cipher').isNotEmpty, isTrue);
      database.execute("PRAGMA cipher='chacha20'");
      database.execute("PRAGMA key='raw:${'01' * 32}'");
      database.execute('PRAGMA journal_mode=WAL');
      database.execute('CREATE TABLE secret(payload TEXT NOT NULL)');
      database.execute('INSERT INTO secret VALUES(?)', [
        'private-native-cipher-marker',
      ]);
      for (final suffix in ['', '-wal']) {
        final file = File('$path$suffix');
        expect(
          latin1.decode(file.readAsBytesSync()),
          isNot(contains('private-native-cipher-marker')),
        );
      }
      database.close();
      final withoutKey = sqlite3.open(path);
      expect(
        () => withoutKey.select('SELECT * FROM secret'),
        throwsA(isA<SqliteException>()),
      );
      withoutKey.close();
      final reopened = sqlite3.open(path);
      reopened.execute("PRAGMA cipher='chacha20'");
      reopened.execute("PRAGMA key='raw:${'01' * 32}'");
      expect(
        reopened.select('SELECT payload FROM secret').first['payload'],
        'private-native-cipher-marker',
      );
      reopened.close();
    },
  );
}
