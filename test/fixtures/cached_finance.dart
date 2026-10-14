import 'package:sqlite3/sqlite3.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/database/local_store.dart';
import 'package:vesper_mobile/features/sync/data/finance_repository.dart';

/// Server-shaped records persisted through the real local repository.
AppState cachedFinanceState({ApiClient? client}) {
  final repo = FinanceRepository(
    client ?? ApiClient(),
    LocalStore(sqlite3.openInMemory()),
    'user',
  );
  repo.atomic(() {
    repo.entities['categories'] = <String, dynamic>{
      'food': {
        'id': 'food',
        'user_id': 'user',
        'name': 'Food',
        'type': 'EXPENSE',
        'version': '1',
      },
      'salary': {
        'id': 'salary',
        'user_id': 'user',
        'name': 'Salary',
        'type': 'INCOME',
        'version': '1',
      },
    };
    repo.entities['accounts'] = <String, dynamic>{
      'cash': {
        'id': 'cash',
        'user_id': 'user',
        'name': 'Cash',
        'balance': '100000.00',
        'version': '1',
      },
    };
  });
  return AppState(repository: repo);
}
