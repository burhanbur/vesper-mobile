import '../../../core/network/api_client.dart';

/// Server identity only; credentials remain inside ApiClient/secure storage.
class AuthUser {
  final String id;
  final String name;
  final String email;
  final String status;
  final List<String> roles;

  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.status,
    required this.roles,
  });

  factory AuthUser.fromJson(dynamic value) {
    if (value is! Map ||
        value['id'] is! String ||
        (value['id'] as String).isEmpty ||
        value['name'] is! String ||
        value['email'] is! String ||
        value['status'] is! String ||
        value['roles'] is! List ||
        !(value['roles'] as List).every((role) => role is String)) {
      throw const ApiFailure('Respons pengguna tidak valid.');
    }
    return AuthUser(
      id: value['id'] as String,
      name: value['name'] as String,
      email: value['email'] as String,
      status: value['status'] as String,
      roles: List<String>.unmodifiable(value['roles'] as List),
    );
  }
}

/// Share this client with bootstrap and financial repositories so refresh/logout
/// operate on the same session. Inject a client for isolated tests.
class AuthRepository {
  final ApiClient client;
  bool _rememberMe = false;
  bool get rememberMe => _rememberMe;

  AuthRepository({ApiClient? client}) : client = client ?? ApiClient.shared;

  Future<void> setRememberMe(bool value) async {
    final session = client.session;
    if (session == null) {
      throw const ApiFailure('Silakan masuk kembali.', statusCode: 401);
    }
    await client.saveSession(session, persist: value);
    _rememberMe = value;
  }

  Future<AuthUser> authenticate({
    required String email,
    required String password,
    String? name,
    bool rememberMe = true,
  }) async {
    final data = await client.authenticate(
      name == null ? 'login' : 'register',
      {
        'email': email.trim().toLowerCase(),
        'password': password,
        if (name != null) 'name': name.trim(),
      },
      persist: rememberMe,
    );
    try {
      final user = AuthUser.fromJson(data['user']);
      _rememberMe = rememberMe;
      return user;
    } on ApiFailure {
      await client.clearSession();
      rethrow;
    }
  }

  /// Restore and validate identity before AppState enters the authenticated flow.
  /// Null means no valid session. Other failures must not be treated as login
  /// success; callers can present retry/offline UI without fabricating identity.
  Future<AuthUser?> bootstrap() async {
    if (client.session == null) {
      await client.restore();
      _rememberMe = client.session != null;
    }
    if (client.session == null) return null;
    final expiry = DateTime.parse(
      client.session!['refresh_expires_at'] as String,
    );
    if (!expiry.isAfter(DateTime.now().toUtc())) {
      await client.clearSession();
      return null;
    }
    try {
      return await currentUser();
    } on ApiFailure catch (error) {
      if (error.statusCode == 401 || client.session == null) return null;
      rethrow;
    }
  }

  Future<AuthUser> currentUser() async {
    final data = await client.request('GET', '/auth/me');
    final user = AuthUser.fromJson(data);
    final session = client.session;
    if (session != null) {
      await client.saveSession({...session, 'user': data});
    }
    return user;
  }

  /// Revoke the current server session; always remove local credentials.
  Future<void> logout() async {
    try {
      if (client.session != null) {
        await client.request('POST', '/auth/logout', retry: false);
      }
    } finally {
      _rememberMe = false;
      await client.clearSession();
    }
  }
}
