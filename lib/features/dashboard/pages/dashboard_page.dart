import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/app_header.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../accounts/pages/accounts_page.dart';
import '../../accounts/widgets/account_card.dart';
import '../../investments/widgets/investment_trade_modal.dart';
import '../../transactions/models/transaction.dart';
import '../../transactions/widgets/add_transaction_modal.dart';
import '../../transactions/widgets/transaction_item_tile.dart';
import '../widgets/net_worth_card.dart';
import '../widgets/offline_banner.dart';
import '../widgets/quick_actions_bar.dart';

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
    final transactions = state.transactions.take(5).toList();
    final netSavings = state.monthNetSavings;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            if (!state.isOfflineMode && state.pendingSyncCount > 0) {
              state.syncPendingNow();
            }
            await Future.delayed(const Duration(milliseconds: 400));
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top App Header (Avatar, Halo Burhan, Keluarga Mafazi, Bell)
                AppHeader(onHouseholdTap: onNavigateToHousehold),

                // Offline Mode Banner
                const OfflineBanner(),

                // Hero Total Kekayaan Card
                const NetWorthCard(),

                // Neraca Card matching contoh-1.png ("Neraca: + Rp 6.800.000")
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: netSavings >= 0
                                      ? AppColors.incomeLight
                                      : AppColors.expenseLight,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  netSavings >= 0
                                      ? Icons.savings_outlined
                                      : Icons.trending_down_rounded,
                                  color: netSavings >= 0
                                      ? AppColors.income
                                      : AppColors.expense,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Flexible(
                                child: Text(
                                  'Neraca Bulan Berjalan',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isHidden
                              ? '••••••'
                              : CurrencyFormatter.formatRupiah(netSavings, withSign: true),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: netSavings >= 0 ? AppColors.income : AppColors.expense,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 6),

                // 4 Quick Actions (Catat, Transfer, Aset, Laporan)
                QuickActionsBar(
                  onAddTransaction: () {
                    AddTransactionModal.show(
                      context,
                      initialType: TransactionType.expense,
                    );
                  },
                  onTransfer: () {
                    AddTransactionModal.show(
                      context,
                      initialType: TransactionType.transfer,
                    );
                  },
                  onInvestments: () => InvestmentTradeModal.show(context),
                  onReports: onNavigateToReports,
                ),

                const SizedBox(height: 10),

                // Akun Terdaftar (Horizontal List) with "Lihat Semua"
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Akun & Rekening',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (context) => const AccountsPage(),
                            ),
                          );
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
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

                SizedBox(
                  height: 195,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    itemCount: accounts.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      return AccountCard(
                        account: accounts[index],
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (context) => const AccountsPage(),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                const SizedBox(height: 20),

                // Transaksi Terbaru
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Transaksi Terbaru',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      InkWell(
                        onTap: onNavigateToTransactions,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
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

                // Transactions List Card Container
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: transactions.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(
                              child: Text(
                                'Belum ada transaksi',
                                style: TextStyle(color: AppColors.textMuted),
                              ),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: transactions.length,
                            separatorBuilder: (context, index) => const Divider(
                              height: 1,
                              color: AppColors.divider,
                              indent: 72,
                            ),
                            itemBuilder: (context, index) {
                              return TransactionItemTile(
                                transaction: transactions[index],
                              );
                            },
                          ),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
