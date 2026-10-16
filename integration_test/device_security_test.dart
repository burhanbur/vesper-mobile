import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:vesper_mobile/app/widgets/app_lock_gate.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/features/dashboard/pages/dashboard_page.dart';
import 'package:vesper_mobile/features/sync/data/finance_repository.dart';
import 'package:vesper_mobile/core/security/app_lock_controller.dart';
import 'package:vesper_mobile/core/security/local_data_failure.dart';
import 'package:vesper_mobile/database/local_store_native.dart';

import '../test/fixtures/security_fakes.dart';
import '../test/fixtures/login_client.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Android login renders server accounts before history and persists completed history',
    (tester) async {
      final user = 'security-test-login-${const Uuid().v4()}';
      final directory = await getApplicationSupportDirectory();
      const secure = FlutterSecureStorage();
      final client = LoginClient()..limited = false;
      final store = await LocalStore.open(user);
      final repo = FinanceRepository(client, store, user);
      final state = AppState(repository: repo);
      Future<void>? login;
      try {
        await tester.pumpWidget(
          AppStateScope(
            state: state,
            child: MaterialApp(
              home: DashboardPage(
                onNavigateToTransactions: () {},
                onNavigateToInvestments: () {},
                onNavigateToReports: () {},
                onNavigateToHousehold: () {},
              ),
            ),
          ),
        );
        login = state.login(userId: user);
        await client.coreReady.future.timeout(const Duration(seconds: 15));
        await tester.pump();
        expect(state.loading, isTrue);
        expect(state.accounts.single.name, 'Server cash');
        expect(find.text('Memuat data dari server'), findsOneWidget);
        expect(find.text('Server cash'), findsOneWidget);
        client.releaseSync.complete();
        await login;
        await tester.pumpAndSettle();
        expect(state.loading, isFalse);
        expect(state.dataError, isNull);
        expect(repo.rows('transactions'), hasLength(2));
        expect(find.text('Memuat data dari server'), findsNothing);
      } finally {
        if (!client.releaseSync.isCompleted) client.releaseSync.complete();
        await login;
        await tester.pumpWidget(const SizedBox());
        state.dispose();
        await Future<void>.delayed(Duration.zero);
        final restarted = await LocalStore.open(user);
        expect((restarted.read()['entities']['transactions'] as Map).length, 2);
        restarted.close();
        await secure.delete(key: 'vesper.snapshot-key.v1.$user');
        await secure.delete(key: 'vesper.storage-version.v1.$user');
        for (final version in ['', '.v3']) {
          for (final suffix in ['', '-wal', '-shm', '-journal']) {
            final path = p.join(
              directory.path,
              'vesper-$user$version.sqlite$suffix',
            );
            if (!user.startsWith('security-test-login-') ||
                !p.isWithin(directory.path, path)) {
              throw StateError('Invalid test cleanup path');
            }
            final file = File(path);
            if (file.existsSync()) file.deleteSync();
          }
        }
      }
    },
  );

  testWidgets(
    'native secure key and encrypted outbox survive restart and missing key fails closed',
    (tester) async {
      // Isolated synthetic user; no real sessions, network or existing data.
      final user = 'security-test-${const Uuid().v4()}';
      final directory = await getApplicationSupportDirectory();
      final keyName = 'vesper.snapshot-key.v1.$user';
      const secure = FlutterSecureStorage(
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.unlocked_this_device,
        ),
      );
      LocalStore? store;
      final snapshot = <String, dynamic>{
        'entities': {
          'accounts': {
            'cash': {
              'balance': '9007199254740993.01',
              'name': 'native-private-marker',
            },
          },
        },
        'outbox': [
          for (final status in [
            'pending',
            'rejected',
            'conflict',
            'acknowledged',
          ])
            {'id': 'original-$status', 'status': status},
        ],
        'cursor': '12345678901234567890',
        'investment_command_snapshots': {
          'original': {'id': 'stable-ledger'},
        },
      };
      try {
        store = await LocalStore.open(user);
        store.write(snapshot);
        expect(store.isIndexed, isTrue);
        final row = store.database
            .select(
              "SELECT payload FROM entity_records WHERE entity_type='accounts' AND id='cash'",
            )
            .single;
        expect(
          jsonDecode(row['payload'] as String),
          snapshot['entities']['accounts']['cash'],
        );
        for (final suffix in ['', '-wal']) {
          final file = File(
            p.join(directory.path, 'vesper-$user.v3.sqlite$suffix'),
          );
          if (file.existsSync()) {
            expect(
              latin1.decode(file.readAsBytesSync()),
              isNot(contains('native-private-marker')),
            );
          }
        }
        store.close();
        store = null;
        store = await LocalStore.open(user);
        expect(store.read(), snapshot);
        store.close();
        store = null;
        final persistedKey = await secure.read(key: keyName);
        expect(persistedKey, isNotNull);
        await secure.delete(key: keyName);
        try {
          await expectLater(
            LocalStore.open(user),
            throwsA(isA<LocalDataFailure>()),
          );
          expect(await secure.read(key: keyName), isNull);
        } finally {
          await secure.write(key: keyName, value: persistedKey);
        }
        store = await LocalStore.open(user);
        expect(store.read(), snapshot);
        store.close();
        store = null;
        for (final suffix in [
          '',
          '-wal',
          '-shm',
          '.v3.sqlite',
          '.v3.sqlite-wal',
          '.v3.sqlite-shm',
        ]) {
          final file = File(
            p.join(
              directory.path,
              suffix.startsWith('.v3')
                  ? 'vesper-$user$suffix'
                  : 'vesper-$user.sqlite$suffix',
            ),
          );
          if (file.existsSync()) {
            expect(
              latin1.decode(file.readAsBytesSync()),
              isNot(contains('native-private-marker')),
            );
          }
        }
      } finally {
        store?.close();
        await secure.delete(key: keyName);
        await secure.delete(key: 'vesper.storage-version.v1.$user');
        for (final suffix in [
          '',
          '-wal',
          '-shm',
          '-journal',
          '.v3.sqlite',
          '.v3.sqlite-wal',
          '.v3.sqlite-shm',
          '.v3.sqlite-journal',
        ]) {
          final path = p.join(
            directory.path,
            suffix.startsWith('.v3')
                ? 'vesper-$user$suffix'
                : 'vesper-$user.sqlite$suffix',
          );
          if (!user.startsWith('security-test-') ||
              !p.isWithin(directory.path, path)) {
            throw StateError('Invalid test cleanup path');
          }
          final file = File(path);
          if (file.existsSync()) file.deleteSync();
        }
      }
    },
  );

  testWidgets(
    'real platform authentication cancellation/unavailability preserves locked presentation',
    (tester) async {
      final preference = MemorySecurityStorage()
        ..values[AppLockController.preferenceKey] = 'true';
      final platform = PlatformDeviceAuthenticator();
      final lock = AppLockController(
        storage: preference,
        authenticator: platform,
      );
      await lock.initialize();
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) =>
              AppLockGate(controller: lock, child: child!),
          home: const Scaffold(body: Text('private financial content')),
        ),
      );
      expect(find.text('private financial content'), findsNothing);
      final cancel = Timer(const Duration(seconds: 1), () => platform.cancel());
      try {
        await lock.unlock().timeout(const Duration(seconds: 15));
        await tester.pumpAndSettle();
        expect(lock.blocksContent, isTrue);
        expect(find.text('private financial content'), findsNothing);
        expect(find.text('Vesper terkunci'), findsOneWidget);
      } finally {
        cancel.cancel();
        await platform.cancel();
        await tester.pumpWidget(const SizedBox());
        lock.dispose();
      }
    },
  );
}
