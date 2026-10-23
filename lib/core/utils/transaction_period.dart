import '../../features/transactions/models/transaction.dart';
import 'app_time_zone.dart';

/// Selected calendar month with exclusive UTC query boundaries.
class TransactionPeriod {
  TransactionPeriod(DateTime month, {this.timeZone = AppTimeZone.device})
    : month = DateTime.utc(month.year, month.month);

  final DateTime month;
  final AppTimeZone timeZone;
  DateTime get start => timeZone.fromCalendar(month);
  DateTime get end =>
      timeZone.fromCalendar(DateTime.utc(month.year, month.month + 1));
  TransactionPeriod withTimeZone(AppTimeZone zone) =>
      TransactionPeriod(month, timeZone: zone);
  TransactionPeriod shift(int months) => TransactionPeriod(
    DateTime.utc(month.year, month.month + months),
    timeZone: timeZone,
  );

  bool contains(DateTime date) {
    return !date.isBefore(start) && date.isBefore(end);
  }

  List<TransactionItem> filter(Iterable<TransactionItem> transactions) =>
      transactions.where((tx) => contains(tx.date)).toList();

  int total(Iterable<TransactionItem> transactions, TransactionType type) =>
      transactions
          .where((tx) => contains(tx.date) && tx.type == type)
          .fold(0, (sum, tx) => sum + tx.amount);
}
