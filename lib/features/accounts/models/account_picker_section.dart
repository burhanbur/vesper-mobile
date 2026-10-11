import 'account.dart';
import 'account_picker_group.dart';

class AccountPickerSection {
  final String category;
  final String label;
  final List<AccountPickerGroup> groups;

  AccountPickerSection(this.category, this.label, this.groups);
}

/// Uses the stored account-type label, not the account name or provider name.
List<AccountPickerSection> buildAccountPickerSections(
  List<AccountPickerGroup> groups,
) {
  final sections = <String, AccountPickerSection>{};
  const cashOrder = [
    'Cash',
    'Rekening Bank',
    'E-wallet',
    'Kartu Kredit / Paylater',
  ];
  const investmentOrder = ['Reksadana', 'Saham', 'Obligasi', 'Emas', 'Crypto'];
  for (final group in groups) {
    final account = group.parent ?? group.entries.first.account;
    final investment = account.type == AccountType.investment;
    final category = investment ? 'Investasi' : 'Cash';
    final stored = account.institution.trim();
    final normalized = stored.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
    final label = switch (normalized) {
      'cash' || 'kas' || 'kastunai' || 'kastunaidompet' => 'Cash',
      'bank' || 'rekeningbank' => 'Rekening Bank',
      'ewallet' || 'dompetdigital' => 'E-wallet',
      'reksadana' || 'mutualfund' => 'Reksadana',
      'saham' || 'stock' || 'stocks' => 'Saham',
      'obligasi' || 'bond' => 'Obligasi',
      'emas' || 'gold' => 'Emas',
      'crypto' || 'kripto' => 'Crypto',
      _ =>
        stored.isNotEmpty
            ? stored
            : switch (account.type) {
                AccountType.bank => 'Rekening Bank',
                AccountType.wallet => 'E-wallet',
                AccountType.creditCard => 'Kartu Kredit / Paylater',
                AccountType.cash => 'Cash',
                AccountType.investment => 'Lainnya',
              },
    };
    final key = '$category:$label';
    sections
        .putIfAbsent(key, () => AccountPickerSection(category, label, []))
        .groups
        .add(group);
  }
  int rank(String label, List<String> order) {
    final index = order.indexOf(label);
    return index < 0 ? order.length : index;
  }

  final result = sections.values.toList();
  result.sort((a, b) {
    if (a.category != b.category) return a.category == 'Cash' ? -1 : 1;
    final order = a.category == 'Cash' ? cashOrder : investmentOrder;
    final comparison = rank(a.label, order).compareTo(rank(b.label, order));
    return comparison != 0
        ? comparison
        : a.label.toLowerCase().compareTo(b.label.toLowerCase());
  });
  return result;
}
