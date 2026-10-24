import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/app_environment.dart';

class ApiFailure implements Exception {
  final String message;
  final int? statusCode;
  final bool isTransient;
  final Duration? retryAfter;
  final String? code;
  const ApiFailure(
    this.message, {
    this.statusCode,
    this.isTransient = false,
    this.retryAfter,
    this.code,
  });
  @override
  String toString() => message;
}

/// The URL includes /api/v1. Load API_BASE_URL with --dart-define-from-file.
class ApiClient {
  static final shared = ApiClient();
  static const _sessionKey = 'vesper.session';
  final Dio dio;
  final FlutterSecureStorage storage;
  Map<String, dynamic>? session;
  Future<void>? _refreshing;
  bool _persistSession = true;
  bool get isSessionPersisted => session != null && _persistSession;

  ApiClient({Dio? dio, FlutterSecureStorage? storage})
    : dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: AppEnvironment.apiBaseUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
            ),
          ),
      storage = storage ?? const FlutterSecureStorage();

  Future<void> restore() async {
    final value = await storage.read(key: _sessionKey);
    if (value == null) return;
    try {
      final decoded = jsonDecode(value);
      session = _validatedSession(decoded);
      _persistSession = true;
    } on FormatException {
      await clearSession();
    } on ApiFailure {
      await clearSession();
    }
  }

  static Map<String, dynamic> _validatedSession(dynamic value) {
    if (value is! Map<String, dynamic> ||
        value['access_token'] is! String ||
        (value['access_token'] as String).isEmpty ||
        value['refresh_token'] is! String ||
        (value['refresh_token'] as String).isEmpty ||
        value['user'] is! Map<String, dynamic> ||
        value['token_type'] != 'Bearer' ||
        DateTime.tryParse(value['expires_at']?.toString() ?? '') == null ||
        DateTime.tryParse(value['refresh_expires_at']?.toString() ?? '') ==
            null) {
      throw const ApiFailure('Respons sesi tidak valid.');
    }
    final user = value['user'] as Map<String, dynamic>;
    if (user['id'] is! String ||
        user['name'] is! String ||
        user['email'] is! String) {
      throw const ApiFailure('Respons pengguna tidak valid.');
    }
    return Map<String, dynamic>.from(value);
  }

  Future<void> saveSession(Map<String, dynamic> value, {bool? persist}) async {
    final validated = _validatedSession(value);
    final shouldPersist = persist ?? _persistSession;
    if (shouldPersist) {
      await storage.write(key: _sessionKey, value: jsonEncode(validated));
    } else {
      await storage.delete(key: _sessionKey);
    }
    _persistSession = shouldPersist;
    session = validated;
  }

  Future<void> clearSession() async {
    session = null;
    await storage.delete(key: _sessionKey);
  }

  Future<Map<String, dynamic>> authenticate(
    String action,
    Map<String, dynamic> body, {
    bool persist = true,
  }) async {
    if (action != 'login' && action != 'register') {
      throw ArgumentError.value(action, 'action');
    }
    final data = await request(
      'POST',
      '/auth/$action',
      body: body,
      authenticated: false,
    );
    final value = _validatedSession(data);
    await saveSession(value, persist: persist);
    return value;
  }

  Future<void> _refresh() async {
    final previous = session;
    final token = previous?['refresh_token'];
    if (token == null) {
      throw const ApiFailure('Silakan masuk kembali.', statusCode: 401);
    }
    final expiry = DateTime.tryParse('${previous?['refresh_expires_at']}');
    if (expiry == null || !expiry.isAfter(DateTime.now().toUtc())) {
      if (identical(session, previous)) await clearSession();
      throw const ApiFailure('Silakan masuk kembali.', statusCode: 401);
    }
    try {
      final data = await request(
        'POST',
        '/auth/refresh',
        body: {'refresh_token': token},
        authenticated: false,
      );
      // Do not resurrect a logged-out session or overwrite a newer login.
      if (identical(session, previous)) {
        await saveSession(_validatedSession(data));
      }
    } on ApiFailure catch (error) {
      // Only an explicit invalid/revoked session response removes credentials.
      if (error.statusCode == 401 && identical(session, previous)) {
        await clearSession();
      }
      rethrow;
    }
  }

  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    bool authenticated = true,
    bool retry = true,
  }) async {
    if (dio.options.baseUrl.isEmpty) {
      throw const ApiFailure('API_BASE_URL belum dikonfigurasi.');
    }
    final accessToken = authenticated ? (session?['access_token']) : null;
    try {
      final response = await dio.request<dynamic>(
        path,
        data: body,
        queryParameters: query,
        options: Options(
          method: method,
          headers: {
            if (accessToken != null) 'Authorization': 'Bearer $accessToken',
          },
        ),
      );
      final envelope = response.data;
      if (envelope is! Map) throw const ApiFailure('Respons API tidak valid.');
      if (envelope['success'] != true) {
        throw ApiFailure('Permintaan gagal.', statusCode: response.statusCode);
      }
      return envelope['data'];
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      // Older API envelopes expose this sync condition only as a stable public
      // message. Recognize it narrowly; other validation errors must not replay.
      final payload = error.response?.data;
      final cursorAhead =
          status == 422 &&
          path == '/sync/pull' &&
          payload is Map &&
          payload['success'] == false &&
          payload['message'] == 'Cursor sinkronisasi melebihi versi server.';
      if (authenticated &&
          retry &&
          status == 401 &&
          session != null &&
          path != '/auth/logout') {
        // A late 401 for the old token must not rotate the new token again.
        if (session?['access_token'] == accessToken) {
          final refresh = _refreshing ??= _refresh();
          try {
            await refresh;
          } finally {
            if (identical(_refreshing, refresh)) _refreshing = null;
          }
        }
        if (session == null) {
          throw const ApiFailure('Silakan masuk kembali.', statusCode: 401);
        }
        return request(method, path, body: body, query: query, retry: false);
      }
      if (authenticated &&
          status == 401 &&
          session?['access_token'] == accessToken) {
        await clearSession();
      }
      // Never expose transport exceptions, request bodies, or server debug data.
      throw ApiFailure(
        cursorAhead
            ? 'Posisi sinkronisasi perangkat lebih tinggi daripada versi server.'
            : switch (status) {
                400 || 422 =>
                  'Permintaan tidak valid. Periksa data yang Anda masukkan.',
                401 => 'Email atau kata sandi salah, atau sesi telah berakhir.',
                403 => 'Anda tidak memiliki akses untuk tindakan ini.',
                409 => 'Data sudah digunakan atau bertentangan dengan data yang ada.',
                429 => 'Server sedang membatasi permintaan. Silakan coba lagi nanti.',
                _ => 'Backend tidak dapat dihubungi. Silakan coba lagi.',
              },
        statusCode: status,
        code: cursorAhead ? 'SYNC_CURSOR_AHEAD' : null,
        retryAfter: status == 429
            ? Duration(
                seconds:
                    (int.tryParse(
                              error.response?.headers.value('retry-after') ??
                                  '',
                            ) ??
                            60)
                        .clamp(1, 604800),
              )
            : null,
        isTransient:
            status == 408 ||
            status == 429 ||
            (status != null && status >= 500 && status <= 599) ||
            (status == null &&
                {
                  DioExceptionType.connectionTimeout,
                  DioExceptionType.sendTimeout,
                  DioExceptionType.receiveTimeout,
                  DioExceptionType.connectionError,
                }.contains(error.type)),
      );
    }
  }

  /// Load a complete snapshot or fail; never return a truncated cache update.
  Future<List<Map<String, dynamic>>> list(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    const pageSize = 100;
    const maxPages = 1000;
    final result = <Map<String, dynamic>>[];
    final seenIds = <String>{};
    for (var page = 1; page <= maxPages; page++) {
      final data = await request(
        'GET',
        path,
        query: {...?query, 'page': page, 'limit': pageSize},
      );
      if (data is! List || data.length > pageSize) {
        throw const ApiFailure('Respons daftar API tidak valid.');
      }
      for (final item in data) {
        if (item is! Map || item.keys.any((key) => key is! String)) {
          throw const ApiFailure('Respons daftar API tidak valid.');
        }
        final row = Map<String, dynamic>.from(item);
        final id = row['id'] ?? row['user_id'];
        if (id is! String || id.isEmpty || !seenIds.add(id)) {
          throw const ApiFailure(
            'Daftar berubah atau halaman berulang. Silakan muat ulang.',
          );
        }
        result.add(row);
      }
      if (data.length < pageSize) return result;
    }
    throw const ApiFailure(
      'Data terlalu besar untuk dimuat sekaligus. Cache sebelumnya tetap tersedia.',
    );
  }
}
