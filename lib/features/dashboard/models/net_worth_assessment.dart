import '../../../core/network/api_client.dart';

/// Server valuation only. Decimal strings are never converted to floating point.
class NetWorthAssessment {
  final String snapshotDate;
  final String observedAt;
  final String balanceBasis;
  bool get isHistoricalObservation =>
      balanceBasis == 'captured_recorded_ledger';
  final bool unavailable;
  bool get complete => amounts['net_worth'] != null;
  final Map<String, String?> amounts;
  final List<String> missingComponents;
  final List<NetWorthHolding> holdings;
  final int excludedAccountCount;

  const NetWorthAssessment._(
    this.snapshotDate,
    this.observedAt,
    this.balanceBasis,
    this.unavailable,
    this.amounts,
    this.missingComponents,
    this.holdings,
    this.excludedAccountCount,
  );

  factory NetWorthAssessment.fromJson(dynamic value) {
    if (value is! Map<String, dynamic> ||
        value['scope'] != 'owner' ||
        value['currency'] != 'IDR' ||
        !['complete', 'partial', 'unavailable'].contains(value['status']) ||
        value['attribution'] != 'unavailable' ||
        !(value['status'] == 'unavailable'
            ? value['balance_basis'] == 'unavailable'
            : [
                'current_recorded_ledger',
                'captured_recorded_ledger',
              ].contains(value['balance_basis']))) {
      throw invalidNetWorth();
    }
    final date = netWorthText(value['snapshot_date']);
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ||
        DateTime.tryParse('${date}T00:00:00Z')
                ?.toIso8601String()
                .substring(0, 10) !=
            date) {
      throw invalidNetWorth();
    }
    final observed = netWorthText(value['observed_at']);
    if (!observed.endsWith('Z') || DateTime.tryParse(observed) == null) {
      throw invalidNetWorth();
    }
    final amounts = <String, String?>{};
    for (final key in [
      'known_assets',
      'known_balance_liabilities',
      'known_net_worth',
      'net_worth',
      'cash_balance',
      'investment_cash_balance',
      'holdings_value',
    ]) {
      if (!value.containsKey(key)) throw invalidNetWorth();
      amounts[key] = netWorthMoney(value[key]);
    }
    for (final key in ['obligation_liabilities', 'receivables_value']) {
      amounts[key] = netWorthMoney(value[key]);
    }
    if ((value['status'] != 'complete' && amounts['net_worth'] != null) ||
        (value['status'] == 'complete' &&
            amounts.values.any((v) => v == null)) ||
        (value['status'] == 'unavailable' &&
            amounts.values.any((v) => v != null))) {
      throw invalidNetWorth();
    }
    final missing = value['missing_components'];
    final rows = value['holdings'];
    final excluded = value['excluded_account_count'];
    if (missing is! List ||
        missing.any((v) => v is! String) ||
        rows is! List ||
        excluded is! int ||
        excluded < 0) {
      throw invalidNetWorth();
    }
    final holdings = rows.map(NetWorthHolding.fromJson).toList();
    if (value['status'] == 'complete') {
      BigInt cents(String key) =>
          BigInt.parse(amounts[key]!.replaceAll('.', ''));
      if (missing.any((v) => v != 'attribution_unavailable') ||
          holdings.any(
            (h) => h.marketValue == null || h.unavailableReason != null,
          ) ||
          cents('known_assets') -
                  cents('known_balance_liabilities') -
                  cents('obligation_liabilities') !=
              cents('net_worth') ||
          amounts['net_worth'] != amounts['known_net_worth']) {
        throw invalidNetWorth();
      }
    }
    return NetWorthAssessment._(
      date,
      observed,
      value['balance_basis'] as String,
      value['status'] == 'unavailable',
      Map.unmodifiable(amounts),
      List<String>.unmodifiable(missing),
      List.unmodifiable(holdings),
      excluded,
    );
  }
}

class NetWorthHolding {
  final String instrumentId;
  final String? marketValue, priceDate, priceSource, unavailableReason;
  final bool? stale;
  const NetWorthHolding._(
    this.instrumentId,
    this.marketValue,
    this.priceDate,
    this.priceSource,
    this.unavailableReason,
    this.stale,
  );

  factory NetWorthHolding.fromJson(dynamic value) {
    if (value is! Map<String, dynamic> ||
        (value['stale'] != null && value['stale'] is! bool)) {
      throw invalidNetWorth();
    }
    String? optionalText(String key) =>
        value[key] == null ? null : netWorthText(value[key]);
    return NetWorthHolding._(
      netWorthText(value['instrument_id']),
      netWorthMoney(value['market_value']),
      optionalText('price_date'),
      optionalText('price_source'),
      optionalText('unavailable_reason'),
      value['stale'] as bool?,
    );
  }
}

ApiFailure invalidNetWorth() =>
    const ApiFailure('Respons penilaian tidak valid.');
String netWorthText(dynamic value) {
  if (value is! String || value.isEmpty) throw invalidNetWorth();
  return value;
}

String? netWorthMoney(dynamic value) {
  if (value == null) return null;
  if (value is! String ||
      RegExp(r'^-?\d+\.\d{2}$').stringMatch(value) != value) {
    throw invalidNetWorth();
  }
  return value;
}
