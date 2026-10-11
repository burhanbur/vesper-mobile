import '../../../core/network/api_client.dart';

class RegisteredDevice {
  final String id;
  final String name;
  final String platform;
  final String appVersion;

  const RegisteredDevice({
    required this.id,
    required this.name,
    required this.platform,
    required this.appVersion,
  });

  factory RegisteredDevice.fromJson(Map<String, dynamic> value) {
    if (value['id'] is! String ||
        value['name'] is! String ||
        value['platform'] is! String ||
        value['app_version'] is! String) {
      throw const ApiFailure('Respons perangkat tidak valid.');
    }
    return RegisteredDevice(
      id: value['id'] as String,
      name: value['name'] as String,
      platform: value['platform'] as String,
      appVersion: value['app_version'] as String,
    );
  }
}

class DevicesRepository {
  final ApiClient client;
  DevicesRepository({ApiClient? client}) : client = client ?? ApiClient.shared;

  Future<List<RegisteredDevice>> list() async {
    try {
      final rows = await client.list('/devices');
      return rows.map(RegisteredDevice.fromJson).toList(growable: false);
    } on TypeError {
      throw const ApiFailure('Respons perangkat tidak valid.');
    }
  }
}
