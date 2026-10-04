import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../models/transaction.dart';

class TransactionItemTile extends StatelessWidget {
  final TransactionItem transaction;
  final VoidCallback? onTap;

  const TransactionItemTile({
    super.key,
    required this.transaction,
    this.onTap,
  });

  IconData _getCategoryIcon() {
    final cat = transaction.categoryName.toLowerCase();
    if (cat.contains('makan')) return Icons.restaurant_rounded;
    if (cat.contains('transpor')) return Icons.directions_car_rounded;
    if (cat.contains('gaji')) return Icons.account_balance_wallet_rounded;
    if (cat.contains('belanja')) return Icons.shopping_bag_outlined;
    if (cat.contains('keluarga')) return Icons.people_outline_rounded;
    if (cat.contains('tagihan')) return Icons.receipt_long_rounded;
    if (cat.contains('transfer')) return Icons.swap_horiz_rounded;
    if (cat.contains('invest')) return Icons.trending_up_rounded;
    if (cat.contains('utang') || cat.contains('piutang')) return Icons.handshake_outlined;
    return Icons.attach_money_rounded;
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
                    CurrencyFormatter.formatRupiah(
                      transaction.amount,
                      withSign: true,
                      isIncome: transaction.type == TransactionType.income,
                      isExpense: transaction.type == TransactionType.expense,
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

            _buildDetailRow('Akun Asal', account?.name ?? 'Akun Utama'),
            if (toAccount != null)
              _buildDetailRow('Akun Tujuan', toAccount.name),
            _buildDetailRow('Tanggal & Waktu', DateFormatter.formatFull(transaction.date)),
            _buildDetailRow('Pelaku (Created By)', transaction.createdByName),
            if (transaction.note != null && transaction.note!.isNotEmpty)
              _buildDetailRow('Catatan', transaction.note!),
            _buildDetailRow(
              'Status Sinkronisasi',
              transaction.syncStatus == SyncStatus.synced
                  ? 'Tersinkron (PostgreSQL)'
                  : 'Lokal SQLite (Menunggu sync)',
              isStatus: true,
              isSynced: transaction.syncStatus == SyncStatus.synced,
            ),

            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Tutup'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isStatus = false, bool isSynced = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          if (isStatus)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isSynced ? AppColors.incomeLight : AppColors.warningLight,
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

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final account = state.getAccountById(transaction.accountId);
    final accountName = account?.name ?? 'Akun';
    final isShared = account?.isShared ?? false;
    final color = _getCategoryColor();
    final isHidden = state.isBalanceHidden;

    return InkWell(
      onTap: onTap ?? () => _showTransactionDetails(context),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            // Category Icon with soft background
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(_getCategoryIcon(), color: color, size: 22),
            ),
            const SizedBox(width: 14),

            // Title & Account / Date / Creator (PRD 4.4)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          transaction.note != null && transaction.note!.isNotEmpty
                              ? transaction.note!
                              : transaction.categoryName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
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
                          '$accountName • ${DateFormatter.formatRelativeOrDate(transaction.date)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                      // Shared member badge per PRD 4.4
                      if (isShared && transaction.createdByName != state.userName) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
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

            // Amount
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  isHidden
                      ? '••••••'
                      : CurrencyFormatter.formatRupiah(
                          transaction.amount,
                          withSign: true,
                          isIncome: transaction.type == TransactionType.income,
                          isExpense: transaction.type == TransactionType.expense,
                        ),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: transaction.type == TransactionType.income
                        ? AppColors.income
                        : (transaction.type == TransactionType.expense
                            ? AppColors.expense
                            : AppColors.textPrimary),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  transaction.categoryName,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
