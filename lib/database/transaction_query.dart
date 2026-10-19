class TransactionCursor {
  final String microseconds;
  final String id;
  const TransactionCursor(this.microseconds, this.id);
}

class TransactionQuery {
  final DateTime? start, end;
  final String? accountId, type, categoryId;
  final String search, actorId, actorName;
  final int limit;
  final TransactionCursor? after;
  const TransactionQuery({
    this.start,
    this.end,
    this.accountId,
    this.type,
    this.categoryId,
    this.search = '',
    this.actorId = '',
    this.actorName = '',
    this.limit = 100,
    this.after,
  });
}

class TransactionPage {
  final List<Map<String, dynamic>> rows;
  final TransactionCursor? next;
  const TransactionPage(this.rows, this.next);
}

class TransactionSummary {
  final String income, expense;
  final Map<int, String> dailyNet;
  const TransactionSummary(this.income, this.expense, this.dailyNet);
}
