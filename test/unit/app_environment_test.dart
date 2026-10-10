import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/core/config/app_environment.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    AppEnvironment.apiBaseUrl = '';
  });

  test(
    'Android startup loads emulator environment without dart defines',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AppEnvironment.apiBaseUrl = '';
      await AppEnvironment.load();
      expect(AppEnvironment.apiBaseUrl, 'http://10.0.2.2:3000/api/v1');
    },
  );

  test('explicit API URL takes precedence over bundled defaults', () async {
    AppEnvironment.apiBaseUrl = 'https://example.test/api/v1';
    await AppEnvironment.load();
    expect(AppEnvironment.apiBaseUrl, 'https://example.test/api/v1');
  });
}
