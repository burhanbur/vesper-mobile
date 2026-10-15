import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/features/household/widgets/group_category_mapping_sheet.dart';

import '../fixtures/cached_finance.dart';

void main() {
  testWidgets(
    'only matching personal categories selectable; offline actions disabled',
    (tester) async {
      final state = cachedFinanceState();
      final repo = state.repository!;
      repo.atomic(
        () => repo.entities['categories']['foreign'] = <String, dynamic>{
          'id': 'foreign',
          'user_id': 'other',
          'type': 'EXPENSE',
          'name': 'Foreign',
        },
      );
      state.toggleOfflineMode();
      await tester.pumpWidget(
        AppStateScope(
          state: state,
          child: const MaterialApp(
            home: Scaffold(
              body: GroupCategoryMappingSheet(
                groupId: 'group',
                categoryId: 'shared',
                categoryName: 'Shared',
                categoryType: 'EXPENSE',
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      expect(find.text('Food'), findsWidgets);
      expect(find.text('Salary'), findsNothing);
      expect(find.text('Foreign'), findsNothing);
      await tester.tap(find.text('Food').last);
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(
                TextButton,
                'Lepas pasangan kategori terpilih',
              ),
            )
            .onPressed,
        isNull,
      );
      expect(find.textContaining('Status belum tersedia.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );
}
