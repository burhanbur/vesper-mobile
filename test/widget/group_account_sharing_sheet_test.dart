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
}
