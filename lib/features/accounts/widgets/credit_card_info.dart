import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../core/widgets/app_toast.dart';
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
      text: limit?.split('.').first ?? '',
    );
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ubah Limit Kartu'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Limit Rupiah utuh tanpa pemisah',
            helperText: 'Kosongkan untuk tidak dilacak.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    // Dialog route may still be animating; its controller is not disposed mid-frame.
    if (result == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await AppStateScope.of(context)
          .updateCreditCardLimit(account.id, creditLimitInput(result));
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
    String money(BigInt value) =>
        state.isBalanceHidden ? '••••••' : 'Rp ${accountDecimal(value)}';
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
