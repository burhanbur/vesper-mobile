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

  test('release accepts a configured HTTPS API endpoint', () {
    expect(
      AppEnvironment.validateApiBaseUrl(
        'https://api.vesper.test/api/v1',
        isRelease: true,
      ),
      'https://api.vesper.test/api/v1',
    );
  });

  test(
    'release rejects missing, insecure, local and placeholder endpoints',
    () {
      for (final url in [
        '',
        'http://api.vesper.test/api/v1',
        'https://localhost/api/v1',
        'https://127.0.0.1/api/v1',
        'https://[::1]/api/v1',
        'https://10.0.2.2/api/v1',
        'https://api.your-domain.invalid/api/v1',
      ]) {
        expect(
          () => AppEnvironment.validateApiBaseUrl(url, isRelease: true),
          throwsFormatException,
          reason: url,
        );
      }
    },
  );

  test(
    'explicit invalid configuration fails instead of loading defaults',
    () async {
      AppEnvironment.apiBaseUrl = 'not-a-url';
      await expectLater(AppEnvironment.load(), throwsFormatException);
    },
  );

  test(
    'API endpoints reject credentials, query, fragment and incorrect path',
    () {
      for (final url in [
        'https://user:password@api.vesper.test/api/v1',
        'https://api.vesper.test/api/v1?token=secret',
        'https://api.vesper.test/api/v1#fragment',
        'https://api.vesper.test',
        'https://api.vesper.test/api/v2',
      ]) {
        expect(
          () => AppEnvironment.validateApiBaseUrl(url),
          throwsFormatException,
          reason: url,
        );
      }
    },
  );
}
