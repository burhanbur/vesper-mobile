import '../../../core/network/api_client.dart';

class PocketAccount {
  final String id, name, ownerId, ownerName, currency, balance;
  const PocketAccount({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.ownerName,
    required this.currency,
    required this.balance,
  });
  factory PocketAccount.fromJson(Map<String, dynamic> json) => PocketAccount(
    id: json['account_id'] as String,
    name: json['name'] as String,
    ownerId: json['owner_user_id'] as String,
    ownerName: json['owner_name'] as String,
    currency: json['currency'] as String,
    balance: pocketMoney(json['balance']),
  );
}

String pocketMoney(Object? value) {
  if (value is! String || !RegExp(r'^-?\d+\.\d{2}$').hasMatch(value)) {
    throw const ApiFailure('Respons nominal kantong tidak valid.');
  }
  return value;
}

class PocketBalance {
  final String currency, balance;
  const PocketBalance(this.currency, this.balance);
}

class GroupPocket {
  final String id, name;
  final String? description;
  final List<PocketBalance> balances;
  final List<PocketAccount> accounts;
  const GroupPocket({
    required this.id,
    required this.name,
    this.description,
    required this.balances,
    required this.accounts,
  });
  factory GroupPocket.fromJson(Map<String, dynamic> json) => GroupPocket(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String?,
    balances: List.unmodifiable(
      (json['balances'] as List).map(
        (row) => PocketBalance(
          row['currency'] as String,
          pocketMoney(row['balance']),
        ),
      ),
    ),
    accounts: List.unmodifiable(
      (json['accounts'] as List).map(
        (row) => PocketAccount.fromJson(Map<String, dynamic>.from(row as Map)),
      ),
    ),
  );
}

/// Online collaboration only: never persisted or added to the ledger sync queue.
class GroupPocketRepository {
  final ApiClient client;
  GroupPocketRepository(this.client);
  Future<List<GroupPocket>> read(String group) async {
    final data = await client.request('GET', '/groups/$group/pockets');
    return List.unmodifiable(
      (data as List).map(
        (row) => GroupPocket.fromJson(Map<String, dynamic>.from(row as Map)),
      ),
    );
  }

  Future<void> create(String group, String name, String description) async {
    await client.request(
      'POST',
      '/groups/$group/pockets',
      body: {
        'name': name.trim(),
        if (description.trim().isNotEmpty) 'description': description.trim(),
      },
    );
  }

  Future<void> update(
    String group,
    String pocket,
    String name,
    String description,
  ) async {
    await client.request(
      'PATCH',
      '/groups/$group/pockets/$pocket',
      body: {
        'name': name.trim(),
        'description': description.trim().isEmpty ? null : description.trim(),
      },
    );
  }

  Future<void> delete(String group, String pocket) async {
    await client.request('DELETE', '/groups/$group/pockets/$pocket');
  }

  Future<void> assign(
    String group,
    String pocket,
    String account, {
    required bool remove,
  }) async {
    await client.request(
      remove ? 'DELETE' : 'POST',
      '/groups/$group/pockets/$pocket/accounts',
      body: {'account_id': account},
    );
  }
}

class PocketCandidate {
  final String id, name, currency, balance;
  const PocketCandidate(this.id, this.name, this.currency, this.balance);
}

/// Local eligibility is a convenience only; the API revalidates ownership and hierarchy.
List<PocketCandidate> pocketCandidates(
  String owner,
  List<Map<String, dynamic>> accounts,
  List<Map<String, dynamic>> types,
) {
  final liveTypes = types
      .where((r) => r['user_id'] == owner && r['deleted_at'] == null)
      .map((r) => r['id'])
      .toSet();
  final live = accounts
      .where((r) => r['user_id'] == owner && r['deleted_at'] == null)
      .toList();
  final parents = accounts
      .where((r) => r['deleted_at'] == null)
      .map((r) => r['parent_account_id'])
      .toSet();
  final byId = {for (final r in live) r['id']: r};
  final result = <PocketCandidate>[];
  for (final row in live) {
    if (row['is_credit_card'] == true ||
        parents.contains(row['id']) ||
        !liveTypes.contains(row['account_type_id'])) {
      continue;
    }
    final parentId = row['parent_account_id'];
    final parent = byId[parentId];
    if (parentId != null &&
        (parent == null || !liveTypes.contains(parent['account_type_id']))) {
      continue;
    }
    final name = parent == null
        ? '${row['name']}'
        : '${parent['name']} - ${row['name']}';
    result.add(
      PocketCandidate(
        '${row['id']}',
        name,
        '${row['currency']}',
        '${row['balance']}',
      ),
    );
  }
  return result;
}
