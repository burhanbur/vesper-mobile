import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'device_info_stub.dart' if (dart.library.js_interop) 'device_info_web.dart';

class DeviceInfoService {
  DeviceInfoService._();

  static const MethodChannel _channel = MethodChannel('vesper/device_info');
  static final Map<TargetPlatform, String> _cachedNativeNames = {};

  /// Resolves a descriptive, user-friendly device name (max 120 chars), e.g.:
  /// - "Samsung Galaxy S10 • Android 12"
  /// - "iPhone 15 Pro • iOS 18.0"
  /// - "Chrome • Windows"
  static Future<String> resolveDeviceName() async {
    if (kIsWeb) {
      return formatWebName(readWebUserAgent());
    }

    final platform = defaultTargetPlatform;
    final cached = _cachedNativeNames[platform];
    if (cached != null) return cached;

    try {
      final raw = await _channel.invokeMethod<dynamic>('getDeviceInfo');
      if (raw is Map) {
        final map = raw.map((k, v) => MapEntry(k.toString(), v));
        final resolved = platform == TargetPlatform.iOS
            ? formatIosName(
                deviceName: map['deviceName']?.toString(),
                modelIdentifier: map['model']?.toString(),
                fallbackModel: map['fallbackModel']?.toString(),
                osVersion: map['osVersion']?.toString(),
                isEmulator: map['isEmulator'] == true,
              )
            : formatAndroidName(
                deviceName: map['deviceName']?.toString(),
                manufacturer: map['manufacturer']?.toString(),
                brand: map['brand']?.toString(),
                model: map['model']?.toString(),
                osVersion: map['osVersion']?.toString(),
                isEmulator: map['isEmulator'] == true,
              );
        _cachedNativeNames[platform] = resolved;
        return resolved;
      }
    } catch (_) {
      // Fallback safely when running in unit tests or unsupported embedders.
    }

    return platform == TargetPlatform.iOS
        ? 'Perangkat iOS'
        : 'Perangkat Android';
  }

  @visibleForTesting
  static void clearCache() => _cachedNativeNames.clear();

  @visibleForTesting
  static String formatAndroidName({
    String? deviceName,
    String? manufacturer,
    String? brand,
    String? model,
    String? osVersion,
    bool isEmulator = false,
  }) {
    final cleanDeviceName = _clean(deviceName);
    final cleanModel = _clean(model);
    final cleanOs = _clean(osVersion);
    final cleanBrand = _normalizeBrand(_clean(brand));
    final cleanMfr = _normalizeBrand(_clean(manufacturer));
    final primaryBrand = _pickBrand(cleanMfr, cleanBrand);

    String primaryName;
    if (isEmulator) {
      if (cleanDeviceName.isNotEmpty &&
          !cleanDeviceName.toLowerCase().startsWith('sdk_gphone') &&
          cleanDeviceName.toLowerCase() != 'android') {
        primaryName = '$cleanDeviceName (Emulator)';
      } else {
        primaryName = 'Android Emulator';
      }
    } else {
      final mappedModel = _lookupAndroidMarketingName(cleanMfr, cleanModel);
      final hardwareLabel = _buildHardwareLabel(
        brand: primaryBrand,
        model: mappedModel ?? cleanModel,
      );

      if (cleanDeviceName.isNotEmpty &&
          cleanDeviceName.toLowerCase() != cleanModel.toLowerCase() &&
          cleanDeviceName.toLowerCase() != 'android' &&
          cleanDeviceName.toLowerCase() != 'localhost') {
        final lowerName = cleanDeviceName.toLowerCase();
        final lowerBrand = primaryBrand.toLowerCase();
        final lowerMfr = cleanMfr.toLowerCase();
        if ((lowerBrand.isNotEmpty && lowerName.contains(lowerBrand)) ||
            (lowerMfr.isNotEmpty && lowerName.contains(lowerMfr))) {
          primaryName = cleanDeviceName;
        } else if (_isMarketingNameForBrand(primaryBrand, cleanDeviceName)) {
          primaryName = '$primaryBrand $cleanDeviceName';
        } else if (hardwareLabel.isNotEmpty &&
            !hardwareLabel.toLowerCase().contains(lowerName)) {
          primaryName = '$cleanDeviceName ($hardwareLabel)';
        } else {
          primaryName = cleanDeviceName;
        }
      } else if (hardwareLabel.isNotEmpty) {
        primaryName = hardwareLabel;
      } else {
        primaryName = 'Perangkat Android';
      }
    }

    final withOs = cleanOs.isNotEmpty
        ? '$primaryName • Android $cleanOs'
        : primaryName;
    return _truncate(withOs, 120);
  }

