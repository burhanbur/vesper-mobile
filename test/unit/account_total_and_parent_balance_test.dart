import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/core/network/api_client.dart';
import 'package:vesper_mobile/database/local_store.dart';
import 'package:vesper_mobile/features/accounts/models/account.dart';
import 'package:vesper_mobile/features/sync/data/finance_repository.dart';

void main() {
  group('Account Total Saldo and Parent Balance Calculations', () {
    test('isCashBankOrWallet correctly classifies account types', () {
      final cashAccount = Account(
        id: '1',
        name: 'Dompet Tunai',
        accountNumber: '111',
        type: AccountType.cash,
        balance: 50000,
      );
      final bankAccount = Account(
        id: '2',
        name: 'BCA Utama',
        accountNumber: '222',
        type: AccountType.bank,
        balance: 5000000,
      );
      final walletAccount = Account(
        id: '3',
        name: 'GoPay',
        accountNumber: '333',
        type: AccountType.wallet,
        balance: 250000,
      );
      final investmentAccount = Account(
        id: '4',
        name: 'Bareksa Reksa Dana',
        accountNumber: '444',
        type: AccountType.investment,
        balance: 10000000,
      );
      final creditCardAccount = Account(
        id: '5',
        name: 'Kartu Kredit BCA',
        accountNumber: '555',
        type: AccountType.creditCard,
        balance: 2000000,
      );

      expect(cashAccount.isCashBankOrWallet, isTrue);
      expect(bankAccount.isCashBankOrWallet, isTrue);
      expect(walletAccount.isCashBankOrWallet, isTrue);
      expect(investmentAccount.isCashBankOrWallet, isFalse);
      expect(creditCardAccount.isCashBankOrWallet, isFalse);
    });

    test('totalLiquidCash includes only cash/bank/ewallet accounts with isIncludeTotal == true', () {
      final repo = FinanceRepository(
        ApiClient(),
        LocalStore(sqlite3.openInMemory()),
        'user1',
      );
      repo.atomic(() {
        repo.entities['accounts'] = <String, dynamic>{
          'acc_cash': {
            'id': 'acc_cash',
            'user_id': 'user1',
            'name': 'Cash On Hand',
            'type': 'CASH',
            'balance': '150000.00',
            'is_include_total': true,
            'version': '1',
          },
          'acc_bank': {
            'id': 'acc_bank',
            'user_id': 'user1',
            'name': 'BCA Giro',
            'type': 'BANK',
            'balance': '2000000.00',
            'is_include_total': true,
            'version': '1',
          },
          'acc_wallet_excluded': {
            'id': 'acc_wallet_excluded',
            'user_id': 'user1',
            'name': 'OVO Rahasia',
            'type': 'EWALLET',
            'balance': '500000.00',
            'is_include_total': false, // Excluded by user
            'version': '1',
          },
          'acc_investment': {
            'id': 'acc_investment',
            'user_id': 'user1',
            'name': 'Bareksa Portofolio',
            'type': 'INVESTMENT',
            'balance': '50000000.00',
            'is_include_total':
                true, // Even if true, investment is not liquid cash/bank/wallet
            'version': '1',
          },
          'acc_loan': {
            'id': 'acc_loan',
            'user_id': 'user1',
            'name': 'Hutang',
            'type': 'LOAN',
            'balance': '1000000.00',
            'is_include_total':
                true, // Even if true, loan is not cash/bank/wallet
            'version': '1',
          },
        };
      });

      final state = AppState(repository: repo);
      addTearDown(state.dispose);

      // Expect total: 150.000 + 2.000.000 = 2.150.000
      expect(state.totalLiquidCash, 2150000);
    });

    test('updateAccountIncludeTotal updates state and prevents accounts with children', () async {
      final repo = FinanceRepository(
        ApiClient(),
        LocalStore(sqlite3.openInMemory()),
        'user1',
      );
      repo.atomic(() {
        repo.entities['accounts'] = <String, dynamic>{
          'parent_bank': {
            'id': 'parent_bank',
            'user_id': 'user1',
            'name': 'Bank Utama',
            'type': 'BANK',
            'balance': '0.00',
            'is_include_total': false,
            'version': '1',
          },
          'child_pocket_1': {
            'id': 'child_pocket_1',
            'user_id': 'user1',
            'parent_account_id': 'parent_bank',
            'name': 'Kantong Liburan',
            'type': 'BANK',
            'balance': '5000000.00',
            'is_include_total': true,
            'version': '1',
          },
          'child_pocket_2': {
            'id': 'child_pocket_2',
            'user_id': 'user1',
            'parent_account_id': 'parent_bank',
            'name': 'Kantong Darurat',
            'type': 'BANK',
            'balance': '3000000.00',
            'is_include_total': true,
            'version': '1',
          },
          'standalone_wallet': {
            'id': 'standalone_wallet',
            'user_id': 'user1',
            'name': 'GoPay',
            'type': 'EWALLET',
            'balance': '500000.00',
            'is_include_total': true,
            'version': '1',
          },
        };
      });

      final state = AppState(repository: repo);
      addTearDown(state.dispose);

      // Verify parent account with children cannot be included in total
      expect(
        () => state.updateAccountIncludeTotal(
          accountId: 'parent_bank',
          isIncludeTotal: true,
        ),
        throwsA(isA<ApiFailure>()),
      );

      // Verify standalone wallet can toggle isIncludeTotal to false
      expect(state.getAccountById('standalone_wallet')!.isIncludeTotal, isTrue);
      await state.updateAccountIncludeTotal(
        accountId: 'standalone_wallet',
        isIncludeTotal: false,
      );
      expect(
        state.getAccountById('standalone_wallet')!.isIncludeTotal,
        isFalse,
      );

      // Simulate synced outbox before next mutation
      repo.outbox.clear();

      // Verify toggle back to true
      await state.updateAccountIncludeTotal(
        accountId: 'standalone_wallet',
        isIncludeTotal: true,
      );
      expect(state.getAccountById('standalone_wallet')!.isIncludeTotal, isTrue);
    });

    test('Parent account aggregates children balances for display', () {
      final repo = FinanceRepository(
        ApiClient(),
        LocalStore(sqlite3.openInMemory()),
        'user1',
      );
      repo.atomic(() {
        repo.entities['accounts'] = <String, dynamic>{
          'bareksa': {
            'id': 'bareksa',
            'user_id': 'user1',
            'name': 'Bareksa',
            'type': 'INVESTMENT',
            'balance': '0.00',
            'is_include_total': false,
            'version': '1',
          },
          'pocket_pasar_uang': {
            'id': 'pocket_pasar_uang',
            'user_id': 'user1',
            'parent_account_id': 'bareksa',
            'name': 'Pasar Uang',
            'type': 'INVESTMENT',
            'balance': '50000000.00',
            'is_include_total': false,
            'version': '1',
          },
          'pocket_pendapatan_tetap': {
            'id': 'pocket_pendapatan_tetap',
            'user_id': 'user1',
            'parent_account_id': 'bareksa',
            'name': 'Pendapatan Tetap',
            'type': 'INVESTMENT',
            'balance': '30000000.00',
            'is_include_total': false,
            'version': '1',
          },
          'pocket_saham': {
            'id': 'pocket_saham',
            'user_id': 'user1',
            'parent_account_id': 'bareksa',
            'name': 'Saham',
            'type': 'INVESTMENT',
            'balance': '23000000.00',
            'is_include_total': false,
            'version': '1',
          },
        };
      });

      final state = AppState(repository: repo);
      addTearDown(state.dispose);

      final bareksa = state.getAccountById('bareksa')!;
      final children = state.getChildrenForAccount('bareksa');

      expect(bareksa.balance, 0);
      expect(children.length, 3);

      final aggregatedBalance =
          bareksa.balance + children.fold<int>(0, (sum, c) => sum + c.balance);
      expect(aggregatedBalance, 103000000);
    });
  });
}
