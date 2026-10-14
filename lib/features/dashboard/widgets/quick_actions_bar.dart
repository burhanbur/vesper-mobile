import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';

class QuickActionsBar extends StatelessWidget {
  final VoidCallback onAddTransaction;
  final VoidCallback onTransfer;
  final VoidCallback onInvestments;
  final VoidCallback onReports;

  const QuickActionsBar({
    super.key,
    required this.onAddTransaction,
    required this.onTransfer,
    required this.onInvestments,
    required this.onReports,
  });

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color bg,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: color.withValues(alpha: 0.18),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 7),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.75)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.025),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildActionButton(
                icon: Icons.add_rounded,
                label: 'Catat',
                color: AppColors.primary,
                bg: AppColors.accentLight,
                onTap: onAddTransaction,
              ),
            ),
            Expanded(
              child: _buildActionButton(
                icon: Icons.swap_horiz_rounded,
                label: 'Transfer 🔒',
                color: AppColors.textMuted,
                bg: AppColors.surfaceVariant,
                onTap: null,
              ),
            ),
            Expanded(
              child: _buildActionButton(
                icon: Icons.trending_up_rounded,
                label: 'Aset Baru',
                color: AppColors.investment,
                bg: AppColors.investmentLight,
                onTap: onInvestments,
              ),
            ),
            Expanded(
              child: _buildActionButton(
                icon: Icons.pie_chart_outline_rounded,
                label: 'Laporan',
                color: AppColors.warning,
                bg: AppColors.warningLight,
                onTap: onReports,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