  @visibleForTesting
  static String formatIosName({
    String? deviceName,
    String? modelIdentifier,
    String? fallbackModel,
    String? osVersion,
    bool isEmulator = false,
  }) {
    final cleanName = _clean(deviceName);
    final cleanId = _clean(modelIdentifier);
    final cleanFallback = _clean(fallbackModel);
    final cleanOs = _clean(osVersion);

    String primaryName;
    if (isEmulator) {
      primaryName = 'iOS Simulator';
    } else {
      final mapped = _iosModelNames[cleanId];
      if (mapped != null) {
        if (cleanName.isNotEmpty &&
            cleanName.toLowerCase() != 'iphone' &&
            cleanName.toLowerCase() != 'ipad' &&
            !cleanName.toLowerCase().contains(mapped.toLowerCase())) {
          primaryName = '$cleanName ($mapped)';
        } else {
          primaryName = mapped;
        }
      } else if (cleanName.isNotEmpty &&
          cleanName.toLowerCase() != 'iphone' &&
          cleanName.toLowerCase() != 'ipad') {
        primaryName = cleanName;
      } else if (cleanFallback.isNotEmpty) {
        primaryName = cleanFallback;
      } else {
        primaryName = 'Perangkat iOS';
      }
    }

    final withOs = cleanOs.isNotEmpty
        ? '$primaryName • iOS $cleanOs'
        : primaryName;
    return _truncate(withOs, 120);
  }

  @visibleForTesting
  static String formatWebName(String? userAgent) {
    final ua = _clean(userAgent);
    if (ua.isEmpty) return 'Vesper Web';

    final browser = _detectBrowser(ua);
    final os = _detectWebOs(ua);
    if (browser != null && os != null) {
      return _truncate('$browser • $os', 120);
    }
    if (browser != null) return _truncate('$browser • Web', 120);
    if (os != null) return _truncate('Browser • $os', 120);
    return 'Vesper Web';
  }

  static String _clean(String? value) => value?.trim() ?? '';

  static String _truncate(String value, int maxLength) {
    final trimmed = value.trim();
    if (trimmed.length <= maxLength) return trimmed;
    return trimmed.substring(0, maxLength).trimRight();
  }

  static String _normalizeBrand(String raw) {
    if (raw.isEmpty) return '';
    const known = <String, String>{
      'samsung': 'Samsung',
      'google': 'Google',
      'xiaomi': 'Xiaomi',
      'redmi': 'Redmi',
      'poco': 'POCO',
      'oppo': 'OPPO',
      'vivo': 'vivo',
      'realme': 'realme',
      'oneplus': 'OnePlus',
      'huawei': 'Huawei',
      'honor': 'HONOR',
      'asus': 'ASUS',
      'sony': 'Sony',
      'motorola': 'Motorola',
      'nokia': 'Nokia',
      'nothing': 'Nothing',
      'infinix': 'Infinix',
      'tecno': 'TECNO',
      'itel': 'itel',
      'lenovo': 'Lenovo',
      'lg': 'LG',
      'htc': 'HTC',
      'zte': 'ZTE',
      'apple': 'Apple',
    };
    final lower = raw.toLowerCase();
    if (known.containsKey(lower)) return known[lower]!;
    return '${raw[0].toUpperCase()}${raw.substring(1)}';
  }

  static String _pickBrand(String manufacturer, String brand) {
    // Sub-brands like Redmi / POCO are more recognizable than "Xiaomi".
    const preferredSubBrands = {'Redmi', 'POCO', 'IQOO', 'iQOO'};
    if (preferredSubBrands.contains(brand)) return brand;
    if (manufacturer.isNotEmpty) return manufacturer;
    return brand;
  }

  static String _buildHardwareLabel({
    required String brand,
    required String model,
  }) {
    if (model.isEmpty) return brand;
    if (brand.isEmpty) return model;
    if (model.toLowerCase().startsWith(brand.toLowerCase())) {
      return model;
    }
    return '$brand $model';
  }

  static bool _isMarketingNameForBrand(String brand, String deviceName) {
    final lowerBrand = brand.toLowerCase();
    final lowerName = deviceName.toLowerCase();
    if (lowerBrand == 'samsung' && lowerName.startsWith('galaxy')) return true;
    if (lowerBrand == 'google' && lowerName.startsWith('pixel')) return true;
    if (lowerBrand == 'sony' && lowerName.startsWith('xperia')) return true;
    if (lowerBrand == 'asus' &&
        (lowerName.startsWith('zenfone') || lowerName.startsWith('rog'))) {
      return true;
    }
    if (lowerBrand == 'oppo' &&
        (lowerName.startsWith('reno') || lowerName.startsWith('find'))) {
      return true;
    }
    if (lowerBrand == 'xiaomi' &&
        (lowerName.startsWith('mi ') ||
            lowerName.startsWith('redmi') ||
            lowerName.startsWith('poco'))) {
      return lowerName.startsWith('mi ');
    }
    return false;
  }

  static String? _lookupAndroidMarketingName(
    String manufacturer,
    String model,
  ) {
    if (model.isEmpty) return null;
    if (manufacturer.toLowerCase() == 'samsung') {
      final upper = model.toUpperCase();
      for (final entry in _samsungModelPrefixes.entries) {
        if (upper.startsWith(entry.key)) return entry.value;
      }
    }
    return null;
  }

