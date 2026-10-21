import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/database/local_store.dart';
import 'package:vesper_mobile/features/bills/data/bills_repository.dart';
import 'package:vesper_mobile/features/sync/data/finance_repository.dart';

const billId = '11111111-1111-4111-8111-111111111111';
const cashId = '22222222-2222-4222-8222-222222222222';
const categoryId = '33333333-3333-4333-8333-333333333333';
Map<String, dynamic> billFixture() => {
  'id': billId,
  'user_id': 'owner',
  'title': 'Rent',
  'transaction_type': 'EXPENSE',
  'amount_type': 'FIXED',
  'amount': '100.00',
  'account_id': cashId,
  'category_id': categoryId,
  'obligation_id': null,
  'frequency': 'MONTHLY',
  'anchor_date': '2026-01-31',
  'end_date': null,
  'utc_offset_minutes': 420,
  'installments': [],
  'reminder_enabled': true,
  'reminder_days': 3,
  'active': true,
  'version': '1',
};
void seedBills(FinanceRepository s) {
  s.atomic(() {
    s.entities['account_types'] = <String, dynamic>{
      'cash': <String, dynamic>{
        'id': 'cash',
        'user_id': 'owner',
        'category': 'CASH',
      },
    };
    s.entities['accounts'] = <String, dynamic>{
      cashId: <String, dynamic>{
        'id': cashId,
        'user_id': 'owner',
        'name': 'Cash',
        'account_type_id': 'cash',
        'currency': 'IDR',
        'balance': '1000.00',
        'version': '1',
      },
    };
    s.entities['categories'] = <String, dynamic>{
      categoryId: <String, dynamic>{
        'id': categoryId,
        'user_id': 'owner',
        'name': 'Rent',
        'type': 'EXPENSE',
        'version': '1',
      },
    };
    s.entities['bill_schedules'] = <String, dynamic>{billId: billFixture()};
    for (final name in [
      'investment_history_coverage',
      'obligation_history_coverage',
      'bill_history_coverage',
    ]) {
      s.state[name] = {
        'schema': 1,
        'user_id': 'owner',
        'complete': true,
        'cursor': s.state['cursor'],
      };
    }
  });
}

class BillTestClient extends ApiClient {
  bool lose = false, interrupt = false;
  String status = 'applied';
  Map<String, dynamic>? server;
  List<Map<String, dynamic>> changes = [];
  final deliveries = <String>[];
  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    bool authenticated = true,
    bool retry = true,
  }) async {
    if (path == '/devices') return {};
    if (path == '/sync/push') {
      final item = (body!['items'] as List).single as Map;
      deliveries.add(jsonEncode(item));
      if (lose) {
        lose = false;
        throw const ApiFailure('Lost response');
      }
      return {
        'results': [
          {
            'index': 0,
            'entity_id': item['entity_id'],
            'status': status,
            'server_data': server,
          },
        ],
      };
    }
    if (path == '/sync/pull') {
      final first = query!['since_version'] == '0';
      if (!first && interrupt) throw const ApiFailure('Interrupted pull');
      return {
        'changes': first ? changes.take(1).toList() : changes.skip(1).toList(),
        'next_version': first ? '1' : '2',
        'has_more': first,
      };
    }
    throw const ApiFailure('Test unsupported');
  }
}

void billProjection(
  FinanceRepository s,
  BillTestClient c, {
  String? balance,
  Map<String, dynamic>? occurrence,
  bool absentLedger = false,
}) {
  final item = s.outbox.single, p = item['payload'] as Map;
  final keys = (item['required_snapshots'] as List).cast<String>();
  c.changes = [
    for (final key in keys)
      () {
        final split = key.indexOf(':'),
            type = key.substring(0, split),
            id = key.substring(split + 1);
        Map<String, dynamic>? row = s.row(type, id);
        if (type == 'accounts' && balance != null) {
          row = {...row!, 'balance': balance};
        }
        if (type == 'bill_occurrences' && occurrence != null) row = occurrence;
        if (type == 'transactions' && absentLedger && id == p['ledger_id']) {
          row = null;
        }
        return <String, dynamic>{
          'entity_type': type,
          'entity_id': id,
          'operation': row == null ? 'DELETE' : 'UPDATE',
          'payload': row == null ? null : {...row, 'version': '1'},
        };
      }(),
  ];
}

