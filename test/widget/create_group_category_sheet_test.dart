import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/features/household/widgets/create_group_category_sheet.dart';

import '../fixtures/cached_finance.dart';

void main() {
  testWidgets('invalid input keeps form open with safe message', (
    tester,
  ) async {
    final state = cachedFinanceState();
    await tester.pumpWidget(
      AppStateScope(
        state: state,
        child: const MaterialApp(
          home: Scaffold(body: CreateGroupCategorySheet()),
        ),
      ),
    );
    expect(find.textContaining('Membutuhkan koneksi.'), findsOneWidget);
    await tester.tap(find.text('Simpan kategori grup'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Masukkan nama kategori'), findsOneWidget);
    expect(find.text('Simpan kategori grup'), findsOneWidget);
    expect(state.repository!.outbox, isEmpty);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });
}
