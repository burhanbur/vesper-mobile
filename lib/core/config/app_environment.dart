import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AppEnvironment {
  static String apiBaseUrl = const String.fromEnvironment('API_BASE_URL');

  static Future<void> load() async {
    if (apiBaseUrl.isNotEmpty || kReleaseMode) return;
    final file = kIsWeb || defaultTargetPlatform != TargetPlatform.android
        ? 'env/web.json'
        : 'env/development.json';
    final values =
        jsonDecode(await rootBundle.loadString(file)) as Map<String, dynamic>;
    final value = values['API_BASE_URL'];
    final uri = value is String ? Uri.tryParse(value) : null;
    if (uri == null ||
        !uri.hasAuthority ||
        !['http', 'https'].contains(uri.scheme)) {
      throw const FormatException('API_BASE_URL tidak valid.');
    }
    apiBaseUrl = value as String;
  }
}
