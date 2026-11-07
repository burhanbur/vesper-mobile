import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/features/investments/pages/portfolio_page.dart';
import 'package:vesper_mobile/features/investments/pages/investment_lifecycle_page.dart';

import '../fixtures/cached_finance.dart';
import '../unit/portfolio_read_test.dart' show ReadClient, seed;

void main() {
  testWidgets('empty portfolio has expandable help and management navigation', (
    tester,
  ) async {
    final api = ReadClient()..response = [];
    final state = cachedFinanceState(client: api)..currentUserId = 'user';
    seed(state.repository!);
    await tester.pumpWidget(
      AppStateScope(
        state: state,
        child: const MaterialApp(home: PortfolioPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Belum ada posisi investasi'), findsOneWidget);
    expect(find.byIcon(Icons.pie_chart_outline_rounded), findsWidgets);
    expect(find.textContaining('bukan ledger lokal'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Tentang data portofolio'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Tentang data portofolio'));
    await tester.pumpAndSettle();
    expect(find.textContaining('bukan ledger lokal'), findsOneWidget);
    expect(find.textContaining('Cache diambil:'), findsOneWidget);
    await tester.ensureVisible(find.text('Kelola investasi'));
    await tester.tap(find.text('Kelola investasi'));
    await tester.pumpAndSettle();
    expect(find.byType(InvestmentLifecyclePage), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });

  testWidgets('controls wrap at narrow width and enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = ReadClient()..response = [];
    final state = cachedFinanceState(client: api)..currentUserId = 'user';
    seed(state.repository!);
    await tester.pumpWidget(
      AppStateScope(
        state: state,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: const PortfolioPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Muat ulang'));
    await tester.pumpAndSettle();
    expect(api.requests.length, 2);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('second').last);
    await tester.pumpAndSettle();
    expect(api.requests.last, '/accounts/second/holdings:null');
    await tester.tap(find.text('Snapshot'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(api.requests.last, contains('/accounts/second/portfolio-snapshot:'));
    await tester.tap(find.text('Saat ini'));
    await tester.pumpAndSettle();
    expect(api.requests.last, '/accounts/second/holdings:null');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });

  testWidgets(
    'read-only portfolio displays exact strings, offline cache and no trade actions',
    (tester) async {
      final api = ReadClient();
      final state = cachedFinanceState(client: api)..currentUserId = 'user';
      seed(state.repository!);
      await tester.pumpWidget(
        AppStateScope(
          state: state,
          child: const MaterialApp(home: PortfolioPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Jumlah: 123456789012.12345678'), findsOneWidget);
      expect(
        find.text('Harga modal rata-rata: IDR 999999999999.12345678'),
        findsOneWidget,
      );
      expect(find.text('Data server • Bukan real-time'), findsOneWidget);
      expect(find.textContaining('Cache diambil:'), findsNothing);
      await tester.ensureVisible(find.text('Tentang data portofolio'));
      await tester.tap(find.text('Tentang data portofolio'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Cache diambil:'), findsOneWidget);
      expect(find.textContaining('bukan ledger lokal'), findsOneWidget);
      expect(find.text('Catat Transaksi Investasi Baru'), findsNothing);
      expect(find.byIcon(Icons.add_rounded), findsNothing);
      state.toggleOfflineMode();
      await tester.pumpAndSettle();
      expect(find.textContaining('Offline —'), findsOneWidget);
      expect(
        find.text('Data cache usang / belum diverifikasi ulang.'),
        findsOneWidget,
      );
      expect(api.requests.length, 1);
      state.repository!.atomic(
        () => state.repository!.entities['accounts'] = <String, dynamic>{},
      );
      state.toggleHideBalance();
      await tester.pumpAndSettle();
      expect(find.text('Belum ada akun investasi milik Anda.'), findsOneWidget);
      expect(find.textContaining('123456789012'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );

  testWidgets('no session does not display another repository cache', (
    tester,
  ) async {
    final state = cachedFinanceState();
    seed(state.repository!);
    await tester.pumpWidget(
      AppStateScope(
        state: state,
        child: const MaterialApp(home: PortfolioPage()),
      ),
    );
    expect(
      find.text('Masuk dan siapkan data akun untuk melihat portofolio.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });
}
