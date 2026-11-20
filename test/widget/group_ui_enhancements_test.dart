import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/features/household/widgets/household_unavailable_view.dart';

import '../fixtures/cached_finance.dart';

void main() {
  testWidgets(
    'Group UI enhancements: shared accounts before pockets, polished hero breakdown, currency formatting, and no raw UUID',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final state = cachedFinanceState();
      final repo = state.repository!;

      const groupId = '01a1b978-c70c-77f1-b181-31a0afef9fdd';
      const userAId = '0199a1b5-user-a';
      const userBId = '0199a1b5-user-b';

      repo.atomic(() {
        repo.entities['account_types'] = {
          'Bank': {'id': 'Bank', 'name': 'Rekening Bank', 'category': 'CASH'},
          'Reksadana': {
            'id': 'Reksadana',
            'name': 'Reksadana',
            'category': 'INVESTMENT',
          },
        };

        repo.entities['accounts'] = {
          'acc-bca': {
            'id': 'acc-bca',
            'name': 'BCA Bersama',
            'account_type_id': 'Bank',
            'balance': '10000000.00',
            'user_id': userAId,
            'is_visible': true,
            'is_include_total': true,
          },
          'acc-invest': {
            'id': 'acc-invest',
            'name': 'Syailendra Invest',
            'account_type_id': 'Reksadana',
            'balance': '50000000.00',
            'user_id': userAId,
            'is_visible': true,
            'is_include_total': true,
          },
        };

        repo.entities['groups'] = {
          groupId: {
            'id': groupId,
            'name': 'BuLuk Fams',
            'role': 'MEMBER',
          },
        };

        repo.entities['members:$groupId'] = {
          userAId: {
            'id': userAId,
            'user_id': userAId,
            'name': 'Burhan Mafazi',
            'role': 'OWNER',
          },
          userBId: {
            'id': userBId,
            'user_id': userBId,
            'name': 'User B',
            'role': 'MEMBER',
          },
        };
        repo.entities['household_category_reports:$groupId'] = {
          '2026-11': {
            'report': {
              'period': '2026-11',
              'categories': [
                {
                  'group_category_id': 'cat-food',
                  'name': 'Makanan & Minuman',
                  'type': 'EXPENSE',
                  'income': '0.00',
                  'expense': '750000.00',
                },
              ],
            },
            'fetched_at': DateTime(2026, 11, 19).toIso8601String(),
          },
        };
      });

      state.currentUserId = userBId;
      state.userName = 'User B';
      state.householdReportPeriod = '2026-11';

      await tester.pumpWidget(
        AppStateScope(
          state: state,
          child: const MaterialApp(home: HouseholdUnavailableView()),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Hero Card breakdown
      expect(find.text('TOTAL KEKAYAAN BERSAMA'), findsOneWidget);
      expect(find.text('Rp 60.000.000'), findsOneWidget);
      expect(find.text('Rp 10.000.000'), findsNWidgets(2)); // Hero Kas & Account item
      expect(find.text('Rp 50.000.000'), findsNWidgets(2)); // Hero Investasi & Account item

      // 2. Position: "Rekening Dibagikan" appears before "Kantong tujuan grup"
      final sharedSectionFinder = find.text('Rekening Dibagikan');
      final pocketsPanelFinder = find.text('Kantong tujuan grup');
      expect(sharedSectionFinder, findsOneWidget);
      expect(pocketsPanelFinder, findsOneWidget);

      final sharedTop = tester.getTopLeft(sharedSectionFinder).dy;
      final pocketsTop = tester.getTopLeft(pocketsPanelFinder).dy;
      expect(sharedTop, lessThan(pocketsTop));

      // 3. Category report: formatted currency
      expect(find.text('Rp 750.000'), findsOneWidget);
      expect(find.text('750000.00'), findsNothing);

      // 4. Activity Tab: Navigate to tab 1
      await tester.tap(find.text('Aktivitas'));
      await tester.pumpAndSettle();

      // Ensure no raw UUIDs are shown anywhere in the activity tab
      expect(find.text(userAId), findsNothing);
      expect(find.text(userBId), findsNothing);

      state.dispose();
    },
  );
}
