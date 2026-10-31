import 'package:flutter/services.dart';

/// String formatting utilities for text normalization and presentation.
class StringFormatter {
  const StringFormatter._();

  /// Capitalizes the first letter of each word in [input].
  ///
  /// Examples:
  /// - `ahmad rizki` -> `Ahmad Rizki`
  /// - `budi santoso` -> `Budi Santoso`
  /// - `pt. karya mandiri` -> `Pt. Karya Mandiri`
  /// - `McDonald` -> `McDonald` (preserves existing internal casing)
  static String capitalizeWords(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return trimmed;

    final words = trimmed.split(RegExp(r'\s+'));
    return words
        .map((word) {
          if (word.isEmpty) return word;
          if (word.length == 1) return word.toUpperCase();
          return word[0].toUpperCase() + word.substring(1);
        })
        .join(' ');
  }
}

/// A [TextInputFormatter] that automatically capitalizes the first letter of
/// each word in real-time as the user types in text inputs.
class CapitalizeWordsInputFormatter extends TextInputFormatter {
  const CapitalizeWordsInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    final buffer = StringBuffer();
    bool capitalizeNext = true;

    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      final isWordBoundary =
          char == ' ' ||
          char == '\t' ||
          char == '\n' ||
          char == '-' ||
          char == '_' ||
          char == '/' ||
          char == '.';

      if (isWordBoundary) {
        buffer.write(char);
        capitalizeNext = true;
      } else if (capitalizeNext) {
        final upper = char.toUpperCase();
        if (upper.length == 1) {
          buffer.write(upper);
        } else {
          buffer.write(char);
        }
        capitalizeNext = false;
      } else {
        buffer.write(char);
      }
    }

    final formatted = buffer.toString();
    if (formatted == text) {
      return newValue;
    }

    return newValue.copyWith(text: formatted, selection: newValue.selection);
  }
}
