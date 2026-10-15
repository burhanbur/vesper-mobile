import '../../../core/network/api_client.dart';
import '../../sync/data/finance_repository.dart';

/// Read contracts only. Decimal text is never converted to floating point.
class PortfolioPosition {
  final String id, code, name, currency, quantity, average;
  final String? marketPrice, marketValue, unrealizedPl;
  const PortfolioPosition(
    this.id,
    this.code,
    this.name,
    this.currency,
    this.quantity,
    this.average,
    this.marketPrice,
    this.marketValue,
    this.unrealizedPl,
  );

  factory PortfolioPosition.fromJson(
    Map<String, dynamic> row, {
    String? accountId,
    String? date,
  }) {
    String text(Map<String, dynamic> map, String key) {
      final value = map[key];
      if (value is! String || value.isEmpty) throw const FormatException();
      return value;
    }

    String decimal(String key, {bool signed = false}) {
      final value = text(row, key);
      final pattern = signed ? r'^-?\d+(\.\d+)?$' : r'^\d+(\.\d+)?$';
      if (!RegExp(pattern).hasMatch(value)) throw const FormatException();
      return value;
    }

    String? nullableDecimal(String key, {bool signed = false}) {
      if (!row.containsKey(key)) throw const FormatException();
      return row[key] == null ? null : decimal(key, signed: signed);
    }

    final instrument = Map<String, dynamic>.from(row['instrument'] as Map);
    if (accountId != null &&
        (row['account_id'] != accountId || row['snapshot_date'] != date)) {
      throw const FormatException();
    }
    if (instrument['currency'] != 'IDR') throw const FormatException();
    return PortfolioPosition(
      text(instrument, 'id'),
      text(instrument, 'code'),
      text(instrument, 'name'),
      text(instrument, 'currency'),
      decimal('quantity_held'),
      decimal('avg_cost_price'),
      accountId == null ? null : nullableDecimal('market_price'),
      accountId == null ? null : nullableDecimal('market_value'),
      accountId == null ? null : nullableDecimal('unrealized_pl', signed: true),
    );
  }
}

class PortfolioRead {
  final List<PortfolioPosition> positions;
  final DateTime fetchedAt;
  const PortfolioRead(this.positions, this.fetchedAt);
}

class PortfolioAccount {
  final String id, name;
  const PortfolioAccount(this.id, this.name);
}

class PortfolioRepository {
  final FinanceRepository source;
  PortfolioRepository(this.source);

  List<PortfolioAccount> get accounts {
    final types = source
        .rows('account_types')
        .where((r) => r['category'] == 'INVESTMENT' && r['deleted_at'] == null)
        .map((r) => r['id'])
        .toSet();
    return source
        .rows('accounts')
        .where(
          (r) =>
              r['user_id'] == source.userId &&
              r['deleted_at'] == null &&
              r['is_visible'] != false &&
              types.contains(r['account_type_id']),
        )
        .map((r) => PortfolioAccount(r['id'] as String, r['name'] as String))
        .toList();
  }

  bool owns(String accountId) => accounts.any((a) => a.id == accountId);
  String _key(String accountId, String? date) =>
      '$accountId:${date ?? 'holdings'}';
  static const _table = 'investment_read_cache';

  PortfolioRead _decode(dynamic data, DateTime at, String id, String? date) {
    if (data is! List) throw const FormatException();
    final positions = data
        .map(
          (r) => PortfolioPosition.fromJson(
            Map<String, dynamic>.from(r as Map),
            accountId: date == null ? null : id,
            date: date,
          ),
        )
        .toList();
    if (positions.map((p) => p.id).toSet().length != positions.length) {
      throw const FormatException();
    }
    return PortfolioRead(List.unmodifiable(positions), at);
  }

  PortfolioRead? cached(String id, String? date) {
    if (!owns(id)) return null;
    try {
      final row = source.row(_table, _key(id, date));
      if (row == null) return null;
      return _decode(
        row['data'],
        DateTime.parse(row['fetched_at'] as String),
        id,
        date,
      );
    } catch (_) {
      return null; // A damaged cache is not a valid empty portfolio.
    }
  }

  Future<PortfolioRead> fetch(
    String id,
    String? date, {
    required bool Function() isCurrent,
  }) async {
    if (!owns(id) || !isCurrent()) {
      throw const ApiFailure('Akun tidak tersedia.');
    }
    if (date != null) {
      final parsed = DateTime.tryParse(date);
      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ||
          parsed == null ||
          parsed.toIso8601String().substring(0, 10) != date) {
        throw const ApiFailure('Tanggal snapshot tidak valid.');
      }
    }
    await source.requireOnline();
    final dynamic data;
    try {
      data = await source.client.request(
        'GET',
        '/accounts/${Uri.encodeComponent(id)}/${date == null ? 'holdings' : 'portfolio-snapshot'}',
        query: date == null ? null : {'date': date},
      );
    } on ApiFailure catch (failure) {
      if (isCurrent() && {401, 403, 404}.contains(failure.statusCode)) {
        source.atomic(() {
          final table = Map<String, dynamic>.from(
            source.entities[_table] as Map? ?? {},
          );
          table.removeWhere((key, _) => key.startsWith('$id:'));
          source.entities[_table] = table;
        });
      }
      rethrow;
    }
    final at = DateTime.now().toUtc();
    final PortfolioRead result;
    try {
      result = _decode(data, at, id, date);
    } catch (_) {
      throw const ApiFailure('Respons portofolio tidak valid.');
    }
    if (isCurrent() && owns(id) && !source.offline) {
      source.atomic(() {
        source.entities[_table] = {
          ...?source.entities[_table] as Map?,
          _key(id, date): {'data': data, 'fetched_at': at.toIso8601String()},
        };
      });
    }
    return result;
  }
}
