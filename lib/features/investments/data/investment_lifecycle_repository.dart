import '../../../core/network/api_client.dart';
import '../../sync/data/finance_repository.dart';
import '../models/investment_position.dart';
import '../models/investment_settlement.dart';

BigInt investmentMinor(String value) {
  if (!RegExp(r'^-?\d+\.\d{2}$').hasMatch(value)) {
    throw const FormatException('Nominal tidak valid.');
  }
  final magnitude = BigInt.parse(value.replaceAll(RegExp(r'[-.]'), ''));
  return value.startsWith('-') ? -magnitude : magnitude;
}

String investmentMoney(BigInt minor) =>
    '${minor.isNegative ? '-' : ''}${minor.abs() ~/ BigInt.from(100)}.'
    '${(minor.abs() % BigInt.from(100)).toString().padLeft(2, '0')}';

class InvestmentOverview {
  final String contributed, proceeds, realized, dividends, buyFees;
  final String? marketValue, unrealized;
  final int missingPrices;
  const InvestmentOverview(
    this.contributed,
    this.proceeds,
    this.realized,
    this.dividends,
    this.buyFees,
    this.marketValue,
    this.unrealized,
    this.missingPrices,
  );
}

/// All lifecycle reads use the durable owner cache. No settlement cash is added
/// to holding valuations. An incomplete feed cannot produce financial totals.
class InvestmentLifecycleRepository {
  final FinanceRepository source;
  InvestmentLifecycleRepository(this.source);

  List<Map<String, dynamic>> get instruments =>
      source
          .rows('instruments')
          .where((r) => r['deleted_at'] == null && r['currency'] == 'IDR')
          .toList()
        ..sort((a, b) => '${a['code']}'.compareTo('${b['code']}'));

  List<Map<String, dynamic>> history([String? accountId]) {
    if (!source.hasCompleteInvestmentHistory) {
      throw const ApiFailure(
        'Selesaikan sinkronisasi awal untuk memverifikasi riwayat.',
      );
    }
    final rows = source
        .rows('investment_transactions')
        .where(
          (r) =>
              r['deleted_at'] == null &&
              source.canTradeAccount('${r['account_id']}', 'INVESTMENT') &&
              (accountId == null || r['account_id'] == accountId),
        )
        .toList();
    rows.sort((a, b) {
      final c = '${a['transacted_at']}'.compareTo('${b['transacted_at']}');
      return c == 0 ? '${a['id']}'.compareTo('${b['id']}') : c;
    });
    return rows;
  }

  InvestmentOverview overview() {
    final positions = <String, InvestmentPosition>{};
    final instrumentIds = <String, String>{};
    var buys = BigInt.zero, sales = BigInt.zero, realized = BigInt.zero;
    var dividends = BigInt.zero, fees = BigInt.zero;
    for (final row in history()) {
      final key = '${row['account_id']}:${row['instrument_id']}';
      final position = positions[key] ?? InvestmentPosition.empty();
      final type = row['type'] as String;
      final quantity = row['quantity'] as String;
      final price = row['price_per_unit'] as String;
      final fee = row['fee'] as String;
      final cash = investmentMinor(
        InvestmentSettlement.calculate(
          type: type,
          quantity: quantity,
          pricePerUnit: price,
          fee: fee,
        ).amount,
      );
      if (type == 'BUY') {
        buys += cash;
        final parts = fee.split('.');
        fees +=
            BigInt.parse(parts.first) * BigInt.from(100) +
            BigInt.parse(parts.length == 1 ? '0' : parts[1].padRight(2, '0'));
      } else if (type == 'SELL') {
        sales += cash;
        realized += investmentMinor(
          position.realizedSale(quantity, price, fee),
        );
      } else {
        dividends += cash;
      }
      positions[key] = type == 'DIVIDEND'
          ? position
          : position.advance(
              InvestmentPositionTrade(
                type: type,
                quantity: quantity,
                pricePerUnit: price,
              ),
            );
      instrumentIds[key] = row['instrument_id'] as String;
    }
    var market = BigInt.zero, unrealized = BigInt.zero, missing = 0;
    final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    for (final entry in positions.entries) {
      if (entry.value.quantity == '0.00000000') continue;
      final quotes =
          source
              .rows('instrument_prices')
              .where(
                (r) =>
                    r['instrument_id'] == instrumentIds[entry.key] &&
                    r['price_date'] is String &&
                    '${r['price_date']}'.compareTo(today) <= 0,
              )
              .toList()
            ..sort(
              (a, b) => '${b['price_date']}'.compareTo('${a['price_date']}'),
            );
      if (quotes.isEmpty) {
        missing++;
        continue;
      }
      final value = entry.value.valueAt(quotes.first['close_price'] as String);
      market += investmentMinor(value.marketValue);
      unrealized += investmentMinor(value.unrealizedPl);
    }
    return InvestmentOverview(
      investmentMoney(buys),
      investmentMoney(sales),
      investmentMoney(realized),
      investmentMoney(dividends),
      investmentMoney(fees),
      missing == 0 ? investmentMoney(market) : null,
      missing == 0 ? investmentMoney(unrealized) : null,
      missing,
    );
  }

  Future<void> discover({required bool Function() isCurrent}) async {
    await source.requireOnline();
    // Fetch both complete lists before replacing either durable read model.
    final instruments = await source.client.list('/instruments');
    final prices = await source.client.list('/instrument-prices');
    if (!isCurrent() || source.offline) return;
    source.atomic(() {
      source.entities['instruments'] = {
        for (final r in instruments) r['id'] as String: r,
        for (final r in this.instruments.where(
          (r) => r['pending_catalog'] == true,
        ))
          r['id'] as String: r,
      };
      source.entities['instrument_prices'] = {
        for (final r in prices) '${r['instrument_id']}:${r['price_date']}': r,
        for (final r
            in source
                .rows('instrument_prices')
                .where((r) => r['pending_catalog'] == true))
          '${r['instrument_id']}:${r['price_date']}': r,
      };
      source.state['investment_catalog_fetched_at'] = DateTime.now()
          .toUtc()
          .toIso8601String();
    });
  }
}
