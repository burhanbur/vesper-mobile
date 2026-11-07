import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/features/household/widgets/group_pockets_panel.dart';

import '../fixtures/cached_finance.dart';

class _FakePocketClient extends ApiClient {
  List<Map<String, dynamic>> pockets = [
    {
      'id': 'pocket-1',
      'name': 'Belanja Rumah',
      'description': 'Kebutuhan bulanan & dapur',
      'balances': [
        {'currency': 'IDR', 'balance': '2863007.00'},
      ],
      'accounts': [
        {
          'account_id': 'mandiri',
          'name': 'Mandiri',
          'owner_user_id': 'user',
          'owner_name': 'Burhan Mafazi',
          'currency': 'IDR',
          'balance': '2863007.00',
        },
      ],
    },
  ];

  final calls = <(String, String, Map<String, dynamic>?)>[];

  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    bool authenticated = true,
    bool retry = true,
  }) async {
    calls.add((method, path, body));
    if (method == 'GET' && path == '/groups/group/pockets') {
      return pockets;
    }
    if (method == 'POST' && path == '/groups/group/pockets') {
      final newPocket = {
        'id': 'pocket-new',
        'name': body?['name'],
        'description': body?['description'],
        'balances': <dynamic>[],
        'accounts': <dynamic>[],
      };
      pockets.add(newPocket);
      return newPocket;
    }
    if (method == 'POST' && path.contains('/accounts')) {
      return null;
    }
    if (method == 'PATCH' && path.contains('/pockets/')) {
      return pockets.first;
    }
    if (method == 'DELETE' && path.contains('/pockets/')) {
      return null;
    }
    throw ApiFailure('Unhandled: $method $path');
  }
}

void main() {
  testWidgets('pocket header wraps on narrow screens with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = cachedFinanceState();
    addTearDown(state.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: GroupPocketsPanel(app: state, groupId: 'group'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Kantong tujuan grup'), findsOneWidget);
    expect(find.text('TRANSPARAN'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'GroupPocketsPanel renders pocket cards, details sheet, suggestion chips and privacy masking',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final client = _FakePocketClient();
      final state = cachedFinanceState(client: client)..currentUserId = 'user';
      state.repository!.atomic(() {
        state.repository!.entities['groups'] = {
          'group': {'id': 'group', 'name': 'Pasutri', 'role': 'OWNER'},
        };
        state.repository!.entities['accounts'] = {
          'mandiri': {
            'id': 'mandiri',
            'name': 'Mandiri',
            'user_id': 'user',
            'currency': 'IDR',
            'balance': '2863007.00',
          },
          'bca': {
            'id': 'bca',
            'name': 'BCA',
            'user_id': 'user',
            'currency': 'IDR',
            'balance': '5000000.00',
          },
        };
        state.repository!.entities['account_types'] = {
          't1': {'id': 't1', 'user_id': 'user', 'name': 'Cash'},
        };
        state.repository!.entities['accounts']['mandiri']['account_type_id'] =
            't1';
        state.repository!.entities['accounts']['bca']['account_type_id'] = 't1';
      });
      addTearDown(state.dispose);

      await tester.pumpWidget(
        AppStateScope(
          state: state,
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: GroupPocketsPanel(app: state, groupId: 'group'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check header and transparent badge
      expect(find.text('Kantong tujuan grup'), findsOneWidget);
      expect(find.text('TRANSPARAN'), findsOneWidget);

      // Check pocket card content
      expect(find.text('Belanja Rumah'), findsOneWidget);
      expect(find.text('Rp 2.863.007'), findsOneWidget);
      expect(find.text('1 akun'), findsOneWidget);
      expect(find.text('Burhan: Mandiri'), findsOneWidget);

      // Test Privacy masking
      state.toggleHideBalance();
      await tester.pumpAndSettle();
      expect(find.text('••••••'), findsOneWidget);
      expect(find.text('Rp 2.863.007'), findsNothing);

      state.toggleHideBalance();
      await tester.pumpAndSettle();

      // Tap pocket card to open _PocketDetails
      await tester.tap(find.text('Belanja Rumah'));
      await tester.pumpAndSettle();

      // In _PocketDetails: hero card and linked accounts
      expect(find.text('TOTAL SALDO KANTONG'), findsOneWidget);
      expect(find.text('Rekening Anggota Tertaut'), findsOneWidget);
      expect(find.text('Pemilik: Burhan Mafazi'), findsOneWidget);
      expect(find.text('Mandiri'), findsOneWidget);
      expect(find.text('Anda'), findsOneWidget);
      expect(find.text('Lepas'), findsOneWidget);

      // Verify edit and delete buttons are present
      expect(find.byTooltip('Ubah kantong'), findsOneWidget);
      expect(find.byTooltip('Hapus kantong'), findsOneWidget);

      // Tap edit pocket
      await tester.tap(find.byTooltip('Ubah kantong'));
      await tester.pumpAndSettle();
      expect(find.text('Ubah Kantong'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Belanja Rumah'),
        'Belanja Bulanan',
      );
      await tester.tap(find.text('Simpan Perubahan'));
      await tester.pumpAndSettle();
      expect(
        client.calls.any(
          (c) => c.$1 == 'PATCH' && c.$2 == '/groups/group/pockets/pocket-1',
        ),
        isTrue,
      );

      // Tap delete pocket
      await tester.tap(find.byTooltip('Hapus kantong'));
      await tester.pumpAndSettle();
      expect(find.text('Hapus Kantong'), findsOneWidget);
      await tester.tap(find.text('Hapus Kantong'));
      await tester.pumpAndSettle();
      expect(
        client.calls.any(
          (c) => c.$1 == 'DELETE' && c.$2 == '/groups/group/pockets/pocket-1',
        ),
        isTrue,
      );

      // Test "+ Buat kantong" with suggestion chips
      await tester.tap(find.text('Buat kantong'));
      await tester.pumpAndSettle();

      expect(find.text('Buat kantong tujuan'), findsOneWidget);
      expect(find.text('Pilih Cepat atau Ketik Nama:'), findsOneWidget);
      expect(find.text('🛡️ Dana Darurat'), findsOneWidget);

      // Tap suggestion chip
      await tester.tap(find.text('🛡️ Dana Darurat'));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(TextFormField, 'Dana Darurat'),
        findsOneWidget,
      );

      // Submit creation using the modal's button (the last one)
      await tester.tap(find.widgetWithText(FilledButton, 'Buat kantong').last);
      await tester.pumpAndSettle();

      // Verify POST call was sent
      expect(
        client.calls.any(
          (c) => c.$1 == 'POST' && c.$2 == '/groups/group/pockets',
        ),
        isTrue,
      );
    },
  );
}
