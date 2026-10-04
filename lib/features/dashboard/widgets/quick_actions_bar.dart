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
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.15)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildActionButton(
            icon: Icons.add_circle_outline_rounded,
            label: 'Catat',
            color: AppColors.primary,
            bg: AppColors.accentLight,
            onTap: onAddTransaction,
          ),
          _buildActionButton(
            icon: Icons.swap_horiz_rounded,
            label: 'Transfer',
            color: AppColors.transfer,
            bg: AppColors.transferLight,
            onTap: onTransfer,
          ),
          _buildActionButton(
            icon: Icons.trending_up_rounded,
            label: 'Aset Baru',
            color: AppColors.investment,
            bg: AppColors.investmentLight,
            onTap: onInvestments,
          ),
          _buildActionButton(
            icon: Icons.pie_chart_outline_rounded,
            label: 'Laporan',
            color: AppColors.warning,
            bg: AppColors.warningLight,
            onTap: onReports,
          ),
        ],
      ),
    );
  }
}
