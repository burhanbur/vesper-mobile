import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/features/household/widgets/group_account_sharing_sheet.dart';
import 'package:vesper_mobile/features/household/widgets/group_category_mapping_sheet.dart';

import '../fixtures/cached_finance.dart';
import '../unit/group_lists_test.dart' show GroupListsClient, accountRow;

void main() {
  testWidgets(
    'loading, actor status, fetch error and offline cache are explicit',
    (tester) async {
      final client = GroupListsClient()..pending = Completer();
      final state = cachedFinanceState(client: client);
      state.repository!.atomic(
        () => state.repository!.entities['groups'] = {
          'group': {'id': 'group', 'name': 'Group', 'role': 'MEMBER'},
        },
      );
      await tester.pumpWidget(
        AppStateScope(
          state: state,
          child: const MaterialApp(
            home: Scaffold(body: GroupAccountSharingSheet(groupId: 'group')),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.textContaining('Status belum tersedia'), findsOneWidget);
      client.pending!.complete([accountRow()]);
      await tester.pumpAndSettle();
      expect(find.text('Dibagikan oleh Anda: Cash'), findsOneWidget);
      expect(find.textContaining('bukan seluruh anggota'), findsOneWidget);
      client.fail = true;
      await tester.tap(find.text('Muat ulang status'));
      await tester.pumpAndSettle();
      expect(find.text('Liste gagal.'), findsOneWidget);
      expect(find.textContaining('Menampilkan cache terakhir'), findsOneWidget);
      state.toggleOfflineMode();
      await tester.pump();
      expect(find.text('Dibagikan oleh Anda: Cash'), findsOneWidget);
      expect(find.textContaining('Offline:'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );

  testWidgets(
    'mapping sheet displays only actor pairs for selected group category',
    (tester) async {
      final client = GroupListsClient()
        ..rows = [
          {
            'id': 'one',
            'group_id': 'group',
            'group_category_id': 'shared',
            'user_category_id': 'food',
          },
          {
            'id': 'two',
            'group_id': 'group',
            'group_category_id': 'different',
            'user_category_id': 'salary',
          },
        ];
      final state = cachedFinanceState(client: client);
      state.repository!.atomic(
        () => state.repository!.entities['groups'] = {
          'group': {'id': 'group', 'name': 'Group', 'role': 'MEMBER'},
        },
      );
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
      await tester.pumpAndSettle();
      expect(find.text('Dipetakan oleh Anda: Food'), findsOneWidget);
      expect(find.text('Dipetakan oleh Anda: salary'), findsNothing);
      expect(find.textContaining('bukan seluruh anggota'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );
}
