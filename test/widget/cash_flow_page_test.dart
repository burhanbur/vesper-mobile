import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/database/local_store.dart';
import 'package:vesper_mobile/features/cash_flow/pages/cash_flow_page.dart';
import 'package:vesper_mobile/features/goals/data/goals_repository.dart';
import 'package:vesper_mobile/features/sync/data/finance_repository.dart';

import '../unit/cash_flow_test.dart' show seedForecast, forecastBill;

void main() {
  testWidgets(
    'forecast shows shortfall, masks projected money and saves scenario without changing balances',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 2600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = LocalStore(sqlite3.openInMemory());
      final source = FinanceRepository(ApiClient(), store, 'owner')
        ..offline = true;
      seedForecast(source);
      final today = goalDay(
        DateTime.now().toUtc().add(const Duration(minutes: 420)),
      );
      forecastBill(source, date: today, amount: '1200.00');
      final before = jsonEncode(source.entities);
      final state = AppState(repository: source)..currentUserId = 'owner';
      state.toggleOfflineMode();
      addTearDown(() {
        state.dispose();
        store.close();
      });
      await tester.pumpWidget(
        AppStateScope(
          state: state,
          child: const MaterialApp(home: CashFlowPage()),
        ),
      );
      expect(find.text('Saldo aktual gabungan: 1000.00 IDR'), findsOneWidget);
      expect(find.text('Proyeksi penutup: -200.00 IDR'), findsOneWidget);
      expect(
        find.textContaining('Potensi kekurangan gabungan pertama'),
        findsOneWidget,
      );
      state.toggleHideBalance();
      await tester.pumpAndSettle();
      expect(find.textContaining('-200.00'), findsNothing);
      expect(find.textContaining('1000.00 IDR'), findsNothing);
      state.toggleHideBalance();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ubah asumsi proyeksi'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Cash'));
      await tester.tap(find.text('Simpan asumsi'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Periksa periode'), findsOneWidget);
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Cash'));
      final horizon = find.byWidgetPredicate(
        (w) =>
            w is DropdownButtonFormField<int> &&
            w.decoration.labelText == 'Horizon termasuk hari ini',
      );
      await tester.tap(horizon);
      await tester.pumpAndSettle();
      await tester.tap(find.text('7 hari').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simpan asumsi'));
      await tester.pumpAndSettle();
      expect(source.state['cash_flow_assumptions']['days'], 7);
      expect(jsonEncode(source.entities), before);
      expect(source.outbox, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'phone layout explains incomplete snapshots and rejects stale-session scenario saves',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = LocalStore(sqlite3.openInMemory());
      final source = FinanceRepository(ApiClient(), store, 'owner')
        ..offline = true;
      seedForecast(source);
      source.atomic(() {
        source.state.remove('bill_history_coverage');
      });
      final state = AppState(repository: source)..currentUserId = 'owner';
      state.toggleOfflineMode();
      addTearDown(() {
        state.dispose();
        store.close();
      });
      await tester.pumpWidget(
        AppStateScope(
          state: state,
          child: const MaterialApp(home: CashFlowPage()),
        ),
      );
      expect(find.textContaining('Selesaikan sinkronisasi'), findsOneWidget);
      expect(find.textContaining('Proyeksi penutup:'), findsNothing);
      await tester.tap(find.text('Ubah asumsi proyeksi'));
      await tester.pumpAndSettle();
      state.currentUserId = 'other';
      state.toggleHideBalance();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simpan asumsi'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Sesi telah berubah'), findsOneWidget);
      expect(source.state['cash_flow_assumptions'], isNull);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(
        find.text('Masuk untuk membuka proyeksi arus kas.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
