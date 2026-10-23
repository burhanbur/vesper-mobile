class SpendingInsight {
  final BigInt current, previous;
  final DateTime currentStart, previousStart;
  final int comparedDays;
  final bool hasPreviousEntries;
  const SpendingInsight({
    required this.current,
    required this.previous,
    required this.currentStart,
    required this.previousStart,
    required this.comparedDays,
    required this.hasPreviousEntries,
  });

  // Hundredths of a percent; never divide monetary values as doubles.
  BigInt? get changePercent => previous == BigInt.zero
      ? null
      : (current - previous) * BigInt.from(10000) ~/ previous;
}

class UpcomingBillsInsight {
  final int count, estimatedCount;
  final BigInt total;
  final String? nextTitle;
  final bool needsReview;
  const UpcomingBillsInsight({
    required this.count,
    required this.estimatedCount,
    required this.total,
    this.nextTitle,
    this.needsReview = false,
  });
}

class BudgetAttentionInsight {
  final String name;
  final BigInt allowance, spent;
  final bool isEstimated;
  const BudgetAttentionInsight(
    this.name,
    this.allowance,
    this.spent, {
    this.isEstimated = false,
  });
  BigInt get remaining => allowance - spent;
  BigInt get percent => spent * BigInt.from(100) ~/ allowance;
}

class DashboardInsights {
  final SpendingInsight? spending;
  final UpcomingBillsInsight? bills;
  final List<BudgetAttentionInsight>? budgets;
  final bool provisional;
  const DashboardInsights({
    this.spending,
    this.bills,
    this.budgets,
    this.provisional = false,
  });
}
