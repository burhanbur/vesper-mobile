import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/core/utils/string_formatter.dart';

void main() {
  group('StringFormatter.capitalizeWords', () {
    test('capitalizes single word', () {
      expect(StringFormatter.capitalizeWords('budi'), 'Budi');
      expect(StringFormatter.capitalizeWords('Budi'), 'Budi');
    });

    test('capitalizes multiple words in full name', () {
      expect(StringFormatter.capitalizeWords('budi santoso'), 'Budi Santoso');
      expect(
        StringFormatter.capitalizeWords('ahmad rizki mafazi'),
        'Ahmad Rizki Mafazi',
      );
    });

    test('handles empty or whitespace strings', () {
      expect(StringFormatter.capitalizeWords(''), '');
      expect(StringFormatter.capitalizeWords('   '), '');
    });

    test('capitalizes initial letter and preserves internal casing', () {
      expect(
        StringFormatter.capitalizeWords('pt. abc sejahtera'),
        'Pt. Abc Sejahtera',
      );
      expect(StringFormatter.capitalizeWords('bca syariah'), 'Bca Syariah');
      expect(StringFormatter.capitalizeWords('tabungan bca'), 'Tabungan Bca');
      expect(StringFormatter.capitalizeWords('mcdonald'), 'Mcdonald');
      expect(StringFormatter.capitalizeWords('McDonald'), 'McDonald');
    });

    test('handles multiple consecutive spaces cleanly', () {
      expect(
        StringFormatter.capitalizeWords('dompet    utama'),
        'Dompet Utama',
      );
    });
  });

  group('CapitalizeWordsInputFormatter', () {
    const formatter = CapitalizeWordsInputFormatter();

    test('capitalizes first letter of each word as typed', () {
      final input1 = const TextEditingValue(
        text: 'b',
        selection: TextSelection.collapsed(offset: 1),
      );
      final result1 = formatter.formatEditUpdate(
        TextEditingValue.empty,
        input1,
      );
      expect(result1.text, 'B');
      expect(result1.selection.baseOffset, 1);

      final input2 = const TextEditingValue(
        text: 'budi santoso',
        selection: TextSelection.collapsed(offset: 12),
      );
      final result2 = formatter.formatEditUpdate(
        TextEditingValue.empty,
        input2,
      );
      expect(result2.text, 'Budi Santoso');
      expect(result2.selection.baseOffset, 12);
    });

    test('handles boundary characters like hyphen and dot', () {
      final input = const TextEditingValue(
        text: 'pt. karya-mandiri',
        selection: TextSelection.collapsed(offset: 17),
      );
      final result = formatter.formatEditUpdate(TextEditingValue.empty, input);
      expect(result.text, 'Pt. Karya-Mandiri');
    });

    test('returns empty value unchanged', () {
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue.empty,
      );
      expect(result.text, '');
    });
  });
}
