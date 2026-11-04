import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/features/household/widgets/group_account_sharing_sheet.dart';

import '../fixtures/cached_finance.dart';
import '../unit/group_account_sharing_test.dart' show SharingClient;

void main() {
  testWidgets('sharing explains privacy and cancellation sends no request', (
    tester,
  ) async {
    final client = SharingClient();
    final state = cachedFinanceState(client: client);
    final repo = state.repository!;
    repo.atomic(() {
      repo.entities['groups'] = <String, dynamic>{
        'group': {'id': 'group', 'name': 'Group', 'role': 'MEMBER'},
      };
      repo.entities['accounts']['foreign'] = <String, dynamic>{
        'id': 'foreign',
        'user_id': 'other',
        'name': 'Foreign',
      };
    });
    await tester.pumpWidget(
      AppStateScope(
        state: state,
        child: const MaterialApp(
          home: Scaffold(body: GroupAccountSharingSheet(groupId: 'group')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('hanya milik Anda'), findsOneWidget);
    expect(find.text('Belum ada akun Anda yang dibagikan.'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    expect(find.text('Foreign'), findsNothing);
    await tester.tap(find.text('Cash').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bagikan akun'));
    await tester.pumpAndSettle();
    expect(find.textContaining('termasuk riwayat sebelumnya'), findsOneWidget);
    expect(client.methods, isEmpty);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(client.methods, isEmpty);
    state.toggleOfflineMode();
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });

  testWidgets(
    'tapping account card directly selects it interactively and displays formatted balance',
    (tester) async {
      final client = SharingClient();
      final state = cachedFinanceState(client: client);
      final repo = state.repository!;
      repo.atomic(() {
        repo.entities['groups'] = <String, dynamic>{
          'group': {'id': 'group', 'name': 'Group', 'role': 'MEMBER'},
        };
      });
      await tester.pumpWidget(
        AppStateScope(
          state: state,
          child: const MaterialApp(
            home: Scaffold(body: GroupAccountSharingSheet(groupId: 'group')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Formatted balance is displayed on the card
      expect(find.text('Rp 100.000'), findsOneWidget);

      // Tap on the 'Cash' card directly
      await tester.tap(find.text('Cash').first);
      await tester.pumpAndSettle();

      // Selection feedback is displayed
      expect(
        find.text('Akun terpilih tidak tercatat pada daftar ini.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

      // Button is enabled
      final filledBtn = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(filledBtn.onPressed, isNotNull);

      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );

  testWidgets(
    'excludes parent accounts and prefixes child accounts with parent name',
    (tester) async {
      final client = SharingClient();
      final state = cachedFinanceState(client: client);
      final repo = state.repository!;
      repo.atomic(() {
        repo.entities['groups'] = <String, dynamic>{
          'group': {'id': 'group', 'name': 'Group', 'role': 'MEMBER'},
        };
        // Parent institution account
        repo.entities['accounts']['bareksa'] = <String, dynamic>{
          'id': 'bareksa',
          'user_id': 'user',
          'name': 'Bareksa',
          'balance': '0.00',
        };
        // Child pocket/holding account
        repo.entities['accounts']['bareksa_star'] = <String, dynamic>{
          'id': 'bareksa_star',
          'user_id': 'user',
          'name': 'Reksadana STAR',
          'parent_account_id': 'bareksa',
          'balance': '500000.00',
        };
        // Standalone account
        repo.entities['accounts']['dompet'] = <String, dynamic>{
          'id': 'dompet',
          'user_id': 'user',
          'name': 'Dompet',
          'balance': '390000.00',
        };
      });

      await tester.pumpWidget(
        AppStateScope(
          state: state,
          child: const MaterialApp(
            home: Scaffold(body: GroupAccountSharingSheet(groupId: 'group')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Parent 'Bareksa' should be excluded from the account cards
      // The child should be prefixed as 'Bareksa - Reksadana STAR'
      expect(find.text('Bareksa - Reksadana STAR'), findsOneWidget);
      expect(find.text('Dompet'), findsOneWidget);

      // Raw parent account name 'Bareksa' shouldn't appear as a standalone card
      expect(find.widgetWithText(InkWell, 'Bareksa'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );
}
