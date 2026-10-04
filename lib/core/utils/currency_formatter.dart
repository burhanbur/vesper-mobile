class CurrencyFormatter {
  CurrencyFormatter._();

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
      final value = (absAmount / 1000000000).toStringAsFixed(1).replaceAll('.', ',');
      return 'Rp ${value.endsWith(',0') ? value.substring(0, value.length - 2) : value} M';
    } else if (absAmount >= 1000000) {
      final value = (absAmount / 1000000).toStringAsFixed(1).replaceAll('.', ',');
      return 'Rp ${value.endsWith(',0') ? value.substring(0, value.length - 2) : value} Jt';
    } else if (absAmount >= 1000) {
      final value = (absAmount / 1000).toStringAsFixed(1).replaceAll('.', ',');
      return 'Rp ${value.endsWith(',0') ? value.substring(0, value.length - 2) : value} Rb';
    }
    return 'Rp $absAmount';
  }

  /// Parses digits from formatted user input string into int
  static int parseRupiah(String input) {
    final digitsOnly = input.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.isEmpty) return 0;
    return int.tryParse(digitsOnly) ?? 0;
  }
}
