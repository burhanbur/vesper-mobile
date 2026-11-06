import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/shell_management_scope.dart';
import '../../accounts/pages/accounts_page.dart';
import '../../bills/pages/bills_page.dart';
import '../../financial_health/pages/financial_health_page.dart';
import '../../goals/pages/goals_page.dart';
import '../../obligations/pages/obligations_page.dart';
import '../../reports/pages/budget_page.dart';

class MainMenuCard extends StatelessWidget {
  final VoidCallback onNavigateToInvestments;
  final VoidCallback onNavigateToReports;

  const MainMenuCard({
    super.key,
    required this.onNavigateToInvestments,
    required this.onNavigateToReports,
  });

  Widget _buildMenuItem({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: iconColor.withValues(alpha: 0.12),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: iconColor.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, color: iconColor, size: 21),
              ),
              const SizedBox(height: 5),
              SizedBox(
                width: double.infinity,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header: Menu Utama & Action (outside card)
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 16,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Menu Utama',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                InkWell(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Semua 8 fitur utama aktif dan siap diakses.',
                        ),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.settings_outlined,
                          size: 13,
                          color: AppColors.accentDark,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Ubah',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accentDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Menu Grid Card Container
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.border.withValues(alpha: 0.8),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.025),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 4x2 Grid of Main Menu Items
                Row(
                  children: [
                    Expanded(
                      child: _buildMenuItem(
                        context: context,
                        label: 'Budget',
                        icon: Icons.pie_chart_outline_rounded,
                        iconColor: const Color(0xFF7C3AED),
                        bgColor: const Color(0xFFF5F3FF),
                        onTap: () => ShellManagementScope.open(
                          context,
                          const BudgetPage(),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _buildMenuItem(
                        context: context,
                        label: 'Goals',
                        icon: Icons.track_changes_rounded,
                        iconColor: const Color(0xFF0284C7),
                        bgColor: const Color(0xFFF0F9FF),
                        onTap: () => ShellManagementScope.open(
                          context,
                          const GoalsPage(),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _buildMenuItem(
                        context: context,
                        label: 'Aset',
                        icon: Icons.account_balance_rounded,
                        iconColor: const Color(0xFFD97706),
                        bgColor: const Color(0xFFFFFBEB),
                        onTap: () => ShellManagementScope.open(
                          context,
                          const AccountsPage(),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _buildMenuItem(
                        context: context,
                        label: 'Investasi',
                        icon: Icons.trending_up_rounded,
                        iconColor: const Color(0xFF16A34A),
                        bgColor: const Color(0xFFF0FDF4),
                        onTap: onNavigateToInvestments,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildMenuItem(
                        context: context,
                        label: 'Utang',
                        icon: Icons.payments_outlined,
                        iconColor: const Color(0xFFE11D48),
                        bgColor: const Color(0xFFFFF1F2),
                        onTap: () => ShellManagementScope.open(
                          context,
                          const ObligationsPage(),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _buildMenuItem(
                        context: context,
                        label: 'Finansial',
                        icon: Icons.monitor_heart_outlined,
                        iconColor: const Color(0xFF15803D),
                        bgColor: const Color(0xFFDCFCE7),
                        onTap: () => ShellManagementScope.open(
                          context,
                          const FinancialHealthPage(),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _buildMenuItem(
                        context: context,
                        label: 'Laporan',
                        icon: Icons.bar_chart_rounded,
                        iconColor: const Color(0xFF475569),
                        bgColor: const Color(0xFFF1F5F9),
                        onTap: onNavigateToReports,
                      ),
                    ),
                    Expanded(
                      child: _buildMenuItem(
                        context: context,
                        label: 'Tagihan',
                        icon: Icons.receipt_long_outlined,
                        iconColor: const Color(0xFF6D28D9),
                        bgColor: const Color(0xFFEDE9FE),
                        onTap: () => ShellManagementScope.open(
                          context,
                          const BillsPage(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
