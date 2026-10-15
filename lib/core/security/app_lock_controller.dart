import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

abstract interface class DeviceAuthenticator {
  Future<bool> isSupported();
  Future<bool> authenticate();
  Future<void> cancel();
}

class PlatformDeviceAuthenticator implements DeviceAuthenticator {
  final LocalAuthentication _auth = LocalAuthentication();

  @override
  Future<bool> isSupported() async =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows) &&
      await _auth.isDeviceSupported();

  @override
  Future<bool> authenticate() => _auth.authenticate(
    localizedReason: 'Verifikasi identitas untuk membuka Vesper',
    biometricOnly: false,
    persistAcrossBackgrounding: false,
  );

  @override
  Future<void> cancel() async {
    await _auth.stopAuthentication();
  }
}

/// Device-wide access policy, independent of login and financial persistence.
/// A failed preference read also blocks presentation until it can be retried.
class AppLockController extends ChangeNotifier {
  static const preferenceKey = 'vesper.app-lock.v1';
  final FlutterSecureStorage storage;
  final DeviceAuthenticator authenticator;
  bool loaded = false, enabled = false, locked = true, busy = false;
  String? error;
  int _epoch = 0;
  bool _disposed = false;
  bool _initializing = false;

  AppLockController({
    FlutterSecureStorage? storage,
    DeviceAuthenticator? authenticator,
  }) : storage = storage ?? const FlutterSecureStorage(),
       authenticator = authenticator ?? PlatformDeviceAuthenticator();

  bool get blocksContent => !loaded || (enabled && locked);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() async {
    if (_disposed || _initializing || loaded) return;
    _initializing = true;
    error = null;
    _notify();
    try {
      // Web has no platform authentication. Never offer a pretend app lock.
      final value = kIsWeb ? null : await storage.read(key: preferenceKey);
      if (_disposed) return;
      if (value != null && value != 'true' && value != 'false') {
        throw const FormatException('Invalid app lock preference');
      }
      enabled = value == 'true';
      locked = enabled;
      loaded = true;
    } catch (_) {
      error = 'Pengaturan keamanan tidak dapat dibaca. Coba lagi.';
    } finally {
      _initializing = false;
      _notify();
    }
  }

  /// Inactive can be the system authentication dialog itself. Hidden/paused
  /// and identity changes invalidate an in-flight result as well as concealing.
  void lock({bool invalidatePrompt = false}) {
    if (_disposed) return;
    if (invalidatePrompt) {
      ++_epoch;
      if (busy) {
        // Cancellation is best effort. The epoch is the actual security guard.
        authenticator.cancel().catchError((Object _) {});
      }
    }
    if (enabled) locked = true;
    _notify();
  }

  Future<void> unlock() async {
    if (!loaded || !enabled || !locked || busy || _disposed) return;
    await _verify(() async {
      locked = false;
    });
  }

  Future<void> setEnabled(bool value) async {
    if (!loaded || busy || _disposed || enabled == value) return;
    await _verify(() async {
      final epoch = _epoch;
      await storage.write(key: preferenceKey, value: '$value');
      if (_disposed || epoch != _epoch) {
        // An interrupted disable must not leave a persisted bypass.
        if (!value) {
          await storage.write(key: preferenceKey, value: 'true');
        }
        return;
      }
      enabled = value;
      locked = false;
    });
  }

  Future<void> _verify(Future<void> Function() onSuccess) async {
    busy = true;
    error = null;
    final epoch = _epoch;
    _notify();
    try {
      if (!await authenticator.isSupported()) {
        error = 'Kunci perangkat tidak tersedia. Aktifkan PIN, sandi, atau biometrik pada pengaturan perangkat.';
      } else if (epoch == _epoch && !_disposed) {
        final accepted = await authenticator.authenticate();
        if (_disposed || epoch != _epoch) return;
        if (accepted) {
          await onSuccess();
        } else {
          error = 'Verifikasi dibatalkan. Aplikasi tetap terlindungi.';
        }
      }
    } catch (_) {
      error = 'Verifikasi atau penyimpanan pengaturan gagal. Coba lagi.';
    } finally {
      busy = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_epoch;
    authenticator.cancel().catchError((Object _) {});
    super.dispose();
  }
}
