import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/features/investments/models/investment_position.dart';

InvestmentPositionTrade trade(String type, String quantity, String price) =>
    InvestmentPositionTrade(
      type: type,
      quantity: quantity,
      pricePerUnit: price,
    );

void main() {
  test('weighted BUY average and partial SELL match backend rules', () {
    final position = InvestmentPosition.replay([
      trade('BUY', '100', '5000'),
      trade('BUY', '100', '6000'),
      trade('SELL', '50', '7000'),
    ]);
    expect(position.quantity, '150.00000000');
    expect(position.average, '5500.00000000');
    final value = position.valueAt('6500');
    expect(value.marketValue, '975000.00');
    expect(value.unrealizedPl, '150000.00');
    expect(value.marketPrice, '6500.00000000');
    expect(value.quantity, position.quantity);
    expect(value.average, position.average);
  });

  test(
    'repeating average is not rounded between trades or during valuation',
    () {
      final first = InvestmentPosition.replay([
        trade('BUY', '1', '0.00000001'),
        trade('BUY', '2', '0.00000002'),
      ]);
      expect(first.average, '0.00000002');
      final next = first
          .advance(trade('SELL', '2', '1'))
          .advance(trade('BUY', '1', '0.00000001'));
      // Exact average is 1.333...e-8, not 1.5e-8 from a rounded snapshot.
      expect(next.average, '0.00000001');
      final highQuantity = InvestmentPosition.replay([
        trade('BUY', '100000000', '0.00000001'),
        trade('BUY', '200000000', '0.00000002'),
      ]);
      expect(highQuantity.valueAt('0.00000002').unrealizedPl, '1.00');
    },
  );

  test('full liquidation resets cost basis before repurchase', () {
    final position = InvestmentPosition.replay([
      trade('BUY', '0.00000001', '999999999999.99999999'),
      trade('SELL', '0.00000001', '1'),
    ]);
    expect(position.quantity, '0.00000000');
    expect(position.average, '0.00000000');
    expect(position.advance(trade('BUY', '2', '3')).average, '3.00000000');
  });

  test('oversell and quantity overflow do not change the source position', () {
    final position = InvestmentPosition.empty().advance(trade('BUY', '1', '2'));
    expect(
      () => position.advance(trade('SELL', '1.00000001', '2')),
      throwsFormatException,
    );
    expect(
      () => position.advance(trade('BUY', '999999999999.99999999', '1')),
      throwsFormatException,
    );
    expect(position.quantity, '1.00000000');
    expect(position.average, '2.00000000');
  });

  test('HALF_UP supports positive and negative half-cent P/L', () {
    final position = InvestmentPosition.empty().advance(trade('BUY', '1', '1'));
    expect(position.valueAt('1.005').unrealizedPl, '0.01');
    expect(position.valueAt('0.995').unrealizedPl, '-0.01');
    expect(position.valueAt('0.999').unrealizedPl, '0.00');
    expect(position.valueAt('0').marketValue, '0.00');
  });

  test('large exact values and Decimal(20,2) overflow are checked', () {
    final position = InvestmentPosition.empty().advance(
      trade('BUY', '900719925474', '10000'),
    );
    expect(
      position.valueAt('10000.00000001').marketValue,
      '9007199254749007.20',
    );
    final max = InvestmentPosition.empty().advance(
      trade('BUY', '999999999999.99999999', '1'),
    );
    expect(() => max.valueAt('999999999999.99999999'), throwsFormatException);
  });

  test('invalid command decimals and unsupported types fail closed', () {
    for (final value in [
      '0',
      '-1',
      '01',
      '1e2',
      '1.000000001',
      '1\n',
      ' 1',
      '1000000000000',
    ]) {
      expect(() => trade('BUY', value, '1'), throwsFormatException);
      expect(() => trade('SELL', '1', value), throwsFormatException);
    }
    expect(() => trade('DIVIDEND', '1', '1'), throwsFormatException);
    expect(
      () => InvestmentPosition.empty().valueAt('1\n'),
      throwsFormatException,
    );
  });
}
