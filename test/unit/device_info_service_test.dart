import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/core/device/device_info_service.dart';

void main() {
  group('DeviceInfoService.formatAndroidName', () {
    test('formats Samsung Galaxy S10 with friendly device name and OS', () {
      expect(
        DeviceInfoService.formatAndroidName(
          deviceName: 'Galaxy S10',
          manufacturer: 'samsung',
          brand: 'samsung',
          model: 'SM-G973F',
          osVersion: '12',
        ),
        'Samsung Galaxy S10 • Android 12',
      );
    });

    test('resolves Samsung model code when device name is absent or raw', () {
      expect(
        DeviceInfoService.formatAndroidName(
          deviceName: 'SM-G973F',
          manufacturer: 'samsung',
          brand: 'samsung',
          model: 'SM-G973F',
          osVersion: '12',
        ),
        'Samsung Galaxy S10 • Android 12',
      );
    });

    test('preserves custom user device name alongside resolved model', () {
      expect(
        DeviceInfoService.formatAndroidName(
          deviceName: 'HP Burhan',
          manufacturer: 'samsung',
          brand: 'samsung',
          model: 'SM-G973F',
          osVersion: '12',
        ),
        'HP Burhan (Samsung Galaxy S10) • Android 12',
      );
    });

    test('does not duplicate brand name for Redmi / Google Pixel', () {
      expect(
        DeviceInfoService.formatAndroidName(
          deviceName: 'Redmi Note 12',
          manufacturer: 'Xiaomi',
          brand: 'Redmi',
          model: '23021RAA2Y',
          osVersion: '13',
        ),
        'Redmi Note 12 • Android 13',
      );
      expect(
        DeviceInfoService.formatAndroidName(
          deviceName: 'Pixel 8',
          manufacturer: 'Google',
          brand: 'google',
          model: 'Pixel 8',
          osVersion: '14',
        ),
        'Google Pixel 8 • Android 14',
      );
    });

    test('formats emulator cleanly and enforces 120 character limit', () {
      expect(
        DeviceInfoService.formatAndroidName(
          deviceName: 'sdk_gphone64_x86_64',
          manufacturer: 'Google',
          brand: 'google',
          model: 'sdk_gphone64_x86_64',
          osVersion: '14',
          isEmulator: true,
        ),
        'Android Emulator • Android 14',
      );
      final longName = DeviceInfoService.formatAndroidName(
        deviceName: 'A' * 150,
        manufacturer: 'samsung',
        model: 'SM-G973F',
        osVersion: '12',
      );
      expect(longName.length, lessThanOrEqualTo(120));
    });
  });

  group('DeviceInfoService.formatIosName', () {
    test('maps iPhone model identifiers cleanly', () {
      expect(
        DeviceInfoService.formatIosName(
          deviceName: 'iPhone',
          modelIdentifier: 'iPhone16,1',
          fallbackModel: 'iPhone',
          osVersion: '18.0',
        ),
        'iPhone 15 Pro • iOS 18.0',
      );
    });
  });

  group('DeviceInfoService.formatWebName', () {
    test('extracts browser and OS from user agent', () {
      expect(
        DeviceInfoService.formatWebName(
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/130.0.0.0 Safari/537.36',
        ),
        'Chrome • Windows',
      );
      expect(DeviceInfoService.formatWebName(null), 'Vesper Web');
    });
  });
}
