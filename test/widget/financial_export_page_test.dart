import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/core/utils/app_time_zone.dart';
import 'package:vesper_mobile/database/local_store.dart';
import 'package:vesper_mobile/features/reports/pages/financial_export_page.dart';
import 'package:vesper_mobile/features/sync/data/finance_repository.dart';

import '../unit/financial_export_test.dart' show seedExport;

void main() {
  testWidgets(
    'export uses selected zone and clears prepared CSV when zone changes',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 2200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = LocalStore(sqlite3.openInMemory());
      final repo = FinanceRepository(ApiClient(), store, 'owner')
        ..offline = true;
      seedExport(repo);
      final state = AppState(repository: repo)..currentUserId = 'owner';
      state.toggleOfflineMode();
      state.setTimeZone(AppTimeZone.wit);
      addTearDown(() {
        state.dispose();
        store.close();
      });
      final today = AppTimeZone.wit.calendarDate(DateTime.now());
      final instant = AppTimeZone.wit.fromCalendar(
        DateTime.utc(today.year, today.month),
      );
      repo.atomic(() {
        repo.entities['transactions'] = <String, dynamic>{
          'boundary': <String, dynamic>{
            'id': 'boundary',
            'account_id': 'account',
            'type': 'EXPENSE',
            'amount': '100.00',
            'category_id': 'expense',
            'transacted_at': instant.toIso8601String(),
            'version': '1',
          },
        };
      });
      await tester.pumpWidget(
        AppStateScope(
          state: state,
          child: const MaterialApp(home: FinancialExportPage()),
        ),
      );
      // Picker results are device-local DateTimes, while the default range is
      // calendar-only. Selecting the opening day must still allow a same-day
      // export, including when the OS zone differs from the selected WIT zone.
      await tester.tap(find.textContaining('Sampai '));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1').first);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Siapkan CSV'));
      await tester.pumpAndSettle();
      expect(find.textContaining('1 baris'), findsOneWidget);
      state.setTimeZone(AppTimeZone.wib);
      await tester.pumpAndSettle();
      expect(find.text('Salin CSV'), findsNothing);
      await tester.tap(find.text('Siapkan CSV'));
      await tester.pumpAndSettle();
      expect(find.textContaining('0 baris'), findsOneWidget);
      expect(repo.outbox, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'export/copy, invalid input, confirmation cancel/save and session isolation',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 2200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = LocalStore(sqlite3.openInMemory());
      final repo = FinanceRepository(ApiClient(), store, 'owner')
        ..offline = true;
      seedExport(repo);
      final now = DateTime.now();
      repo.atomic(() {
        repo.entities['transactions'] = <String, dynamic>{
          'existing': <String, dynamic>{
            'id': 'existing',
            'account_id': 'account',
            'type': 'INCOME',
            'amount': '1000.00',
            'transacted_at': DateTime(
              now.year,
              now.month,
              now.day,
              12,
            ).toUtc().toIso8601String(),
            'category_id': 'income',
            'version': '1',
            'description': 'Catatan awal',
          },
        };
      });
      final state = AppState(repository: repo)..currentUserId = 'owner';
      state.toggleOfflineMode();
      addTearDown(() {
        state.dispose();
        store.close();
      });
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        AppStateScope(
          state: state,
          child: const MaterialApp(home: FinancialExportPage()),
        ),
      );
      await tester.tap(find.text('Siapkan CSV'));
      await tester.pumpAndSettle();
      expect(find.textContaining('1 baris'), findsOneWidget);
      await tester.ensureVisible(find.text('Salin CSV'));
      await tester.tap(find.text('Salin CSV'));
      await tester.pumpAndSettle();
      expect(clipboard, contains('Catatan awal'));
      expect(clipboard, startsWith('\uFEFF'));

      final cash = find.byWidgetPredicate(
        (w) =>
            w is DropdownButtonFormField<String> &&
            w.decoration.labelText == 'Akun rekonsiliasi',
      );
      await tester.ensureVisible(cash);
      await tester.tap(cash);
      await tester.pumpAndSettle();
      expect(find.textContaining('foreign ('), findsNothing);
      expect(find.textContaining('usd ('), findsNothing);
      await tester.tap(find.text('=SUM(1,2) (1000.00 IDR)').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(TextField).first);
      await tester.enterText(find.byType(TextField).first, '1200.01');
      await tester.enterText(find.byType(TextField).last, 'Statement ref 42');
      await tester.ensureVisible(find.text('Bandingkan saldo'));
      await tester.tap(find.text('Bandingkan saldo'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Rupiah bulat dalam batas presisi aman'),
        findsOneWidget,
      );
      expect(repo.outbox, isEmpty);
      await tester.enterText(find.byType(TextField).first, '1200');
      await tester.tap(find.text('Bandingkan saldo'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Tinjau penyesuaian'));
      await tester.tap(find.text('Tinjau penyesuaian'));
      await tester.pumpAndSettle();
      expect(find.textContaining('memengaruhi laporan'), findsOneWidget);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(repo.outbox, isEmpty);
      await tester.tap(find.text('Tinjau penyesuaian'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Catat penyesuaian'));
      await tester.pumpAndSettle();
      expect(repo.row('accounts', 'account')!['balance'], '1200.00');
      expect(repo.rows('transactions'), hasLength(2));
      expect(
        repo.rows('transactions').last['description'],
        contains('Statement ref 42'),
      );
      state.currentUserId = 'other';
      await tester.pumpWidget(
        AppStateScope(
          state: state,
          child: const MaterialApp(
            home: FinancialExportPage(key: ValueKey('other')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Masuk dan tunggu data lokal tersedia.'),
        findsOneWidget,
      );
      expect(find.textContaining('Statement ref 42'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
