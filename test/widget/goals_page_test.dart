import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/database/local_store.dart';
import 'package:vesper_mobile/features/goals/pages/goals_page.dart';
import 'package:vesper_mobile/features/sync/data/finance_repository.dart';

import '../unit/goals_test.dart' show seedGoals, acceptGoals;

void main() {
  testWidgets('create offline, allocate, withdraw, finish, privacy and scope', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = LocalStore(sqlite3.openInMemory());
    final source = FinanceRepository(ApiClient(), store, 'owner')
      ..offline = true;
    seedGoals(source);
    final state = AppState(repository: source)..currentUserId = 'owner';
    state.toggleOfflineMode();
    addTearDown(() {
      state.dispose();
      store.close();
    });
    await tester.pumpWidget(
      AppStateScope(
        state: state,
        child: const MaterialApp(home: GoalsPage()),
      ),
    );
    await tester.tap(find.text('Buat goal'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Nama goal'),
      'Holiday',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Target nominal (contoh: 1000000.00)'),
      '1000.001',
    );
    await tester.tap(find.text('Simpan lokal'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(source.outbox, isEmpty);
    await tester.enterText(
      find.widgetWithText(TextField, 'Target nominal (contoh: 1000000.00)'),
      '1000',
    );
    await tester.tap(find.text('Simpan lokal'));
    await tester.pumpAndSettle();
    expect(find.text('Holiday'), findsOneWidget);
    expect(find.textContaining('Pribadi — hanya saya'), findsOneWidget);
    acceptGoals(source);
    await tester.tap(find.text('Alokasikan dana'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cash').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Total alokasi dari akun ini'),
      '1000',
    );
    await tester.tap(find.text('Simpan alokasi'));
    await tester.pumpAndSettle();
    expect(find.text('100%'), findsOneWidget);
    expect(source.row('accounts', 'cash')!['balance'], '1000.00');
    expect(source.rows('transactions'), isEmpty);
    acceptGoals(source);
    await tester.tap(find.text('Tandai selesai'));
    await tester.pumpAndSettle();
    expect(source.rows('goals').single['status'], 'COMPLETED');
    acceptGoals(source);
    await tester.tap(find.text('Ubah / tarik'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Total alokasi dari akun ini'),
      '0',
    );
    await tester.tap(find.text('Simpan alokasi'));
    await tester.pumpAndSettle();
    expect(source.rows('goal_allocations').single['amount'], '0.00');
    state.toggleHideBalance();
    await tester.pumpAndSettle();
    expect(find.text('100%'), findsNothing);
    expect(find.textContaining('Didukung saldo: ••••••'), findsOneWidget);
    state.currentUserId = 'other';
    await tester.pumpWidget(
      AppStateScope(
        state: state,
        child: const MaterialApp(home: GoalsPage(key: ValueKey('other'))),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Holiday'), findsNothing);
    expect(find.text('Masuk untuk membuka goal.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
