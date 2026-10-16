import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/features/dashboard/widgets/offline_banner.dart';

class _StatusState extends AppState {
  final completion = Completer<void>();
  String? resultError;
  void publish({required bool busy, String? error}) {
    loading = busy;
    dataError = error;
    notifyListeners();
  }

  @override
  Future<void> syncPendingNow() async {
    publish(busy: true);
    await completion.future;
    publish(busy: false, error: resultError);
  }
}

void main() {
  for (final failsAgain in [false, true]) {
    testWidgets(
      'empty queue exposes loading/error and awaits ${failsAgain ? 'failed' : 'successful'} retry',
      (tester) async {
        final state = _StatusState()..loading = true;
        addTearDown(state.dispose);
        await tester.pumpWidget(
          AppStateScope(
            state: state,
            child: MaterialApp(
              home: Scaffold(
                body: MediaQuery(
                  data: const MediaQueryData(
                    size: Size(320, 640),
                    textScaler: TextScaler.linear(2),
                  ),
                  child: const SingleChildScrollView(child: OfflineBanner()),
                ),
              ),
            ),
          ),
        );
        expect(state.pendingSyncCount, 0);
        expect(find.text('Memuat data dari server'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        state.publish(busy: false, error: 'API unavailable');
        await tester.pumpAndSettle();
        expect(find.text('Data server belum berhasil dimuat'), findsOneWidget);
        await tester.tap(find.text('Coba muat ulang'));
        await tester.pump();
        expect(find.text('Memuat data dari server'), findsOneWidget);
        expect(find.byType(SnackBar), findsNothing);
        state.resultError = failsAgain ? 'Still unavailable' : null;
        state.completion.complete();
        await tester.pumpAndSettle();
        expect(
          find.text(
            failsAgain
                ? 'Data belum berhasil dimuat. Coba lagi nanti.'
                : 'Data berhasil diperbarui.',
          ),
          findsOneWidget,
        );
        if (failsAgain) {
          expect(find.text('Data berhasil diperbarui.'), findsNothing);
          expect(find.text('Coba muat ulang'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
