import '../../../core/network/api_client.dart';
import '../../reports/data/financial_export_repository.dart';
import '../../sync/data/finance_repository.dart';

const allocationClasses = [
  'CASH',
  'RECEIVABLE',
  'STOCK',
  'MUTUAL_FUND',
  'CRYPTO',
  'BOND',
  'GOLD',
  'OTHER',
];
const allocationLabels = {
  'CASH': 'Kas & kas investasi',
  'RECEIVABLE': 'Piutang',
  'STOCK': 'Saham',
  'MUTUAL_FUND': 'Reksa dana',
  'CRYPTO': 'Kripto',
  'BOND': 'Obligasi',
  'GOLD': 'Emas',
  'OTHER': 'Investasi lain',
  'UNCLASSIFIED': 'Kelas belum diketahui',
};

ApiFailure invalidAllocation() =>
    const ApiFailure('Respons alokasi aset tidak valid.');
BigInt allocationMinor(dynamic value) {
  if (value is! String || !RegExp(r'^\d+\.\d{2}$').hasMatch(value)) {
    throw invalidAllocation();
  }
  return BigInt.parse(value.replaceAll('.', ''));
}

String? allocationWeight(BigInt amount, BigInt? total) =>
    total == null || total == BigInt.zero
    ? null
    : financialDecimal(amount * BigInt.from(10000) ~/ total);

class AllocationSnapshot {
  final Map<String, dynamic> json;
  AllocationSnapshot._(this.json);
  bool get complete => json['status'] == 'complete';
  List<Map<String, dynamic>> get classes =>
      (json['classes'] as List).cast<Map<String, dynamic>>();
  List<Map<String, dynamic>> get instruments =>
      (json['instruments'] as List).cast<Map<String, dynamic>>();
  BigInt? get total => json['total_assets'] == null
      ? null
      : allocationMinor(json['total_assets']);
  List<Map<String, dynamic>> get rankedInstruments {
    if (!complete || total == null || total == BigInt.zero) return [];
    return instruments
        .where(
          (i) =>
              i['market_value'] != null &&
              allocationMinor(i['market_value']) > BigInt.zero,
        )
        .toList()
      ..sort(
        (a, b) =>
            allocationMinor(b['known_amount'])
                .compareTo(allocationMinor(a['known_amount'])),
      );
  }

  String? get topThreeWeight => rankedInstruments.isEmpty
      ? null
      : allocationWeight(
          rankedInstruments
              .take(3)
              .fold(
                BigInt.zero,
                (sum, row) => sum + allocationMinor(row['known_amount']),
              ),
          total,
        );
  factory AllocationSnapshot.fromJson(dynamic value) {
    if (value is! Map<String, dynamic> ||
        value['scope'] != 'owner' ||
        value['currency'] != 'IDR' ||
        value['denominator'] != 'gross_positive_supported_assets' ||
        value['balance_basis'] != 'current_recorded_ledger' ||
        !['complete', 'partial'].contains(value['status'])) {
      throw invalidAllocation();
    }
    final complete = value['status'] == 'complete';
    bool date(dynamic v) =>
        v is String &&
        RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v) &&
        DateTime.tryParse('${v}T00:00:00Z')
                ?.toIso8601String()
                .substring(0, 10) ==
            v;
    if (!date(value['snapshot_date']) ||
        value['observed_at'] is! String ||
        !(value['observed_at'] as String).endsWith('Z') ||
        DateTime.tryParse(value['observed_at']) == null ||
        value['excluded_account_count'] is! int ||
        value['excluded_account_count'] < 0 ||
        value['warnings'] is! List ||
        (value['warnings'] as List).any((v) => v is! String)) {
      throw invalidAllocation();
    }
    final known = allocationMinor(value['known_assets']);
    allocationMinor(value['excluded_liabilities']);
    final total = value['total_assets'] == null
        ? null
        : allocationMinor(value['total_assets']);
    if (complete ? total != known : total != null) throw invalidAllocation();
    List<Map<String, dynamic>> rows(String key) {
      if (value[key] is! List ||
          (value[key] as List).any((r) => r is! Map<String, dynamic>)) {
        throw invalidAllocation();
      }
      return (value[key] as List).cast<Map<String, dynamic>>();
    }

    final classes = rows('classes'), instruments = rows('instruments');
    final seen = <String>{}, seenInstruments = <String>{};
    var sum = BigInt.zero;
    void validateValue(Map<String, dynamic> row) {
      final amount = allocationMinor(row['known_amount']);
      final market = row['market_value'] == null
          ? null
          : allocationMinor(row['market_value']);
      if ((market != null && market != amount) ||
          (complete && market == null) ||
          row['weight_percent'] !=
              (complete ? allocationWeight(amount, total) : null)) {
        throw invalidAllocation();
      }
    }

