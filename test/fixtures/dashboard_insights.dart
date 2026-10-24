import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/database/local_store.dart';
import 'package:vesper_mobile/features/sync/data/finance_repository.dart';

const insightBillId = '11111111-1111-4111-8111-111111111111';

FinanceRepository insightRepository({bool indexed = false, ApiClient? client}) {
  final directory = indexed
      ? Directory.systemTemp.createTempSync('vesper-insights-test-')
      : null;
  if (directory != null) {
    addTearDown(() {
      if (directory.parent.absolute.path !=
              Directory.systemTemp.absolute.path ||
          !directory.path
              .split(Platform.pathSeparator)
              .last
              .startsWith('vesper-insights-test-')) {
        throw StateError('Unexpected test directory: ${directory.path}');
      }
      directory.deleteSync(recursive: true);
    });
  }
  final store = indexed
      ? LocalStore.indexed(
          sqlite3.open('${directory!.path}/insights.sqlite'),
          key: List.generate(32, (i) => i),
          userId: 'user',
        )
      : LocalStore(sqlite3.openInMemory());
  final source = FinanceRepository(client ?? ApiClient(), store, 'user');
  source.atomic(() {
    source.entities['accounts'] = <String, dynamic>{
      'cash': {
        'id': 'cash',
        'user_id': 'user',
        'name': 'BCA',
        'currency': 'IDR',
        'balance': '5000000.00',
        'account_type_id': 'cash-type',
      },
      'foreign': {
        'id': 'foreign',
        'user_id': 'other',
        'currency': 'IDR',
        'name': 'Shared',
        'balance': '0.00',
      },
      'usd': {
        'id': 'usd',
        'user_id': 'user',
        'currency': 'USD',
        'name': 'USD',
        'balance': '0.00',
      },
    };
    source.entities['account_types'] = <String, dynamic>{
      'cash-type': {
        'id': 'cash-type',
        'user_id': 'user',
        'category': 'CASH',
        'name': 'Bank',
      },
    };
    source.entities['categories'] = <String, dynamic>{
      'food': {
        'id': 'food',
        'user_id': 'user',
        'name': 'Makan & minum',
        'type': 'EXPENSE',
      },
    };
    source.entities['transactions'] = <String, dynamic>{};
    source.entities['budgets'] = <String, dynamic>{
      'budget': {
        'id': 'budget',
        'category_id': 'food',
        'period_type': 'MONTHLY',
        'anchor_date': '2026-01-01',
        'current_amount': '1000000.00',
      },
    };
    source.entities['bill_schedules'] = <String, dynamic>{};
    source.state['transaction_snapshot_coverage'] = {
      'schema': 1,
      'user_id': 'user',
      'complete': true,
    };
    for (final name in [
      'investment_history_coverage',
      'bill_history_coverage',
      'obligation_history_coverage',
    ]) {
      source.state[name] = {
        'schema': 1,
        'user_id': 'user',
        'complete': true,
        'cursor': source.state['cursor'],
      };
    }
  });
  return source;
}

Map<String, dynamic> insightExpense(
  String id,
  String at,
  String amount, {
  String type = 'EXPENSE',
  String account = 'cash',
}) => {
  'id': id,
  'type': type,
  'account_id': account,
  'category_id': 'food',
  'amount': amount,
  'transacted_at': at,
};

Map<String, dynamic> insightBill(String date, {String id = insightBillId}) => {
  'id': id,
  'user_id': 'user',
  'title': 'Internet rumah',
  'transaction_type': 'EXPENSE',
  'amount_type': 'FIXED',
  'amount': '350000.50',
  'account_id': 'cash',
  'category_id': 'food',
  'frequency': 'ONCE',
  'anchor_date': date,
  'utc_offset_minutes': 420,
  'installments': [],
  'active': true,
};
