import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/transaction_period.dart';
import '../../../core/utils/app_time_zone.dart';
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
  AppTimeZone? _timeZone;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final zone = AppStateScope.of(context).timeZone;
    _period = _timeZone == null
        ? TransactionPeriod(zone.at(DateTime.now()), timeZone: zone)
        : _period.withTimeZone(zone);
    _timeZone = zone;
  }

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
    final transactions = state.transactionsInPeriod(_period.start, _period.end);
    final income = _period.total(transactions, TransactionType.income);
    final expense = _period.total(transactions, TransactionType.expense);

    // Previous month for delta comparison
    final prevPeriod = _period.shift(-1);
    final prevTx = state.transactionsInPeriod(prevPeriod.start, prevPeriod.end);
    final prevIncome = prevPeriod.total(prevTx, TransactionType.income);
    final prevExpense = prevPeriod.total(prevTx, TransactionType.expense);
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

            // Pemasukan & Pengeluaran Grid Cards with prev-month delta
            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    label: 'Pemasukan',
                    amount: income,
                    prevAmount: prevIncome,
                    icon: Icons.arrow_downward_rounded,
                    iconBg: AppColors.incomeLight,
                    iconColor: AppColors.income,
                    amountColor: AppColors.income,
                    money: money,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    label: 'Pengeluaran',
                    amount: expense,
                    prevAmount: prevExpense,
                    icon: Icons.arrow_upward_rounded,
                    iconBg: AppColors.expenseLight,
                    iconColor: AppColors.expense,
                    amountColor: AppColors.expense,
                    money: money,
                    // Higher expense is worse, so invert the delta sentiment
                    invertDelta: true,
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

          // Donut chart — only shown on Pengeluaran / Pemasukan tabs
          if (_selectedTab != 0 && sorted.isNotEmpty)
            _DonutChart(
              sorted: sorted,
              breakdownTotal: breakdownTotal,
              isIncome: _selectedTab == 2,
              getCategoryColor: _getCategoryColor,
              isHidden: state.isBalanceHidden,
            ),

          if (_selectedTab != 0 && sorted.isNotEmpty)
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

class _SummaryCard extends StatelessWidget {
  final String label;
  final int amount;
  final int prevAmount;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final Color amountColor;
  final String Function(int) money;
  final bool invertDelta;

  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.prevAmount,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.amountColor,
    required this.money,
    this.invertDelta = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasPrev = prevAmount > 0;
    final delta = hasPrev ? (amount - prevAmount) / prevAmount : 0.0;
    final isPositiveSentiment = invertDelta ? delta <= 0 : delta >= 0;
    final deltaLabel = hasPrev
        ? '${delta >= 0 ? '+' : ''}${(delta * 100).toStringAsFixed(0)}% vs bln lalu'
        : 'Bln lalu: -';

    return Container(
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
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 14, color: iconColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            money(amount),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: amountColor,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            deltaLabel,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: hasPrev
                  ? (isPositiveSentiment ? AppColors.income : AppColors.expense)
                  : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutChart extends StatefulWidget {
  final List<MapEntry<String, int>> sorted;
  final int breakdownTotal;
  final bool isIncome;
  final Color Function(int index, bool isIncome) getCategoryColor;
  final bool isHidden;

  const _DonutChart({
    required this.sorted,
    required this.breakdownTotal,
    required this.isIncome,
    required this.getCategoryColor,
    required this.isHidden,
  });

  @override
  State<_DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<_DonutChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final sections = <PieChartSectionData>[];
    final maxSlices = widget.sorted.length > 6 ? 6 : widget.sorted.length;
    int otherTotal = 0;
    for (var i = 0; i < widget.sorted.length; i++) {
      if (i < maxSlices) {
        final entry = widget.sorted[i];
        final pct = widget.breakdownTotal > 0
            ? entry.value / widget.breakdownTotal
            : 0.0;
        final isTouched = i == _touchedIndex;
        sections.add(
          PieChartSectionData(
            value: entry.value.toDouble(),
            color: widget.getCategoryColor(i, widget.isIncome),
            radius: isTouched ? 56 : 48,
            title: '${(pct * 100).toStringAsFixed(0)}%',
            titleStyle: TextStyle(
              fontSize: isTouched ? 13 : 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              shadows: const [Shadow(color: Colors.black26, blurRadius: 4)],
            ),
            showTitle: pct >= 0.05,
          ),
        );
      } else {
        otherTotal += widget.sorted[i].value;
      }
    }
    if (otherTotal > 0) {
      sections.add(
        PieChartSectionData(
          value: otherTotal.toDouble(),
          color: AppColors.textMuted.withValues(alpha: 0.4),
          radius: 48,
          title: 'Lainnya',
          titleStyle: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          showTitle: false,
        ),
      );
    }

    final touched = _touchedIndex >= 0 && _touchedIndex < widget.sorted.length
        ? widget.sorted[_touchedIndex]
        : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.isIncome ? 'Distribusi Pemasukan' : 'Distribusi Pengeluaran',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: Row(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sections: sections,
                      centerSpaceRadius: 52,
                      sectionsSpace: 2,
                      pieTouchData: PieTouchData(
                        touchCallback: (event, response) {
                          setState(() {
                            if (!event.isInterestedForInteractions ||
                                response == null ||
                                response.touchedSection == null) {
                              _touchedIndex = -1;
                              return;
                            }
                            _touchedIndex =
                                response.touchedSection!.touchedSectionIndex;
                          });
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Center label overlay
                SizedBox(
                  width: 130,
                  child: touched != null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              touched.key.isEmpty
                                  ? 'Tanpa kategori'
                                  : touched.key,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.isHidden
                                  ? 'Rp •••••'
                                  : CurrencyFormatter.formatRupiah(
                                      touched.value,
                                    ),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: widget.isIncome
                                    ? AppColors.income
                                    : AppColors.expense,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.breakdownTotal > 0
                                  ? '${(touched.value / widget.breakdownTotal * 100).toStringAsFixed(1)}%'
                                  : '0%',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: List.generate(
                            maxSlices > 5 ? 5 : maxSlices,
                            (i) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: widget.getCategoryColor(
                                        i,
                                        widget.isIncome,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      widget.sorted[i].key.isEmpty
                                          ? 'Tanpa kategori'
                                          : widget.sorted[i].key,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
