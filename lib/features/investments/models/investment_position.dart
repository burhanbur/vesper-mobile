/// A validated position-changing trade, independent of double-based UI models.
class InvestmentPositionTrade {
  final String type;
  final BigInt _quantity;
  final BigInt _price;

  InvestmentPositionTrade._(this.type, this._quantity, this._price);

  factory InvestmentPositionTrade({
    required String type,
    required String quantity,
    required String pricePerUnit,
  }) {
    if (type != 'BUY' && type != 'SELL') {
      throw const FormatException('Hanya BUY dan SELL yang didukung.');
    }
    final units = _parsePrecise(quantity);
    final price = _parsePrecise(pricePerUnit);
    if (units == BigInt.zero || price == BigInt.zero) {
      throw const FormatException('Kuantitas dan harga harus positif.');
    }
    return InvestmentPositionTrade._(type, units, price);
  }
}

final _scale = BigInt.from(10).pow(8);
final _maxPrecise = BigInt.from(10).pow(20) - BigInt.one;
final _maxCash = BigInt.from(10).pow(20) - BigInt.one;
final _precisePattern = RegExp(r'^(0|[1-9]\d{0,11})(\.\d{1,8})?$');

BigInt _parsePrecise(String value) {
  final match = _precisePattern.firstMatch(value);
  if (match == null || match.end != value.length) {
    throw const FormatException('Format desimal investasi tidak valid.');
  }
  final parts = value.split('.');
  return BigInt.parse(parts.first) * _scale +
      BigInt.parse(parts.length == 1 ? '0' : parts[1].padRight(8, '0'));
}

// HALF_UP away from zero also handles negative unrealized P/L.
BigInt _round(BigInt numerator, BigInt denominator) {
  final magnitude =
      (numerator.abs() + denominator ~/ BigInt.two) ~/ denominator;
  return numerator.isNegative ? -magnitude : magnitude;
}

String _format(BigInt value, int decimals) {
  final scale = BigInt.from(10).pow(decimals);
  final magnitude = value.abs();
  return '${value.isNegative ? '-' : ''}${magnitude ~/ scale}.'
      '${(magnitude % scale).toString().padLeft(decimals, '0')}';
}

/// Exact moving-average projection from a COMPLETE, chronologically ordered
/// history. Never initialize this from rounded holdings or a partial sync page.
/// Fees affect cash settlement, not the weighted purchase price.
class InvestmentPosition {
  final BigInt _quantity;
  // Rational average in price's 1e-8 units; never round between trades.
  final BigInt _averageNumerator;
  final BigInt _averageDenominator;

  InvestmentPosition._(this._quantity, BigInt numerator, BigInt denominator)
    : _averageNumerator = numerator ~/ numerator.gcd(denominator),
      _averageDenominator = denominator ~/ numerator.gcd(denominator);

  factory InvestmentPosition.empty() =>
      InvestmentPosition._(BigInt.zero, BigInt.zero, BigInt.one);

  /// The caller must establish history completeness and backend ordering.
  factory InvestmentPosition.replay(Iterable<InvestmentPositionTrade> trades) =>
      trades.fold(
        InvestmentPosition.empty(),
        (position, trade) => position.advance(trade),
      );

  String get quantity => _format(_quantity, 8);
  String get average =>
      _format(_round(_averageNumerator, _averageDenominator), 8);

  InvestmentPosition advance(InvestmentPositionTrade trade) {
    if (trade.type == 'SELL') {
      if (trade._quantity > _quantity) {
        throw const FormatException('Quantity jual melebihi holding tersedia.');
      }
      final remaining = _quantity - trade._quantity;
      return remaining == BigInt.zero
          ? InvestmentPosition.empty()
          : InvestmentPosition._(
              remaining,
              _averageNumerator,
              _averageDenominator,
            );
    }
    final next = _quantity + trade._quantity;
    if (next > _maxPrecise) {
      throw const FormatException(
        'Kuantitas investasi melebihi batas maksimum.',
      );
    }
    return InvestmentPosition._(
      next,
      _quantity * _averageNumerator +
          trade._quantity * trade._price * _averageDenominator,
      next * _averageDenominator,
    );
  }

  InvestmentPositionValuation valueAt(String marketPrice) {
    final price = _parsePrecise(marketPrice);
    final cashDivisor = BigInt.from(10).pow(14);
    final market = _round(_quantity * price, cashDivisor);
    final profit = _round(
      _quantity * (price * _averageDenominator - _averageNumerator),
      cashDivisor * _averageDenominator,
    );
    if (market.abs() > _maxCash || profit.abs() > _maxCash) {
      throw const FormatException('Nilai investasi melebihi batas maksimum.');
    }
    return InvestmentPositionValuation._(
      quantity,
      average,
      _format(price, 8),
      _format(market, 2),
      _format(profit, 2),
    );
  }
}

class InvestmentPositionValuation {
  final String quantity, average, marketPrice, marketValue, unrealizedPl;
  const InvestmentPositionValuation._(
    this.quantity,
    this.average,
    this.marketPrice,
    this.marketValue,
    this.unrealizedPl,
  );
}
