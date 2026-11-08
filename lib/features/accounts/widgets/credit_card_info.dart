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

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    bool fullWidth = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
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

    final limitStr = widget.account.creditLimit;
    final hasLimit =
        limitStr != null &&
        limitStr.isNotEmpty &&
        accountMinor(limitStr) > BigInt.zero;
    final limitMinor = hasLimit ? accountMinor(limitStr) : BigInt.zero;
    final debtMinor = summary.debt;
    final percent = limitMinor > BigInt.zero
        ? (debtMinor.toDouble() / limitMinor.toDouble()).clamp(0.0, 1.0)
        : 0.0;
    final percentStr = (percent * 100).toStringAsFixed(0);
    final barColor = percent > 0.8
        ? AppColors.expense
        : percent > 0.5
        ? AppColors.warning
        : AppColors.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Limit & Utilization Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.border.withValues(alpha: 0.7),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.speed_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Penggunaan Limit',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    if (hasLimit)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: barColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$percentStr% terpakai',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: barColor,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                if (hasLimit) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percent,
                      minHeight: 8,
                      backgroundColor: AppColors.surfaceVariant,
                      valueColor: AlwaysStoppedAnimation<Color>(barColor),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Terpakai: ${money(summary.debt)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        'Total Limit: ${money(limitMinor)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ] else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 15,
                          color: AppColors.textMuted,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Limit belum diatur. Atur limit kartu untuk memantau sisa kuota belanja.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (summary.remaining?.isNegative == true) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.expenseLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.expense.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 16,
                          color: AppColors.expense,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Melebihi limit kartu. Pencatatan pengeluaran tetap diperbolehkan.',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.expense,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 12),

                // Stats Metrics Grid
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        label: 'Utang Terpakai',
                        value: money(summary.debt),
                        icon: Icons.receipt_long_rounded,
                        color: AppColors.expense,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMetricTile(
                        label: 'Sisa Limit',
                        value: summary.remaining == null
                            ? 'Tidak dilacak'
                            : money(summary.remaining!),
                        icon: Icons.pie_chart_outline_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                if (summary.overpayment > BigInt.zero) ...[
                  const SizedBox(height: 10),
                  _buildMetricTile(
                    label: 'Kelebihan Bayar',
                    value: money(summary.overpayment),
                    icon: Icons.account_balance_wallet_outlined,
                    color: AppColors.info,
                    fullWidth: true,
                  ),
                ],

                const SizedBox(height: 14),

                // Action & Sync Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: pending
                                ? AppColors.warning
                                : AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          pending ? 'Menunggu sinkronisasi' : 'Tersinkronisasi',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: pending
                                ? AppColors.warning
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    if (!(state.repository?.isMappedObligationAccount(
                          widget.account.id,
                        ) ??
                        true))
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          side: const BorderSide(color: AppColors.primary),
                        ),
                        icon: const Icon(Icons.tune_rounded, size: 14),
                        label: Text(
                          _saving ? 'Menyimpan…' : 'Ubah Limit',
                          style: const TextStyle(fontSize: 12),
                        ),
                        onPressed: _saving ? null : _editLimit,
                      ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 2. Panduan & Edukasi Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Panduan Kartu Kredit',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildGuideRow(
                  Icons.shopping_bag_outlined,
                  'Belanja: Pilih kartu ini saat mencatat transaksi pengeluaran.',
                ),
                const SizedBox(height: 6),
                _buildGuideRow(
                  Icons.swap_horiz_rounded,
                  'Bayar Tagihan: Transfer saldo dari rekening bank fisik ke kartu ini.',
                ),
                const SizedBox(height: 6),
                _buildGuideRow(
                  Icons.verified_user_outlined,
                  'Pencatatan ini tidak melakukan debet otomatis ke bank penerbit.',
                ),
                const SizedBox(height: 6),
                _buildGuideRow(
                  Icons.info_outline_rounded,
                  'Kelebihan bayar bukan kas likuid dan tidak menambah limit penerbit.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
