import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keys are persisted before any encrypted commit. Existing encrypted data is
/// never assigned a replacement key when secure storage is missing/unavailable.
class SnapshotKeyStore {
  final FlutterSecureStorage storage;
  const SnapshotKeyStore({
    this.storage = const FlutterSecureStorage(
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.unlocked_this_device,
      ),
    ),
  });

  Future<List<int>> load(String userId, {required bool encrypted}) async {
    final keyName = 'vesper.snapshot-key.v1.$userId';
    final existing = await storage.read(key: keyName);
    if (existing != null) {
      final key = base64Decode(existing);
      if (key.length != 32) {
        throw const FormatException('Invalid stored financial data key');
      }
      return key;
    }
    if (encrypted) {
      throw StateError(
        'Kunci data lokal tidak tersedia. Data tetap disimpan; jangan hapus atau instal ulang aplikasi. Hubungi dukungan untuk pemulihan.',
      );
    }
    final random = Random.secure();
    final key = List<int>.generate(32, (_) => random.nextInt(256));
    final value = base64Encode(key);
    await storage.write(key: keyName, value: value);
    if (await storage.read(key: keyName) != value) {
      throw StateError('Kunci data lokal tidak dapat diverifikasi.');
    }
    return key;
  }
}
