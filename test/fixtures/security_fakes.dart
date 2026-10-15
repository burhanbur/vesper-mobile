import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:vesper_mobile/core/security/app_lock_controller.dart';

class MemorySecurityStorage extends FlutterSecureStorage {
  final Map<String, String> values = {};
  bool failRead = false, failWrite = false;
  Future<void> Function()? onWrite;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (failRead) throw StateError('Storage unavailable');
    return values[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (failWrite) throw StateError('Storage full');
    await onWrite?.call();
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}

class FakeDeviceAuthenticator implements DeviceAuthenticator {
  bool supported = true, accepted = true;
  int prompts = 0, cancellations = 0;
  Future<bool> Function()? response;

  @override
  Future<bool> isSupported() async => supported;
  @override
  Future<bool> authenticate() async {
    prompts++;
    return response == null ? accepted : await response!();
  }

  @override
  Future<void> cancel() async {
    cancellations++;
  }
}
