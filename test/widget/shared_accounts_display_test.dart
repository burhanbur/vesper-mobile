import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/features/accounts/pages/accounts_page.dart';

import '../fixtures/cached_finance.dart';

void main() {
  testWidgets(
    'Shared accounts from another user display group badge, owner name, group name, and orphan child accounts are displayed as roots',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final state = cachedFinanceState();
      final repo = state.repository!;

      const groupFamsId = '01a1b978-c70c-77f1-b181-31a0afef9fdd';
      const userAId = '0199a1b5-user-a';
      const userBId = '0199a1b5-user-b';

      repo.atomic(() {
        repo.entities['account_types'] = {
          'Cash': {'id': 'Cash', 'name': 'Cash', 'category': 'CASH'},
          'Bank': {'id': 'Bank', 'name': 'Rekening Bank', 'category': 'CASH'},
          'Reksadana': {
            'id': 'Reksadana',
            'name': 'Reksadana',
            'category': 'INVESTMENT',
          },
        };

        // User B has NO personal accounts.
        // User A shared 3 accounts to group BuLuk Fams:
        // 1. Mandiri (Cash)
        // 2. BCA (Cash)
        // 3. Syailendra (Investment) - has parentAccountId 'bareksa-broker', which is NOT shared to User B
        repo.entities['accounts'] = {
          'acc-mandiri': {
            'id': 'acc-mandiri',
            'name': 'Mandiri',
            'account_type_id': 'Bank',
            'balance': '1938047.00',
            'user_id': userAId,
            'is_visible': true,
            'is_include_total': true,
          },
          'acc-bca': {
            'id': 'acc-bca',
            'name': 'BCA',
            'account_type_id': 'Bank',
            'balance': '8056118.00',
            'user_id': userAId,
            'is_visible': true,
            'is_include_total': true,
          },
          'acc-syailendra': {
            'id': 'acc-syailendra',
            'name': 'Reksadana Syailendra',
            'account_type_id': 'Reksadana',
            'balance': '102896987.00',
            'user_id': userAId,
            'parent_account_id': 'bareksa-broker', // parent not in User B's accounts!
            'is_visible': true,
            'is_include_total': true,
          },
        };

        repo.entities['groups'] = {
          groupFamsId: {
            'id': groupFamsId,
            'name': 'BuLuk Fams',
            'role': 'MEMBER',
          },
        };

        repo.entities['members:$groupFamsId'] = {
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
      });

      // User B is logged in
      state.currentUserId = userBId;
      state.toggleOfflineMode();
      addTearDown(state.dispose);

      // Verify accounts in state
      final accounts = state.accounts;
      expect(accounts.length, 3);
      for (final acc in accounts) {
        expect(acc.isShared, isTrue);
        expect(acc.householdId, groupFamsId);
        expect(acc.groupName, 'BuLuk Fams');
        expect(acc.ownerName, 'Burhan Mafazi');
      }

      // Root accounts must include Syailendra because bareksa-broker is not in accessible accounts
      final rootAccounts = state.rootAccounts;
      expect(rootAccounts.map((a) => a.id).toSet(), {
        'acc-mandiri',
        'acc-bca',
        'acc-syailendra',
      });

      await tester.pumpWidget(
        AppStateScope(
          state: state,
          child: const MaterialApp(home: AccountsPage()),
        ),
      );
      await tester.pumpAndSettle();

      // Check header counts
      // Semua Rekening should count all 3 roots
      expect(find.text('Semua Rekening (3)'), findsOneWidget);
      // Akun Pribadi should be 0 because User B has no personal accounts
      expect(find.text('Akun Pribadi (0)'), findsOneWidget);
      // BuLuk Fams pill should count 3 accounts
      expect(find.text('BuLuk Fams (3)'), findsOneWidget);

      // Check displayed accounts in list
      expect(find.text('Mandiri'), findsOneWidget);
      expect(find.text('BCA'), findsOneWidget);
      expect(find.text('Reksadana Syailendra'), findsOneWidget);

      // Check badge displays group name
      expect(find.text('👥 BuLuk Fams'), findsNWidgets(3));

      // Check subtitle displays owner and group attribution
      expect(
        find.text('Milik Burhan Mafazi • BuLuk Fams'),
        findsNWidgets(3),
      );

      // Filter by Akun Pribadi
      await tester.tap(find.text('Akun Pribadi (0)'));
      await tester.pumpAndSettle();
      expect(find.text('Mandiri'), findsNothing);
      expect(find.text('BCA'), findsNothing);
      expect(find.text('Reksadana Syailendra'), findsNothing);

      // Filter by BuLuk Fams
      await tester.tap(find.text('BuLuk Fams (3)'));
      await tester.pumpAndSettle();
      expect(find.text('Mandiri'), findsOneWidget);
      expect(find.text('BCA'), findsOneWidget);
      expect(find.text('Reksadana Syailendra'), findsOneWidget);
    },
  );
}
