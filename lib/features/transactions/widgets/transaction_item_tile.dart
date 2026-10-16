import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../models/transaction.dart';
import 'add_transaction_modal.dart';

class TransactionItemTile extends StatelessWidget {
  final TransactionItem transaction;
  final VoidCallback? onTap;
  final bool showDate;

  const TransactionItemTile({
    super.key,
    required this.transaction,
    this.onTap,
    this.showDate = true,
  });

  IconData _getCategoryIcon() {
    final cat = transaction.categoryName.toLowerCase();
    final description = '$cat ${transaction.note ?? ''}'.toLowerCase();
    if (description.contains('penyesuaian saldo') ||
        description.contains('koreksi saldo')) {
      return Icons.tune_rounded;
    }
    if (cat.contains('makan') ||
        cat.contains('kuliner') ||
        cat.contains('food')) {
      return Icons.restaurant_rounded;
    }
    if (cat.contains('transpor') ||
        cat.contains('bensin') ||
        cat.contains('ojek')) {
      return Icons.directions_car_rounded;
    }
    if (cat.contains('gaji') ||
        cat.contains('salary') ||
        cat.contains('income')) {
      return Icons.account_balance_wallet_rounded;
    }
    if (cat.contains('belanja') || cat.contains('shopping')) {
      return Icons.shopping_bag_outlined;
    }
    if (cat.contains('keluarga') || cat.contains('family')) {
      return Icons.people_outline_rounded;
    }
    if (cat.contains('tagihan') ||
        cat.contains('listrik') ||
        cat.contains('air') ||
        cat.contains('internet') ||
        cat.contains('pulsa')) {
      return Icons.receipt_long_rounded;
    }
    if (cat.contains('transfer')) return Icons.swap_horiz_rounded;
    if (cat.contains('invest')) return Icons.trending_up_rounded;
    if (cat.contains('utang') || cat.contains('piutang')) {
      return Icons.handshake_outlined;
    }
    if (cat.contains('penyesuaian') ||
        cat.contains('saldo') ||
        cat.contains('koreksi') ||
        cat.contains('adjust')) {
      return Icons.tune_rounded;
    }
    if (cat.contains('kesehatan') ||
        cat.contains('medis') ||
        cat.contains('obat')) {
      return Icons.medical_services_outlined;
    }
    if (cat.contains('hiburan') || cat.contains('game')) {
      return Icons.sports_esports_outlined;
    }
    if (cat.contains('pendidikan') ||
        cat.contains('kursus') ||
        cat.contains('sekolah')) {
      return Icons.school_outlined;
    }

    switch (transaction.type) {
      case TransactionType.income:
        return Icons.account_balance_wallet_rounded;
      case TransactionType.expense:
        return Icons.receipt_long_rounded;
      case TransactionType.transfer:
        return Icons.swap_horiz_rounded;
      case TransactionType.investmentBuy:
      case TransactionType.investmentSell:
        return Icons.trending_up_rounded;
    }
  }

  Color _getCategoryColor() {
    switch (transaction.type) {
      case TransactionType.income:
        return AppColors.income;
      case TransactionType.expense:
        return AppColors.expense;
      case TransactionType.transfer:
        return AppColors.transfer;
      case TransactionType.investmentBuy:
      case TransactionType.investmentSell:
        return AppColors.investment;
    }
  }

