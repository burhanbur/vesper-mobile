import 'package:flutter/services.dart';

/// Lossless money input: dots group thousands and a comma preserves decimals.
/// Currency precision and supported fractions remain repository decisions.
class CurrencyAmountInput extends TextInputFormatter {
  const CurrencyAmountInput();

  static final _grouped = RegExp(r'^[1-9]\d{0,2}(?:\.\d{3})+$');
  static final _decimal = RegExp(r'^(0|[1-9]\d*)(?:\.(\d*))?$');

  static String fromDecimal(String value) {
    final match = _decimal.firstMatch(value);
    if (match == null) return value;
    final integer = match[1]!.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (match) => '${match[1]}.',
    );
    final fraction = match[2];
    return fraction == null ||
            (fraction.isNotEmpty && !RegExp(r'[1-9]').hasMatch(fraction))
        ? integer
        : '$integer,$fraction';
  }

  /// Convert only recognized presentation syntax; never discard invalid input.
  static String toDecimal(String value) {
    final parts = value.split(',');
    final integer = parts.first;
    final raw = _grouped.hasMatch(integer)
        ? integer.replaceAll('.', '')
        : integer;
    if (parts.length == 1) return raw;
    if (parts.length == 2 &&
        RegExp(r'^(0|[1-9]\d*)$').hasMatch(raw) &&
        RegExp(r'^\d+$').hasMatch(parts[1])) {
      return '$raw.${parts[1]}';
    }
    // An incomplete comma must remain invalid, not become a valid integer.
    return value;
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!newValue.composing.isCollapsed || newValue.text.isEmpty) {
      return newValue;
    }
    final text = newValue.text;
    final parts = text.split(',');
    String formatted;
    if (parts.length == 2) {
      final integer = _grouped.hasMatch(parts.first)
          ? parts.first.replaceAll('.', '')
          : parts.first;
      if (!RegExp(r'^(0|[1-9]\d*)$').hasMatch(integer) ||
          !RegExp(r'^\d*$').hasMatch(parts[1])) {
        return newValue;
      }
      formatted = '${fromDecimal(integer)},${parts[1]}';
    } else if (parts.length == 1) {
      // A trailing dot is a newly typed decimal separator, not grouping.
      final oldText = oldValue.text;
      final editsGroupedInteger =
          _grouped.hasMatch(oldText) &&
          text.split('.').length == oldText.split('.').length &&
          (text.length - oldText.length).abs() == 1;
      final raw = _grouped.hasMatch(text) || editsGroupedInteger
          ? text.replaceAll('.', '')
          : text;
      formatted = fromDecimal(raw);
    } else {
      return newValue;
    }
    // Keep the caret anchored to the same number of digits/decimal markers.
    final offset = newValue.selection.extentOffset;
    final before = offset < 0 ? text.length : offset.clamp(0, text.length);
    final remaining = text.substring(before).replaceAll('.', '').length;
    var caret = formatted.length;
    var count = 0;
    while (caret > 0 && count < remaining) {
      caret--;
      if (formatted[caret] != '.') count++;
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: caret),
    );
  }
}
