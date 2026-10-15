import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/features/investments/pages/portfolio_page.dart';

import '../fixtures/cached_finance.dart';
import '../unit/portfolio_read_test.dart' show ReadClient, seed;

void main() {
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
