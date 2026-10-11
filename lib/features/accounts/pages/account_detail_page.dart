import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../transactions/models/transaction.dart';
import '../../transactions/widgets/add_transaction_modal.dart';
import '../../transactions/widgets/transaction_item_tile.dart';
import '../widgets/balance_adjustment_dialog.dart';

/// Account ledger displayed within the shell's management navigator.
class AccountDetailPage extends StatefulWidget {
  final String accountId;
  final VoidCallback onSettings;

  const AccountDetailPage({
    super.key,
    required this.accountId,
    required this.onSettings,
  });

  @override
  State<AccountDetailPage> createState() => _AccountDetailPageState();
}

class _AccountDetailPageState extends State<AccountDetailPage> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Render cached history first. Use the existing full sync/list refresh so an
    // account-filtered snapshot cannot replace other accounts' cached history.
    final state = AppStateScope.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(state.refresh());
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final account = state.getAccountById(widget.accountId);
    final parentId = account?.parentAccountId;
    final parent = parentId != null && parentId != account?.id
        ? state.getAccountById(parentId)
        : null;
    final title = account == null
        ? 'Detail Akun'
        : parent == null
        ? account.name
        : '${parent.name} - ${account.name}';
    final transactions = state.transactionsForAccount(widget.accountId);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (account != null)
            IconButton(
              tooltip: 'Pengaturan & Sharing',
              icon: const Icon(Icons.settings_outlined),
              onPressed: widget.onSettings,
            ),
        ],
      ),
      body: account == null
          ? const Center(child: Text('Akun tidak ditemukan.'))
          : RefreshIndicator(
              onRefresh: state.refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Saldo Rekening'),
                        const SizedBox(height: 8),
                        Text(
                          state.isBalanceHidden
                              ? '••••••'
                              : CurrencyFormatter.formatRupiah(account.balance),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Wrap(
                          spacing: 12,
                          children: [
                            OutlinedButton(
                              onPressed: () {
                                if (account.ownerUserId !=
                                        state.currentUserId ||
                                    state.currentUserId.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Hanya pemilik akun dapat menyesuaikan saldo.',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                showDialog<void>(
                                  context: context,
                                  builder: (_) => BalanceAdjustmentDialog(
                                    state: state,
                                    accountId: account.id,
                                  ),
                                );
                              },
                              child: const Text('Ubah Saldo'),
                            ),
                            OutlinedButton(
                              onPressed:
                                  state.selectableAccounts.any(
                                    (candidate) => candidate.id == account.id,
                                  )
                                  ? () => AddTransactionModal.show(
                                      context,
                                      initialType: TransactionType.transfer,
                                      initialAccountId: account.id,
                                    )
                                  : null,
                              child: const Text('Transfer Saldo'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Riwayat Transaksi',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Text('Terbaru terlebih dahulu • Akun ini saja'),
                        if (state.loading) const LinearProgressIndicator(),
                        if (state.isOfflineMode || state.dataError != null)
                          const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Text(
                              'Menampilkan data lokal. Tarik untuk mencoba sinkronisasi kembali.',
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (transactions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Belum ada transaksi pada akun ini.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    ...transactions.map(
                      (transaction) => TransactionItemTile(
                        key: ValueKey(transaction.id),
                        transaction: transaction,
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
