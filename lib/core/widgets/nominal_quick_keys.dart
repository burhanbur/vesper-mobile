import 'package:flutter/material.dart';

import '../utils/currency_formatter.dart';
import 'currency_amount_input.dart';
import '../../app/theme/app_colors.dart';

enum NominalFormatMode {
  /// Formats as `Rp 10.000` (used by AddTransactionModal).
  rupiahWithPrefix,

  /// Formats as `10.000` using [CurrencyTextInputFormatter] (digits only).
  groupedNumber,

  /// Formats as `10.000` using [CurrencyAmountInput] (preserves comma decimal).
  currencyAmountInput,
}

/// Appends [zeros] (`'00'` or `'000'`) to the integer part of [controller]'s
/// nominal text, keeping the caret at the end without closing the keyboard.
void appendNominalZeros(
  TextEditingController controller,
  String zeros, {
  required NominalFormatMode mode,
  ValueChanged<String>? onChanged,
  int maxDigits = 15,
}) {
  final raw = controller.text.trim();
  String integerDigits;
  String decimalSuffix = '';

  if (mode == NominalFormatMode.currencyAmountInput && raw.contains(',')) {
    final parts = raw.split(',');
    integerDigits = parts.first.replaceAll(RegExp(r'[^\d]'), '');
    decimalSuffix = ',${parts.sublist(1).join('')}';
  } else {
    integerDigits = raw.replaceAll(RegExp(r'[^\d]'), '');
  }

  integerDigits = integerDigits.replaceFirst(RegExp(r'^0+'), '');
  if (integerDigits.isEmpty) {
    return;
  }
  final nextDigits = integerDigits + zeros;
  if (nextDigits.length > maxDigits) {
    return;
  }

  final String formatted;
  switch (mode) {
    case NominalFormatMode.rupiahWithPrefix:
      final parsed = int.tryParse(nextDigits);
      if (parsed == null) return;
      formatted = CurrencyFormatter.formatRupiah(parsed);
      break;
    case NominalFormatMode.groupedNumber:
      final parsed = int.tryParse(nextDigits);
      if (parsed == null) return;
      formatted = CurrencyFormatter.formatNumber(parsed);
      break;
    case NominalFormatMode.currencyAmountInput:
      formatted = '${CurrencyAmountInput.fromDecimal(nextDigits)}$decimalSuffix';
      break;
  }

  controller.value = TextEditingValue(
    text: formatted,
    selection: TextSelection.collapsed(offset: formatted.length),
  );
  onChanged?.call(formatted);
}

/// Compact `00` and `000` helper keys shown alongside nominal inputs so users
/// can enter large Rupiah values quickly without losing keyboard focus.
class NominalQuickKeys extends StatelessWidget {
  final TextEditingController controller;
  final NominalFormatMode mode;
  final ValueChanged<String>? onChanged;
  final String? keyPrefix;
  final MainAxisAlignment alignment;

  const NominalQuickKeys({
    super.key,
    required this.controller,
    required this.mode,
    this.onChanged,
    this.keyPrefix,
    this.alignment = MainAxisAlignment.end,
  });

  @override
  Widget build(BuildContext context) {
    final prefix = keyPrefix == null ? 'nominal_quick' : '${keyPrefix}_quick';
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisAlignment: alignment,
        children: [
          const Text(
            'Tambah nol:',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 8),
          _ZeroKeyButton(
            key: ValueKey('${prefix}_00'),
            label: '00',
            onTap: () => appendNominalZeros(
              controller,
              '00',
              mode: mode,
              onChanged: onChanged,
            ),
          ),
          const SizedBox(width: 6),
          _ZeroKeyButton(
            key: ValueKey('${prefix}_000'),
            label: '000',
            onTap: () => appendNominalZeros(
              controller,
              '000',
              mode: mode,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _ZeroKeyButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ZeroKeyButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceVariant,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}
