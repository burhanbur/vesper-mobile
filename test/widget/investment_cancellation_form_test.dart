import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/database/local_store.dart';
import 'package:vesper_mobile/features/investments/models/investment.dart';
import 'package:vesper_mobile/features/investments/widgets/offline_investment_trade_form.dart';
import 'package:vesper_mobile/features/sync/data/finance_repository.dart';

class _Client extends ApiClient {
  late FinanceRepository repo;
  int requests = 0;
  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    bool authenticated = true,
    bool retry = true,
  }) async {
    if (path == '/devices') return {};
    if (method == 'GET' && path.startsWith('/sync/investment-recoveries')) {
      throw const ApiFailure('Missing', statusCode: 404);
    }
    if (path == '/sync/investment-recoveries') {
      requests++;
      expect(repo.outbox.single['recovery_requested'], isTrue);
      expect(repo.rows('transactions').single['amount'], '10.01');
      return {
        'user_id': 'actor',
        'trade_id': body!['command']['entity_id'],
        'linked_transaction_id':
            body['command']['payload']['linked_transaction_id'],
        'command_sha256': body['command_sha256'],
        'status': 'PENDING',
        'requested_at': '2026-10-16T00:00:00.000Z',
        'reviewed_at': null,
      };
    }
    if (path == '/sync/pull') {
      return {'changes': [], 'next_version': '0', 'has_more': false};
    }
    throw StateError(path);
  }
}

void main() {
  testWidgets(
    'cancellation requires confirmation, persists before request and keeps pending financial rows',
    (tester) async {
      final store = LocalStore(sqlite3.openInMemory());
      final client = _Client();
      final repo = FinanceRepository(client, store, 'actor');
      client.repo = repo;
      repo.atomic(() {
        repo.entities['transactions'] = {
          'leg': {'id': 'leg', 'amount': '10.01'},
        };
        repo.outbox.add({
          'id': 'queue',
          'entity_type': 'investment_transactions',
          'entity_id': 'trade',
          'operation': 'CREATE',
          'client_version': '0',
          'status': 'rejected',
          'payload': {
            'linked_transaction_id': 'leg',
            'quantity': '1',
            'price_per_unit': '10.005',
            'fee': '0',
          },
        });
      });
      final state = AppState(repository: repo);
      addTearDown(state.dispose);
      addTearDown(store.close);
      await tester.pumpWidget(
        AppStateScope(
          state: state,
          child: const MaterialApp(
            home: Scaffold(
              body: OfflineInvestmentTradeForm(
                initialType: InvestmentTradeType.buy,
              ),
            ),
          ),
        ),
      );
      final button = find.text('Ajukan pembatalan');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kembali'));
      await tester.pumpAndSettle();
      expect(client.requests, 0);
      expect(repo.outbox.single['recovery_requested'], isNull);
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ajukan'));
      await tester.pumpAndSettle();
      expect(client.requests, 1);
      expect(repo.outbox.single['status'], 'rejected');
      expect(repo.outbox.single['recovery_receipt']['status'], 'PENDING');
      expect(repo.rows('transactions').single['amount'], '10.01');
      expect(
        find.text('Pengajuan tersimpan. Menunggu peninjauan pengelola.'),
        findsOneWidget,
      );
      final retryButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Coba ulang command asli'),
      );
      expect(retryButton.onPressed, isNull);
      expect(
        FinanceRepository(
          client,
          store,
          'actor',
        ).outbox.single['recovery_requested'],
        isTrue,
      );
      state.toggleOfflineMode();
      await tester.pumpAndSettle();
      final check = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Periksa status pembatalan'),
      );
      expect(check.onPressed, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
