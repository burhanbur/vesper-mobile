import '../../../core/utils/budget_period.dart';
import '../../../core/utils/currency_formatter.dart';

class BudgetItem {
  final String id;
  final String categoryId;
  final String categoryName;
  final String icon;
  final int allocatedAmount; // in Rupiah (integer portion / rounded)
  final int spentAmount; // in Rupiah (integer portion / rounded)
  final String periodType; // 'MONTHLY', 'WEEKLY', 'ANNUAL', 'DAILY'
  final DateTime anchorDate;
  final String period;
  final BudgetPeriodRange? periodRange;
  final String? rawAllowance;
  final String? rawSpent;
  final int periodDays;
  final bool isLocalEstimate;

  const BudgetItem({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.icon,
    required this.allocatedAmount,
    required this.spentAmount,
    this.periodType = 'MONTHLY',
    required this.anchorDate,
    this.period = '',
    this.periodRange,
    this.rawAllowance,
    this.rawSpent,
    this.periodDays = 0,
    this.isLocalEstimate = false,
  });

  int get remainingAmount => allocatedAmount - spentAmount;

  double get progressPercentage {
    if (allocatedAmount <= 0) return spentAmount > 0 ? 1.0 : 0.0;
    return (spentAmount / allocatedAmount).clamp(0.0, 1.5);
  }

  bool get isOverBudget => spentAmount > allocatedAmount;

  String get allocatedDisplay => _formatAmount(rawAllowance, allocatedAmount);
  String get spentDisplay => _formatAmount(rawSpent, spentAmount);
  String get remainingDisplay {
    if (remainingAmount < 0) {
      return '-${CurrencyFormatter.formatRupiah(remainingAmount.abs())}';
    }
    return CurrencyFormatter.formatRupiah(remainingAmount);
  }

  static String _formatAmount(String? raw, int fallback) {
    if (raw == null || raw.isEmpty) {
      return fallback < 0
          ? '-${CurrencyFormatter.formatRupiah(fallback.abs())}'
          : CurrencyFormatter.formatRupiah(fallback);
    }
    final match = RegExp(r'^(-)?(\d+)(?:\.(\d+))?$').firstMatch(raw.trim());
    if (match == null) {
      return fallback < 0
          ? '-${CurrencyFormatter.formatRupiah(fallback.abs())}'
          : CurrencyFormatter.formatRupiah(fallback);
    }
    final isNegative = match.group(1) != null;
    final integerPart = int.tryParse(match.group(2)!) ?? fallback.abs();
    final formattedInt = CurrencyFormatter.formatRupiah(integerPart);
    final fraction = match.group(3) ?? '';
    final sign = isNegative ? '-' : '';
    if (fraction.isNotEmpty && fraction != '00' && fraction != '0') {
      return '$sign$formattedInt,${fraction.length > 2 ? fraction.substring(0, 2) : fraction}';
    }
    return '$sign$formattedInt';
  }

  BudgetItem copyWith({
    String? id,
    String? categoryId,
    String? categoryName,
    String? icon,
    int? allocatedAmount,
    int? spentAmount,
    String? periodType,
    DateTime? anchorDate,
    String? period,
    BudgetPeriodRange? periodRange,
    String? rawAllowance,
    String? rawSpent,
    int? periodDays,
    bool? isLocalEstimate,
  }) {
    return BudgetItem(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      icon: icon ?? this.icon,
      allocatedAmount: allocatedAmount ?? this.allocatedAmount,
      spentAmount: spentAmount ?? this.spentAmount,
      periodType: periodType ?? this.periodType,
      anchorDate: anchorDate ?? this.anchorDate,
      period: period ?? this.period,
      periodRange: periodRange ?? this.periodRange,
      rawAllowance: rawAllowance ?? this.rawAllowance,
      rawSpent: rawSpent ?? this.rawSpent,
      periodDays: periodDays ?? this.periodDays,
      isLocalEstimate: isLocalEstimate ?? this.isLocalEstimate,
    );
  }
}
