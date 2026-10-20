import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/currency_formatter.dart';
import '../models/balance_adjustment.dart';

class BalanceAdjustmentDialog extends StatefulWidget {
  final AppState state;
  final String accountId;
  const BalanceAdjustmentDialog({
    super.key,
    required this.state,
    required this.accountId,
  });

  @override
  State<BalanceAdjustmentDialog> createState() =>
      _BalanceAdjustmentDialogState();
}

class _BalanceAdjustmentDialogState extends State<BalanceAdjustmentDialog> {
  final controller = TextEditingController();
  String? error;
  int? initialBalance;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    initialBalance = widget.state.getAccountById(widget.accountId)?.balance;
    if (initialBalance != null) {
      if (widget.state.isBalanceHidden) {
        controller.text = initialBalance.toString();
      } else {
        controller.text = CurrencyFormatter.formatRupiah(
          initialBalance!,
          withSign: initialBalance! < 0,
        );
      }
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _onAmountChanged(String val) {
    setState(() {
      error = null;
    });

    if (widget.state.isBalanceHidden) {
      return;
    }

    final trimmed = val.trim();
    if (trimmed.isEmpty) {
      return;
    }

    // If user enters invalid characters like decimals, don't auto-format over it, let validation show the error
    if (trimmed.contains(',') ||
        trimmed.contains('e') ||
        trimmed.contains('E')) {
      return;
    }
    if (trimmed.contains('.')) {
      final withoutRp = trimmed.replaceFirst(RegExp(r'^-?Rp\s*'), '');
      if (!withoutRp.contains('.') ||
          !RegExp(r'^\d{1,3}(?:\.\d{3})+$').hasMatch(withoutRp)) {
        if (!trimmed.startsWith('Rp') && !trimmed.startsWith('-Rp')) {
          return;
        }
      }
    }

    final isNegative = trimmed.startsWith('-');
    final digits = trimmed.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) {
      if (isNegative && controller.text != '-') {
        controller.value = const TextEditingValue(
          text: '-',
          selection: TextSelection.collapsed(offset: 1),
        );
      }
      return;
    }

    final parsed = int.tryParse(digits);
    if (parsed == null) return;

    final formattedDigits = CurrencyFormatter.formatRupiah(parsed);
    final formatted = isNegative ? '-$formattedDigits' : formattedDigits;

    if (controller.text != formatted) {
      controller.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  int? _parseInput(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    final isNegative = trimmed.startsWith('-');
    final clean = trimmed.replaceFirst('-', '').trim();

    // Check for decimals, commas or exponential notation
    if (clean.contains(',') || clean.contains('e') || clean.contains('E')) {
      throw const ApiFailure('Masukkan Rupiah bulat tanpa pemisah.');
    }

    if (clean.contains('.')) {
      final withoutRp = clean.replaceFirst(RegExp(r'^Rp\s*'), '');
      if (!RegExp(r'^\d{1,3}(?:\.\d{3})+$').hasMatch(withoutRp)) {
        throw const ApiFailure('Masukkan Rupiah bulat tanpa pemisah.');
      }
    }

    final digits = clean.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) {
      if (trimmed == '-' || trimmed == '-Rp') return null;
      throw const ApiFailure('Masukkan Rupiah bulat tanpa pemisah.');
    }

    final rawString = isNegative ? '-$digits' : digits;
    return parseAdjustmentTarget(rawString);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        int? target;
        int? delta;
        String? validation;
        final account = widget.state.getAccountById(widget.accountId);
        if (account == null) {
          validation = 'Akun tidak ditemukan.';
        } else if (account.balance != initialBalance) {
          validation = 'Saldo berubah. Tutup dan buka kembali Ubah Saldo.';
        } else {
          try {
            target = _parseInput(controller.text);
            if (target != null) {
              delta = adjustmentDifference(account.balance, target);
            }
          } catch (e) {
            validation = e.toString();
          }
        }
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          actionsPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          title: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ubah Saldo',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (account != null)
                      Text(
                        account.name,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: isSaving ? null : () => Navigator.pop(context),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 15,
                        color: AppColors.textMuted,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Target dihitung dari saldo lokal, termasuk transaksi tertunda. Penyesuaian masuk laporan pemasukan/pengeluaran. Perubahan dari perangkat lain dapat mengubah saldo setelah sinkronisasi.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 16,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Saldo saat ini: ${widget.state.isBalanceHidden
                              ? '••••••'
                              : initialBalance == null
                              ? '-'
                              : CurrencyFormatter.formatRupiah(initialBalance!, withSign: initialBalance! < 0)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Target Saldo Baru',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: controller,
                  enabled: !isSaving,
                  autofocus: true,
                  obscureText: widget.state.isBalanceHidden,
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                  ),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.state.isBalanceHidden ? '••••••' : 'Rp 0',
                    prefixIcon: Icon(
                      Icons.payments_rounded,
                      color: widget.state.isBalanceHidden
                          ? AppColors.textMuted
                          : AppColors.primary,
                      size: 20,
                    ),
                    errorText:
                        error ?? (controller.text.isEmpty ? null : validation),
                  ),
                  onChanged: _onAmountChanged,
                ),
                const SizedBox(height: 12),
                if (delta != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: delta == 0
                          ? AppColors.surfaceVariant
                          : delta > 0
                          ? AppColors.incomeLight
                          : AppColors.expenseLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: delta == 0
                            ? AppColors.border
                            : delta > 0
                            ? AppColors.income.withValues(alpha: 0.3)
                            : AppColors.expense.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          delta == 0
                              ? Icons.check_circle_outline_rounded
                              : delta > 0
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded,
                          size: 16,
                          color: delta == 0
                              ? AppColors.textSecondary
                              : delta > 0
                              ? AppColors.income
                              : AppColors.expense,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            delta == 0
                                ? 'Tidak ada perubahan'
                                : '${delta > 0 ? 'Pemasukan' : 'Pengeluaran'}: ${widget.state.isBalanceHidden ? '••••••' : '${delta > 0 ? '+' : '-'}${CurrencyFormatter.formatRupiah(delta.abs())}'}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: delta == 0
                                  ? AppColors.textSecondary
                                  : delta > 0
                                  ? AppColors.income
                                  : AppColors.expense,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: target == null || delta == null || isSaving
                  ? null
                  : () {
                      setState(() {
                        isSaving = true;
                        error = null;
                      });
                      try {
                        widget.state.adjustAccountBalance(
                          widget.accountId,
                          target!,
                          expectedBalance: initialBalance,
                        );
                        Navigator.pop(context);
                      } catch (e) {
                        setState(() {
                          isSaving = false;
                          error = e.toString().replaceFirst('ApiFailure: ', '');
                        });
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }
}
