import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:vesper_mobile/database/local_store_native.dart';
import 'package:vesper_mobile/database/snapshot_cipher.dart';
import 'package:vesper_mobile/database/snapshot_key_store.dart';

import '../fixtures/security_fakes.dart';

void main() {
  final key = List<int>.generate(32, (i) => i);
  Map<String, dynamic> pendingState() => {
    'entities': {
      'accounts': {
        'account': {
          'balance': '9007199254740993.01',
          'name': 'private-marker-financial-data',
        },
      },
    },
    'outbox': [
      for (final status in ['pending', 'rejected', 'conflict', 'acknowledged'])
        {
          'id': 'original-$status',
          'status': status,
          'payload': {'quantity': '1.00000001'},
        },
    ],
    'cursor': '9007199254740994',
    'investment_command_snapshots': {
      'trade': {'id': 'stable-ledger'},
    },
    'investment_history_coverage': {'user_id': 'user', 'complete': false},
  };

  String temporaryDatabase() {
    final directory = Directory.systemTemp.createTempSync(
      'vesper-encryption-test-',
    );
    final parent = Directory.systemTemp.absolute.path;
    if (directory.parent.absolute.path != parent ||
        !directory.path.contains('vesper-encryption-test-')) {
      throw StateError('Unexpected temporary directory');
    }
    addTearDown(() => directory.deleteSync(recursive: true));
    return '${directory.path}${Platform.pathSeparator}test.sqlite';
  }

  test('versioned encryption randomizes nonces, authenticates user and detects tampering', () {
    final cipher = SnapshotCipher(key, 'user');
    final otherUser = SnapshotCipher(key, 'other');
    addTearDown(cipher.dispose);
    addTearDown(otherUser.dispose);
    final text = jsonEncode(pendingState());
    final first = cipher.encrypt(text);
    final second = cipher.encrypt(text);
    expect(first, isNot(second));
    expect(cipher.decrypt(first), text);
    expect(first, isNot(contains('private-marker')));
    expect(
      () => otherUser.decrypt(first),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
    final bytes = base64Decode(first.substring(SnapshotCipher.prefix.length));
    bytes[15] ^= 1;
    expect(
      () => cipher.decrypt('${SnapshotCipher.prefix}${base64Encode(bytes)}'),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
  });

  test('legacy migration preserves every command, decimal, cursor and staging row across restart', () {
    final path = temporaryDatabase();
    final legacy = LocalStore(sqlite3.open(path));
    final state = pendingState();
    legacy.write(state);
    legacy.close();
    final store = LocalStore(
      sqlite3.open(path),
      cipher: SnapshotCipher(key, 'user'),
    );
    expect(store.read(), state);
    expect(store.database.select('PRAGMA user_version').first.values.first, 2);
    final raw =
        store.database.select('SELECT payload FROM state').first['payload']
            as String;
    expect(raw, startsWith(SnapshotCipher.prefix));
    for (final suffix in ['', '-wal', '-shm']) {
      final file = File('$path$suffix');
      if (file.existsSync()) {
        expect(
          latin1.decode(file.readAsBytesSync()),
          isNot(contains('private-marker-financial-data')),
        );
      }
    }
    store.write({...state, 'cursor': '9007199254740995'});
    store.close();
    final restarted = LocalStore(
      sqlite3.open(path),
      cipher: SnapshotCipher(key, 'user'),
    );
    expect(restarted.read(), {...state, 'cursor': '9007199254740995'});
    restarted.close();
  });

  test(
    'failed migration commit retains original plaintext and remains retryable',
    () {
      final database = sqlite3.openInMemory();
      final legacy = LocalStore(database);
      legacy.write(pendingState());
      final original = database
          .select('SELECT payload FROM state')
          .first['payload'];
      database.execute(
        "CREATE TRIGGER fail_migration BEFORE UPDATE ON state BEGIN SELECT RAISE(ABORT, 'disk full'); END",
      );
      final cipher = SnapshotCipher(key, 'user');
      expect(
        () => LocalStore(database, cipher: cipher),
        throwsA(isA<SqliteException>()),
      );
      cipher.dispose();
      expect(database.select('PRAGMA user_version').first.values.first, 0);
      expect(
        database.select('SELECT payload FROM state').first['payload'],
        original,
      );
      database.execute('DROP TRIGGER fail_migration');
      final retry = LocalStore(database, cipher: SnapshotCipher(key, 'user'));
      expect(retry.read(), pendingState());
      retry.close();
    },
  );

  test('restart at encrypted migration checkpoint finishes cleanup without changing commands', () {
    final path = temporaryDatabase();
    final database = sqlite3.open(path);
    final legacy = LocalStore(database);
    legacy.write(pendingState());
    final cipher = SnapshotCipher(key, 'user');
    database.execute('UPDATE state SET payload=? WHERE id=1', [
      cipher.encrypt(jsonEncode(pendingState())),
    ]);
    database.execute('PRAGMA user_version=1');
    cipher.dispose();
    legacy.close();
    final resumed = LocalStore(
      sqlite3.open(path),
      cipher: SnapshotCipher(key, 'user'),
    );
    expect(resumed.read(), pendingState());
    expect(
      resumed.database.select('PRAGMA user_version').first.values.first,
      2,
    );
    resumed.close();
  });

  test('wrong key and corrupted ciphertext leave persisted data untouched', () {
    final path = temporaryDatabase();
    final store = LocalStore(
      sqlite3.open(path),
      cipher: SnapshotCipher(key, 'user'),
    );
    store.write(pendingState());
    store.close();
    final database = sqlite3.open(path);
    final original = database
        .select('SELECT payload FROM state')
        .first['payload'];
    final wrong = SnapshotCipher(List.filled(32, 200), 'user');
    expect(
      () => LocalStore(database, cipher: wrong),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
    wrong.dispose();
    expect(
      database.select('SELECT payload FROM state').first['payload'],
      original,
    );
    database.close();
    final restored = LocalStore(
      sqlite3.open(path),
      cipher: SnapshotCipher(key, 'user'),
    );
    expect(restored.read(), pendingState());
    restored.close();
  });

  test('missing, malformed or unavailable secure keys are never replaced for encrypted data', () async {
    final storage = MemorySecurityStorage();
    final keys = SnapshotKeyStore(storage: storage);
    await expectLater(keys.load('user', encrypted: true), throwsStateError);
    expect(storage.values, isEmpty);
    storage.failWrite = true;
    await expectLater(keys.load('user', encrypted: false), throwsStateError);
    expect(storage.values, isEmpty);
    storage.failWrite = false;
    final created = await keys.load('user', encrypted: false);
    expect(created, hasLength(32));
    expect(await keys.load('user', encrypted: true), created);
    expect(await keys.load('other', encrypted: false), isNot(created));
    final persisted = Map.of(storage.values);
    storage.failRead = true;
    await expectLater(keys.load('user', encrypted: true), throwsStateError);
    expect(storage.values, persisted);
    storage.failRead = false;
    storage.values['vesper.snapshot-key.v1.user'] = base64Encode([1, 2]);
    await expectLater(
      keys.load('user', encrypted: true),
      throwsFormatException,
    );
    expect(storage.values['vesper.snapshot-key.v1.user'], base64Encode([1, 2]));
  });
}