void main() {
  test('calendar anchor clamps without drift, leap years, weekly/end bounds and fixed timezone', () {
    final b = billFixture();
    expect(billDue(b, '2026-02-28'), '100.00');
    expect(billDue(b, '2026-03-31'), '100.00');
    expect(billDue(b, '2026-03-28'), isNull);
    b['frequency'] = 'YEARLY';
    b['anchor_date'] = '2024-02-29';
    expect(billDue(b, '2025-02-28'), '100.00');
    expect(billDue(b, '2028-02-29'), '100.00');
    b['frequency'] = 'WEEKLY';
    b['anchor_date'] = '2026-01-01';
    b['end_date'] = '2026-01-08';
    expect(billDue(b, '2026-01-08'), '100.00');
    expect(billDue(b, '2026-01-15'), isNull);
    expect(
      billToday(b, DateTime.utc(2026, 1, 1, 18)),
      DateTime.utc(2026, 1, 2),
    );
  });
  for (final indexed in [false, true]) {
    group(indexed ? 'indexed bills' : 'snapshot bills', () {
      late LocalStore store;
      late FinanceRepository s;
      late BillsRepository repo;
      late BillTestClient client;
      Directory? temporary;
      setUp(() {
        if (indexed) {
          temporary = Directory.systemTemp.createTempSync('vesper-bills-test-');
        }
        store = indexed
            ? LocalStore.indexed(
                sqlite3.open('${temporary!.path}/finance.sqlite'),
                key: List.generate(32, (i) => i),
                userId: 'owner',
              )
            : LocalStore(sqlite3.openInMemory());
        client = BillTestClient();
        s = FinanceRepository(client, store, 'owner')..offline = true;
        seedBills(s);
        repo = BillsRepository(s);
      });
      tearDown(() {
        store.close();
        if (temporary != null) {
          final d = temporary!.absolute;
          if (d.parent.path != Directory.systemTemp.absolute.path ||
              !d.path.contains('vesper-bills-test-')) {
            throw StateError('Unsafe cleanup');
          }
          d.deleteSync(recursive: true);
          temporary = null;
        }
      });
      BillDueItem due() => repo
          .occurrences(now: DateTime.utc(2026, 2, 28))
          .firstWhere((o) => o.date == '2026-02-28');
      test('reminders never mutate cash, are configurable, read once and suppress paid/skipped', () {
        final before = jsonEncode(s.state);
        final reminders = repo.reminders(now: DateTime.utc(2026, 2, 28));
        expect(reminders, hasLength(1));
        expect(jsonEncode(s.state), before);
        expect(s.outbox, isEmpty);
        s.atomic(() {
          (s.entities['bill_schedules'] as Map)[billId] = {
            ...billFixture(),
            'reminder_enabled': false,
          };
        });
        expect(repo.reminders(now: DateTime.utc(2026, 2, 28)), isEmpty);
      });
      test('fixed payment is atomic, rejects duplicate and locks account until full reconciliation', () async {
        final o = due();
        repo.command(o, 'PAY', amount: '100');
        expect(s.row('accounts', cashId)!['balance'], '900.00');
        expect(s.rows('transactions').single['amount'], '100.00');
        expect(
          () => repo.command(o, 'PAY', amount: '100'),
          throwsA(isA<ApiFailure>()),
        );
        expect(
          () => s.mutate('accounts', 'UPDATE', {'name': 'edit'}, id: cashId),
          throwsA(isA<ApiFailure>()),
        );
        billProjection(s, client);
        client.interrupt = true;
        s.offline = false;
        await expectLater(s.sync(), throwsA(isA<ApiFailure>()));
        expect(s.outbox.single['status'], 'acknowledged');
        expect(s.row('accounts', cashId)!['balance'], '900.00');
        client.interrupt = false;
        await s.sync();
        expect(s.outbox, isEmpty);
        expect(s.row('accounts', cashId)!['balance'], '900.00');
      });
      test('lost acknowledgement reuses command/ledger identity after durable restart', () async {
        repo.command(due(), 'PAY', amount: '100');
        billProjection(s, client);
        client.lose = true;
        s.offline = false;
        await expectLater(s.sync(), throwsA(isA<ApiFailure>()));
        final restored = FinanceRepository(client, store, 'owner');
        await restored.sync();
        expect(client.deliveries, hasLength(2));
        expect(client.deliveries[0], client.deliveries[1]);
        expect(restored.outbox, isEmpty);
        expect(restored.row('accounts', cashId)!['balance'], '900.00');
      });
      test('cross-device already-paid conflict adopts authoritative state and removes optimistic duplicate', () async {
        s.atomic(() {
          (s.entities['accounts'] as Map)[cashId] = {
            ...s.row('accounts', cashId)!,
            'balance': '900.00',
          };
        });
        final o = due();
        repo.command(o, 'PAY', amount: '100');
        expect(s.row('accounts', cashId)!['balance'], '800.00');
        final server = <String, dynamic>{
          ...s.row('bill_occurrences', o.id)!,
          'transaction_id': 'external-payment',
          'version': '1',
        };
        client.status = 'conflict';
        client.server = server;
        billProjection(
          s,
          client,
          balance: '900.00',
          occurrence: server,
          absentLedger: true,
        );
        s.offline = false;
        await s.sync();
        expect(s.outbox.single['status'], 'conflict');
        s.retryBillCommand(s.outbox.single['id'] as String, useServer: true);
        await s.sync();
        expect(s.outbox, isEmpty);
        expect(s.row('accounts', cashId)!['balance'], '900.00');
        expect(s.rows('transactions'), isEmpty);
      });
      test(
        'skip and reopen create no financial rows and require explicit reasons',
        () {
          expect(() => repo.command(due(), 'SKIP'), throwsA(isA<ApiFailure>()));
          repo.command(due(), 'SKIP', note: 'Not due this month');
          expect(s.row('accounts', cashId)!['balance'], '1000.00');
          expect(s.rows('transactions'), isEmpty);
          expect(s.rows('bill_occurrences').single['status'], 'SKIPPED');
        },
      );
      test(
        'links existing transaction once; changed evidence requires review',
        () {
          s.atomic(() {
            s.entities['transactions'] = <String, dynamic>{
              'paid': <String, dynamic>{
                'id': 'paid',
                'account_id': cashId,
                'category_id': categoryId,
                'type': 'EXPENSE',
                'amount': '100.00',
                'transacted_at': '2026-02-28T00:00:00Z',
                'version': '1',
              },
            };
          });
          repo.command(due(), 'LINK_TRANSACTION', recordId: 'paid');
          expect(s.rows('transactions'), hasLength(1));
          expect(s.row('accounts', cashId)!['balance'], '1000.00');
          s.atomic(() {
            (s.entities['transactions'] as Map)['paid'] = {
              ...s.row('transactions', 'paid')!,
              'deleted_at': '2026-03-01T00:00:00Z',
            };
          });
          expect(
            repo.status(s.rows('bill_occurrences').single, billFixture()),
            'NEEDS_REVIEW',
          );
        },
      );
      test(
        'estimated actual, fractional input and invalid ownership guard cash',
        () {
          expect(
            () => repo.command(due(), 'PAY', amount: '99'),
            throwsA(isA<ApiFailure>()),
          );
          expect(
            () => repo.command(due(), 'PAY', amount: '100.01'),
            throwsA(isA<ApiFailure>()),
          );
          s.atomic(() {
            (s.entities['bill_schedules'] as Map)[billId] = {
              ...billFixture(),
              'amount_type': 'ESTIMATED',
            };
          });
          repo.command(due(), 'PAY', amount: '120');
          expect(s.row('accounts', cashId)!['balance'], '880.00');
        },
      );
      test('SQLite failure rolls back occurrence, outbox and cash together', () {
        final before = jsonEncode(s.state),
            table = indexed ? 'entity_records' : 'state';
        store.database.execute(
          "CREATE TRIGGER fail_bill BEFORE INSERT ON $table BEGIN SELECT RAISE(ABORT, 'fail'); END",
        );
        store.database.execute(
          "CREATE TRIGGER fail_bill_update BEFORE UPDATE ON $table BEGIN SELECT RAISE(ABORT, 'fail'); END",
        );
        expect(
          () => repo.command(due(), 'PAY', amount: '100'),
          throwsA(anything),
        );
        expect(jsonEncode(s.state), before);
        expect(jsonEncode(store.read()), before);
      });
    });
  }
}
