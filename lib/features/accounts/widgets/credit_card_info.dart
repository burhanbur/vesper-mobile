import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/currency_amount_input.dart';
import '../../../core/utils/currency_formatter.dart';
import '../models/account.dart';
import '../models/credit_card_summary.dart';

/// Read exact raw decimals; never route card summaries through integer UI balances.
class CreditCardInfo extends StatefulWidget {
  final Account account;
  const CreditCardInfo({super.key, required this.account});
  @override
  State<CreditCardInfo> createState() => _CreditCardInfoState();
}

class _CreditCardInfoState extends State<CreditCardInfo> {
  bool _saving = false;
  Future<void> _editLimit() async {
    final account = widget.account;
    final limit = account.creditLimit;
    if (limit != null &&
        accountMinor(limit) % BigInt.from(100) != BigInt.zero) {
      AppToast.showError(
        context,
        'Limit pecahan ditampilkan tepat; pengubahan pecahan belum didukung.',
      );
      return;
    }
    final controller = TextEditingController(
      text: CurrencyAmountInput.fromDecimal(limit ?? ''),
    );
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 16, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.credit_card_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Ubah Limit Kartu',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.border),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: TextField(
                    controller: controller,
                    inputFormatters: const [CurrencyAmountInput()],
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Limit kartu (Rp)',
                      prefixText: 'Rp ',
                      hintText: '9.000.000',
                      helperText: 'Kosongkan jika tidak ingin melacak limit.',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Batal'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pop(ctx, controller.text),
                          child: const Text('Simpan'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    // Dialog route may still be animating; its controller is not disposed mid-frame.
    if (result == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await AppStateScope.of(context).updateCreditCardLimit(
        account.id,
        creditLimitInput(CurrencyAmountInput.toDecimal(result)),
      );
    } catch (error) {
      if (mounted) AppToast.showError(context, '$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final summary = widget.account.creditSummary;
    final pending =
        state.repository?.outbox.any(
          (e) =>
              (e['entity_type'] == 'accounts' &&
                  e['entity_id'] == widget.account.id) ||
              e['payload']?['account_id'] == widget.account.id ||
              e['payload']?['from_account_id'] == widget.account.id ||
              e['payload']?['to_account_id'] == widget.account.id,
        ) ??
        false;
    String money(BigInt value) => state.isBalanceHidden
        ? '••••••'
        : CurrencyFormatter.formatMinorRupiah(value);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Belanja: pilih kartu ini. Bayar tagihan: transfer dari rekening bank ke kartu ini.',
          ),
          Text('Utang Terpakai: ${money(summary.debt)}'),
          Text(
            summary.remaining == null
                ? 'Sisa Limit: tidak dilacak'
                : 'Sisa Limit: ${money(summary.remaining!)}',
          ),
          Text('Kelebihan Bayar: ${money(summary.overpayment)}'),
          if (summary.remaining?.isNegative == true)
            const Text(
              'Melebihi limit. Pencatatan pengeluaran tetap diperbolehkan.',
            ),
          const Text(
            'Kelebihan bayar bukan kas likuid dan tidak menambah limit penerbit.',
          ),
          const Text('Pencatatan ini tidak melakukan pembayaran ke bank.'),
          Text(
            pending
                ? 'Menunggu sinkronisasi / periksa status konflik'
                : 'Tersinkronisasi',
          ),
          if (!(state.repository?.isMappedObligationAccount(
                widget.account.id,
              ) ??
              true))
            TextButton(
              onPressed: _saving ? null : _editLimit,
              child: Text(
                _saving ? 'Menyimpan…' : 'Ubah limit (tidak mengubah saldo)',
              ),
            ),
        ],
      ),
    );
  }
}
