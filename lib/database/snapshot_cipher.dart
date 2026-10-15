import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';

/// Versioned authenticated envelope. The user/schema binding prevents copying
/// another user's ciphertext into this database, even when keys are misrouted.
class SnapshotCipher {
  static const prefix = 'vesper:aes-gcm:v1:';
  final SecretKeyData _key;
  final List<int> _aad;
  final DartAesGcm _algorithm = DartAesGcm.with256bits();

  SnapshotCipher(List<int> key, String userId)
    : _key = SecretKeyData(key),
      _aad = utf8.encode('vesper.financial-snapshot.v1:$userId') {
    if (key.length != 32) throw ArgumentError('Invalid snapshot key length');
  }

  String encrypt(String plaintext) {
    final box = _algorithm.encryptSync(
      utf8.encode(plaintext),
      secretKeyData: _key,
      aad: _aad,
    );
    return '$prefix${base64Encode(box.concatenation())}';
  }

  String decrypt(String envelope) {
    if (!envelope.startsWith(prefix)) {
      throw const FormatException('Unsupported financial snapshot format');
    }
    final box = SecretBox.fromConcatenation(
      base64Decode(envelope.substring(prefix.length)),
      nonceLength: 12,
      macLength: 16,
    );
    return utf8.decode(
      _algorithm.decryptSync(box, secretKeyData: _key, aad: _aad),
    );
  }

  void dispose() => _key.destroy();
}
