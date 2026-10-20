import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/shell_management_scope.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../accounts/pages/accounts_page.dart';

class WealthTransparencySheet extends StatelessWidget {
  const WealthTransparencySheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const WealthTransparencySheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final isHidden = state.isBalanceHidden;

    final liquidCash = state.totalLiquidCash;
    final investments = state.totalInvestmentValue;
    final debt = state.totalDebt;
    final netWorth = state.totalNetWorth;

    final totalAssets = (liquidCash + investments) > 0
        ? (liquidCash + investments)
        : 1;
    final liquidPercent = ((liquidCash / totalAssets) * 100).clamp(0.0, 100.0);
    final investPercent = ((investments / totalAssets) * 100).clamp(0.0, 100.0);

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.pie_chart_outline_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Transparansi & Alokasi Kekayaan',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Estimasi tercatat lokal; bukan net worth lengkap',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Grand Net Worth Hero Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    AppColors.primaryGradientStart,
                    AppColors.primaryGradientEnd,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Estimasi lokal (parsial)',
                        style: TextStyle(
                          color: AppColors.sageMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Likuid + Investasi - Hutang',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isHidden
                        ? 'Rp •••••••••'
                        : CurrencyFormatter.formatRupiah(netWorth),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Progress Allocation Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      height: 8,
                      child: Row(
                        children: [
                          if (liquidPercent > 0)
                            Expanded(
                              flex: liquidPercent.toInt().clamp(1, 100),
                              child: Container(color: const Color(0xFF10B981)),
                            ),
                          if (investPercent > 0)
                            Expanded(
                              flex: investPercent.toInt().clamp(1, 100),
                              child: Container(color: const Color(0xFF8B5CF6)),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '🟢 Likuid ${liquidPercent.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '🟣 Investasi ${investPercent.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3 Detail Cards (Dana Likuid, Portofolio Investasi, Hutang)
            Row(
              children: [
                // Dana Likuid
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.account_balance_wallet_rounded,
                                color: Colors.white,
                                size: 12,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Expanded(
                              child: Text(
                                'Dana Likuid',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF065F46),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isHidden
                              ? '••••••'
                              : CurrencyFormatter.formatRupiah(liquidCash),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF065F46),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Kas & Bank Siap Pakai',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF047857),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Portofolio Investasi
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F3FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFDDD6FE)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: const BoxDecoration(
                                color: Color(0xFF8B5CF6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.trending_up_rounded,
                                color: Colors.white,
                                size: 12,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Expanded(
                              child: Text(
                                'Aset Investasi',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF5B21B6),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isHidden
                              ? '••••••'
                              : CurrencyFormatter.formatRupiah(investments),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF5B21B6),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Saham & Reksadana',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF6D28D9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Hutang & Kewajiban (if any or 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: debt > 0
                    ? const Color(0xFFFFF1F2)
                    : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: debt > 0 ? const Color(0xFFFECDD3) : AppColors.border,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.credit_card_rounded,
                        color: debt > 0
                            ? const Color(0xFFE11D48)
                            : AppColors.textMuted,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Hutang & Kewajiban',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: debt > 0
                              ? const Color(0xFF9F1239)
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    isHidden ? '••••••' : CurrencyFormatter.formatRupiah(debt),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: debt > 0
                          ? const Color(0xFFE11D48)
                          : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Button to open full AccountsPage
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                ShellManagementScope.open(context, const AccountsPage());
              },
              icon: const Icon(Icons.account_tree_outlined, size: 18),
              label: const Text('Buka Kelola Akun & Portofolio Lengkap'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