  void _showTransactionDetails(BuildContext context) {
    final state = AppStateScope.of(context);
    final account = state.getAccountById(transaction.accountId);
    final toAccount = transaction.toAccountId != null
        ? state.getAccountById(transaction.toAccountId!)
        : null;
    final canModify =
        transaction.type == TransactionType.income ||
        transaction.type == TransactionType.expense;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Detail Transaksi',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Big Amount Header
            Center(
              child: Column(
                children: [
                  Text(
                    state.isBalanceHidden
                        ? '••••••'
                        : CurrencyFormatter.formatRupiah(
                            transaction.amount,
                            withSign: true,
                            isIncome: transaction.isIncoming,
                            isExpense: !transaction.isIncoming,
                          ),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: transaction.type == TransactionType.income
                          ? AppColors.income
                          : (transaction.type == TransactionType.expense
                                ? AppColors.expense
                                : AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    transaction.categoryName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            const Divider(color: AppColors.divider),
            const SizedBox(height: 12),

            _buildDetailRow('Jenis Transaksi', transaction.typeLabel),
            _buildDetailRow('Akun', account?.name ?? 'Akun Utama'),
            if (toAccount != null)
              _buildDetailRow('Akun Tujuan', toAccount.name),
            _buildDetailRow(
              'Tanggal & Waktu',
              DateFormatter.formatFull(transaction.date),
            ),
            _buildDetailRow('Dibuat oleh', transaction.createdByName),
            if (transaction.note != null && transaction.note!.isNotEmpty)
              _buildDetailRow('Catatan', transaction.note!),
            _buildDetailRow(
              'Status Sinkronisasi',
              transaction.syncStatus == SyncStatus.synced
                  ? 'Tersinkron'
                  : 'Menunggu sinkronisasi',
              isStatus: true,
              isSynced: transaction.syncStatus == SyncStatus.synced,
            ),

            const SizedBox(height: 24),
            if (canModify) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        AddTransactionModal.show(
                          context,
                          initialType: transaction.type,
                          initialAccountId: transaction.accountId,
                          transactionToEdit: transaction,
                        );
                      },
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Ubah'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmDelete(ctx, context, state),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Hapus'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.expense,
                        side: const BorderSide(color: AppColors.expense),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Tutup'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(
    BuildContext sheetCtx,
    BuildContext pageCtx,
    AppState state,
  ) {
    showDialog<void>(
      context: sheetCtx,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Hapus Transaksi?'),
        content: Text(
          'Transaksi "${transaction.note?.isNotEmpty == true ? transaction.note : transaction.categoryName}" '
          'sebesar ${CurrencyFormatter.formatRupiah(transaction.amount)} akan dihapus. '
          'Saldo akun terkait akan dikembalikan secara otomatis.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () {
              Navigator.of(dialogCtx).pop(); // close dialog
              Navigator.of(sheetCtx).pop(); // close bottom sheet
              try {
                state.deleteTransaction(transaction.id);
                ScaffoldMessenger.of(pageCtx).showSnackBar(
                  const SnackBar(
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: AppColors.primary,
                    content: Text('Transaksi berhasil dihapus.'),
                  ),
                );
              } on ApiFailure catch (err) {
                ScaffoldMessenger.of(pageCtx).showSnackBar(
                  SnackBar(
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: AppColors.expense,
                    content: Text(err.toString()),
                  ),
                );
              }
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isStatus = false,
    bool isSynced = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          if (isStatus)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isSynced
                    ? AppColors.incomeLight
                    : AppColors.warningLight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSynced ? AppColors.income : AppColors.warning,
                ),
              ),
            )
          else
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRightSubLabel(Color color) {
    if (transaction.type == TransactionType.transfer) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          transaction.typeLabel,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      );
    }

    if (transaction.type == TransactionType.investmentBuy ||
        transaction.type == TransactionType.investmentSell) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          transaction.typeLabel,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      );
    }

    if (transaction.isDebt || transaction.isReceivable) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          transaction.isDebt ? 'Utang' : 'Piutang',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    // For regular income/expense, display time if available
    final local = transaction.date.toLocal();
    if (local.hour != 0 || local.minute != 0) {
      return Text(
        DateFormatter.formatTime(transaction.date),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppColors.textMuted,
        ),
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final account = state.getAccountById(transaction.accountId);
    final accountName = account?.name ?? 'Akun';
    final isShared = account?.isShared ?? false;
    final color = _getCategoryColor();
    final isHidden = state.isBalanceHidden;

    final hasNote =
        transaction.note != null && transaction.note!.trim().isNotEmpty;
    final primaryTitle = hasNote
        ? transaction.note!.trim()
        : transaction.categoryName;

    final subtitleParts = <String>[];
    if (hasNote && transaction.categoryName.isNotEmpty) {
      subtitleParts.add(transaction.categoryName);
    }
    subtitleParts.add(accountName);
    if (showDate) {
      subtitleParts.add(DateFormatter.formatRelativeOrDate(transaction.date));
    }
    final subtitle = subtitleParts.join(' • ');

    return InkWell(
      onTap: onTap ?? () => _showTransactionDetails(context),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Category Icon with soft background & delicate border
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: color.withValues(alpha: 0.20),
                  width: 1,
                ),
              ),
              child: Icon(_getCategoryIcon(), color: color, size: 22),
            ),
            const SizedBox(width: 12),

            // Title & Subtitle (Expanded to take full space)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          primaryTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ),
                      if (transaction.syncStatus == SyncStatus.pending) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.cloud_upload_outlined,
                          size: 14,
                          color: AppColors.warning,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                      // Shared member badge per PRD 4.4
                      if (isShared &&
                          transaction.createdByName.isNotEmpty &&
                          transaction.createdByName != state.userName) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            transaction.createdByName.split(' ').first,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accentDark,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Amount & Type/Time badge (Intrinsic width, NO flex greedy crushing)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isHidden
                      ? '••••••'
                      : CurrencyFormatter.formatRupiah(
                          transaction.amount,
                          withSign: true,
                          isIncome: transaction.isIncoming,
                          isExpense: !transaction.isIncoming,
                        ),
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: transaction.type == TransactionType.income
                        ? AppColors.income
                        : (transaction.type == TransactionType.expense
                              ? AppColors.expense
                              : AppColors.textPrimary),
                  ),
                ),
                const SizedBox(height: 3),
                _buildRightSubLabel(color),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
