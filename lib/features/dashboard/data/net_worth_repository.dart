import '../../../core/network/api_client.dart';
import '../../sync/data/finance_repository.dart';
import '../models/net_worth_assessment.dart';

class NetWorthRepository {
  const NetWorthRepository(this.source);
  final FinanceRepository source;

  Future<NetWorthAssessment> fetch(DateTime? date) async {
    await source.requireOnline();
    final result = await source.client.request(
      'GET',
      '/net-worth/snapshots',
      query: {
        'currency': 'IDR',
        if (date != null) 'date': date.toIso8601String().substring(0, 10),
      },
    );
    // ApiClient.request already unwraps the API envelope's data field.
    final data = NetWorthAssessment.fromJson(result);
    if (date != null &&
        data.snapshotDate != date.toIso8601String().substring(0, 10)) {
      throw const ApiFailure('Tanggal penilaian tidak sesuai.');
    }
    return data;
  }
}
