import '../../../core/network/api_client.dart';

/// Online-only, scoped reads: never mix another member's data into personal sync.
class CollaborationRepository {
  final ApiClient client;
  CollaborationRepository(this.client);

  Future<Map<String, dynamic>> read(
    String group,
    String period,
    int page,
  ) async {
    final result = await client.request(
      'GET',
      '/groups/$group/collaboration',
      query: {'period': period, 'page': page, 'limit': 20},
    );
    if (result is! Map<String, dynamic> ||
        result['period'] != period ||
        result['page'] != page ||
        result['limit'] != 20) {
      throw const ApiFailure('Respons kolaborasi tidak valid.');
    }
    for (final list in ['balances', 'contributions', 'feed']) {
      if (result[list] is! List) {
        throw const ApiFailure('Respons kolaborasi tidak valid.');
      }
      final entries = result[list] as List;
      if (list != 'balances' && entries.length > 20) {
        throw const ApiFailure('Halaman kolaborasi terlalu besar.');
      }
      for (final row in entries) {
        if (row is! Map ||
            row['currency'] is! String ||
            !RegExp(r'^[A-Z]{3}$').hasMatch(row['currency'] as String)) {
          throw const ApiFailure('Respons kolaborasi tidak valid.');
        }
        if (list != 'balances' &&
            (row['user_id'] is! String || (row['user_id'] as String).isEmpty)) {
          throw const ApiFailure('Identitas kontribusi tidak valid.');
        }
        if (list == 'feed' &&
            (row['id'] is! String ||
                (row['id'] as String).isEmpty ||
                row['category'] is! String ||
                !['INCOME', 'EXPENSE'].contains(row['type']) ||
                row['transacted_at'] is! String ||
                DateTime.tryParse(row['transacted_at'] as String)?.isUtc !=
                    true)) {
          throw const ApiFailure('Aktivitas kolaborasi tidak valid.');
        }
        for (final key
            in list == 'balances'
                ? ['balance']
                : list == 'contributions'
                ? ['income', 'expense']
                : ['amount']) {
          final value = row[key];
          final match = value is String
              ? RegExp(r'^-?\d+(\.\d+)?$').firstMatch(value)
              : null;
          if (match == null || match.end != (value as String).length) {
            throw const ApiFailure('Nominal kolaborasi tidak valid.');
          }
        }
      }
    }
    return result;
  }

  Future<void> manage(String group, String user, String action) async {
    if (!['REMOVE', 'TRANSFER_OWNER'].contains(action)) {
      throw ArgumentError.value(action);
    }
    await client.request(
      'POST',
      '/groups/$group/membership',
      body: {'user_id': user, 'action': action},
    );
  }

  /// Resolve privileges from a fresh online membership read, not the visible page.
  /// Fail closed when membership disappears or the bounded scan is exhausted.
  Future<String?> actorRole(String group, String actor) async {
    final seen = <String>{};
    for (var page = 1; page <= 1000; page++) {
      final rows = await members(group, page);
      for (final row in rows) {
        final id = row['user_id'] as String;
        if (!seen.add(id)) {
          throw const ApiFailure('Halaman anggota berulang.');
        }
        if (id == actor) return row['role'] as String;
      }
      if (rows.length < 20) return null;
    }
    throw const ApiFailure('Daftar anggota melebihi batas aman.');
  }

  Future<List<Map<String, dynamic>>> members(String group, int page) async {
    final result = await client.request(
      'GET',
      '/groups/$group/members',
      query: {'page': page, 'limit': 20},
    );
    if (result is! List || result.length > 20) {
      throw const ApiFailure('Respons anggota tidak valid.');
    }
    return result.map((row) {
      if (row is! Map<String, dynamic> ||
          row['user_id'] is! String ||
          row['name'] is! String ||
          !['OWNER', 'MEMBER'].contains(row['role'])) {
        throw const ApiFailure('Respons anggota tidak valid.');
      }
      return row;
    }).toList();
  }
}
