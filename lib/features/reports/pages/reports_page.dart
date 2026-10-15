import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/transaction_period.dart';
import '../../../core/widgets/month_selector.dart';
import '../../transactions/models/transaction.dart';
import 'budget_page.dart';

/// Reports are derived from the same durable transaction snapshot as the ledger.
class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  int _selectedTab = 0;
  TransactionPeriod _period = TransactionPeriod(DateTime.now());

  static IconData _getCategoryIcon(String categoryName, bool isIncome) {
    final cat = categoryName.toLowerCase();
    if (isIncome) {
      if (cat.contains('gaji') || cat.contains('salary')) {
        return Icons.work_rounded;
      }
      if (cat.contains('bonus') || cat.contains('reward')) {
        return Icons.card_giftcard_rounded;
      }
      if (cat.contains('invest') || cat.contains('dividen')) {
        return Icons.trending_up_rounded;
      }
      if (cat.contains('usaha') || cat.contains('bisnis')) {
        return Icons.storefront_rounded;
      }
      return Icons.account_balance_wallet_rounded;
    }
    if (cat.contains('makan') ||
        cat.contains('kuliner') ||
        cat.contains('food')) {
      return Icons.restaurant_rounded;
    }
    if (cat.contains('belanja') ||
        cat.contains('shopping') ||
        cat.contains('market')) {
      return Icons.shopping_bag_outlined;
    }
    if (cat.contains('transpor') ||
        cat.contains('bensin') ||
        cat.contains('kendaraan') ||
        cat.contains('ojek')) {
      return Icons.directions_car_rounded;
    }
    if (cat.contains('rumah') ||
        cat.contains('household') ||
        cat.contains('home')) {
      return Icons.home_rounded;
    }
    if (cat.contains('tagihan') ||
        cat.contains('bill') ||
        cat.contains('listrik') ||
        cat.contains('air') ||
        cat.contains('pulsa')) {
      return Icons.receipt_long_rounded;
    }
    if (cat.contains('hiburan') ||
        cat.contains('entertain') ||
        cat.contains('game')) {
      return Icons.sports_esports_rounded;
    }
    if (cat.contains('kesehatan') ||
        cat.contains('health') ||
        cat.contains('obat')) {
      return Icons.favorite_rounded;
    }
    if (cat.contains('pendidikan') || cat.contains('edu')) {
      return Icons.school_rounded;
    }
    return Icons.category_rounded;
  }

  static Color _getCategoryColor(int index, bool isIncome) {
    if (isIncome) {
      const incomeColors = [
        AppColors.income,
        Color(0xFF0D9488),
        Color(0xFF2563EB),
        Color(0xFF7C3AED),
        Color(0xFFD97706),
      ];
      return incomeColors[index % incomeColors.length];
    }
    const expenseColors = [
      AppColors.expense,
      Color(0xFFEA580C),
      Color(0xFFD97706),
      Color(0xFF2563EB),
      Color(0xFF7C3AED),
      Color(0xFF0D9488),
      Color(0xFFEC4899),
    ];
    return expenseColors[index % expenseColors.length];
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final transactions = _period.filter(state.transactions);
    final income = _period.total(transactions, TransactionType.income);
    final expense = _period.total(transactions, TransactionType.expense);
    final totals = <String, int>{};
    for (final tx in transactions) {
      final type = _selectedTab == 2
          ? TransactionType.income
          : TransactionType.expense;
      if (tx.type == type) {
        totals.update(
          tx.categoryName,
          (v) => v + tx.amount,
          ifAbsent: () => tx.amount,
        );
      }
    }
    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final breakdownTotal = sorted.fold<int>(0, (sum, e) => sum + e.value);

    String money(int amount) => state.isBalanceHidden
        ? 'Rp •••••'
        : CurrencyFormatter.formatRupiah(amount);

    final isSurplusPositive = (income - expense) >= 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Insights & Laporan'),
        actions: [
          IconButton(
            tooltip: 'Rencana Budget',
            icon: const Icon(Icons.pie_chart_outline_rounded),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const BudgetPage())),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Segmented Tab Bar
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                for (final (index, label) in [
                  'Ringkasan',
                  'Pengeluaran',
                  'Pemasukan',
                ].indexed)
                  Expanded(
                    child: TextButton(
                      key: ValueKey('reports_tab_$index'),
                      style: TextButton.styleFrom(
                        backgroundColor: _selectedTab == index
                            ? AppColors.primary
                            : Colors.transparent,
                        foregroundColor: _selectedTab == index
                            ? Colors.white
                            : AppColors.textSecondary,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => setState(() => _selectedTab = index),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: _selectedTab == index
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: _selectedTab == index
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Month Selector & Source Indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                MonthSelector(
                  period: _period,
                  onChanged: (period) => setState(() => _period = period),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      size: 13,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 5),
                    const Flexible(
                      child: Text(
                        'Berdasarkan transaksi yang tersimpan di perangkat.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Overview Cards based on Tab
          if (_selectedTab == 0) ...[
            // Surplus / Neraca Periode Hero Card
            Container(
              padding: const EdgeInsets.all(20),
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
                    blurRadius: 16,
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
                      const Expanded(
                        child: Text(
                          'Surplus / Neraca Periode',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isSurplusPositive
                              ? AppColors.accent.withValues(alpha: 0.25)
                              : AppColors.expense.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSurplusPositive
                                ? AppColors.accent.withValues(alpha: 0.5)
                                : AppColors.expense.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isSurplusPositive
                                  ? Icons.trending_up_rounded
                                  : Icons.trending_down_rounded,
                              size: 14,
                              color: isSurplusPositive
                                  ? AppColors.accent
                                  : const Color(0xFFFF8B88),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isSurplusPositive ? 'Surplus' : 'Defisit',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isSurplusPositive
                                    ? AppColors.accent
                                    : const Color(0xFFFF8B88),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    money(income - expense),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Pemasukan & Pengeluaran Grid Cards
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: AppColors.incomeLight,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.arrow_downward_rounded,
                                size: 14,
                                color: AppColors.income,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Pemasukan',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          money(income),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.income,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: AppColors.expenseLight,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.arrow_upward_rounded,
                                size: 14,
                                color: AppColors.expense,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Pengeluaran',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          money(expense),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.expense,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            // Tab 1 (Pengeluaran) or Tab 2 (Pemasukan) Single Hero Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _selectedTab == 1
                      ? AppColors.expense.withValues(alpha: 0.3)
                      : AppColors.income.withValues(alpha: 0.3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _selectedTab == 1
                              ? AppColors.expenseLight
                              : AppColors.incomeLight,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _selectedTab == 1
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded,
                          size: 16,
                          color: _selectedTab == 1
                              ? AppColors.expense
                              : AppColors.income,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _selectedTab == 1
                              ? 'Total Pengeluaran Periode'
                              : 'Total Pemasukan Periode',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    money(_selectedTab == 1 ? expense : income),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: _selectedTab == 1
                          ? AppColors.expense
                          : AppColors.income,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),

          // Breakdown Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _selectedTab == 2
                      ? 'Rincian Sumber Pemasukan'
                      : 'Rincian Kategori Pengeluaran',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (sorted.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${sorted.length} Kategori',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Empty state or Category Breakdown Cards
          if (sorted.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 40,
                    color: AppColors.textMuted.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Belum ada transaksi pada periode ini.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                itemCount: sorted.length,
                separatorBuilder: (_, _) => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Divider(color: AppColors.divider, height: 1),
                ),
                itemBuilder: (context, index) {
                  final entry = sorted[index];
                  final isIncome = _selectedTab == 2;
                  final categoryColor = _getCategoryColor(index, isIncome);
                  final pct = breakdownTotal > 0
                      ? (entry.value / breakdownTotal)
                      : 0.0;
                  final pctString = '${(pct * 100).toStringAsFixed(0)}%';

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 4,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: categoryColor.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _getCategoryIcon(entry.key, isIncome),
                                color: categoryColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.key.isEmpty
                                        ? 'Tanpa kategori'
                                        : entry.key,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    pctString,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              money(entry.value),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct,
                            backgroundColor: AppColors.surfaceVariant,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              categoryColor,
                            ),
                            minHeight: 5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

          // Error banner if any
          if (state.dataError != null)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.expenseLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.expense.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.expense,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.dataError!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.expense,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              onPressed: state.loading ? null : state.refresh,
              icon: state.loading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Muat ulang'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
