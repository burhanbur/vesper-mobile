import '../../../core/network/api_client.dart';

const maxSafeRupiah = 9007199254740991;

int parseAdjustmentTarget(String text) {
  if (!RegExp(r'^-?\d+$').hasMatch(text.trim())) {
    throw const ApiFailure('Masukkan Rupiah bulat tanpa pemisah.');
  }
  final value = BigInt.parse(text.trim());
  if (value.abs() > BigInt.from(maxSafeRupiah)) {
    throw const ApiFailure('Nominal melampaui batas presisi aman.');
  }
  return value.toInt();
}

int adjustmentDifference(int current, int target) {
  if (BigInt.from(current).abs() > BigInt.from(maxSafeRupiah) ||
      BigInt.from(target).abs() > BigInt.from(maxSafeRupiah)) {
    throw const ApiFailure('Saldo melampaui batas presisi aman.');
  }
  final delta = BigInt.from(target) - BigInt.from(current);
  if (delta.abs() > BigInt.from(maxSafeRupiah)) {
    throw const ApiFailure('Selisih melampaui batas presisi aman.');
  }
  return delta.toInt();
}
