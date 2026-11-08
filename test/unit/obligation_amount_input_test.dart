import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/features/obligations/pages/obligation_amount_input.dart';

void main() {
  const formatter = ObligationAmountInput();
  TextEditingValue edit(String text, {String old = ''}) =>
      formatter.formatEditUpdate(
        TextEditingValue(text: old),
        TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        ),
      );

  test('groups exact large values and API prefills without floating point', () {
    for (final raw in ['1000000', '999999999999999999']) {
      final display = edit(raw).text;
      expect(display, contains('.'));
      expect(ObligationAmountInput.toDecimal(display), raw);
      expect(ObligationAmountInput.fromDecimal('$raw.00'), display);
    }
    expect(edit('1.0000', old: '1.000').text, '10.000');
    expect(edit('1.00', old: '1.000').text, '100');
    expect(edit('').text, '');
  });

  test('preserves meaningful fractions and invalid input for validation', () {
    for (final raw in ['1.01', '1000000.01', '0.001', '1000.0001']) {
      final display = edit(raw).text;
      expect(ObligationAmountInput.toDecimal(display), raw);
      expect(ObligationAmountInput.fromDecimal(raw), display);
    }
    expect(edit('1000,01').text, '1.000,01');
    expect(ObligationAmountInput.toDecimal('1.000,01'), '1000.01');
    for (final invalid in ['-100', 'abc', '1,', '1,,2', '1.00.00']) {
      expect(ObligationAmountInput.toDecimal(edit(invalid).text), invalid);
    }
    expect(edit('1000.').text, '1.000,');
    expect(ObligationAmountInput.toDecimal('1.000,'), '1.000,');
  });

  test('keeps composition and positions caret after grouping', () {
    const composing = TextEditingValue(
      text: '1000',
      composing: TextRange(start: 0, end: 4),
    );
    expect(
      formatter.formatEditUpdate(TextEditingValue.empty, composing),
      composing,
    );
    final result = formatter.formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(
        text: '12345',
        selection: TextSelection.collapsed(offset: 2),
      ),
    );
    expect(result.text, '12.345');
    expect(result.selection.extentOffset, 3);
  });
}
