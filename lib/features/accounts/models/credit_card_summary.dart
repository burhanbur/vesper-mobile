/// Exact minor-unit arithmetic for raw account decimal strings.
BigInt accountMinor(String value) {
  if (!RegExp(r'^-?\d+(?:\.\d{1,2})?$').hasMatch(value)) {
    throw const FormatException('Nominal akun tidak valid.');
  }
  final negative = value.startsWith('-');
  final parts = value.replaceFirst('-', '').split('.');
  final minor =
      BigInt.parse(parts.first) * BigInt.from(100) +
      BigInt.parse(parts.length == 1 ? '0' : parts[1].padRight(2, '0'));
  return negative ? -minor : minor;
}

String accountDecimal(BigInt value) {
  final digits = value.abs().toString().padLeft(3, '0');
  return '${value.isNegative ? '-' : ''}${digits.substring(0, digits.length - 2)}.${digits.substring(digits.length - 2)}';
}

/// Whole-IDR input deliberately rejects fractions instead of removing punctuation.
String? creditLimitInput(String input) {
  final value = input.trim();
  if (value.isEmpty) return null;
  if (!RegExp(r'^\d+$').hasMatch(value) || BigInt.parse(value) <= BigInt.zero) {
    throw const FormatException(
      'Limit harus berupa Rupiah utuh positif tanpa pemisah.',
    );
  }
  return '${BigInt.parse(value)}.00';
}

class CreditCardSummary {
  final BigInt balance;
  final BigInt? limit;
  CreditCardSummary(String balance, String? limit)
    : balance = accountMinor(balance),
      limit = limit == null ? null : accountMinor(limit);
  BigInt get debt => balance.isNegative ? -balance : BigInt.zero;
  BigInt get overpayment => balance.isNegative ? BigInt.zero : balance;
  BigInt? get remaining => limit == null ? null : limit! - debt;
}
