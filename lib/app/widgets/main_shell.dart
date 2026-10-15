import 'package:flutter/material.dart';

import '../../features/dashboard/pages/dashboard_page.dart';
import '../../features/household/pages/household_page.dart';
import '../../features/investments/pages/portfolio_page.dart';

import '../../features/reports/pages/reports_page.dart';
import '../../features/settings/pages/settings_page.dart';
import '../../features/transactions/models/transaction.dart';
import '../../features/transactions/pages/transactions_page.dart';
import '../../features/transactions/widgets/add_transaction_modal.dart';
import '../theme/app_colors.dart';
import 'shell_management_scope.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  final _managementNavigatorKey = GlobalKey<NavigatorState>();
  bool _managementOpen = false;

  void _openManagementPage(Widget page) {
    setState(() => _managementOpen = true);
    _managementNavigatorKey.currentState!
        .push<void>(MaterialPageRoute<void>(builder: (_) => page))
        .then((_) {
          if (mounted) {
            setState(() {
              _managementOpen = _managementNavigatorKey.currentState!.canPop();
            });
          }
        });
  }

  void _onTabSelected(int index) {
    _managementNavigatorKey.currentState?.popUntil((route) => route.isFirst);
    setState(() {
      _managementOpen = false;
      _currentIndex = index;
    });
  }

  void _showQuickActionSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: 28,
        ),
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
            const Text(
              'Aksi Cepat',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            // 4 Quick Action items
            _buildActionItem(
              ctx,
              icon: Icons.remove_circle_outline_rounded,
              color: AppColors.expense,
              bgColor: AppColors.expenseLight,
              title: 'Catat Pengeluaran',
              subtitle: 'Makan, belanja, tagihan & kebutuhan harian',
              onTap: () {
                Navigator.of(ctx).pop();
                AddTransactionModal.show(
                  context,
                  initialType: TransactionType.expense,
                );
              },
            ),
            const SizedBox(height: 10),
            _buildActionItem(
              ctx,
              icon: Icons.add_circle_outline_rounded,
              color: AppColors.income,
              bgColor: AppColors.incomeLight,
              title: 'Catat Pemasukan',
              subtitle: 'Gaji, bonus, side income & dividen',
              onTap: () {
                Navigator.of(ctx).pop();
                AddTransactionModal.show(
                  context,
                  initialType: TransactionType.income,
                );
              },
            ),
            const SizedBox(height: 10),
            _buildActionItem(
              ctx,
              icon: Icons.swap_horiz_rounded,
              color: AppColors.transfer,
              bgColor: AppColors.transferLight,
              title: 'Transfer Antar Akun / Utang',
              subtitle: 'Pindah dana rekening & pencatatan utang-piutang',
              onTap: () {
                Navigator.of(ctx).pop();
                AddTransactionModal.show(
                  context,
                  initialType: TransactionType.transfer,
                );
              },
            ),
            const SizedBox(height: 10),
            _buildActionItem(
              ctx,
              icon: Icons.trending_up_rounded,
              color: AppColors.investment,
              bgColor: AppColors.investmentLight,
              title: 'Lihat Portofolio',
              subtitle: 'Holdings dan snapshot investasi • hanya baca',
              onTap: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const PortfolioPage(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionItem(
    BuildContext ctx, {
    required IconData icon,
    required Color color,
    required Color bgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(
        onNavigateToTransactions: () => _onTabSelected(1),
        onNavigateToInvestments: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => const PortfolioPage(),
            ),
          );
        },
        onNavigateToReports: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (context) => const ReportsPage()),
          );
        },
        onNavigateToHousehold: () => _onTabSelected(2),
      ),
      const TransactionsPage(),
      const HouseholdPage(),
      const SettingsPage(),
    ];

    return Scaffold(
      body: Stack(
        children: [
          Offstage(
            offstage: _managementOpen,
            child: ShellManagementScope(
              openPage: _openManagementPage,
              child: IndexedStack(index: _currentIndex, children: pages),
            ),
          ),
          Offstage(
            offstage: !_managementOpen,
            child: NavigatorPopHandler<Object?>(
              enabled: _managementOpen,
              onPopWithResult: (_) =>
                  _managementNavigatorKey.currentState!.pop(),
              child: ShellManagementScope(
                openPage: _openManagementPage,
                child: Navigator(
                  key: _managementNavigatorKey,
                  onGenerateRoute: (_) => MaterialPageRoute<void>(
                    builder: (_) => const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(
            top: BorderSide(color: AppColors.borderSubtle, width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        padding: const EdgeInsets.only(top: 8, bottom: 12),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Tab 1: Beranda (contoh-1.png & contoh-2.png)
              _buildNavButton(
                index: 0,
                icon: Icons.home_outlined,
                activeIcon: Icons.home_filled,
                label: 'Beranda',
              ),

              // Tab 2: Transaksi
              _buildNavButton(
                index: 1,
                icon: Icons.receipt_long_outlined,
                activeIcon: Icons.receipt_long_rounded,
                label: 'Transaksi',
              ),

              // Center Floating Action Button (+) matching contoh-1.png & contoh-2.png
              GestureDetector(
                key: const ValueKey('shell_quick_action'),
                onTap: () => _showQuickActionSheet(context),
                child: Container(
                  width: 48,
                  height: 48,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),

              // Tab 3: Grup (Ruang Bersama Pasangan & Grup)
              _buildNavButton(
                index: 2,
                icon: Icons.groups_outlined,
                activeIcon: Icons.groups_rounded,
                label: 'Grup',
              ),

              // Tab 4: Lainnya
              _buildNavButton(
                index: 3,
                icon: Icons.grid_view_outlined,
                activeIcon: Icons.grid_view_rounded,
                label: 'Lainnya',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavButton({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final isSelected = _currentIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () => _onTabSelected(index),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                color: isSelected ? AppColors.primary : AppColors.textMuted,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppColors.primary : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
