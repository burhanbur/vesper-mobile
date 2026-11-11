import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/core/network/api_client.dart';

void main() {
  group('AppState Profile Tests', () {
    test('updateProfile validates empty full name', () async {
      final state = AppState();
      expect(
        () => state.updateProfile(fullName: '   '),
        throwsA(isA<ApiFailure>().having((e) => e.message, 'message', contains('Nama lengkap tidak boleh kosong'))),
      );
    });

    test('updateProfile validates invalid phone number', () async {
      final state = AppState();
      expect(
        () => state.updateProfile(fullName: 'John Doe', phoneNumber: 'abc!'),
        throwsA(isA<ApiFailure>().having((e) => e.message, 'message', contains('Format nomor telepon tidak valid'))),
      );
    });

    test('updateProfile validates invalid gender', () async {
      final state = AppState();
      expect(
        () => state.updateProfile(fullName: 'John Doe', gender: 'Other'),
        throwsA(isA<ApiFailure>().having((e) => e.message, 'message', contains('Pilihan jenis kelamin tidak valid'))),
      );
    });
  });
}

