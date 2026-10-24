import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/database/transaction_query.dart';
import 'package:vesper_mobile/features/dashboard/pages/dashboard_page.dart';
import 'package:vesper_mobile/features/sync/data/finance_repository.dart';

import '../fixtures/dashboard_insights.dart';

class _BudgetRefreshClient extends ApiClient {
  late FinanceRepository source;
  String? requestedPeriod;

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
    if (path == '/sync/pull') {
      return {'changes': [], 'has_more': false, 'next_version': '1'};
    }
    if (path == '/budgets/budget/progress') {
      requestedPeriod = query!['period'] as String;
      return {
        'period': requestedPeriod,
        'allowance': '1000000.00',
        'total_amount': '850000.00',
      };
    }
    return source.rows(path.substring(1).replaceAll('-', '_'));
  }
}

void main() {
  for (final scenario in [(false, false), (true, false), (true, true)]) {
    final (indexed, rejectAlias) = scenario;
    testWidgets(
      'dashboard can query history after budget refresh (indexed=$indexed, reject=$rejectAlias)',
      (tester) async {
        final client = _BudgetRefreshClient();
        final source = insightRepository(indexed: indexed, client: client);
        client.source = source;
        source.atomic(() {
          source.entities['transactions'] = <String, dynamic>{
            'expense': insightExpense(
              'expense',
              DateTime.now().toUtc().toIso8601String(),
              '850000.00',
            ),
          };
        });
        final state = AppState(repository: source)..currentUserId = 'user';
        addTearDown(source.store.close);
        addTearDown(state.dispose);
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
        await tester.pumpAndSettle();
        final transactions = jsonEncode(source.rows('transactions'));
        if (rejectAlias) {
          source.store.database.execute('''
            CREATE TEMP TRIGGER fail_budget_alias BEFORE INSERT ON metadata
            WHEN NEW.key LIKE 'progress:budget:%'
            BEGIN SELECT RAISE(ABORT, 'Simulated cache persistence failure'); END
          ''');
        }
        await state.refresh();
        await tester.pumpAndSettle();
        expect(state.dataError, rejectAlias ? isNotNull : isNull);
        expect(tester.takeException(), isNull);
        expect(
          source.transactionPage(const TransactionQuery()).rows.single['id'],
          'expense',
        );
        final key = rejectAlias
            ? 'progress:budget'
            : 'progress:budget:${client.requestedPeriod}';
        final dynamic saved;
        if (indexed) {
          saved = jsonDecode(
            source.store.database.select(
                  'SELECT payload FROM metadata WHERE key=?',
                  [key],
                ).single['payload']
                as String,
          );
        } else {
          saved = source.store.read()[key];
        }
        expect(saved['total_amount'], '850000.00');
        expect(jsonEncode(source.rows('transactions')), transactions);
        expect(source.outbox, isEmpty);
      },
    );
  }
}
