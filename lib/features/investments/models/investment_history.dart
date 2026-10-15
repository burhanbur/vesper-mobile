import 'investment_position.dart';

/// Validates and orders a complete, account-scoped history supplied by sync.
/// This class cannot prove completeness: callers must finish the initial pull
/// and revalidate account access before using its positions for commands.
class InvestmentHistory {
  final String accountId;
  final Map<String, InvestmentPosition> _positions;
  final Map<String, DateTime> _latest;

  InvestmentHistory._(this.accountId, this._positions, this._latest);

  InvestmentPosition position(String instrumentId) =>
      _positions[instrumentId] ?? InvestmentPosition.empty();

  /// Backend commands must be strictly newer than every trade of the pair.
  bool canAppend(String instrumentId, DateTime at) =>
      !_latest.containsKey(instrumentId) || at.isAfter(_latest[instrumentId]!);

  factory InvestmentHistory.fromCompleteRows({
    required String accountId,
    required Iterable<Map<String, dynamic>> rows,
  }) {
    if (accountId.isEmpty) throw const FormatException('Akun tidak valid.');
    final ids = <String>{};
    final ordered =
        <
          ({
            String id,
            String instrument,
            DateTime at,
            InvestmentPositionTrade? trade,
          })
        >[];
    for (final row in rows) {
      String text(String key) {
        final value = row[key];
        if (value is! String || value.isEmpty) {
          throw const FormatException('Histori investasi tidak valid.');
        }
        return value;
      }

      final id = text('id');
      final instrument = text('instrument_id');
      if (row['account_id'] != accountId || !ids.add(id)) {
        throw const FormatException('Identitas histori investasi tidak valid.');
      }
      // Tombstones must be removed by sync, not silently replayed as trades.
      if (row['deleted_at'] != null) {
        throw const FormatException('Histori mengandung transaksi terhapus.');
      }
      final timestamp = text('transacted_at');
      final at = DateTime.tryParse(timestamp);
      // Server DTO uses canonical UTC milliseconds. Reject normalization of
      // invalid calendar dates and local timestamps rather than guessing order.
      if (at == null ||
          !at.isUtc ||
          at.toIso8601String() != timestamp ||
          at.microsecond != 0) {
        throw const FormatException('Waktu histori investasi tidak valid.');
      }
      final type = text('type');
      InvestmentPositionTrade? trade;
      if (type == 'DIVIDEND') {
        // Existing server dividends do not change quantity/cost basis. They do
        // still participate in chronology; this does not enable new dividends.
        for (final field in ['quantity', 'price_per_unit']) {
          final value = text(field);
          final match = RegExp(r'^(0|[1-9]\d{0,11})\.\d{8}$').firstMatch(value);
          if (match == null || match.end != value.length) {
            throw const FormatException('Nilai dividen tidak valid.');
          }
        }
      } else {
        trade = InvestmentPositionTrade(
          type: type,
          quantity: text('quantity'),
          pricePerUnit: text('price_per_unit'),
        );
      }
      ordered.add((id: id, instrument: instrument, at: at, trade: trade));
    }
    ordered.sort((a, b) {
      final time = a.at.compareTo(b.at);
      return time == 0 ? a.id.compareTo(b.id) : time;
    });
    final positions = <String, InvestmentPosition>{};
    final latest = <String, DateTime>{};
    for (final row in ordered) {
      var position = positions[row.instrument] ?? InvestmentPosition.empty();
      if (row.trade != null) position = position.advance(row.trade!);
      positions[row.instrument] = position;
      latest[row.instrument] = row.at;
    }
    return InvestmentHistory._(
      accountId,
      Map.unmodifiable(positions),
      Map.unmodifiable(latest),
    );
  }
}
