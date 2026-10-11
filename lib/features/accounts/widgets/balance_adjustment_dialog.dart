import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
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

  @override
  void initState() {
    super.initState();
    initialBalance = widget.state.getAccountById(widget.accountId)?.balance;
    controller.text = initialBalance?.toString() ?? '';
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
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
            target = parseAdjustmentTarget(controller.text);
            delta = adjustmentDifference(account.balance, target);
          } catch (e) {
            validation = e.toString();
          }
        }
        return AlertDialog(
          title: const Text('Ubah Saldo'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Target dihitung dari saldo lokal, termasuk transaksi tertunda. Penyesuaian masuk laporan pemasukan/pengeluaran. Perubahan dari perangkat lain dapat mengubah saldo setelah sinkronisasi.',
                ),
                Text(
                  'Saldo saat ini: ${widget.state.isBalanceHidden
                      ? '••••••'
                      : initialBalance == null
                      ? '-'
                      : CurrencyFormatter.formatRupiah(initialBalance!)}',
                ),
                TextField(
                  controller: controller,
                  autofocus: true,
                  obscureText: widget.state.isBalanceHidden,
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Target saldo (Rupiah bulat)',
                    errorText:
                        error ?? (controller.text.isEmpty ? null : validation),
                  ),
                  onChanged: (_) => setState(() {
                    error = null;
                  }),
                ),
                const SizedBox(height: 12),
                if (delta != null)
                  Text(
                    delta == 0
                        ? 'Tidak ada perubahan'
                        : '${delta > 0 ? 'Pemasukan' : 'Pengeluaran'}: ${widget.state.isBalanceHidden ? '••••••' : '${delta > 0 ? '+' : '-'}${CurrencyFormatter.formatRupiah(delta.abs())}'}',
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: target == null || delta == null
                  ? null
                  : () {
                      try {
                        widget.state.adjustAccountBalance(
                          widget.accountId,
                          target!,
                          expectedBalance: initialBalance,
                        );
                        Navigator.pop(context);
                      } catch (e) {
                        setState(() {
                          error = e.toString();
                        });
                      }
                    },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }
}
