import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/database/local_store.dart';
import 'package:vesper_mobile/features/financial_health/pages/financial_health_page.dart';
import 'package:vesper_mobile/features/sync/data/finance_repository.dart';

import '../unit/financial_health_test.dart' show seedHealth, healthTransaction;

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'compact health layout keeps accounts/formulas in details at text scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final store = LocalStore(sqlite3.openInMemory());
        final source = FinanceRepository(ApiClient(), store, 'owner')
          ..offline = true;
        seedHealth(source);
        source.atomic(() {
          for (var i = 0; i < 24; i++) {
            source.entities['accounts']['extra-$i'] = {
              ...source.row('accounts', 'cash')!,
              'id': 'extra-$i',
              'name': 'Akun tambahan $i',
            };
          }
        });
        final now = DateTime.now().toUtc();
        final date = DateTime.utc(
          now.year,
          now.month - 1,
          15,
        ).toIso8601String();
        healthTransaction(source, 'salary', 'INCOME', '1000', date: date);
        healthTransaction(source, 'food', 'EXPENSE', '200', date: date);
        final state = AppState(repository: source)..currentUserId = 'owner';
        state.toggleOfflineMode();
        addTearDown(state.dispose);
        addTearDown(store.close);
        await tester.pumpWidget(
          AppStateScope(
            state: state,
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const FinancialHealthPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('UTC'), findsNothing);
        expect(find.text('Akun tambahan 0'), findsNothing);
        expect(find.textContaining('Pemasukan − pengeluaran'), findsNothing);
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('health_saving')),
          250,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('health_saving')));
        await tester.pumpAndSettle();
        expect(find.textContaining('Rp 1.000'), findsOneWidget);
        state.toggleHideBalance();
        await tester.pumpAndSettle();
        expect(find.textContaining('Rp 1.000'), findsNothing);
        expect(find.text('80,00%'), findsNothing);
        await tester.tap(find.byTooltip('Tutup'));
        await tester.pumpAndSettle();
        for (final id in ['debt', 'liquidity', 'emergency']) {
          await tester.scrollUntilVisible(
            find.byKey(ValueKey('health_$id')),
            250,
          );
          expect(tester.takeException(), isNull);
        }
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('health_basis')),
          250,
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const ValueKey('health_basis')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('health_basis')));
        await tester.pumpAndSettle();
        expect(find.text('Akun tambahan 0'), findsNothing);
        await tester.ensureVisible(find.text('Akun terpilih (25)'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Akun terpilih (25)'));
        await tester.pumpAndSettle();
        expect(find.text('Akun tambahan 0'), findsOneWidget);
        expect(find.textContaining('UTC'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'shows formulas, masks derived money and persists configurable period without ledger mutations',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 2600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = LocalStore(sqlite3.openInMemory());
      final source = FinanceRepository(ApiClient(), store, 'owner')
        ..offline = true;
      seedHealth(source);
      final now = DateTime.now().toUtc();
      final date = DateTime.utc(now.year, now.month - 1, 15).toIso8601String();
      healthTransaction(source, 'salary', 'INCOME', '1000', date: date);
      healthTransaction(source, 'food', 'EXPENSE', '200', date: date);
      final state = AppState(repository: source)..currentUserId = 'owner';
      state.toggleOfflineMode();
      addTearDown(() {
        state.dispose();
        store.close();
      });
      await tester.pumpWidget(
        AppStateScope(
          state: state,
          child: const MaterialApp(home: FinancialHealthPage()),
        ),
      );
      expect(find.text('80,00%'), findsOneWidget);
      expect(find.text('15,00 bulan'), findsOneWidget);
      expect(find.textContaining('Pokok + bunga'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('health_debt')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Pokok + bunga'), findsOneWidget);
      await tester.tap(find.byTooltip('Tutup'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('health_notes')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Bukti bulanan terbatas'), findsOneWidget);
      await tester.tap(find.byTooltip('Tutup'));
      await tester.pumpAndSettle();
      state.toggleHideBalance();
      await tester.pumpAndSettle();
      expect(find.text('80,00%'), findsNothing);
      expect(find.textContaining('1000.00 IDR'), findsNothing);
      expect(find.text('••••••'), findsNWidgets(3));
      state.toggleHideBalance();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ubah asumsi'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('6 bulan').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Cash'));
      await tester.tap(find.text('Simpan asumsi'));
      await tester.pumpAndSettle();
      expect(find.textContaining('minimal satu akun'), findsOneWidget);
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Cash'));
      await tester.tap(find.text('Simpan asumsi'));
      await tester.pumpAndSettle();
      expect(find.textContaining('6 bulan penuh'), findsOneWidget);
      expect(source.state['financial_health_assumptions']['months'], 6);
      expect(source.rows('transactions'), hasLength(2));
      expect(source.row('accounts', 'cash')!['balance'], '1000.00');
      expect(source.outbox, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'phone layout explains incomplete data and rejects saves after a session switch',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = LocalStore(sqlite3.openInMemory());
      final source = FinanceRepository(ApiClient(), store, 'owner')
        ..offline = true;
      seedHealth(source);
      source.atomic(() {
        source.state.remove('investment_history_coverage');
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
          child: const MaterialApp(home: FinancialHealthPage()),
        ),
      );
      expect(find.text('Belum tersedia'), findsWidgets);
      await tester.tap(find.text('Ubah asumsi'));
      await tester.pumpAndSettle();
      state.currentUserId = 'other';
      state.toggleHideBalance();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simpan asumsi'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Sesi telah berubah'), findsOneWidget);
      expect(source.state['financial_health_assumptions'], isNull);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(
        find.text('Masuk untuk membuka indikator keuangan.'),
        findsOneWidget,
      );
      expect(find.text('Cash'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
