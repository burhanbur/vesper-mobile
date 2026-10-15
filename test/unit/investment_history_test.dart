import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/features/investments/models/investment_history.dart';

Map<String, dynamic> row(
  String id,
  String type,
  String quantity,
  int day, {
  String instrument = 'stock',
  String price = '10',
}) => {
  'id': id,
  'account_id': 'account',
  'instrument_id': instrument,
  'type': type,
  'quantity': quantity,
  'price_per_unit': price,
  'transacted_at': DateTime.utc(2026, 10, day).toIso8601String(),
  'deleted_at': null,
};

InvestmentHistory history(List<Map<String, dynamic>> rows) =>
    InvestmentHistory.fromCompleteRows(accountId: 'account', rows: rows);

void main() {
  test('orders unsorted history and isolates instruments', () {
    final rows = [
      row('sell', 'SELL', '1', 3),
      row('b', 'BUY', '2', 2, price: '20'),
      row('a', 'BUY', '1', 1),
      row('other', 'BUY', '9', 1, instrument: 'bond'),
    ];
    final result = history(rows);
    expect(result.position('stock').quantity, '2.00000000');
    expect(result.position('stock').average, '16.66666667');
    expect(result.position('bond').quantity, '9.00000000');
    expect(result.position('missing').quantity, '0.00000000');
    expect(rows.first['id'], 'sell');
  });

  test('timestamp ties use backend ascending ID order', () {
    final result = history([row('b', 'SELL', '1', 1), row('a', 'BUY', '2', 1)]);
    expect(result.position('stock').quantity, '1.00000000');
    expect(result.canAppend('stock', DateTime.utc(2026, 10, 1)), false);
    expect(
      result.canAppend('stock', DateTime.utc(2026, 10, 1, 0, 0, 0, 1)),
      true,
    );
    expect(result.canAppend('new', DateTime.utc(2026)), true);
  });

  test('legacy dividends retain position but advance chronology', () {
    final result = history([
      row('a', 'BUY', '1', 1),
      row('d', 'DIVIDEND', '5.00000000', 3, price: '2.00000000'),
    ]);
    expect(result.position('stock').quantity, '1.00000000');
    expect(result.position('stock').average, '10.00000000');
    expect(result.canAppend('stock', DateTime.utc(2026, 10, 2)), false);
  });

  test('rejects duplicate IDs, wrong scope, tombstones and unknown types', () {
    for (final patch in [
      {'account_id': 'another'},
      {'instrument_id': ''},
      {'deleted_at': 'deleted'},
      {'type': 'UNKNOWN'},
      {'quantity': '1e2'},
      {'transacted_at': '2026-02-30T00:00:00.000Z'},
      {'transacted_at': '2026-10-01T00:00:00.000'},
    ]) {
      expect(
        () => history([
          {...row('a', 'BUY', '1', 1), ...patch},
        ]),
        throwsFormatException,
      );
    }
    expect(
      () => history([row('a', 'BUY', '1', 1), row('a', 'BUY', '1', 2)]),
      throwsFormatException,
    );
    expect(() => history([row('a', 'SELL', '1', 1)]), throwsFormatException);
  });

  test('empty complete history is empty, not a fabricated holding', () {
    expect(history([]).position('stock').average, '0.00000000');
  });
}
