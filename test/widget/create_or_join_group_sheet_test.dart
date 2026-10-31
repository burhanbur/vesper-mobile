import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/core/widgets/app_toast.dart';
import 'package:vesper_mobile/features/household/widgets/create_group_sheet.dart';

import '../fixtures/cached_finance.dart';

class _MockGroupClient extends ApiClient {
  final calls = <Map<String, dynamic>>[];
  bool shouldFail = false;

  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    bool authenticated = true,
    bool retry = true,
  }) async {
    calls.add({'method': method, 'path': path, 'body': body});
    if (shouldFail) {
      throw const ApiFailure('Kode undangan tidak valid.');
    }
    if (path == '/groups/join') {
      return {'id': 'joined-id', 'name': 'Joined Household'};
    }
    if (path == '/groups') {
      return {'id': 'new-id', 'name': body?['name'], 'code': 'NEWCODE12345'};
    }
    if (path.endsWith('/members')) {
      return [];
    }
    return {};
  }
}

void main() {
  tearDown(() {
    AppToast.dismiss();
  });

  testWidgets('Join mode requires only invitation code without UUID field', (
    tester,
  ) async {
    final client = _MockGroupClient();
    final state = cachedFinanceState(client: client);

    await tester.pumpWidget(
      AppStateScope(
        state: state,
        child: const MaterialApp(
          home: Scaffold(body: CreateOrJoinGroupSheet()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Initially in "Buat Grup Baru" tab
    expect(find.text('Nama Grup Finansial'), findsOneWidget);

    // Switch to "Gabung via Kode" tab
    await tester.tap(find.text('🔑 Gabung via Kode'));
    await tester.pumpAndSettle();

    // Verify only the 12-character code field exists, NO UUID field
    expect(find.text('Kode Undangan Grup'), findsOneWidget);
    expect(find.text('ID Grup (UUID)'), findsNothing);
    expect(find.text('ID Grup'), findsNothing);

    // Enter invitation code
    final codeField = find.byType(TextField);
    expect(codeField, findsOneWidget);
    await tester.enterText(codeField, 'abcd1234efgh');
    await tester.pump();

    // Tap Gabung Grup button
    await tester.tap(find.text('Gabung ke Grup Sekarang'));
    await tester.pumpAndSettle();

    // Verify it called /groups/join with normalized uppercase code
    final joinCall = client.calls.firstWhere(
      (c) => c['path'] == '/groups/join',
    );
    expect(joinCall['body'], {'code': 'ABCD1234EFGH'});

    AppToast.dismiss();
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });

  testWidgets('Join mode shows inline error banner when API returns error', (
    tester,
  ) async {
    final client = _MockGroupClient()..shouldFail = true;
    final state = cachedFinanceState(client: client);

    await tester.pumpWidget(
      AppStateScope(
        state: state,
        child: const MaterialApp(
          home: Scaffold(body: CreateOrJoinGroupSheet()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Switch to "Gabung via Kode" tab
    await tester.tap(find.text('🔑 Gabung via Kode'));
    await tester.pumpAndSettle();

    // Enter invitation code
    final codeField = find.byType(TextField);
    await tester.enterText(codeField, 'invalidcode1');
    await tester.pump();

    // Tap submit
    await tester.tap(find.text('Gabung ke Grup Sekarang'));
    await tester.pumpAndSettle();

    // Error message must be visible in the sheet and overlay (both render the text)
    expect(
      find.textContaining('Kode undangan tidak valid'),
      findsAtLeastNWidgets(1),
    );

    AppToast.dismiss();
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });
}
