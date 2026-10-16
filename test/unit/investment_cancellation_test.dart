import '../fixtures/recovery_client.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/database/local_store.dart';
import 'package:vesper_mobile/features/sync/data/finance_repository.dart';

const portfolio = '11111111-1111-4111-8111-111111111111';
const cash = '22222222-2222-4222-8222-222222222222';
const instrument = '33333333-3333-4333-8333-333333333333';

void main() {
  test('Dart and backend share the canonical wire fingerprint independently of local queue identity', () {
    const canonical =
        '{"client_version":"0","entity_id":"44444444-4444-4444-8444-444444444444","entity_type":"investment_transactions","operation":"CREATE","payload":{"account_id":"11111111-1111-4111-8111-111111111111","cash_account_id":"22222222-2222-4222-8222-222222222222","description":"Recovery test","fee":"0","instrument_id":"33333333-3333-4333-8333-333333333333","linked_transaction_id":"55555555-5555-4555-8555-555555555555","price_per_unit":"10.005","quantity":"1","transacted_at":"2026-10-16T00:00:00.000Z","type":"BUY"}}';
    final store = LocalStore(sqlite3.openInMemory());
    final repo = FinanceRepository(RecoveryClient(), store, 'actor');
    try {
      repo.atomic(
        () => repo.outbox.add({
          ...jsonDecode(canonical) as Map,
          'id': 'local-queue',
          'status': 'rejected',
        }),
      );
      expect(
        repo.investmentRecoveryReference('local-queue')['wire_command_sha256'],
        '5bd9978d357c75ff87322d6be56efd918a35cbea47784495deda6f8854fa3864',
      );
      repo.atomic(() => repo.outbox.single['id'] = 'other-queue');
      expect(
        repo.investmentRecoveryReference('other-queue')['wire_command_sha256'],
        '5bd9978d357c75ff87322d6be56efd918a35cbea47784495deda6f8854fa3864',
      );
    } finally {
      store.close();
    }
  });
  for (final indexed in [false, true]) {
    group(indexed ? 'indexed cancellation' : 'legacy cancellation', () {
      late LocalStore store;
      late FinanceRepository repo;
      late RecoveryClient client;
      Directory? directory;
      late String queueId;
      setUp(() {
        if (indexed) {
          directory = Directory.systemTemp.createTempSync(
            'vesper-cancel-test-',
          );
          store = LocalStore.indexed(
            sqlite3.open('${directory!.path}/finance.sqlite'),
            key: List.generate(32, (i) => i),
            userId: 'actor',
          );
        } else {
          store = LocalStore(sqlite3.openInMemory());
        }
        client = RecoveryClient();
        repo = FinanceRepository(client, store, 'actor');
        repo.atomic(() {
          repo.entities['accounts'] = {
            for (final id in [cash, portfolio])
              id: {
                'id': id,
                'user_id': 'actor',
                'account_type_id': id == cash ? 'cashType' : 'investType',
                'currency': 'IDR',
                'balance': id == cash ? '100.00' : '0.00',
              },
          };
          repo.entities['account_types'] = {
            for (final entry in [
              ('cashType', 'CASH'),
              ('investType', 'INVESTMENT'),
            ])
              entry.$1: {
                'id': entry.$1,
                'user_id': 'actor',
                'category': entry.$2,
              },
          };
          repo.entities['instruments'] = {
            instrument: {'id': instrument, 'currency': 'IDR'},
          };
          repo.state['investment_history_coverage'] = {
            'schema': 1,
            'user_id': 'actor',
            'complete': true,
            'cursor': '0',
          };
        });
        repo.createInvestmentTrade(
          accountId: portfolio,
          cashAccountId: cash,
          instrumentId: instrument,
          type: 'BUY',
          quantity: '1',
          pricePerUnit: '10.005',
          at: DateTime.utc(2026, 10, 16),
        );
        queueId = repo.outbox.single['id'] as String;
        repo.atomic(() => repo.outbox.single['status'] = 'rejected');
      });
      tearDown(() {
        store.close();
        if (directory != null) {
          final target = directory!.absolute;
          if (target.parent.path != Directory.systemTemp.absolute.path ||
              !target.path.contains('vesper-cancel-test-')) {
            throw StateError('Unsafe temporary target');
          }
          target.deleteSync(recursive: true);
        }
      });
      test('pending review never rolls back money; lost response resumes by durable identity after restart', () async {
        final original = jsonEncode(repo.outbox.single['payload']);
        repo.requestInvestmentCancellation(queueId);
        expect(repo.row('accounts', cash)!['balance'], '89.99');
        client.loseResponse = true;
        await expectLater(repo.sync(), throwsA(isA<ApiFailure>()));
        repo = FinanceRepository(client, store, 'actor');
        client.loseResponse = false;
        await repo.sync();
        expect(client.requests, 1);
        expect(client.pushes, 0);
        expect(repo.outbox.single['recovery_receipt']['status'], 'PENDING');
        expect(jsonEncode(repo.outbox.single['payload']), original);
        expect(repo.row('accounts', cash)!['balance'], '89.99');
        expect(
          () => repo.retryInvestmentTrade(queueId),
          throwsA(isA<ApiFailure>()),
        );
      });
      test('approval installs authoritative decimal cash once and retains unrelated outbox across restart', () async {
        repo.atomic(
          () => repo.outbox.add({
            'id': 'unrelated',
            'entity_type': 'categories',
            'entity_id': 'category',
            'status': 'rejected',
          }),
        );
        repo.requestInvestmentCancellation(queueId);
        client.decision = 'CANCELLED';
        await repo.sync();
        repo = FinanceRepository(client, store, 'actor');
        expect(repo.outbox.single['id'], 'unrelated');
        expect(repo.row('accounts', cash)!['balance'], '123.45');
        expect(repo.rows('investment_transactions'), isEmpty);
        expect(repo.rows('transactions'), isEmpty);
        expect(repo.hasCompleteInvestmentHistory, isTrue);
        expect(
          (repo.state['investment_recovery_receipts'] as Map)
              .values
              .single['status'],
          'CANCELLED',
        );
        await repo.sync();
        expect(repo.row('accounts', cash)!['balance'], '123.45');
      });
      test('interrupted replay retains original rows and retries complete reconciliation after restart', () async {
        repo.requestInvestmentCancellation(queueId);
        client.decision = 'CANCELLED';
        client.failFinalPage = true;
        await expectLater(repo.sync(), throwsA(isA<ApiFailure>()));
        repo = FinanceRepository(client, store, 'actor');
        expect(repo.outbox.single['status'], 'cancellation_approved');
        expect(repo.row('accounts', cash)!['balance'], '89.99');
        expect(repo.rows('investment_transactions'), hasLength(1));
        client.failFinalPage = false;
        await repo.sync();
        expect(repo.outbox, isEmpty);
        expect(repo.row('accounts', cash)!['balance'], '123.45');
      });
      test(
        'wrong owner or fingerprint receipt fails closed and retains command',
        () async {
          repo.requestInvestmentCancellation(queueId);
          await repo.sync();
          client.decision = 'CANCELLED';
          for (final wrong in [
            {'user_id': 'other'},
            {'command_sha256': '0' * 64},
            {'trade_id': 'other'},
            {'linked_transaction_id': 'other'},
          ]) {
            client.wrongReceipt = wrong;
            await expectLater(repo.sync(), throwsA(isA<ApiFailure>()));
            expect(repo.outbox.single['status'], 'rejected');
            expect(repo.row('accounts', cash)!['balance'], '89.99');
          }
        },
      );
      test('missing authoritative account or nonempty trade never releases cancellation', () async {
        repo.requestInvestmentCancellation(queueId);
        client.decision = 'CANCELLED';
        client.omitCash = true;
        await expectLater(repo.sync(), throwsA(isA<ApiFailure>()));
        expect(repo.outbox, hasLength(1));
        client.omitCash = false;
        client.invalidTrade = true;
        await expectLater(repo.sync(), throwsA(isA<ApiFailure>()));
        expect(repo.row('accounts', cash)!['balance'], '89.99');
        expect(repo.rows('investment_transactions'), hasLength(1));
      });
      test('failed final commit retains decision and all optimistic rows on disk', () async {
        repo.requestInvestmentCancellation(queueId);
        client.decision = 'CANCELLED';
        client.beforeFinalCommit = () => store.database.execute(
          "CREATE TRIGGER fail_cancel BEFORE UPDATE ON ${indexed ? 'store_info' : 'state'} BEGIN SELECT RAISE(ABORT, 'disk'); END",
        );
        await expectLater(repo.sync(), throwsA(isA<SqliteException>()));
        repo = FinanceRepository(client, store, 'actor');
        expect(repo.outbox.single['status'], 'cancellation_approved');
        expect(repo.rows('investment_transactions'), hasLength(1));
        expect(repo.rows('transactions'), hasLength(1));
        expect(repo.row('accounts', cash)!['balance'], '89.99');
        store.database.execute('DROP TRIGGER fail_cancel');
        client.beforeFinalCommit = null;
        await repo.sync();
        expect(repo.outbox, isEmpty);
        expect(repo.row('accounts', cash)!['balance'], '123.45');
      });
      test('denied review permits only explicit unchanged retry and offline requests retain state', () async {
        repo.offline = true;
        final before = store.read();
        expect(
          () => repo.requestInvestmentCancellation(queueId),
          throwsA(isA<ApiFailure>()),
        );
        expect(store.read(), before);
        repo.offline = false;
        repo.requestInvestmentCancellation(queueId);
        client.decision = 'DENIED';
        await repo.sync();
        final payload = jsonEncode(repo.outbox.single['payload']);
        repo.retryInvestmentTrade(queueId);
        expect(repo.outbox.single['status'], 'pending');
        expect(repo.outbox.single['recovery_requested'], isNull);
        expect(jsonEncode(repo.outbox.single['payload']), payload);
        expect(repo.row('accounts', cash)!['balance'], '89.99');
      });
      test('definitive refusal or unsupported backend retains money and allows explicit original retry', () async {
        final payload = jsonEncode(repo.outbox.single['payload']);
        for (final status in [403, 404, 409, 422]) {
          repo.atomic(() => repo.outbox.single['status'] = 'rejected');
          repo.requestInvestmentCancellation(queueId);
          client.refuseRequest = true;
          client.refusalCode = status;
          await expectLater(repo.sync(), throwsA(isA<ApiFailure>()));
          repo = FinanceRepository(client, store, 'actor');
          expect(repo.outbox.single['recovery_requested'], isNull);
          expect(repo.row('accounts', cash)!['balance'], '89.99');
          repo.retryInvestmentTrade(queueId);
          expect(jsonEncode(repo.outbox.single['payload']), payload);
          expect(repo.outbox.single['status'], 'pending');
        }
      });
    });
  }
}
