import '../../../core/network/api_client.dart';

/// Server decimal strings are retained exactly; no floating-point conversion.
class HouseholdCategoryAggregate {
  final String id, name, type, income, expense;
  const HouseholdCategoryAggregate(
    this.id,
    this.name,
    this.type,
    this.income,
    this.expense,
  );
  factory HouseholdCategoryAggregate.fromJson(Map<String, dynamic> json) {
    final decimal = RegExp(r'^-?\d+(?:\.\d+)?$');
    if (json['group_category_id'] is! String ||
        json['name'] is! String ||
        !['INCOME', 'EXPENSE'].contains(json['type']) ||
        json['income'] is! String ||
        json['expense'] is! String ||
        !decimal.hasMatch(json['income'] as String) ||
        !decimal.hasMatch(json['expense'] as String)) {
      throw const ApiFailure('Respons laporan kategori tidak valid.');
    }
    return HouseholdCategoryAggregate(
      json['group_category_id'],
      json['name'],
      json['type'],
      json['income'],
      json['expense'],
    );
  }
}

class HouseholdCategoryReport {
  final String period;
  final List<HouseholdCategoryAggregate> categories;
  final DateTime fetchedAt;
  const HouseholdCategoryReport(this.period, this.categories, this.fetchedAt);
  factory HouseholdCategoryReport.fromJson(
    Map<String, dynamic> json,
    String expectedPeriod,
    DateTime fetchedAt,
  ) {
    if (json['period'] != expectedPeriod || json['categories'] is! List) {
      throw const ApiFailure('Periode respons laporan kategori tidak valid.');
    }
    return HouseholdCategoryReport(
      expectedPeriod,
      (json['categories'] as List)
          .map(
            (row) => HouseholdCategoryAggregate.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(),
      fetchedAt,
    );
  }
}

String utcReportPeriod(DateTime date) =>
    '${date.toUtc().year.toString().padLeft(4, '0')}-${date.toUtc().month.toString().padLeft(2, '0')}';

void validateReportPeriod(String period) {
  if (!RegExp(r'^[1-9]\d{3}-(0[1-9]|1[0-2])$').hasMatch(period)) {
    throw const ApiFailure('Periode harus berupa bulan UTC YYYY-MM.');
  }
}
