class BudgetItem {
  final String id;
  final String categoryId;
  final String categoryName;
  final String icon;
  final int allocatedAmount; // in Rupiah
  final int spentAmount; // in Rupiah
  final String periodType; // 'MONTHLY', 'WEEKLY', 'ANNUAL'
  final DateTime anchorDate;

  const BudgetItem({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.icon,
    required this.allocatedAmount,
    required this.spentAmount,
    this.periodType = 'MONTHLY',
    required this.anchorDate,
  });

  int get remainingAmount => allocatedAmount - spentAmount;

  double get progressPercentage {
    if (allocatedAmount <= 0) return 0.0;
    return (spentAmount / allocatedAmount).clamp(0.0, 1.5);
  }

  bool get isOverBudget => spentAmount > allocatedAmount;

  BudgetItem copyWith({
    String? id,
    String? categoryId,
    String? categoryName,
    String? icon,
    int? allocatedAmount,
    int? spentAmount,
    String? periodType,
    DateTime? anchorDate,
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
    );
  }
}
