import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../database/transaction_query.dart';
import '../../transactions/models/transaction.dart';
import '../../transactions/widgets/add_transaction_modal.dart';
import '../../transactions/widgets/transaction_item_tile.dart';
import '../models/account.dart';
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
  final _pages = <TransactionCursor?>[null];
  int _page = 0;
  Object? _scope;
  int? _revision;

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
    if (_scope != state.localDataScope ||
        _revision != state.localDataRevision) {
      _scope = state.localDataScope;
      _revision = state.localDataRevision;
      _page = 0;
      _pages
        ..clear()
        ..add(null);
    }
    final history = state.transactionPage(
      TransactionQuery(accountId: widget.accountId, after: _pages[_page]),
    );
    final transactions = history.items;
    final children = account != null
        ? state.getChildrenForAccount(account.id)
        : const <Account>[];
    final hasChildren = children.isNotEmpty;

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
                key: ValueKey((_scope, _revision, _page, widget.accountId)),
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
                        if (hasChildren) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Total akumulasi dari ${children.length} kantong terhubung: ${state.isBalanceHidden ? '••••••' : CurrencyFormatter.formatRupiah(account.balance + children.fold<int>(0, (sum, c) => sum + c.balance))}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.accentDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
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
                        const SizedBox(height: 18),
                        // Include in Total Toggle Card
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: account.isIncludeTotal && !hasChildren
                                  ? AppColors.accent.withValues(alpha: 0.3)
                                  : AppColors.border,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: account.isIncludeTotal && !hasChildren
                                      ? AppColors.accent.withValues(alpha: 0.12)
                                      : AppColors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  account.isIncludeTotal && !hasChildren
                                      ? Icons.visibility_rounded
                                      : Icons.visibility_off_rounded,
                                  color: account.isIncludeTotal && !hasChildren
                                      ? AppColors.accentDark
                                      : AppColors.textMuted,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Sertakan dalam Total Saldo',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      hasChildren
                                          ? 'Akun induk otomatis dikecualikan agar saldo kantong tidak ganda.'
                                          : account.isIncludeTotal
                                          ? 'Saldo akun ini dihitung dalam ringkasan total saldo.'
                                          : 'Saldo akun ini diabaikan dari ringkasan total saldo.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: hasChildren
                                            ? const Color(0xFFD97706)
                                            : AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              CupertinoSwitch(
                                key: const ValueKey(
                                  'account_include_total_switch',
                                ),
                                value: account.isIncludeTotal && !hasChildren,
                                activeTrackColor: AppColors.primary,
                                onChanged:
                                    (account.ownerUserId !=
                                                state.currentUserId &&
                                            state.currentUserId.isNotEmpty) ||
                                        hasChildren
                                    ? null
                                    : (val) async {
                                        try {
                                          await state.updateAccountIncludeTotal(
                                            accountId: account.id,
                                            isIncludeTotal: val,
                                          );
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Gagal memperbarui: $e',
                                                    ),
                                                  ),
                                                );
                                          }
                                        }
                                      },
                              ),
                            ],
                          ),
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
                  SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Halaman transaksi sebelumnya',
                          onPressed: _page == 0
                              ? null
                              : () => setState(() => _page--),
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Expanded(
                          child: Text(
                            'Halaman ${_page + 1} · ${transactions.length} ditampilkan',
                            textAlign: TextAlign.center,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Halaman transaksi berikutnya',
                          onPressed: history.next == null
                              ? null
                              : () => setState(() {
                                  if (_pages.length == _page + 1) {
                                    _pages.add(history.next);
                                  }
                                  _page++;
                                }),
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
