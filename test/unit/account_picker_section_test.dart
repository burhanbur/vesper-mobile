import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/features/accounts/models/account.dart';
import 'package:vesper_mobile/features/accounts/models/account_picker_group.dart';
import 'package:vesper_mobile/features/accounts/models/account_picker_section.dart';

void main() {
  test('Stored type labels determine ordered sections even for cash enum', () {
    final accounts = [
      for (final label in [
        'Saham',
        'E-wallet',
        'Reksadana',
        'Rekening Bank',
        'Cash',
        'Hutang & Piutang',
      ])
        Account(
          id: label,
          name: label,
          type: ['Saham', 'Reksadana'].contains(label)
              ? AccountType.investment
              : AccountType.cash,
          institution: label,
          balance: 0,
          accountNumber: '',
        ),
    ];
    final sections = buildAccountPickerSections(
      buildAccountPickerGroups(
        selectableAccounts: accounts,
        accountUniverse: accounts,
      ),
    );
    expect(sections.map((s) => s.label), [
      'Cash',
      'Rekening Bank',
      'E-wallet',
      'Hutang & Piutang',
      'Reksadana',
      'Saham',
    ]);
    expect(sections.map((s) => s.category), [
      'Cash',
      'Cash',
      'Cash',
      'Cash',
      'Investasi',
      'Investasi',
    ]);
  });
}