    for (final row in classes) {
      final kind = row['asset_class'];
      if (kind is! String ||
          ![...allocationClasses, 'UNCLASSIFIED'].contains(kind) ||
          !seen.add(kind) ||
          row['unavailable_count'] is! int ||
          row['unavailable_count'] < 0 ||
          (complete &&
              (kind == 'UNCLASSIFIED' || row['unavailable_count'] != 0))) {
        throw invalidAllocation();
      }
      validateValue(row);
      sum += allocationMinor(row['known_amount']);
    }
    if (sum != known || !allocationClasses.every(seen.contains)) {
      throw invalidAllocation();
    }
    final instrumentTotals = <String, BigInt>{};
    for (final row in instruments) {
      final id = row['instrument_id'];
      if (id is! String ||
          !RegExp(r'^[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$')
              .hasMatch(id) ||
          !seenInstruments.add(id) ||
          !seen.contains(row['asset_class']) ||
          ['CASH', 'RECEIVABLE'].contains(row['asset_class']) ||
          row['quantity'] is! String ||
          !RegExp(r'^-?\d+\.\d{8}$').hasMatch(row['quantity']) ||
          row['account_count'] is! int ||
          row['account_count'] <= 0 ||
          (row['stale'] != null && row['stale'] is! bool) ||
          (row['price_date'] != null && !date(row['price_date'])) ||
          [
            'name',
            'code',
            'price_source',
          ].any((k) => row[k] != null && row[k] is! String) ||
          row['unavailable_reasons'] is! List ||
          (row['unavailable_reasons'] as List).any((v) => v is! String) ||
          (complete && (row['unavailable_reasons'] as List).isNotEmpty)) {
        throw invalidAllocation();
      }
      validateValue(row);
      final kind = row['asset_class'] as String;
      instrumentTotals[kind] =
          (instrumentTotals[kind] ?? BigInt.zero) +
          allocationMinor(row['known_amount']);
    }
    for (final row in classes.where(
      (r) => !['CASH', 'RECEIVABLE'].contains(r['asset_class']),
    )) {
      if (allocationMinor(row['known_amount']) !=
          (instrumentTotals[row['asset_class']] ?? BigInt.zero)) {
        throw invalidAllocation();
      }
    }
    return AllocationSnapshot._(value);
  }
}

class AssetAllocationRepository {
  final FinanceRepository source;
  const AssetAllocationRepository(this.source);
  AllocationSnapshot? get cached {
    final data = source.state['asset_allocation_cache'];
    if (data is! Map ||
        data['user_id'] != source.userId ||
        data['schema'] != 1) {
      return null;
    }
    try {
      return AllocationSnapshot.fromJson(data['snapshot']);
    } catch (_) {
      return null;
    }
  }

  Map<String, String>? get targets {
    final config = source.state['asset_allocation_targets'];
    if (config is! Map ||
        config['schema'] != 1 ||
        config['user_id'] != source.userId ||
        config['values'] is! Map) {
      return null;
    }
    try {
      final values = Map<String, String>.from(config['values'] as Map);
      validateTargets(values);
      return values;
    } catch (_) {
      return null;
    }
  }

  void validateTargets(Map<String, String> values) {
    var total = BigInt.zero;
    if (values.length != allocationClasses.length ||
        !allocationClasses.every(values.containsKey)) {
      throw const ApiFailure('Isi target untuk setiap kelas aset.');
    }
    for (final v in values.values) {
      if (!RegExp(r'^(0|[1-9]\d{0,2})(?:\.\d{1,2})?$').hasMatch(v)) {
        throw const ApiFailure(
          'Target harus 0–100 dengan maksimal dua desimal.',
        );
      }
      final parts = v.split('.');
      final bps =
          BigInt.parse(parts.first) * BigInt.from(100) +
          BigInt.parse(parts.length == 1 ? '0' : parts[1].padRight(2, '0'));
      if (bps > BigInt.from(10000)) {
        throw const ApiFailure('Target tidak boleh melebihi 100%.');
      }
      total += bps;
    }
    if (total != BigInt.from(10000)) {
      throw const ApiFailure('Total target harus tepat 100%.');
    }
  }

  void saveTargets(Map<String, String>? values) {
    if (values != null) validateTargets(values);
    source.atomic(() {
      if (values == null) {
        source.state.remove('asset_allocation_targets');
      } else {
        source.state['asset_allocation_targets'] = {
          'schema': 1,
          'user_id': source.userId,
          'values': {
            for (final e in values.entries) e.key: _canonicalPercent(e.value),
          },
        };
      }
    });
  }

  String _canonicalPercent(String value) {
    final parts = value.split('.');
    return '${parts.first}.${(parts.length == 1 ? '0' : parts[1]).padRight(2, '0')}';
  }

  String? deviation(AllocationSnapshot snapshot, String kind) {
    final target = targets?[kind];
    final actual = snapshot.classes
        .where((c) => c['asset_class'] == kind)
        .firstOrNull?['weight_percent'];
    if (!snapshot.complete || target == null || actual == null) return null;
    return financialDecimal(
      allocationMinor(actual) - allocationMinor(_canonicalPercent(target)),
    );
  }

  Future<AllocationSnapshot> fetch({required bool Function() isCurrent}) async {
    await source.requireOnline();
    final raw = await source.client.request(
      'GET',
      '/net-worth/allocation',
      query: {'currency': 'IDR'},
    );
    final snapshot = AllocationSnapshot.fromJson(raw);
    if (!isCurrent() || source.offline) {
      throw const ApiFailure('Sesi/koneksi telah berubah.');
    }
    source.atomic(() {
      source.state['asset_allocation_cache'] = {
        'schema': 1,
        'user_id': source.userId,
        'snapshot': raw,
      };
    });
    return snapshot;
  }

  void clearCache() => source.atomic(() {
    source.state.remove('asset_allocation_cache');
  });
}
