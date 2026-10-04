enum InvestmentAssetType {
  crypto,
  mutualFund,
  gold,
  stock,
  bond,
}

enum InvestmentTradeType {
  buy,
  sell,
  dividend,
}

class InvestmentTransactionRecord {
  final String id;
  final InvestmentTradeType type;
  final double quantity;
  final double pricePerUnit;
  final int fee;
  final int totalAmount; // in Rupiah
  final String? cashAccountId;
  final int? realizedPl;
  final DateTime transactedAt;
  final String? note;

  const InvestmentTransactionRecord({
    required this.id,
    required this.type,
    required this.quantity,
    required this.pricePerUnit,
    required this.fee,
    required this.totalAmount,
    this.cashAccountId,
    this.realizedPl,
    required this.transactedAt,
    this.note,
  });
}

class InvestmentAsset {
  final String id;
  final String name;
  final String symbol;
  final InvestmentAssetType type;
  final int totalCurrentValue; // in Rupiah (integer)
  final int totalInvestedValue; // in Rupiah (integer)
  final String quantityDisplay;
  final double quantity;
  final double avgCostPrice;
  final double currentPrice;
  final bool isPriceUpdatedToday;
  final DateTime lastUpdated;
  final List<InvestmentTransactionRecord> transactions;

  const InvestmentAsset({
    required this.id,
    required this.name,
    required this.symbol,
    required this.type,
    required this.totalCurrentValue,
    required this.totalInvestedValue,
    required this.quantityDisplay,
    this.quantity = 1.0,
    this.avgCostPrice = 0.0,
    this.currentPrice = 0.0,
    this.isPriceUpdatedToday = true,
    required this.lastUpdated,
    this.transactions = const [],
  });

  int get unrealizedGainLoss => totalCurrentValue - totalInvestedValue;

  double get returnPercentage {
    if (totalInvestedValue == 0) return 0.0;
    return ((totalCurrentValue - totalInvestedValue) / totalInvestedValue) * 100.0;
  }

  bool get isProfitable => unrealizedGainLoss >= 0;

  InvestmentAsset copyWith({
    String? id,
    String? name,
    String? symbol,
    InvestmentAssetType? type,
    int? totalCurrentValue,
    int? totalInvestedValue,
    String? quantityDisplay,
    double? quantity,
    double? avgCostPrice,
    double? currentPrice,
    bool? isPriceUpdatedToday,
    DateTime? lastUpdated,
    List<InvestmentTransactionRecord>? transactions,
  }) {
    return InvestmentAsset(
      id: id ?? this.id,
      name: name ?? this.name,
      symbol: symbol ?? this.symbol,
      type: type ?? this.type,
      totalCurrentValue: totalCurrentValue ?? this.totalCurrentValue,
      totalInvestedValue: totalInvestedValue ?? this.totalInvestedValue,
      quantityDisplay: quantityDisplay ?? this.quantityDisplay,
      quantity: quantity ?? this.quantity,
      avgCostPrice: avgCostPrice ?? this.avgCostPrice,
      currentPrice: currentPrice ?? this.currentPrice,
      isPriceUpdatedToday: isPriceUpdatedToday ?? this.isPriceUpdatedToday,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      transactions: transactions ?? this.transactions,
    );
  }
}
