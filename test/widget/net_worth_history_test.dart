import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/features/dashboard/pages/net_worth_assessment_page.dart';

import '../fixtures/cached_finance.dart';
import '../unit/net_worth_assessment_test.dart' show snapshot;

void main() {
  Future<AppState> mount(
    WidgetTester tester,
    Map<String, dynamic> payload, {
    Completer<void>? gate,
    bool fail = false,
  }) async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid/api/v1'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (gate != null) await gate.future;
          if (fail) {
            handler.reject(DioException(requestOptions: options));
          } else {
            final body = Map<String, dynamic>.from(payload);
            body['snapshot_date'] =
                options.queryParameters['date'] ??
                DateTime.now().toUtc().toIso8601String().substring(0, 10);
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {'success': true, 'data': body},
              ),
            );
          }
        },
      ),
    );
    final state = cachedFinanceState(client: ApiClient(dio: dio));
    addTearDown(state.dispose);
    await tester.pumpWidget(
      AppStateScope(
        state: state,
        child: const MaterialApp(home: NetWorthAssessmentPage()),
      ),
    );
    return state;
  }

  testWidgets(
    'captured observation shows timestamp, stale quotes and hidden values',
    (tester) async {
      final state = await mount(
        tester,
        snapshot()..['balance_basis'] = 'captured_recorded_ledger',
      );
      await tester.tap(find.text('Muat penilaian'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Observasi historis pertama'), findsOneWidget);
      expect(find.textContaining('2026-10-20T12:00:00Z'), findsOneWidget);
      expect(
        find.textContaining('Observasi ini masih parsial'),
        findsOneWidget,
      );
      expect(find.textContaining('9007199254740993.01'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('old'), 200);
      expect(find.textContaining('USANG'), findsOneWidget);
      expect(find.text('12.34'), findsOneWidget);
      state.toggleHideBalance();
      await tester.pumpAndSettle();
      expect(find.textContaining('9007199254740993.01'), findsNothing);
      expect(find.text('12.34'), findsNothing);
      await tester.scrollUntilVisible(
        find.textContaining('Subtotal diketahui:'),
        -200,
      );
      expect(find.textContaining('Subtotal diketahui: ••••••'), findsOneWidget);
      state.currentUserId = 'other-owner';
      state.setFlowStep(AppFlowStep.main);
      await tester.pumpAndSettle();
      expect(find.textContaining('Observasi historis pertama'), findsNothing);
      expect(find.textContaining('2026-10-20T12:00:00Z'), findsNothing);
    },
  );

  testWidgets('absent history is unavailable rather than zero or a capture', (
    tester,
  ) async {
    final payload = snapshot()
      ..['status'] = 'unavailable'
      ..['balance_basis'] = 'unavailable'
      ..['holdings'] = [];
    for (final key in [
      'known_assets',
      'known_balance_liabilities',
      'known_net_worth',
      'cash_balance',
      'investment_cash_balance',
      'holdings_value',
    ]) {
      payload[key] = null;
    }
    await mount(tester, payload);
    await tester.tap(find.text('Muat penilaian'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Histori belum tersedia'), findsOneWidget);
    expect(find.textContaining('bukan bukti historis'), findsOneWidget);
    expect(find.textContaining('Subtotal diketahui:'), findsNothing);
    expect(find.textContaining('Observasi historis pertama'), findsNothing);
  });

  for (final ownerChange in [true, false]) {
    testWidgets(
      'pending response cannot cross ${ownerChange ? 'owner' : 'session'} boundary',
      (tester) async {
        final gate = Completer<void>();
        final state = await mount(tester, snapshot(), gate: gate);
        await tester.tap(find.text('Muat penilaian'));
        await tester.pump();
        if (ownerChange) {
          state.currentUserId = 'other-owner';
        } else {
          state.repository = null;
        }
        state.setFlowStep(AppFlowStep.auth);
        await tester.pump();
        gate.complete();
        await tester.pumpAndSettle();
        expect(find.textContaining('Subtotal diketahui:'), findsNothing);
        expect(find.textContaining('Penilaian belum tersedia.'), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      },
    );
  }

  testWidgets('request failure offers retry without changing local truth', (
    tester,
  ) async {
    final state = await mount(tester, snapshot(), fail: true);
    await tester.tap(find.text('Muat penilaian'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Periksa koneksi'), findsOneWidget);
    expect(find.textContaining('Subtotal diketahui:'), findsNothing);
    expect(state.totalNetWorth, 100000);
    expect(state.repository!.outbox, isEmpty);
  });

  testWidgets('date picker result cannot cross an owner session boundary', (
    tester,
  ) async {
    final state = await mount(tester, snapshot());
    await tester.tap(find.text('Tanggal: hari ini (UTC)'));
    await tester.pumpAndSettle();
    state.currentUserId = 'other-owner';
    state.setFlowStep(AppFlowStep.main);
    await tester.pump();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Tanggal: hari ini (UTC)'), findsOneWidget);
    expect(find.textContaining('Tanggal UTC:'), findsNothing);
    expect(find.text('Kembali ke hari ini (UTC)'), findsNothing);
  });

  testWidgets('day selection clears assessment and can reset to UTC today', (
    tester,
  ) async {
    await mount(tester, snapshot());
    await tester.tap(find.text('Muat penilaian'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tanggal: hari ini (UTC)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Switch to input'));
    await tester.pumpAndSettle();
    final yesterday = DateTime.now().toUtc().subtract(const Duration(days: 1));
    await tester.enterText(
      find.byType(TextField),
      '${yesterday.month}/${yesterday.day}/${yesterday.year}',
    );
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Subtotal diketahui:'), findsNothing);
    expect(find.textContaining('Tanggal UTC:'), findsOneWidget);
    await tester.tap(find.text('Kembali ke hari ini (UTC)'));
    await tester.pumpAndSettle();
    expect(find.text('Tanggal: hari ini (UTC)'), findsOneWidget);
    expect(find.text('Kembali ke hari ini (UTC)'), findsNothing);
    await tester.tap(find.text('Muat penilaian'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Subtotal diketahui:'), findsOneWidget);
  });
}
