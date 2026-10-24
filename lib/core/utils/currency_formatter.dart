import 'package:flutter/services.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  /// Formats an integer into dotted thousand separated string without 'Rp ' prefix: "12.500.000"
  static String formatNumber(int amount, {bool allowNegative = false}) {
    final isNegative = allowNegative && amount < 0;
    final absAmount = amount.abs();
    final buffer = StringBuffer();
    final str = absAmount.toString();

    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }

    return (isNegative ? '-' : '') + buffer.toString();
  }

  /// Lossless presentation of minor units, including fractional Rupiah.
  static String formatMinorRupiah(BigInt amount) {
    final major = (amount.abs() ~/ BigInt.from(100)).toString();
    final grouped = major.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (match) => '${match[1]}.',
    );
    final cents = amount.abs() % BigInt.from(100);
    final fraction = cents == BigInt.zero
        ? ''
        : ',${cents.toString().padLeft(2, '0')}';
    return '${amount.isNegative ? '-' : ''}Rp $grouped$fraction';
  }

  /// Formats an integer rupiah value into standard format: "Rp 12.500.000"
  /// If [withSign] is true, prefixes '+' or '-' based on [isPositive] or [isNegative].
  static String formatRupiah(
    int amount, {
    bool withSign = false,
    bool isExpense = false,
    bool isIncome = false,
  }) {
    final absAmount = amount.abs();
    final buffer = StringBuffer();
    final str = absAmount.toString();

    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }

    final formatted = 'Rp ${buffer.toString()}';

    if (withSign) {
      if (isExpense || amount < 0) {
        return '-$formatted';
      } else if (isIncome || amount > 0) {
        return '+$formatted';
      }
    }

    return formatted;
  }

  /// Compact representation e.g. "Rp 245,5 Jt" or "Rp 12,5 Rb"
  static String formatCompact(int amount) {
    final absAmount = amount.abs();
    if (absAmount >= 1000000000) {
      final value = (absAmount / 1000000000)
          .toStringAsFixed(1)
          .replaceAll('.', ',');
      return 'Rp ${value.endsWith(',0') ? value.substring(0, value.length - 2) : value} M';
    } else if (absAmount >= 1000000) {
      final value = (absAmount / 1000000)
          .toStringAsFixed(1)
          .replaceAll('.', ',');
      return 'Rp ${value.endsWith(',0') ? value.substring(0, value.length - 2) : value} Jt';
    } else if (absAmount >= 1000) {
      final value = (absAmount / 1000).toStringAsFixed(1).replaceAll('.', ',');
      return 'Rp ${value.endsWith(',0') ? value.substring(0, value.length - 2) : value} Rb';
    }
    return 'Rp $absAmount';
  }

  /// Parses digits from formatted user input string into int
  static int parseRupiah(String input, {bool allowNegative = false}) {
    final trimmed = input.trim();
    final isNegative = allowNegative && (trimmed.startsWith('-') || trimmed.contains('-'));
    final digitsOnly = trimmed.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.isEmpty) return 0;
    final val = int.tryParse(digitsOnly) ?? 0;
    return isNegative ? -val : val;
  }

  /// Sanitizes any string into a clean numeric string (no currency, no separators)
  static String sanitizeAmount(String input, {bool allowNegative = false}) {
    final trimmed = input.trim();
    final isNegative = allowNegative && (trimmed.startsWith('-') || trimmed.contains('-'));
    final digitsOnly = trimmed.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.isEmpty) return '0';
    return (isNegative ? '-' : '') + digitsOnly;
  }
}

/// A [TextInputFormatter] that formats numeric input into currency with dot thousand separators.
class CurrencyTextInputFormatter extends TextInputFormatter {
  final bool includePrefix;
  final bool allowNegative;

  const CurrencyTextInputFormatter({
    this.includePrefix = false,
    this.allowNegative = false,
  });

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final trimmed = newValue.text.trim();
    final isNegative = allowNegative && (trimmed.startsWith('-') || (trimmed.contains('-') && oldValue.text.isNotEmpty));
    final digits = trimmed.replaceAll(RegExp(r'[^\d]'), '');

    if (digits.isEmpty) {
      if (isNegative) {
        return const TextEditingValue(
          text: '-',
          selection: TextSelection.collapsed(offset: 1),
        );
      }
      return const TextEditingValue(text: '');
    }

    final parsed = BigInt.tryParse(digits) ?? BigInt.zero;
    final rawDigits = parsed.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < rawDigits.length; i++) {
      if (i > 0 && (rawDigits.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(rawDigits[i]);
    }

    var formatted = buffer.toString();
    if (isNegative) {
      formatted = '-$formatted';
    }
    if (includePrefix) {
      formatted = 'Rp $formatted';
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
