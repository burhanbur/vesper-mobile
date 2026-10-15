import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/core/security/app_lock_controller.dart';

import '../fixtures/security_fakes.dart';

void main() {
  test(
    'startup and read failures conceal until a valid preference is loaded',
    () async {
      final storage = MemorySecurityStorage()..failRead = true;
      final lock = AppLockController(
        storage: storage,
        authenticator: FakeDeviceAuthenticator(),
      );
      addTearDown(lock.dispose);
      expect(lock.blocksContent, isTrue);
      await lock.initialize();
      expect(lock.loaded, isFalse);
      expect(lock.blocksContent, isTrue);
      storage.failRead = false;
      storage.values[AppLockController.preferenceKey] = 'broken';
      await lock.initialize();
      expect(lock.blocksContent, isTrue);
      storage.values[AppLockController.preferenceKey] = 'true';
      await lock.initialize();
      expect(lock.enabled, isTrue);
      expect(lock.blocksContent, isTrue);
    },
  );

  test(
    'enable and disable require verification and a durable preference',
    () async {
      final storage = MemorySecurityStorage();
      final auth = FakeDeviceAuthenticator();
      final lock = AppLockController(storage: storage, authenticator: auth);
      addTearDown(lock.dispose);
      await lock.initialize();
      auth.accepted = false;
      await lock.setEnabled(true);
      expect(lock.enabled, isFalse);
      expect(storage.values, isEmpty);
      auth.accepted = true;
      storage.failWrite = true;
      await lock.setEnabled(true);
      expect(lock.enabled, isFalse);
      storage.failWrite = false;
      await lock.setEnabled(true);
      expect(lock.enabled, isTrue);
      expect(storage.values[AppLockController.preferenceKey], 'true');
      lock.lock();
      auth.accepted = false;
      await lock.setEnabled(false);
      expect(lock.blocksContent, isTrue);
      auth.accepted = true;
      await lock.setEnabled(false);
      expect(lock.enabled, isFalse);
      expect(storage.values[AppLockController.preferenceKey], 'false');
    },
  );

  test('cancel, missing credentials and plugin errors never bypass an enabled lock', () async {
    final storage = MemorySecurityStorage()
      ..values[AppLockController.preferenceKey] = 'true';
    final auth = FakeDeviceAuthenticator()..supported = false;
    final lock = AppLockController(storage: storage, authenticator: auth);
    addTearDown(lock.dispose);
    await lock.initialize();
    await lock.unlock();
    expect(lock.blocksContent, isTrue);
    expect(auth.prompts, 0);
    auth.supported = true;
    auth.accepted = false;
    await lock.unlock();
    expect(lock.blocksContent, isTrue);
    auth.response = () async => throw StateError('Biometry enrollment changed');
    await lock.unlock();
    expect(lock.blocksContent, isTrue);
    auth.response = null;
    auth.accepted = true;
    await lock.unlock();
    expect(lock.blocksContent, isFalse);
  });

  test(
    'background/user change invalidates late success and duplicate prompts',
    () async {
      final storage = MemorySecurityStorage()
        ..values[AppLockController.preferenceKey] = 'true';
      final response = Completer<bool>();
      final auth = FakeDeviceAuthenticator()..response = () => response.future;
      final lock = AppLockController(storage: storage, authenticator: auth);
      addTearDown(lock.dispose);
      await lock.initialize();
      final pending = lock.unlock();
      await Future<void>.delayed(Duration.zero);
      await lock.unlock();
      expect(auth.prompts, 1);
      lock.lock(invalidatePrompt: true);
      response.complete(true);
      await pending;
      expect(lock.blocksContent, isTrue);
      expect(auth.cancellations, 1);
      final restarted = AppLockController(
        storage: storage,
        authenticator: auth,
      );
      addTearDown(restarted.dispose);
      await restarted.initialize();
      expect(restarted.blocksContent, isTrue);
    },
  );

  test('interrupted disable restores the enabled preference', () async {
    final storage = MemorySecurityStorage()
      ..values[AppLockController.preferenceKey] = 'true';
    final lock = AppLockController(
      storage: storage,
      authenticator: FakeDeviceAuthenticator(),
    );
    addTearDown(lock.dispose);
    await lock.initialize();
    var first = true;
    storage.onWrite = () async {
      if (first) {
        first = false;
        lock.lock(invalidatePrompt: true);
      }
    };
    await lock.setEnabled(false);
    expect(lock.blocksContent, isTrue);
    expect(storage.values[AppLockController.preferenceKey], 'true');
  });
}
