import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/features/auth/data/auth_repository.dart';

Map<String, dynamic> _session({bool expired = false}) => {
  'access_token': 'access',
  'refresh_token': 'refresh',
  'token_type': 'Bearer',
  'expires_at': DateTime.now()
      .toUtc()
      .subtract(const Duration(minutes: 1))
      .toIso8601String(),
  'refresh_expires_at': DateTime.now()
      .toUtc()
      .add(Duration(days: expired ? -1 : 1))
      .toIso8601String(),
  'user': {
    'id': 'user',
    'name': 'User',
    'email': 'user@example.test',
    'status': 'ACTIVE',
    'roles': <String>[],
  },
};

ApiClient _client(
  void Function(RequestOptions, RequestInterceptorHandler) respond,
) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));
  dio.interceptors.add(InterceptorsWrapper(onRequest: respond));
  return ApiClient(dio: dio);
}

void _fail(
  RequestOptions options,
  RequestInterceptorHandler handler,
  int? status,
) {
  handler.reject(
    DioException(
      requestOptions: options,
      type: status == null
          ? DioExceptionType.connectionError
          : DioExceptionType.badResponse,
      response: status == null
          ? null
          : Response<dynamic>(requestOptions: options, statusCode: status),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  for (final status in <int?>[null, 408, 429, 503]) {
    test(
      'Refresh failure $status preserves persisted credentials and cached identity',
      () async {
        FlutterSecureStorage.setMockInitialValues({
          'vesper.session': jsonEncode(_session()),
        });
        final client = _client(
          (options, handler) => _fail(
            options,
            handler,
            options.path == '/auth/me' ? 401 : status,
          ),
        );
        final auth = AuthRepository(client: client);
        expect((await auth.bootstrap())?.id, 'user');
        expect(client.session?['refresh_token'], 'refresh');
        expect(await client.storage.read(key: 'vesper.session'), isNotNull);
      },
    );
  }

  test(
    'Explicit revoked refresh never falls back to cached identity',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'vesper.session': jsonEncode(_session()),
      });
      final client = _client(
        (options, handler) => _fail(options, handler, 401),
      );
      expect(await AuthRepository(client: client).bootstrap(), isNull);
      expect(client.session, isNull);
      expect(await client.storage.read(key: 'vesper.session'), isNull);
    },
  );

  test(
    'Expired persisted refresh does not contact API or restore identity',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'vesper.session': jsonEncode(_session(expired: true)),
      });
      var calls = 0;
      final client = _client((options, handler) {
        calls++;
        _fail(options, handler, null);
      });
      expect(await AuthRepository(client: client).bootstrap(), isNull);
      expect(calls, 0);
      expect(client.session, isNull);
    },
  );

  test(
    'Expiry reached during offline request cannot restore cached identity',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'vesper.session': jsonEncode(_session()),
      });
      late ApiClient client;
      client = _client((options, handler) {
        client.session!['refresh_expires_at'] = DateTime.now()
            .toUtc()
            .subtract(const Duration(seconds: 1))
            .toIso8601String();
        _fail(options, handler, null);
      });
      expect(await AuthRepository(client: client).bootstrap(), isNull);
      expect(client.session, isNull);
    },
  );

  test(
    'A non-persisted session cannot bootstrap from cached identity',
    () async {
      final client = _client(
        (options, handler) => _fail(options, handler, null),
      );
      await client.saveSession(_session(), persist: false);
      await expectLater(
        AuthRepository(client: client).bootstrap(),
        throwsA(isA<ApiFailure>()),
      );
      expect(client.session, isNotNull);
    },
  );

  test(
    'Forbidden identity is not an offline success and retains credentials',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'vesper.session': jsonEncode(_session()),
      });
      final client = _client(
        (options, handler) => _fail(options, handler, 403),
      );
      await expectLater(
        AuthRepository(client: client).bootstrap(),
        throwsA(isA<ApiFailure>()),
      );
      expect(client.session, isNotNull);
    },
  );

  test('Malformed refresh response retains credentials but cannot bootstrap offline', () async {
    FlutterSecureStorage.setMockInitialValues({
      'vesper.session': jsonEncode(_session()),
    });
    final client = _client((options, handler) {
      if (options.path == '/auth/me') {
        _fail(options, handler, 401);
      } else {
        handler.resolve(
          Response<dynamic>(
            requestOptions: options,
            statusCode: 200,
            data: {
              'success': true,
              'data': {'invalid': true},
            },
          ),
        );
      }
    });
    await expectLater(
      AuthRepository(client: client).bootstrap(),
      throwsA(isA<ApiFailure>()),
    );
    expect(client.session, isNotNull);
  });

  test(
    '401 after successful refresh removes session instead of using cache',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'vesper.session': jsonEncode(_session()),
      });
      final client = _client((options, handler) {
        if (options.path == '/auth/refresh') {
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: {
                'success': true,
                'data': {..._session(), 'access_token': 'new-access'},
              },
            ),
          );
        } else {
          _fail(options, handler, 401);
        }
      });
      expect(await AuthRepository(client: client).bootstrap(), isNull);
      expect(client.session, isNull);
    },
  );
}
