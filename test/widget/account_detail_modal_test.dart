import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/features/accounts/pages/account_detail_page.dart';
import 'package:vesper_mobile/features/accounts/pages/accounts_page.dart';

import '../fixtures/cached_finance.dart';

void main() {
  testWidgets(
    'Cached account opens detail and sharing dropdown without mutating data',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = cachedFinanceState()..currentUserId = 'user';
      state.toggleOfflineMode();
      addTearDown(state.dispose);
      final repo = state.repository!;
      repo.atomic(() {
        repo.entities['groups'] = {
          'group': {'id': 'group', 'name': 'Fixture group'},
        };
      });
      final before = repo.store.read();
      await tester.pumpWidget(
        AppStateScope(
          state: state,
          child: const MaterialApp(home: AccountsPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Cash'), findsWidgets);
      await tester.tap(find.text('Cash').last);
      await tester.pumpAndSettle();
      expect(find.byType(AccountDetailPage), findsOneWidget);
      expect(find.text('Saldo Rekening'), findsOneWidget);
      expect(find.text('Rp 100.000'), findsOneWidget);
      await tester.tap(find.byTooltip('Pengaturan & Sharing'));
      await tester.pumpAndSettle();
      expect(find.text('Bagikan ke Ruang Grup Bersama'), findsOneWidget);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(find.text('Pilih Grup yang Dapat Mengakses'), findsOneWidget);
      final dropdown = tester.widget<DropdownButton<String>>(
        find.byType(DropdownButton<String>),
      );
      expect(dropdown.value, 'group');
      expect(dropdown.items!.map((item) => item.value), ['group']);
      // Cancel: opening presentation settings must not report a server write.
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(repo.outbox, isEmpty);
      expect(repo.state, before);
      expect(repo.store.read(), before);
      expect(tester.takeException(), isNull);
    },
  );
}
