import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/core/widgets/currency_amount_input.dart';
import 'package:vesper_mobile/features/obligations/pages/obligation_amount_input.dart';

void main() {
  const formatter = CurrencyAmountInput();

  test('prefills exact money and preserves non-IDR decimal precision', () {
    for (final value in ['1000000.25', '0.001', '999999999999999999.1234']) {
      final display = CurrencyAmountInput.fromDecimal(value);
      expect(CurrencyAmountInput.toDecimal(display), value);
      expect(ObligationAmountInput.fromDecimal(value), display);
    }
    expect(CurrencyAmountInput.fromDecimal('1000000.00'), '1.000.000');
    expect(CurrencyAmountInput.toDecimal('1.000.000'), '1000000');
  });

  test(
    'typing, paste and editing never round fractions or sanitize errors',
    () {
      for (final entry in {
        '1000000': '1.000.000',
        '1000000,01': '1.000.000,01',
        '1000000.01': '1.000.000,01',
        '1.000.000,1234': '1.000.000,1234',
        '1000,': '1.000,',
        '-100': '-100',
        'oops': 'oops',
        '1,,2': '1,,2',
      }.entries) {
        final result = formatter.formatEditUpdate(
          TextEditingValue.empty,
          TextEditingValue(
            text: entry.key,
            selection: TextSelection.collapsed(offset: entry.key.length),
          ),
        );
        expect(result.text, entry.value);
      }
      expect(CurrencyAmountInput.toDecimal('1.000.000,1234'), '1000000.1234');
      expect(CurrencyAmountInput.toDecimal('1.000,'), '1.000,');
      expect(CurrencyAmountInput.toDecimal('1,,2'), '1,,2');
    },
  );
}
