import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/budget_period.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../transactions/models/transaction.dart';
import '../models/budget.dart';

class BudgetPage extends StatefulWidget {
  const BudgetPage({super.key});

  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  int _selectedPeriodTab = 0; // 0: Bulanan, 1: Tahunan

  late DateTime _selectedMonth;
  late int _currentYear;
  bool _didFetchInitial = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
    _currentYear = now.year;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didFetchInitial) {
      _didFetchInitial = true;
      _fetchProgress();
    }
  }

  void _fetchProgress() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = AppStateScope.of(context);
      if (_selectedPeriodTab == 0) {
        final periodKey = formatPeriodKey(_selectedMonth, 'MONTHLY');
        state.loadBudgetProgressForPeriod(periodKey, periodType: 'MONTHLY');
      } else {
        final periodKey = '$_currentYear';
        state.loadBudgetProgressForPeriod(periodKey, periodType: 'ANNUAL');
      }
    });
  }

  IconData _getCategoryIcon(String iconName) {
    switch (iconName) {
      case 'restaurant':
        return Icons.restaurant_rounded;
      case 'shopping_cart':
        return Icons.shopping_bag_outlined;
      case 'favorite':
        return Icons.favorite_outline_rounded;
      case 'directions_car':
        return Icons.directions_car_outlined;
      case 'receipt':
        return Icons.receipt_long_outlined;
      case 'movie':
        return Icons.movie_outlined;
      default:
        return Icons.category_outlined;
    }
  }

  void _showAddBudgetModal(BuildContext context) {
    final amountController = TextEditingController();
    final state = AppStateScope.of(context);
    final availableCategories = state.expenseCategories
        .map((c) => c.name)
        .toList();
    String? selectedCategory = availableCategories.isNotEmpty
        ? availableCategories.first
        : null;

    final isYearly = _selectedPeriodTab == 1;
    final targetPeriodLabel = isYearly
        ? 'Tahun $_currentYear'
        : DateFormatter.formatMonthYear(_selectedMonth);

    bool isSaving = false;
    String? errorMessage;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
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
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tetapkan Budget Kategori',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Periode: $targetPeriodLabel',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: isSaving ? null : () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.expenseLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.expense),
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
                          errorMessage!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.expense,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              const Text(
                'Pilih Kategori',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedCategory,
                    isExpanded: true,
                    items: availableCategories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: isSaving
                        ? null
                        : (val) {
                            if (val != null) {
                              setModalState(() {
                                selectedCategory = val;
                                errorMessage = null;
                              });
                            }
                          },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isYearly
                    ? 'Jumlah Alokasi Budget (Rp / Tahun)'
                    : 'Jumlah Alokasi Budget (Rp / Bulan)',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                autofocus: true,
                enabled: !isSaving,
                onChanged: (_) {
                  if (errorMessage != null) {
                    setModalState(() => errorMessage = null);
                  }
                },
                decoration: InputDecoration(
                  hintText: 'Contoh: 1500000',
                  prefixText: 'Rp ',
                  prefixStyle: const TextStyle(fontWeight: FontWeight.w700),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: isSaving
                    ? null
                    : () async {
                        final text = amountController.text.trim();
                        final amount = int.tryParse(text) ?? 0;
                        if (selectedCategory == null) {
                          setModalState(() {
                            errorMessage = 'Pilih kategori terlebih dahulu.';
                          });
                          return;
                        }
                        if (amount <= 0) {
                          setModalState(() {
                            errorMessage =
                                'Jumlah alokasi budget harus lebih dari Rp 0.';
                          });
                          return;
                        }

                        setModalState(() {
                          isSaving = true;
                          errorMessage = null;
                        });

                        final targetPeriodType = isYearly
                            ? 'ANNUAL'
                            : 'MONTHLY';
                        final targetAnchor = isYearly
                            ? '$_currentYear-01-01'
                            : '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}-01';

                        try {
                          final result = await state.setCategoryBudget(
                            categoryName: selectedCategory!,
                            allocatedAmount: amount,
                            periodType: targetPeriodType,
                            anchorDate: targetAnchor,
                          );

                          if (!modalCtx.mounted) return;
                          Navigator.of(ctx).pop();

                          _fetchProgress();

                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: result.isSyncedOnline
                                  ? AppColors.income
                                  : AppColors.primary,
                              content: Row(
                                children: [
                                  Icon(
                                    result.isSyncedOnline
                                        ? Icons.check_circle_rounded
                                        : Icons.cloud_queue_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(result.feedbackMessage)),
                                ],
                              ),
                            ),
                          );
                        } catch (e) {
                          if (!modalCtx.mounted) return;
                          setModalState(() {
                            isSaving = false;
                            errorMessage = e.toString().replaceFirst(
                              'ApiFailure: ',
                              '',
                            );
                          });
                        }
                      },
                child: isSaving
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text('Menyimpan...'),
                        ],
                      )
                    : const Text('Simpan Budget'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final isYearly = _selectedPeriodTab == 1;

    final List<BudgetItem> displayedBudgets;
    final int totalAllocated;
    final int totalSpent;

    if (isYearly) {
      final annualPeriodKey = '$_currentYear';
      final annualBudgets = state.budgetsForPeriod(
        period: annualPeriodKey,
        periodType: 'ANNUAL',
      );
      if (annualBudgets.isNotEmpty) {
        displayedBudgets = annualBudgets;
      } else {
        displayedBudgets = state.budgets.map((b) {
          final yearTransactions = state.transactions.where(
            (tx) =>
                tx.type == TransactionType.expense &&
                tx.categoryId == b.categoryId &&
                tx.date.year == _currentYear,
          );
          final actualYearSpent = yearTransactions.fold(
            0,
            (sum, tx) => sum + tx.amount,
          );
          final annualAllocated = b.allocatedAmount * 12;
          return b.copyWith(
            period: annualPeriodKey,
            allocatedAmount: annualAllocated,
            spentAmount: actualYearSpent,
            periodType: 'ANNUAL',
            rawAllowance: '$annualAllocated.00',
            rawSpent: '$actualYearSpent.00',
            periodDays: 365,
          );
        }).toList();
      }
      totalAllocated = displayedBudgets.fold(
        0,
        (sum, b) => sum + b.allocatedAmount,
      );
      totalSpent = displayedBudgets.fold(0, (sum, b) => sum + b.spentAmount);
    } else {
      final monthlyPeriodKey = formatPeriodKey(_selectedMonth, 'MONTHLY');
      displayedBudgets = state.budgetsForPeriod(
        period: monthlyPeriodKey,
        periodType: 'MONTHLY',
      );
      totalAllocated = displayedBudgets.fold(
        0,
        (sum, b) => sum + b.allocatedAmount,
      );
      totalSpent = displayedBudgets.fold(0, (sum, b) => sum + b.spentAmount);
    }

    final totalRemaining = totalAllocated - totalSpent;
    final isOverBudget = totalSpent > totalAllocated;
    final totalProgressPct = totalAllocated > 0
        ? (totalSpent / totalAllocated).clamp(0.0, 1.0)
        : (totalSpent > 0 ? 1.0 : 0.0);
    final remainingPct = totalAllocated > 0
        ? (isOverBudget
              ? 0.0
              : ((totalAllocated - totalSpent) / totalAllocated) * 100)
        : 0.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Budget & Perencanaan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppColors.primary),
            onPressed: () => _showAddBudgetModal(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Segmented Toggle: Bulanan vs Tahunan (contoh-2.png)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _selectedPeriodTab = 0);
                          _fetchProgress();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !isYearly
                                ? AppColors.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              'Bulanan',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: !isYearly
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _selectedPeriodTab = 1);
                          _fetchProgress();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isYearly
                                ? AppColors.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              'Tahunan',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isYearly
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Period Navigator: < Bulan Tahun > or < Tahun >
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, size: 22),
                    color: AppColors.textSecondary,
                    onPressed: () {
                      setState(() {
                        if (isYearly) {
                          _currentYear--;
                        } else {
                          _selectedMonth = DateTime(
                            _selectedMonth.year,
                            _selectedMonth.month - 1,
                          );
                        }
                      });
                      _fetchProgress();
                    },
                  ),
                  Text(
                    isYearly
                        ? 'Tahun $_currentYear'
                        : DateFormatter.formatMonthYear(_selectedMonth),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, size: 22),
                    color: AppColors.textSecondary,
                    onPressed: () {
                      setState(() {
                        if (isYearly) {
                          _currentYear++;
                        } else {
                          _selectedMonth = DateTime(
                            _selectedMonth.year,
                            _selectedMonth.month + 1,
                          );
                        }
                      });
                      _fetchProgress();
                    },
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Hero Total Budget Card (contoh-2.png)
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
                        Expanded(
                          child: Text(
                            isYearly
                                ? 'Total Budget Tahunan (12 Bulan)'
                                : 'Total Budget Bulanan',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        if (totalAllocated > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: !isOverBudget
                                  ? AppColors.incomeLight
                                  : AppColors.expenseLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              !isOverBudget ? '✅ On Track' : '⚠️ Over Budget',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: !isOverBudget
                                    ? AppColors.income
                                    : AppColors.expense,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      CurrencyFormatter.formatRupiah(totalAllocated),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: totalProgressPct,
                        minHeight: 10,
                        backgroundColor: AppColors.surfaceVariant,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isOverBudget || totalProgressPct > 0.85
                              ? AppColors.expense
                              : AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            isOverBudget
                                ? 'Terlampaui: ${CurrencyFormatter.formatRupiah(totalSpent - totalAllocated)}'
                                : (isYearly
                                      ? 'Sisa Tahun Ini: ${CurrencyFormatter.formatCompact(totalRemaining)} (${remainingPct.toStringAsFixed(0)}%)'
                                      : 'Tersisa: ${CurrencyFormatter.formatRupiah(totalRemaining)} (${remainingPct.toStringAsFixed(0)}%)'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isOverBudget
                                  ? AppColors.expense
                                  : (totalAllocated == 0
                                        ? AppColors.textMuted
                                        : AppColors.accentDark),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isYearly
                              ? 'YTD: ${CurrencyFormatter.formatCompact(totalSpent)}'
                              : 'Terpakai: ${CurrencyFormatter.formatCompact(totalSpent)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Category Budget List Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      isYearly
                          ? 'Budget Tahunan per Kategori'
                          : 'Budget per Kategori',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${displayedBudgets.length} Kategori',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Category Budget Items (contoh-2.png)
              if (displayedBudgets.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 36,
                    horizontal: 20,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 44,
                        color: AppColors.textMuted.withValues(alpha: 0.6),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isYearly
                            ? 'Belum ada budget untuk tahun $_currentYear'
                            : 'Belum ada budget untuk ${DateFormatter.formatMonthYear(_selectedMonth)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Tetapkan batasan pengeluaran kategori agar keuanganmu tetap terkontrol.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _showAddBudgetModal(context),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Tetapkan Budget'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: displayedBudgets.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = displayedBudgets[index];

                    final allocated = item.allocatedAmount;
                    final spent = item.spentAmount;
                    final progress = allocated > 0
                        ? (spent / allocated).clamp(0.0, 1.0)
                        : (spent > 0 ? 1.0 : 0.0);
                    final pct = allocated > 0
                        ? ((spent / allocated) * 100).toInt()
                        : (spent > 0 ? 100 : 0);

                    // Warning logic
                    final isExceeded = spent > allocated;
                    final isWarning =
                        allocated > 0 && (spent / allocated) >= 0.75;

                    Color statusColor = AppColors.primary;
                    if (isExceeded) {
                      statusColor = AppColors.expense;
                    } else if (isWarning) {
                      statusColor = AppColors.warning;
                    }

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  _getCategoryIcon(item.icon),
                                  color: statusColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.categoryName,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isYearly
                                          ? 'YTD: ${CurrencyFormatter.formatCompact(spent)} / Thn: ${CurrencyFormatter.formatCompact(allocated)}'
                                          : '${CurrencyFormatter.formatRupiah(spent)} / ${CurrencyFormatter.formatRupiah(allocated)}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isExceeded && allocated > 0
                                      ? '$pct%'
                                      : (allocated == 0 && spent > 0
                                            ? '>100%'
                                            : '$pct%'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 8,
                              backgroundColor: AppColors.surfaceVariant,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

              const SizedBox(height: 20),

              // Annual Goal Card when Yearly tab is active
              if (isYearly) ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.accentLight.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.flag_rounded,
                            color: AppColors.accentDark,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Target Tabungan Tahunan $_currentYear',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Total alokasi budget tahunan yang direncanakan: ${CurrencyFormatter.formatRupiah(totalAllocated)}. Terpakai aktual: ${CurrencyFormatter.formatRupiah(totalSpent)}.',
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Button "+ Tambah Budget"
              OutlinedButton.icon(
                onPressed: () => _showAddBudgetModal(context),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('Tetapkan Budget Baru'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
