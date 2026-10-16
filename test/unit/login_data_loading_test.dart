import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/database/local_store_native.dart';
import 'package:vesper_mobile/features/sync/data/finance_repository.dart';

import '../fixtures/login_client.dart';

void main() {
  for (final indexed in [false, true]) {
    testWidgets(
      '${indexed ? 'v3' : 'snapshot'} login publishes accounts before history, retains page and honors Retry-After',
      (tester) async {
        Directory? temporary;
        final store = indexed
            ? LocalStore.indexed(
                sqlite3.open(
                  '${(temporary = Directory.systemTemp.createTempSync('vesper-login-test-')).path}${Platform.pathSeparator}test.sqlite',
                ),
                key: List.generate(32, (i) => i),
                userId: 'user',
              )
            : LocalStore(sqlite3.openInMemory());
        final client = LoginClient();
        final repo = FinanceRepository(client, store, 'user');
        final state = AppState(repository: repo);
        final visibleTransactions = <String>{};
        state.addListener(
          () => visibleTransactions.addAll(
            repo.rows('transactions').map((row) => row['id'] as String),
          ),
        );
        try {
          final login = state.login(userId: 'user');
          await tester.pump();
          expect(client.coreReady.isCompleted, isTrue);
          expect(state.accounts.single.name, 'Server cash');
          expect(state.loading, isTrue);
          expect(client.paths.take(5), [
            '/account-types',
            '/accounts',
            '/categories',
            '/groups',
            '/devices',
          ]);
          client.releaseSync.complete();
          await login;
          expect(visibleTransactions, contains('one'));
          expect(state.loading, isFalse);
          expect(state.dataError, isNotNull);
          expect(repo.state['cursor'], '1');
          expect(repo.hasCompleteInvestmentHistory, isFalse);
          expect(client.paths, isNot(contains('/transactions')));
          expect(repo.outbox, isEmpty);
          await tester.pump(const Duration(seconds: 19));
          expect(client.registrations, 1);
          await tester.pump(const Duration(seconds: 1));
          expect(client.registrations, 2);
          expect(client.cursors, ['0', '1', '1']);
          expect(state.dataError, isNull);
          expect(repo.hasCompleteInvestmentHistory, isTrue);
          expect(repo.rows('transactions'), hasLength(2));
          expect(store.read()['cursor'], '2');
        } finally {
          state.dispose();
          await tester.pump();
          if (temporary != null) {
            if (temporary.parent.absolute.path !=
                    Directory.systemTemp.absolute.path ||
                !temporary.path.contains('vesper-login-test-')) {
              throw StateError('Invalid test directory');
            }
            temporary.deleteSync(recursive: true);
          }
        }
      },
    );
  }

  test('transport preserves Retry-After without retrying requests or losing session', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.badResponse,
              response: Response<dynamic>(
                requestOptions: options,
                statusCode: 429,
                headers: Headers.fromMap({
                  'retry-after': ['37'],
                }),
              ),
            ),
          );
        },
      ),
    );
    final client = ApiClient(dio: dio)
      ..session = {'access_token': 'test-session'};
    await expectLater(
      client.request('GET', '/accounts'),
      throwsA(
        isA<ApiFailure>()
            .having((error) => error.statusCode, 'status', 429)
            .having(
              (error) => error.retryAfter,
              'retryAfter',
              const Duration(seconds: 37),
            ),
      ),
    );
    expect(client.session?['access_token'], 'test-session');
    dio.close();
  });
}
