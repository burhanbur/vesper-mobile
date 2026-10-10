import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/features/accounts/models/account.dart';
import 'package:vesper_mobile/features/accounts/models/account_picker_group.dart';

Account account(
  String id,
  String name, {
  String? parent,
  int order = 0,
  String institution = '',
  String owner = '',
}) => Account(
  id: id,
  name: name,
  type: AccountType.bank,
  balance: 123,
  accountNumber: '',
  parentAccountId: parent,
  sequenceOrder: order,
  institution: institution,
  ownerName: owner,
);

void main() {
  test(
    'shuffled universe and selection sort roots and every sibling level',
    () {
      final root = account('root', 'Zulu', order: -1);
      final other = account('other', 'Alpha');
      final branchA = account('branch-a', 'alpha', parent: root.id);
      final branchB = account('branch-b', 'Beta', parent: root.id);
      final a = account('a', 'same', parent: branchA.id);
      final b = account('b', 'SAME', parent: branchA.id);
      final c = account('c', 'Earlier', parent: branchA.id, order: -1);
      final d = account('d', 'A', parent: branchB.id);
      final universe = [d, b, other, branchB, c, root, a, branchA];
      final groups = buildAccountPickerGroups(
        selectableAccounts: [other, d, b, a, c],
        accountUniverse: universe,
      );
      expect(groups.first.parent?.id, 'root');
      expect(groups.first.entries.map((entry) => entry.account.id), [
        'c',
        'a',
        'b',
        'd',
      ]);
      expect(groups.last.entries.single.account.id, 'other');
      final reversed = buildAccountPickerGroups(
        selectableAccounts: [c, a, b, d, other],
        accountUniverse: universe.reversed.toList(),
      );
      expect(
        reversed
            .expand((group) => group.entries)
            .map((entry) => entry.account.id),
        groups
            .expand((group) => group.entries)
            .map((entry) => entry.account.id),
      );
    },
  );

  test('duplicate parent names and institutions never merge distinct IDs', () {
    final first = account('a', 'Bank', institution: 'Same');
    final second = account('b', 'BANK', institution: 'Same');
    final left = account('left', 'Pocket', parent: 'a');
    final right = account('right', 'Pocket', parent: 'b');
    final groups = buildAccountPickerGroups(
      selectableAccounts: [right, left],
      accountUniverse: [second, right, left, first],
    );
    expect(groups.map((group) => group.parent?.id), ['a', 'b']);
    expect(groups.map((group) => group.entries.single.account.id), [
      'left',
      'right',
    ]);
  });

  test('deep chains resolve root-first and search ancestors, owner and institution', () {
    final root = account('root', 'Savings', owner: 'Alice');
    final middle = account(
      'middle',
      'Travel',
      parent: 'root',
      institution: 'Real Bank',
    );
    final leaf = account('leaf', 'Tickets', parent: 'middle');
    final universe = [leaf, root, middle];
    final entry = resolveAccountPickerEntry(leaf, universe);
    expect(entry.breadcrumb, 'Savings › Travel');
    expect(entry.hasUnavailableParent, isFalse);
    for (final query in [
      ' savings ',
      'TRAVEL',
      'alice',
      'real bank',
      'tickets',
    ]) {
      final groups = buildAccountPickerGroups(
        selectableAccounts: [leaf],
        accountUniverse: universe,
        query: query,
      );
      expect(groups.single.entries.single.account.id, 'leaf');
    }
    expect(
      buildAccountPickerGroups(
        selectableAccounts: [leaf],
        accountUniverse: universe,
        query: 'unknown',
      ),
      isEmpty,
    );
  });

  test(
    'missing parents, self cycles and multi-node cycles fall back safely',
    () {
      final missing = account('missing', 'Orphan', parent: 'absent');
      final self = account('self', 'Self', parent: 'self');
      final a = account('a', 'A', parent: 'b');
      final b = account('b', 'B', parent: 'a');
      final leaf = account('leaf', 'Leaf', parent: 'a');
      final partial = account('partial', 'Partial', parent: 'missing');
      final universe = [missing, self, a, b, leaf, partial];
      for (final item in universe) {
        final entry = resolveAccountPickerEntry(item, universe);
        expect(entry.hasUnavailableParent, isTrue);
        expect(entry.ancestors, isEmpty);
        expect(entry.breadcrumb, isEmpty);
      }
      final groups = buildAccountPickerGroups(
        selectableAccounts: [missing, self, leaf, partial],
        accountUniverse: universe,
      );
      expect(groups, hasLength(4));
      expect(groups.every((group) => group.parent == null), isTrue);
    },
  );
}
