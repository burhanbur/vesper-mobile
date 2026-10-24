import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/core/utils/budget_period.dart';
import 'package:vesper_mobile/core/utils/date_formatter.dart';
import 'package:vesper_mobile/features/reports/pages/budget_page.dart';

import '../fixtures/dashboard_insights.dart';

class _BudgetPeriodClient extends ApiClient {
  final String firstPeriod;
  final periods = <String>[];
  _BudgetPeriodClient(this.firstPeriod);
  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    bool authenticated = true,
    bool retry = true,
  }) async {
    if (path != '/budgets/budget/progress') {
      throw StateError('Unexpected request: $path');
    }
    final period = query!['period'] as String;
    periods.add(period);
    return {
      'period': period,
      'allowance': period.compareTo(firstPeriod) >= 0 ? '250000.00' : '0.00',
      'total_amount': '0.00',
    };
  }
}

void main() {
  for (final indexed in [false, true]) {
    testWidgets(
      'budget label, cached allowance and requested calendar month agree ($indexed)',
      (tester) async {
        tester.view.physicalSize = const Size(400, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final now = DateTime.now().toUtc();
        final month = DateTime.utc(now.year, now.month);
        final previousMonth = DateTime.utc(now.year, now.month - 1);
        final currentKey = formatPeriodKey(month, 'MONTHLY');
        final previousKey = formatPeriodKey(previousMonth, 'MONTHLY');
        final client = _BudgetPeriodClient(currentKey);
        final source = insightRepository(indexed: indexed, client: client);
        addTearDown(source.store.close);
        source.atomic(() {
          source.entities['categories']['food']['name'] = 'Vehicle';
          source.entities['budgets']['budget']['current_amount'] = '250000.00';
          source.entities['budgets']['budget']['anchor_date'] =
              '$currentKey-01';
          source.state['progress:budget:$currentKey'] = {
            'period': currentKey,
            'allowance': '250000.00',
            'total_amount': '0.00',
          };
          source.state['progress:budget:$previousKey'] = {
            'period': previousKey,
            'allowance': '0.00',
            'total_amount': '1109500.00',
          };
        });
        final state = AppState(repository: source)..currentUserId = 'user';
        addTearDown(state.dispose);
        await tester.pumpWidget(
          AppStateScope(
            state: state,
            child: const MaterialApp(home: BudgetPage()),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(DateFormatter.formatMonthYear(month)), findsOneWidget);
        expect(client.periods.last, currentKey);
        expect(find.text('Vehicle'), findsOneWidget);
        expect(find.textContaining('250.000'), findsWidgets);

        await tester.tap(find.byIcon(Icons.chevron_left_rounded));
        await tester.pumpAndSettle();
        expect(
          find.text(DateFormatter.formatMonthYear(previousMonth)),
          findsOneWidget,
        );
        expect(client.periods.last, previousKey);
        expect(find.text('Vehicle'), findsNothing);
        await tester.tap(find.byIcon(Icons.chevron_right_rounded));
        await tester.pumpAndSettle();
        expect(client.periods.last, currentKey);
        expect(find.text('Vehicle'), findsOneWidget);
        // Exercise forward navigation too, including crossing into another year.
        for (var offset = 1; offset <= 3; offset++) {
          final next = DateTime.utc(month.year, month.month + offset);
          await tester.tap(find.byIcon(Icons.chevron_right_rounded));
          await tester.pumpAndSettle();
          expect(
            find.text(DateFormatter.formatMonthYear(next)),
            findsOneWidget,
          );
          expect(client.periods.last, formatPeriodKey(next, 'MONTHLY'));
          expect(find.text('Vehicle'), findsOneWidget);
        }
        expect(source.outbox, isEmpty);
        expect(source.rows('budgets'), hasLength(1));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
