/// Exact cash settlement for the backend BUY/SELL command contract.
/// Values stay in decimal strings/BigInt, including on Flutter web.
class InvestmentSettlement {
  final String amount;
  final String ledgerType;

  const InvestmentSettlement._(this.amount, this.ledgerType);

  static final _precise = RegExp(r'^(0|[1-9]\d{0,11})(\.\d{1,8})?$');
  static final _fee = RegExp(r'^(0|[1-9]\d{0,17})(\.\d{1,2})?$');
  static final _cashDivisor = BigInt.from(10).pow(14);
  static final _maxCashMinor = BigInt.from(10).pow(20) - BigInt.one;

  static BigInt _parse(String value, RegExp pattern, int decimals) {
    // Check match length as well: `$` may match before a trailing newline.
    final match = pattern.firstMatch(value);
    if (match == null || match.end != value.length) {
      throw const FormatException('Format desimal investasi tidak valid.');
    }
    final parts = value.split('.');
    return BigInt.parse(parts.first) * BigInt.from(10).pow(decimals) +
        BigInt.parse(
          parts.length == 1 ? '0' : parts[1].padRight(decimals, '0'),
        );
  }

  static InvestmentSettlement calculate({
    required String type,
    required String quantity,
    required String pricePerUnit,
    String fee = '0',
  }) {
    if (type != 'BUY' && type != 'SELL') {
      throw const FormatException('Hanya BUY dan SELL yang didukung.');
    }
    final units = _parse(quantity, _precise, 8);
    final price = _parse(pricePerUnit, _precise, 8);
    final feeMinor = _parse(fee, _fee, 2);
    if (units == BigInt.zero || price == BigInt.zero) {
      throw const FormatException('Kuantitas dan harga harus positif.');
    }
    final gross = units * price;
    final scaledFee = feeMinor * _cashDivisor;
    final net = type == 'BUY' ? gross + scaledFee : gross - scaledFee;
    if (net <= BigInt.zero) {
      throw const FormatException('Nominal cash setelah fee harus positif.');
    }
    // Positive HALF_UP, applied once after fee, matching backend settlement.
    final minor = (net + _cashDivisor ~/ BigInt.two) ~/ _cashDivisor;
    if (minor == BigInt.zero || minor > _maxCashMinor) {
      throw const FormatException('Nominal cash di luar batas yang didukung.');
    }
    final whole = minor ~/ BigInt.from(100);
    final fraction = (minor % BigInt.from(100)).toString().padLeft(2, '0');
    return InvestmentSettlement._(
      '$whole.$fraction',
      type == 'BUY' ? 'EXPENSE' : 'INCOME',
    );
  }
}
