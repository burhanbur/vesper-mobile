import 'account.dart';

/// A selectable account with its verified, root-first parent chain.
class AccountPickerEntry {
  final Account account;
  final List<Account> ancestors;
  final bool hasUnavailableParent;

  AccountPickerEntry({
    required this.account,
    required List<Account> ancestors,
    this.hasUnavailableParent = false,
  }) : ancestors = List.unmodifiable(ancestors);

  String get breadcrumb => ancestors.map((parent) => parent.name).join(' › ');

  bool matches(String query) {
    final normalized = query.trim().toLowerCase();
    return [account, ...ancestors].any(
      (item) => [
        item.name,
        item.institution,
        item.ownerName,
      ].any((value) => value.toLowerCase().contains(normalized)),
    );
  }
}

class AccountPickerGroup {
  /// Null for an orphan or cyclic chain; never invent a parent.
  final Account? parent;
  final List<AccountPickerEntry> entries;

  AccountPickerGroup({
    required this.parent,
    required List<AccountPickerEntry> entries,
  }) : entries = List.unmodifiable(entries);
}

int comparePickerAccounts(Account left, Account right) {
  final sequence = left.sequenceOrder.compareTo(right.sequenceOrder);
  if (sequence != 0) return sequence;
  final name = left.name.toLowerCase().compareTo(right.name.toLowerCase());
  return name != 0 ? name : left.id.compareTo(right.id);
}

/// Resolves only IDs in the full universe, without guessing from display labels.
AccountPickerEntry resolveAccountPickerEntry(
  Account account,
  List<Account> universe,
) {
  final byId = {for (final item in universe) item.id: item};
  final visited = <String>{account.id};
  final parents = <Account>[];
  var parentId = account.parentAccountId;
  while (parentId != null) {
    final parent = byId[parentId];
    if (parent == null || !visited.add(parentId)) {
      // Invalid chains stay selectable, but must not claim a verified root.
      return AccountPickerEntry(
        account: account,
        ancestors: const [],
        hasUnavailableParent: true,
      );
    }
    parents.add(parent);
    parentId = parent.parentAccountId;
  }
  return AccountPickerEntry(
    account: account,
    ancestors: parents.reversed.toList(),
  );
}

/// Orders roots and every sibling level identically, then filters leaves.
/// [selectableAccounts] remains the caller's selection policy.
List<AccountPickerGroup> buildAccountPickerGroups({
  required List<Account> selectableAccounts,
  required List<Account> accountUniverse,
  String query = '',
}) {
  final entries = selectableAccounts
      .map((account) => resolveAccountPickerEntry(account, accountUniverse))
      .where((entry) => entry.matches(query))
      .toList();
  entries.sort((left, right) {
    final leftPath = [...left.ancestors, left.account];
    final rightPath = [...right.ancestors, right.account];
    for (
      var index = 0;
      index < leftPath.length && index < rightPath.length;
      index++
    ) {
      if (leftPath[index].id == rightPath[index].id) continue;
      return comparePickerAccounts(leftPath[index], rightPath[index]);
    }
    return leftPath.length.compareTo(rightPath.length);
  });
  final grouped = <String, List<AccountPickerEntry>>{};
  for (final entry in entries) {
    final rootId = entry.ancestors.isEmpty
        ? entry.account.id
        : entry.ancestors.first.id;
    grouped.putIfAbsent(rootId, () => []).add(entry);
  }
  return grouped.values
      .map(
        (items) => AccountPickerGroup(
          parent: items.first.ancestors.firstOrNull,
          entries: items,
        ),
      )
      .toList();
}
