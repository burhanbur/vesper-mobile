import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import 'budget_page.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  int _selectedTab = 0; // 0: Ringkasan, 1: Pengeluaran, 2: Pemasukan

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final isHidden = state.isBalanceHidden;

    final income = state.monthIncome;
    final expense = state.monthExpense;
    final netSavings = state.monthNetSavings;
    final savingsRate = income > 0 ? (netSavings / income) * 100 : 0.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Insights & Laporan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.pie_chart_outline_rounded, color: AppColors.primary),
            tooltip: 'Rencana Budget',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (context) => const BudgetPage()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Segmented Toggle: Ringkasan vs Pengeluaran vs Pemasukan
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    _buildSegmentTab(0, 'Ringkasan'),
                    _buildSegmentTab(1, 'Pengeluaran'),
                    _buildSegmentTab(2, 'Pemasukan'),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Dynamic Tab Body
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _selectedTab == 0
                    ? _buildSummaryTab(state, isHidden, income, expense, netSavings, savingsRate)
                    : _selectedTab == 1
                        ? _buildExpenseTab(state, isHidden, expense)
                        : _buildIncomeTab(state, isHidden, income),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentTab(int index, String title) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        key: ValueKey('reports_tab_$index'),
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==================== TAB 0: RINGKASAN ====================

  Widget _buildSummaryTab(
    AppState state,
    bool isHidden,
    int income,
    int expense,
    int netSavings,
    double savingsRate,
  ) {
    return Column(
      key: const ValueKey('summary_tab'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Net Savings Summary Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Surplus / Neraca Bulan Ini',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: netSavings >= 0 ? AppColors.incomeLight : AppColors.expenseLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Savings Rate: ${savingsRate.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: netSavings >= 0 ? AppColors.income : AppColors.expense,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                isHidden
                    ? 'Rp •••••••••'
                    : CurrencyFormatter.formatRupiah(netSavings, withSign: true),
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: netSavings >= 0 ? AppColors.primary : AppColors.expense,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: AppColors.divider),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Pemasukan: ${CurrencyFormatter.formatCompact(income)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.income,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pengeluaran: ${CurrencyFormatter.formatCompact(expense)}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.expense,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Perbandingan Bulanan
        const Text(
          'Perbandingan Bulanan',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildBarGroup(month: 'Apr', incH: 65, expH: 42),
                  _buildBarGroup(month: 'Mei', incH: 70, expH: 50),
                  _buildBarGroup(month: 'Jun', incH: 80, expH: 45),
                  _buildBarGroup(month: 'Jul', incH: 85, expH: 60),
                  _buildBarGroup(month: 'Agu', incH: 75, expH: 52),
                  _buildBarGroup(month: 'Sep', incH: 100, expH: 55, isCurrent: true),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: AppColors.divider),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLegend(color: AppColors.primary, label: 'Pemasukan'),
                  const SizedBox(width: 20),
                  _buildLegend(color: AppColors.expense, label: 'Pengeluaran'),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Kategori Terbesar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Kategori Terbesar',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (context) => const BudgetPage()),
                );
              },
              child: const Text('Kelola Budget', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _buildCategoryRow('Makanan & Minuman', 1665000, 33.3, Icons.restaurant_rounded, AppColors.primary),
              const SizedBox(height: 16),
              _buildCategoryRow('Belanja Bulanan', 1250000, 25.0, Icons.shopping_bag_outlined, AppColors.accentDark),
              const SizedBox(height: 16),
              _buildCategoryRow('Keluarga (Orang Tua)', 1000000, 20.0, Icons.people_outline_rounded, const Color(0xFFD97706)),
              const SizedBox(height: 16),
              _buildCategoryRow('Tagihan & WiFi', 585000, 11.7, Icons.receipt_long_rounded, AppColors.transfer),
              const SizedBox(height: 16),
              _buildCategoryRow('Transportasi', 500000, 10.0, Icons.directions_car_rounded, const Color(0xFF6B7280)),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Financial Health Indicator Card
        _buildHealthScoreCard(savingsRate),
      ],
    );
  }

  // ==================== TAB 1: PENGELUARAN ====================

  Widget _buildExpenseTab(AppState state, bool isHidden, int expense) {
    return Column(
      key: const ValueKey('expense_tab'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Total Expense Hero Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Total Pengeluaran Bulan Ini',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.incomeLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.trending_down_rounded, size: 14, color: AppColors.income),
                        SizedBox(width: 4),
                        Text(
                          'Hemat 12% vs Ags',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.income,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                isHidden ? 'Rp •••••••••' : CurrencyFormatter.formatRupiah(expense),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.expense,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: AppColors.divider),
              const SizedBox(height: 12),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Rata-rata: Rp 55.500 / hari',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pagu: Rp 8.000.000 (Aman)',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.accentDark),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Tren Pengeluaran 6 Bulan
        const Text(
          'Tren Pengeluaran (6 Bulan Terakhir)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildSingleBar(month: 'Apr', height: 42, label: '1,2 Jt', color: AppColors.expense),
                  _buildSingleBar(month: 'Mei', height: 50, label: '1,4 Jt', color: AppColors.expense),
                  _buildSingleBar(month: 'Jun', height: 45, label: '1,3 Jt', color: AppColors.expense),
                  _buildSingleBar(month: 'Jul', height: 60, label: '1,8 Jt', color: AppColors.expense),
                  _buildSingleBar(month: 'Agu', height: 52, label: '1,5 Jt', color: AppColors.expense),
                  _buildSingleBar(month: 'Sep', height: 55, label: '1,6 Jt', color: AppColors.expense, isCurrent: true),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: AppColors.divider),
              const SizedBox(height: 12),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline_rounded, size: 14, color: AppColors.textMuted),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Rata-rata 6 bln: Rp 1.470.000 / bln',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Rincian Lengkap Kategori Pengeluaran
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Rincian Kategori Pengeluaran',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('5 Kategori', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 10),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _buildCategoryRowWithTx(
                name: 'Makanan & Minuman',
                amount: 1665000,
                pct: 33.3,
                icon: Icons.restaurant_rounded,
                color: AppColors.primary,
                txCount: 14,
              ),
              const SizedBox(height: 16),
              _buildCategoryRowWithTx(
                name: 'Belanja Bulanan (Supermarket)',
                amount: 1250000,
                pct: 25.0,
                icon: Icons.shopping_bag_outlined,
                color: AppColors.accentDark,
                txCount: 6,
              ),
              const SizedBox(height: 16),
              _buildCategoryRowWithTx(
                name: 'Keluarga (Bakti Orang Tua)',
                amount: 1000000,
                pct: 20.0,
                icon: Icons.people_outline_rounded,
                color: const Color(0xFFD97706),
                txCount: 1,
              ),
              const SizedBox(height: 16),
              _buildCategoryRowWithTx(
                name: 'Tagihan, Listrik & WiFi',
                amount: 585000,
                pct: 11.7,
                icon: Icons.receipt_long_rounded,
                color: AppColors.transfer,
                txCount: 3,
              ),
              const SizedBox(height: 16),
              _buildCategoryRowWithTx(
                name: 'Transportasi & Bensin',
                amount: 500000,
                pct: 10.0,
                icon: Icons.directions_car_rounded,
                color: const Color(0xFF6B7280),
                txCount: 8,
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Expense Insight Advice
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.accentLight.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded, color: AppColors.accentDark, size: 24),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  '💡 Pengeluaran terbesar Anda bulan ini ada di Makanan & Minuman (33.3%). Pengeluaran rutin lainnya tetap terkendali dengan baik.',
                  style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== TAB 2: PEMASUKAN ====================

  Widget _buildIncomeTab(AppState state, bool isHidden, int income) {
    return Column(
      key: const ValueKey('income_tab'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Total Income Hero Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Total Pemasukan Bulan Ini',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.incomeLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.trending_up_rounded, size: 14, color: AppColors.income),
                        SizedBox(width: 4),
                        Text(
                          '+8.5% vs Ags',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.income,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                isHidden ? 'Rp •••••••••' : CurrencyFormatter.formatRupiah(income),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.income,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: AppColors.divider),
              const SizedBox(height: 12),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Utama: Rp 12.000.000',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sampingan: Rp 3.220.000',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.accentDark),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Tren Pemasukan 6 Bulan
        const Text(
          'Tren Pemasukan (6 Bulan Terakhir)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildSingleBar(month: 'Apr', height: 65, label: '13,5 Jt', color: AppColors.primary),
                  _buildSingleBar(month: 'Mei', height: 70, label: '14,0 Jt', color: AppColors.primary),
                  _buildSingleBar(month: 'Jun', height: 75, label: '14,2 Jt', color: AppColors.primary),
                  _buildSingleBar(month: 'Jul', height: 85, label: '14,8 Jt', color: AppColors.primary),
                  _buildSingleBar(month: 'Agu', height: 80, label: '14,5 Jt', color: AppColors.primary),
                  _buildSingleBar(month: 'Sep', height: 100, label: '15,2 Jt', color: AppColors.primary, isCurrent: true),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: AppColors.divider),
              const SizedBox(height: 12),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline_rounded, size: 14, color: AppColors.income),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Pemasukan bertumbuh konsisten tiap kuartal',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Rincian Sumber Pemasukan
        const Text(
          'Rincian Sumber Pemasukan',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _buildCategoryRowWithTx(
                name: 'Gaji Pokok (Burhan Mafazi)',
                amount: 10000000,
                pct: 65.7,
                icon: Icons.work_outline_rounded,
                color: AppColors.primary,
                txCount: 1,
              ),
              const SizedBox(height: 16),
              _buildCategoryRowWithTx(
                name: 'Gaji & Kontribusi (Sarah Mafazi)',
                amount: 4500000,
                pct: 29.5,
                icon: Icons.wallet_rounded,
                color: const Color(0xFF9D4EDD),
                txCount: 1,
              ),
              const SizedBox(height: 16),
              _buildCategoryRowWithTx(
                name: 'Imbal Hasil Investasi & Dividen',
                amount: 720000,
                pct: 4.8,
                icon: Icons.trending_up_rounded,
                color: AppColors.income,
                txCount: 2,
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Kaidah Alokasi Finansial 50/30/20
        const Text(
          'Evaluasi Alokasi Pemasukan (50/30/20)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAllocationBar(label: 'Kebutuhan Pokok (Needs)', actualPct: 28, targetPct: 50, color: AppColors.income),
              const SizedBox(height: 14),
              _buildAllocationBar(label: 'Keinginan (Wants)', actualPct: 12, targetPct: 30, color: const Color(0xFFD97706)),
              const SizedBox(height: 14),
              _buildAllocationBar(label: 'Tabungan & Investasi', actualPct: 60, targetPct: 20, color: AppColors.primary),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== SHARED WIDGET BUILDERS ====================

  Widget _buildHealthScoreCard(double savingsRate) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.health_and_safety_rounded, color: AppColors.accent, size: 20),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Kesehatan Finansial',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '92 / 100 • Prima',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textOnAccent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: _HealthMiniPill(title: 'Dana Darurat', value: '4.8 bln')),
              Expanded(child: _HealthMiniPill(title: 'Rasio Utang', value: '0%')),
              Expanded(child: _HealthMiniPill(title: 'Cashflow', value: 'Surplus')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSingleBar({
    required String month,
    required double height,
    required String label,
    required Color color,
    bool isCurrent = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: isCurrent ? AppColors.textPrimary : AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 22,
          height: height,
          decoration: BoxDecoration(
            color: isCurrent ? color : color.withValues(alpha: 0.5),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          month,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500,
            color: isCurrent ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildAllocationBar({
    required String label,
    required int actualPct,
    required int targetPct,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            Text('$actualPct% (Maks $targetPct%)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (actualPct / 100).clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: AppColors.surfaceVariant,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryRow(String name, int amount, double pct, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Text(
              '${CurrencyFormatter.formatCompact(amount)} (${pct.toStringAsFixed(1)}%)',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct / 100,
            minHeight: 6,
            backgroundColor: AppColors.surfaceVariant,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryRowWithTx({
    required String name,
    required int amount,
    required double pct,
    required IconData icon,
    required Color color,
    required int txCount,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '$txCount transaksi',
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            Text(
              '${CurrencyFormatter.formatCompact(amount)} (${pct.toStringAsFixed(1)}%)',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (pct / 100).clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: AppColors.surfaceVariant,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildBarGroup({
    required String month,
    required double incH,
    required double expH,
    bool isCurrent = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              width: 12,
              height: incH,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              width: 12,
              height: expH,
              decoration: BoxDecoration(
                color: AppColors.expense.withValues(alpha: 0.85),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          month,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500,
            color: isCurrent ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildLegend({required Color color, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _HealthMiniPill extends StatelessWidget {
  final String title;
  final String value;

  const _HealthMiniPill({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 10, color: AppColors.sageMuted)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ],
    );
  }
}
