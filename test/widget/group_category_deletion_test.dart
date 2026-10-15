import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/features/household/widgets/create_group_category_sheet.dart';

import '../fixtures/cached_finance.dart';
import '../unit/group_category_deletion_test.dart' show DeleteCategoryClient;

void main() {
  testWidgets(
    'deletion requires confirmation and cancellation sends no write',
    (tester) async {
      final client = DeleteCategoryClient();
      final state = cachedFinanceState(client: client);
      final repo = state.repository!;
      repo.atomic(() {
        repo.entities['groups'] = <String, dynamic>{
          'group': {'id': 'group', 'name': 'Group', 'role': 'OWNER'},
        };
        repo.entities['group_categories:group'] = <String, dynamic>{
          'category': {
            'id': 'category',
            'group_id': 'group',
            'name': 'Shared',
            'type': 'EXPENSE',
          },
        };
      });
      await tester.pumpWidget(
        AppStateScope(
          state: state,
          child: const MaterialApp(
            home: Scaffold(
              body: CreateGroupCategorySheet(
                categoryId: 'category',
                groupId: 'group',
                initialName: 'Shared',
              ),
            ),
          ),
        ),
      );
      await tester.ensureVisible(find.text('Hapus kategori grup'));
      await tester.tap(find.text('Hapus kategori grup'));
      await tester.pumpAndSettle();
      expect(find.textContaining('seluruh pemetaannya'), findsOneWidget);
      expect(client.writes, 0);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(client.writes, 0);
      expect(repo.row('group_categories:group', 'category'), isNotNull);
      state.toggleOfflineMode();
      await tester.pump();
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Hapus kategori grup'),
            )
            .onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );
}
