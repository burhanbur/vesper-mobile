import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/app_header.dart';
import '../../../app/widgets/shell_management_scope.dart';
import '../../../database/transaction_query.dart';
import '../../accounts/pages/accounts_page.dart';
import '../../accounts/pages/account_detail_page.dart';
import '../../accounts/widgets/account_card.dart';
import '../../bills/pages/bills_page.dart';
import '../../reports/pages/budget_page.dart';
import '../../transactions/widgets/transaction_item_tile.dart';
import '../widgets/net_worth_card.dart';
import '../widgets/offline_banner.dart';
import '../widgets/main_menu_card.dart';
import '../widgets/dashboard_insights_panel.dart';
import 'net_worth_assessment_page.dart';

class DashboardPage extends StatelessWidget {
  final VoidCallback onNavigateToTransactions;
  final VoidCallback onNavigateToInvestments;
  final VoidCallback onNavigateToReports;
  final VoidCallback onNavigateToHousehold;

  const DashboardPage({
    super.key,
    required this.onNavigateToTransactions,
    required this.onNavigateToInvestments,
    required this.onNavigateToReports,
    required this.onNavigateToHousehold,
  });

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final isHidden = state.isBalanceHidden;
    final accounts = state.accounts;
    final transactions = state
        .transactionPage(const TransactionQuery(limit: 5))
        .items;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            if (!state.isOfflineMode) {
              await state.syncPendingNow();
            }
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top App Header (Avatar, Greeting, Household Selector, Bell)
                AppHeader(onHouseholdTap: onNavigateToHousehold),

                // Offline Mode Banner
                const OfflineBanner(),

                // Hero Total Kekayaan Card (includes Pemasukan, Pengeluaran, Surplus/Defisit)
                const NetWorthCard(),

                const SizedBox(height: 10),

                // Highlighted Main Menu Card matching Screenshot 1
                MainMenuCard(
                  onNavigateToInvestments: onNavigateToInvestments,
                  onNavigateToReports: onNavigateToReports,
                ),

                DashboardInsightsPanel(
                  insights: state.dashboardInsights,
                  hidden: isHidden,
                  onBills: () =>
                      ShellManagementScope.open(context, const BillsPage()),
                  onSpending: onNavigateToReports,
                  onBudgets: () =>
                      ShellManagementScope.open(context, const BudgetPage()),
                  onValuation: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const NetWorthAssessmentPage(),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Akun Terdaftar (Horizontal List) with "Lihat Semua"
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 6,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 16,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          'Akun & Rekening',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            ShellManagementScope.open(
                              context,
                              const AccountsPage(),
                            );
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            child: Text(
                              'Lihat semua',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.accentDark,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (accounts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Text(
                      'Belum ada akun',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 4,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final account in accounts)
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: AccountCard(
                              key: ValueKey('dashboard_account_${account.id}'),
                              account: account,
                              onTap: () => ShellManagementScope.open(
                                context,
                                AccountDetailPage(
                                  accountId: account.id,
                                  onSettings: () =>
                                      AccountsPage.showAccountSettings(
                                        context,
                                        state.getAccountById(account.id) ??
                                            account,
                                      ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                const SizedBox(height: 12),

                // Transaksi Terbaru
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 6,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 16,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          'Transaksi Terbaru',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                        InkWell(
                          onTap: onNavigateToTransactions,
                          borderRadius: BorderRadius.circular(8),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            child: Text(
                              'Lihat semua',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.accentDark,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Transactions List Card Container
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.border.withValues(alpha: 0.75),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.025),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: transactions.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 28,
                              horizontal: 24,
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceVariant,
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    child: const Icon(
                                      Icons.receipt_long_outlined,
                                      color: AppColors.textMuted,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'Belum ada transaksi',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Catat transaksi pertama Anda',
                                    style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 11,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            itemCount: transactions.length,
                            separatorBuilder: (context, index) => Divider(
                              height: 1,
                              color: AppColors.divider.withValues(alpha: 0.8),
                              indent: 62,
                              endIndent: 14,
                            ),
                            itemBuilder: (context, index) {
                              return TransactionItemTile(
                                transaction: transactions[index],
                                isCompact: true,
                              );
                            },
                          ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
