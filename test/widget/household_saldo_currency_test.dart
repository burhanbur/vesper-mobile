import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/features/household/widgets/household_unavailable_view.dart';

import '../fixtures/cached_finance.dart';

class _CollaborationBalanceClient extends ApiClient {
  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    bool authenticated = true,
    bool retry = true,
  }) async {
    if (path.endsWith('/collaboration')) {
      return {
        'period': query!['period'],
        'page': query['page'],
        'limit': 20,
        'balances': [
          {'currency': 'IDR', 'balance': '10000000.00'},
          {'currency': 'USD', 'balance': '2500.50'},
        ],
        'contributions': <dynamic>[],
        'feed': <dynamic>[],
      };
    }
    if (path.endsWith('/members')) {
      return [
        {'user_id': 'user', 'name': 'Owner', 'role': 'OWNER'},
      ];
    }
    if (path.endsWith('/category-report')) {
      return {'period': query!['period'], 'categories': <dynamic>[]};
    }
    throw ApiFailure('Unhandled: $path');
  }
}

void main() {
  testWidgets(
    'HouseholdUnavailableView renders Saldo kas bersama with formatted currency and respects privacy masking',
    (tester) async {
      final client = _CollaborationBalanceClient();
      final state = cachedFinanceState(client: client)..currentUserId = 'user';
      state.repository!.atomic(() {
        state.repository!.entities['groups'] = {
          'group': {
            'id': 'group',
            'name': 'Keluarga Bahagia',
            'code': 'INVITE123456',
            'role': 'OWNER',
          },
        };
      });
      addTearDown(state.dispose);

      await tester.pumpWidget(
        AppStateScope(
          state: state,
          child: const MaterialApp(home: HouseholdUnavailableView()),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure the 'Saldo' tab and 'Saldo kas bersama' header exist
      expect(find.text('Saldo'), findsOneWidget);
      expect(find.text('Saldo kas bersama'), findsOneWidget);

      // Verify that balances are formatted as currency, NOT raw decimal strings
      expect(find.text('Rp 10.000.000'), findsOneWidget);
      expect(find.text('USD 2.500,50'), findsOneWidget);
      expect(find.text('IDR 10000000.00'), findsNothing);
      expect(find.text('USD 2500.50'), findsNothing);

      // Verify hide balance privacy mask
      state.toggleHideBalance();
      await tester.pumpAndSettle();

      expect(find.text('••••••'), findsNWidgets(2));
      expect(find.text('Rp 10.000.000'), findsNothing);
      expect(find.text('USD 2.500,50'), findsNothing);
    },
  );
}
