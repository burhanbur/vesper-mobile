import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/features/investments/models/investment_settlement.dart';

void main() {
  InvestmentSettlement settle({
    String type = 'BUY',
    String quantity = '2',
    String price = '10.25',
    String fee = '0.50',
  }) => InvestmentSettlement.calculate(
    type: type,
    quantity: quantity,
    pricePerUnit: price,
    fee: fee,
  );

  test('BUY includes fee and SELL deducts fee exactly', () {
    expect(settle().amount, '21.00');
    expect(settle().ledgerType, 'EXPENSE');
    expect(settle(type: 'SELL').amount, '20.00');
    expect(settle(type: 'SELL').ledgerType, 'INCOME');
  });

  test('rounds HALF_UP only after fee at the cash boundary', () {
    expect(settle(quantity: '1', price: '1.005', fee: '0').amount, '1.01');
    expect(settle(quantity: '1', price: '1.00499999', fee: '0').amount, '1.00');
    expect(
      settle(type: 'SELL', quantity: '1', price: '1.005', fee: '0.01').amount,
      '1.00',
    );
    expect(
      settle(quantity: '0.00000001', price: '500000', fee: '0').amount,
      '0.01',
    );
  });

  test('keeps values above JavaScript safe integers exact', () {
    expect(
      settle(quantity: '900719925474', price: '10000', fee: '0.01').amount,
      '9007199254740000.01',
    );
    expect(
      settle(quantity: '1', price: '1', fee: '999999999999999998.99').amount,
      '999999999999999999.99',
    );
  });

  test('rejects zero or negative net, rounded zero, and cash overflow', () {
    for (final call in <InvestmentSettlement Function()>[
      () => settle(quantity: '0'),
      () => settle(price: '0'),
      () => settle(type: 'SELL', fee: '20.50'),
      () => settle(type: 'SELL', fee: '21'),
      () => settle(quantity: '0.00000001', price: '0.00000001', fee: '0'),
      () => settle(quantity: '999999999999', price: '999999999999'),
      () => settle(quantity: '1', price: '1', fee: '999999999999999999.99'),
      () => settle(type: 'DIVIDEND'),
    ]) {
      expect(call, throwsFormatException);
    }
  });

  test('rejects decimal formats that the command schema does not accept', () {
    for (final invalid in [
      '01',
      '-1',
      '+1',
      '1e2',
      '.1',
      '1.',
      ' 1',
      '1\n',
      'NaN',
      '1000000000000',
      '0.000000001',
      '1,5',
    ]) {
      expect(() => settle(quantity: invalid), throwsFormatException);
      expect(() => settle(price: invalid), throwsFormatException);
    }
    for (final invalid in ['-1', '00', '0.001', '1000000000000000000', '1\n']) {
      expect(() => settle(fee: invalid), throwsFormatException);
    }
  });
}
