import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/core/utils/currency_formatter.dart';

void main() {
  group('CurrencyFormatter.formatCurrency', () {
    test(
      'formats standard integer and decimal strings into Rupiah with dots',
      () {
        expect(
          CurrencyFormatter.formatCurrency('10000000.00'),
          'Rp 10.000.000',
        );
        expect(CurrencyFormatter.formatCurrency('10000000'), 'Rp 10.000.000');
        expect(CurrencyFormatter.formatCurrency('500000'), 'Rp 500.000');
        expect(CurrencyFormatter.formatCurrency('0.00'), 'Rp 0');
        expect(CurrencyFormatter.formatCurrency('0'), 'Rp 0');
      },
    );

    test('preserves non-zero fraction cents with Indonesian comma', () {
      expect(CurrencyFormatter.formatCurrency('12345.67'), 'Rp 12.345,67');
      expect(CurrencyFormatter.formatCurrency('500.5'), 'Rp 500,5');
      expect(CurrencyFormatter.formatCurrency('1000.05'), 'Rp 1.000,05');
    });

    test('handles negative values correctly', () {
      expect(CurrencyFormatter.formatCurrency('-50000.00'), '-Rp 50.000');
      expect(CurrencyFormatter.formatCurrency('-12345.67'), '-Rp 12.345,67');
      expect(CurrencyFormatter.formatCurrency('-0.00'), 'Rp 0');
    });

    test('supports foreign currency codes', () {
      expect(
        CurrencyFormatter.formatCurrency('1500000.00', currency: 'USD'),
        'USD 1.500.000',
      );
      expect(
        CurrencyFormatter.formatCurrency('1234.50', currency: 'USD'),
        'USD 1.234,50',
      );
      expect(
        CurrencyFormatter.formatCurrency('-250.75', currency: 'EUR'),
        '-EUR 250,75',
      );
    });

    test('handles numeric types int, double, and BigInt', () {
      expect(CurrencyFormatter.formatCurrency(2500000), 'Rp 2.500.000');
      expect(CurrencyFormatter.formatCurrency(1250.75), 'Rp 1.250,75');
      expect(
        CurrencyFormatter.formatCurrency(BigInt.from(100000000)),
        'Rp 100.000.000',
      );
    });

    test('handles null and empty gracefully', () {
      expect(CurrencyFormatter.formatCurrency(null), 'Rp 0');
      expect(CurrencyFormatter.formatCurrency(''), 'Rp 0');
      expect(CurrencyFormatter.formatCurrency(null, currency: 'SGD'), 'SGD 0');
    });
  });
}
