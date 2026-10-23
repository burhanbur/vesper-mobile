import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/core/utils/app_time_zone.dart';
import 'package:vesper_mobile/core/utils/date_formatter.dart';
import 'package:vesper_mobile/features/dashboard/widgets/dashboard_insights_panel.dart';
import 'package:vesper_mobile/features/settings/pages/settings_page.dart';
import 'package:vesper_mobile/features/settings/widgets/time_zone_sheet.dart';
import 'package:vesper_mobile/features/transactions/pages/transactions_page.dart';

import '../fixtures/dashboard_insights.dart';
import 'dashboard_insights_test.dart' show sampleInsights;

void main() {
  testWidgets('settings saves chosen zone and sheet fits 320px at 2x text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final source = insightRepository();
    final state = AppState(repository: source)..currentUserId = 'user';
    state.toggleOfflineMode();
    addTearDown(source.store.close);
    addTearDown(state.dispose);
    await tester.pumpWidget(
      AppStateScope(
        state: state,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const SettingsPage(),
        ),
      ),
    );
    final setting = find.byKey(const ValueKey('settings_time_zone'));
    await tester.ensureVisible(setting);
    await tester.tap(setting);
    await tester.pumpAndSettle();
    expect(find.text('Ikuti perangkat'), findsWidgets);
    final choice = find.byKey(const ValueKey('time_zone_wit'));
    await tester.ensureVisible(choice);
    await tester.tap(choice);
    await tester.pumpAndSettle();
    expect(state.timeZone, AppTimeZone.wit);
    expect(source.outbox, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stale sheet cannot save into a different session', (
    tester,
  ) async {
    final source = insightRepository();
    final state = AppState(repository: source)..currentUserId = 'user';
    addTearDown(source.store.close);
    addTearDown(state.dispose);
    await tester.pumpWidget(
      AppStateScope(
        state: state,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => TimeZoneSheet.show(context),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    state.currentUserId = 'other';
    await tester.tap(find.byKey(const ValueKey('time_zone_wib')));
    await tester.pumpAndSettle();
    expect(source.state['display_time_zone'], isNull);
    expect(find.textContaining('Sesi telah berubah'), findsOneWidget);
  });

  testWidgets(
    'transaction day grouping and time update together when zone changes',
    (tester) async {
      final source = insightRepository();
      final state = AppState(repository: source)..currentUserId = 'user';
      state.toggleOfflineMode();
      state.setTimeZone(AppTimeZone.wib);
      addTearDown(source.store.close);
      addTearDown(state.dispose);
      final now = AppTimeZone.wib.at(DateTime.now());
      final instant = DateTime.utc(now.year, now.month, 1, 16, 30);
      source.atomic(() {
        source.entities['transactions'] = <String, dynamic>{
          'boundary': insightExpense(
            'boundary',
            instant.toIso8601String(),
            '100.00',
          ),
        };
      });
      await tester.pumpWidget(
        AppStateScope(
          state: state,
          child: const MaterialApp(home: TransactionsPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          DateFormatter.formatShort(DateTime.utc(now.year, now.month, 1)),
        ),
        findsOneWidget,
      );
      expect(find.text('23:30'), findsOneWidget);
      state.setTimeZone(AppTimeZone.wit);
      await tester.pumpAndSettle();
      expect(
        find.text(
          DateFormatter.formatShort(DateTime.utc(now.year, now.month, 2)),
        ),
        findsOneWidget,
      );
      expect(find.text('01:30'), findsOneWidget);
      expect(find.text('23:30'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('dashboard comparison label has no UTC suffix', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DashboardInsightsPanel(
              insights: sampleInsights(),
              hidden: false,
              onBills: () {},
              onSpending: () {},
              onBudgets: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('1–23 Okt vs 1–23 Sep'), findsOneWidget);
    expect(find.textContaining('UTC'), findsNothing);
  });
}
