import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/features/investments/models/investment_history.dart';
import 'package:vesper_mobile/features/investments/models/investment_trade_command.dart';

const account = '11111111-1111-4111-8111-111111111111';
const cash = '22222222-2222-4222-8222-222222222222';
const stock = '33333333-3333-4333-8333-333333333333';
final date = DateTime.utc(2026, 10, 15);

InvestmentHistory history({bool bought = false}) =>
    InvestmentHistory.fromCompleteRows(
      accountId: account,
      rows: [
        if (bought)
          {
            'id': 'previous',
            'account_id': account,
            'instrument_id': stock,
            'type': 'BUY',
            'quantity': '2',
            'price_per_unit': '10',
            'transacted_at': '2026-10-14T00:00:00.000Z',
          },
      ],
    );

InvestmentTradeCommand prepare({
  String type = 'BUY',
  String quantity = '1',
  String balance = '10.01',
  String price = '0.015',
  String fee = '0',
  String accountId = account,
  String cashId = cash,
  DateTime? at,
  bool bought = false,
}) => InvestmentTradeCommand.prepare(
  history: history(bought: bought),
  accountId: accountId,
  cashAccountId: cashId,
  instrumentId: stock,
  cashBalance: balance,
  type: type,
  quantity: quantity,
  pricePerUnit: price,
  fee: fee,
  at: at ?? date,
);

void main() {
  test(
    'BUY settles fractional cents once and keeps a stable JSON envelope',
    () {
      final command = prepare();
      expect(command.cashBalanceAfter, '9.99');
      expect(command.settlement.amount, '0.02');
      expect(command.positionAfter.quantity, '1.00000000');
      expect(command.positionAfter.average, '0.01500000');
      expect(command.id, isNot(command.linkedTransactionId));
      final encoded = jsonEncode(command.toPushItem());
      expect(jsonEncode(command.toPushItem()), encoded);
      final decoded = jsonDecode(encoded) as Map;
      expect(decoded['entity_id'], command.id);
      expect(decoded['client_version'], '0');
      expect(
        decoded['payload']['linked_transaction_id'],
        command.linkedTransactionId,
      );
      expect(decoded['payload']['quantity'], '1');
    },
  );

  test('SELL accounts for fees without changing remaining average cost', () {
    final command = prepare(
      type: 'SELL',
      bought: true,
      price: '12.345',
      fee: '0.01',
    );
    expect(command.cashBalanceAfter, '22.35');
    expect(command.settlement.amount, '12.34');
    expect(command.positionAfter.quantity, '1.00000000');
    expect(command.positionAfter.average, '10.00000000');
    expect(history(bought: true).position(stock).quantity, '2.00000000');
  });

  test('oversell and nonpositive settlement cannot become commands', () {
    expect(() => prepare(type: 'SELL'), throwsFormatException);
    expect(
      () => prepare(type: 'SELL', bought: true, quantity: '3'),
      throwsFormatException,
    );
    expect(
      () => prepare(type: 'SELL', bought: true, fee: '1'),
      throwsFormatException,
    );
  });

  test('history identity and strictly later millisecond UTC are required', () {
    expect(() => prepare(accountId: cash), throwsFormatException);
    expect(() => prepare(cashId: account), throwsFormatException);
    expect(() => prepare(cashId: 'invalid'), throwsFormatException);
    expect(
      () => prepare(bought: true, at: DateTime.utc(2026, 10, 14)),
      throwsFormatException,
    );
    expect(() => prepare(at: DateTime(2026, 10, 15)), throwsFormatException);
    expect(
      () => prepare(at: date.add(const Duration(microseconds: 1))),
      throwsFormatException,
    );
  });

  test(
    'cash arithmetic is lossless above JS safe integers and allows overdraft',
    () {
      expect(
        prepare(balance: '9007199254740993.01').cashBalanceAfter,
        '9007199254740992.99',
      );
      expect(prepare(balance: '0').cashBalanceAfter, '-0.02');
      expect(() => prepare(balance: '1.001'), throwsFormatException);
      expect(() => prepare(balance: '1.00\n'), throwsFormatException);
      expect(
        () => prepare(balance: '-999999999999999999.99'),
        throwsFormatException,
      );
      expect(
        () => prepare(
          type: 'SELL',
          bought: true,
          balance: '999999999999999999.99',
        ),
        throwsFormatException,
      );
    },
  );
}
