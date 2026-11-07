import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/features/transactions/pages/transactions_page.dart';
import 'package:vesper_mobile/features/transactions/widgets/add_transaction_modal.dart';

import '../fixtures/cached_finance.dart';

void main() {
  testWidgets('Category chips are sorted A–Z in expense and income tabs', (
    tester,
  ) async {
    final state = cachedFinanceState()..currentUserId = 'user';
    addTearDown(state.dispose);
    state.repository!.atomic(() {
      state.repository!.entities['categories'] = {
        for (final type in ['EXPENSE', 'INCOME'])
          for (final name in ['Zebra', 'apple', 'Banana'])
            '$type-$name': {
              'id': '$type-$name',
              'user_id': 'user',
              'name': name,
              'type': type,
              'version': '1',
            },
      };
    });
    await tester.pumpWidget(
      AppStateScope(
        state: state,
        child: const MaterialApp(home: Scaffold(body: AddTransactionModal())),
      ),
    );
    for (final tab in ['Pengeluaran', 'Pemasukan']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      final labels = tester
          .widgetList<ChoiceChip>(find.byType(ChoiceChip))
          .map((chip) => (chip.label as Text).data)
          .toList();
      expect(labels, ['apple', 'Banana', 'Zebra']);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'Save stays visible before and after scrolling and above keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final state = AppState();
      addTearDown(state.dispose);
      await tester.pumpWidget(
        AppStateScope(
          state: state,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return TextButton(
                    onPressed: () => AddTransactionModal.show(context),
                    child: const Text('Open'),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final save = find.byKey(const ValueKey('transaction_save_button'));
      expect(save.hitTestable(), findsOneWidget);
      final before = tester.getTopLeft(save);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(save), before);
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      expect(save.hitTestable(), findsOneWidget);
      expect(tester.getBottomRight(save).dy, lessThanOrEqualTo(460));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Transaction header has search without duplicate add action', (
    tester,
  ) async {
    final state = AppState();
    addTearDown(state.dispose);
    await tester.pumpWidget(
      AppStateScope(
        state: state,
        child: const MaterialApp(home: TransactionsPage()),
      ),
    );
    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    expect(find.byIcon(Icons.add_circle_outline_rounded), findsNothing);
  });

  testWidgets(
    'AddTransactionModal places Tanggal & Waktu and Deskripsi above Kategori across tabs',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final state = AppState();
      addTearDown(state.dispose);

      await tester.pumpWidget(
        AppStateScope(
          state: state,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => AddTransactionModal.show(context),
                  child: const Text('Open Modal'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // 1. Expense Tab (default)
      expect(find.text('Tanggal & Waktu'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('transaction_date_picker')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('transaction_time_picker')),
        findsOneWidget,
      );
      expect(find.text('Deskripsi (opsional)'), findsOneWidget);
      expect(find.text('Kategori'), findsOneWidget);

      final datePosExpense = tester.getTopLeft(find.text('Tanggal & Waktu')).dy;
      final descPosExpense = tester
          .getTopLeft(find.text('Deskripsi (opsional)'))
          .dy;
      final catPosExpense = tester.getTopLeft(find.text('Kategori')).dy;

      expect(
        datePosExpense,
        lessThan(descPosExpense),
        reason: 'Tanggal & Waktu must be above Deskripsi',
      );
      expect(
        descPosExpense,
        lessThan(catPosExpense),
        reason: 'Deskripsi must be above Kategori',
      );

      // 2. Income Tab
      await tester.tap(find.text('Pemasukan'));
      await tester.pumpAndSettle();

      expect(find.text('Tanggal & Waktu'), findsOneWidget);
      expect(find.text('Deskripsi (opsional)'), findsOneWidget);
      expect(find.text('Kategori'), findsOneWidget);

      final datePosIncome = tester.getTopLeft(find.text('Tanggal & Waktu')).dy;
      final descPosIncome = tester
          .getTopLeft(find.text('Deskripsi (opsional)'))
          .dy;
      final catPosIncome = tester.getTopLeft(find.text('Kategori')).dy;

      expect(datePosIncome, lessThan(descPosIncome));
      expect(descPosIncome, lessThan(catPosIncome));

      // 3. Transfer Tab
      await tester.tap(find.text('Transfer'));
      await tester.pumpAndSettle();

      expect(find.text('Tanggal & Waktu'), findsOneWidget);
      expect(find.text('Deskripsi (opsional)'), findsOneWidget);
      expect(
        find.text('Kategori'),
        findsNothing,
        reason: 'Kategori is not used in Transfer',
      );

      final datePosTransfer = tester
          .getTopLeft(find.text('Tanggal & Waktu'))
          .dy;
      final descPosTransfer = tester
          .getTopLeft(find.text('Deskripsi (opsional)'))
          .dy;
      expect(datePosTransfer, lessThan(descPosTransfer));

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Date and time pickers can be opened in AddTransactionModal', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = AppState();
    addTearDown(state.dispose);

    await tester.pumpWidget(
      AppStateScope(
        state: state,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => AddTransactionModal.show(context),
                child: const Text('Open Modal'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Modal'));
    await tester.pumpAndSettle();

    // Tap Date Picker
    final datePickerBtn = find.byKey(const ValueKey('transaction_date_picker'));
    expect(datePickerBtn, findsOneWidget);
    await tester.tap(datePickerBtn);
    await tester.pumpAndSettle();

    // Confirm date picker dialog opened
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Tap Time Picker
    final timePickerBtn = find.byKey(const ValueKey('transaction_time_picker'));
    expect(timePickerBtn, findsOneWidget);
    await tester.tap(timePickerBtn);
    await tester.pumpAndSettle();

    // Confirm time picker dialog opened
    expect(find.byType(TimePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