  static String? _detectBrowser(String ua) {
    if (ua.contains('Edg/') || ua.contains('EdgA/') || ua.contains('EdgiOS/')) {
      return 'Microsoft Edge';
    }
    if (ua.contains('OPR/') || ua.contains('Opera')) return 'Opera';
    if (ua.contains('SamsungBrowser/')) return 'Samsung Internet';
    if (ua.contains('Firefox/') || ua.contains('FxiOS/')) return 'Firefox';
    if (ua.contains('Chrome/') || ua.contains('CriOS/')) return 'Chrome';
    if (ua.contains('Safari/')) return 'Safari';
    return null;
  }

  static String? _detectWebOs(String ua) {
    if (ua.contains('Windows')) return 'Windows';
    if (ua.contains('Android')) return 'Android';
    if (ua.contains('iPhone') || ua.contains('iPad')) return 'iOS';
    if (ua.contains('Mac OS X') || ua.contains('Macintosh')) return 'macOS';
    if (ua.contains('CrOS')) return 'ChromeOS';
    if (ua.contains('Linux')) return 'Linux';
    return null;
  }

  static const Map<String, String> _samsungModelPrefixes = {
    'SM-G970': 'Galaxy S10e',
    'SM-G973': 'Galaxy S10',
    'SM-G975': 'Galaxy S10+',
    'SM-G977': 'Galaxy S10 5G',
    'SM-G980': 'Galaxy S20',
    'SM-G981': 'Galaxy S20 5G',
    'SM-G985': 'Galaxy S20+',
    'SM-G986': 'Galaxy S20+ 5G',
    'SM-G988': 'Galaxy S20 Ultra',
    'SM-G990': 'Galaxy S21 FE',
    'SM-G991': 'Galaxy S21',
    'SM-G996': 'Galaxy S21+',
    'SM-G998': 'Galaxy S21 Ultra',
    'SM-S901': 'Galaxy S22',
    'SM-S906': 'Galaxy S22+',
    'SM-S908': 'Galaxy S22 Ultra',
    'SM-S911': 'Galaxy S23',
    'SM-S916': 'Galaxy S23+',
    'SM-S918': 'Galaxy S23 Ultra',
    'SM-S711': 'Galaxy S23 FE',
    'SM-S921': 'Galaxy S24',
    'SM-S926': 'Galaxy S24+',
    'SM-S928': 'Galaxy S24 Ultra',
    'SM-S721': 'Galaxy S24 FE',
    'SM-S931': 'Galaxy S25',
    'SM-S936': 'Galaxy S25+',
    'SM-S938': 'Galaxy S25 Ultra',
    'SM-N970': 'Galaxy Note10',
    'SM-N975': 'Galaxy Note10+',
    'SM-N980': 'Galaxy Note20',
    'SM-N981': 'Galaxy Note20 5G',
    'SM-N985': 'Galaxy Note20 Ultra',
    'SM-N986': 'Galaxy Note20 Ultra 5G',
    'SM-A525': 'Galaxy A52',
    'SM-A528': 'Galaxy A52s 5G',
    'SM-A536': 'Galaxy A53 5G',
    'SM-A546': 'Galaxy A54 5G',
    'SM-A556': 'Galaxy A55 5G',
    'SM-A566': 'Galaxy A56 5G',
    'SM-A346': 'Galaxy A34 5G',
    'SM-A356': 'Galaxy A35 5G',
    'SM-F936': 'Galaxy Z Fold4',
    'SM-F946': 'Galaxy Z Fold5',
    'SM-F956': 'Galaxy Z Fold6',
    'SM-F721': 'Galaxy Z Flip4',
    'SM-F731': 'Galaxy Z Flip5',
    'SM-F741': 'Galaxy Z Flip6',
  };

  static const Map<String, String> _iosModelNames = {
    'iPhone13,1': 'iPhone 12 mini',
    'iPhone13,2': 'iPhone 12',
    'iPhone13,3': 'iPhone 12 Pro',
    'iPhone13,4': 'iPhone 12 Pro Max',
    'iPhone14,2': 'iPhone 13 Pro',
    'iPhone14,3': 'iPhone 13 Pro Max',
    'iPhone14,4': 'iPhone 13 mini',
    'iPhone14,5': 'iPhone 13',
    'iPhone14,6': 'iPhone SE (3rd gen)',
    'iPhone14,7': 'iPhone 14',
    'iPhone14,8': 'iPhone 14 Plus',
    'iPhone15,2': 'iPhone 14 Pro',
    'iPhone15,3': 'iPhone 14 Pro Max',
    'iPhone15,4': 'iPhone 15',
    'iPhone15,5': 'iPhone 15 Plus',
    'iPhone16,1': 'iPhone 15 Pro',
    'iPhone16,2': 'iPhone 15 Pro Max',
    'iPhone17,1': 'iPhone 16 Pro',
    'iPhone17,2': 'iPhone 16 Pro Max',
    'iPhone17,3': 'iPhone 16',
    'iPhone17,4': 'iPhone 16 Plus',
    'iPhone17,5': 'iPhone 16e',
  };
}
