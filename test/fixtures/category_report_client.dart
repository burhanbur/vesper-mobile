import 'dart:async';

import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/app/app_state.dart';

class CategoryReportClient extends ApiClient {
  final List<String> requests = [];
  bool fail = false;
  String amount = '25000.25';
  Completer<dynamic>? pending;
  String? responsePeriod;
  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    bool authenticated = true,
    bool retry = true,
  }) async {
    if (!path.endsWith('/category-report')) {
      throw const ApiFailure('Unrelated request');
    }
    final period = query!['period'] as String;
    requests.add('$path?$period');
    if (pending != null) return pending!.future;
    if (fail) {
      throw const ApiFailure('Server tidak terjangkau.', isTransient: true);
    }
    return reportPayload(responsePeriod ?? period, amount);
  }
}

Map<String, dynamic> reportPayload(String period, String amount) => {
  'period': period,
  'categories': [
    {
      'group_category_id': 'category',
      'name': 'Shared food',
      'type': 'EXPENSE',
      'income': '0.00',
      'expense': amount,
    },
  ],
};

void seedReportGroups(AppState state) {
  state.repository!.atomic(() {
    state.repository!.entities['groups'] = {
      'group': {'id': 'group', 'name': 'Our group', 'role': 'OWNER'},
      'other': {'id': 'other', 'name': 'Other group', 'role': 'MEMBER'},
    };
  });
}
