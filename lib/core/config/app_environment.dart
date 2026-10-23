import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AppEnvironment {
  static String apiBaseUrl = const String.fromEnvironment('API_BASE_URL');

  static Future<void> load() async {
    if (apiBaseUrl.isNotEmpty || kReleaseMode) {
      apiBaseUrl = validateApiBaseUrl(apiBaseUrl, isRelease: kReleaseMode);
      return;
    }
    final file = kIsWeb || defaultTargetPlatform != TargetPlatform.android
        ? 'env/web.json'
        : 'env/development.json';
    final values =
        jsonDecode(await rootBundle.loadString(file)) as Map<String, dynamic>;
    final value = values['API_BASE_URL'];
    apiBaseUrl = validateApiBaseUrl(value is String ? value : '');
  }

  static String validateApiBaseUrl(String value, {bool isRelease = false}) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.host.isEmpty ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path != '/api/v1' && uri.path != '/api/v1/')) {
      throw const FormatException('API_BASE_URL tidak valid.');
    }
    if (isRelease &&
        (uri.scheme != 'https' ||
            uri.host == 'localhost' ||
            uri.host == '127.0.0.1' ||
            uri.host == '::1' ||
            uri.host == '10.0.2.2' ||
            uri.host.endsWith('.invalid'))) {
      throw const FormatException(
        'Release membutuhkan API_BASE_URL production dengan HTTPS.',
      );
    }
    return value;
  }
}
