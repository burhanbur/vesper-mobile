import '../../features/transactions/models/transaction.dart';

/// Calendar periods use local presentation time, with an exclusive end boundary.
class TransactionPeriod {
  TransactionPeriod(DateTime month) : start = DateTime(month.year, month.month);

  final DateTime start;
  DateTime get end => DateTime(start.year, start.month + 1);
  TransactionPeriod shift(int months) =>
      TransactionPeriod(DateTime(start.year, start.month + months));

  bool contains(DateTime date) {
    final local = date.toLocal();
    return !local.isBefore(start) && local.isBefore(end);
  }

  List<TransactionItem> filter(Iterable<TransactionItem> transactions) =>
      transactions.where((tx) => contains(tx.date)).toList();

  int total(Iterable<TransactionItem> transactions, TransactionType type) =>
      transactions
          .where((tx) => contains(tx.date) && tx.type == type)
          .fold(0, (sum, tx) => sum + tx.amount);
}
