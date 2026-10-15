import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/features/household/widgets/collaboration_panel.dart';

import '../fixtures/cached_finance.dart';

class PagedClient extends ApiClient {
  final requests = <String>[];
  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    bool authenticated = true,
    bool retry = true,
  }) async {
    final page = query!['page'] as int;
    requests.add('$path:$page');
    if (path.endsWith('/members')) {
      if (page == 2) {
        return [
          <String, dynamic>{
            'user_id': 'user',
            'name': 'Owner',
            'role': 'OWNER',
          },
        ];
      }
      return List.generate(
        20,
        (i) => <String, dynamic>{
          'user_id': 'member$i',
          'name': 'Member $i',
          'role': 'MEMBER',
        },
      );
    }
    return <String, dynamic>{
      'period': query['period'],
      'page': page,
      'limit': 20,
      'balances': <dynamic>[],
      'contributions': List.generate(
        page == 1 ? 20 : 1,
        (i) => <String, dynamic>{
          'user_id': 'member$i',
          'currency': 'IDR',
          'income': '1.00',
          'expense': '0.00',
        },
      ),
      'feed': <dynamic>[],
    };
  }
}

void main() {
  testWidgets(
    'owner outside visible page retains actions and lists page independently',
    (tester) async {
      final client = PagedClient();
      final state = cachedFinanceState(client: client);
      addTearDown(state.dispose);
      state.repository!.atomic(() {
        state.repository!.entities['groups'] = <String, dynamic>{
          'group': <String, dynamic>{'id': 'group', 'name': 'Group'},
        };
      });
      await tester.pumpWidget(
        AppStateScope(
          state: state,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: CollaborationPanel()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final menus = tester.widgetList<PopupMenuButton<String>>(
        find.byType(PopupMenuButton<String>),
      );
      expect(menus, hasLength(20));
      expect(menus.every((menu) => menu.enabled), isTrue);
      await tester.ensureVisible(find.text('Kontribusi berikutnya'));
      await tester.tap(find.text('Kontribusi berikutnya'));
      await tester.pumpAndSettle();
      expect(find.text('Kontribusi • Halaman 2'), findsOneWidget);
      expect(find.text('Aktivitas • Halaman 1'), findsOneWidget);
      expect(find.text('Anggota • Halaman 1'), findsOneWidget);
      expect(
        client.requests.where((r) => r.endsWith('/collaboration:2')),
        isNotEmpty,
      );
      expect(tester.takeException(), isNull);
      state.toggleOfflineMode();
      await tester.pumpAndSettle();
      expect(find.byType(PopupMenuButton<String>), findsNothing);
      expect(find.textContaining('Member 0'), findsNothing);
      expect(find.text('Kontribusi • Halaman 2'), findsNothing);
      state.toggleOfflineMode();
      await tester.pumpAndSettle();
      expect(find.text('Kontribusi • Halaman 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
