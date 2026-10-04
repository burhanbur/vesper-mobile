import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/features/accounts/models/account.dart';
import 'package:vesper_mobile/features/investments/models/investment.dart';
import 'package:vesper_mobile/features/transactions/models/transaction.dart';

void main() {
  group('Finance Rules & PRD Business Logic', () {
    late AppState appState;

    setUp(() {
      appState = AppState();
    });

    test('Parent account balance excludes double counting in total liquid cash', () {
      // Bank Jago is a parent with children pockets and has isIncludeTotal = false
      final jagoParent = appState.getAccountById('acc-jago');
      expect(jagoParent, isNotNull);
      expect(jagoParent!.isIncludeTotal, isFalse);

      final jagoChildren = appState.getChildrenForAccount('acc-jago');
      expect(jagoChildren.length, 3);

      final totalChildrenBalance = jagoChildren.fold(0, (sum, c) => sum + c.balance);
      expect(jagoParent.balance, totalChildrenBalance);

      // Verify total liquid cash sums only isIncludeTotal accounts
      int expectedCash = 0;
      for (final acc in appState.accounts) {
        if (acc.isIncludeTotal && acc.type != AccountType.investment) {
          expectedCash += acc.balance;
        }
      }
      expect(appState.totalLiquidCash, expectedCash);
    });

    test('Transfer does not count as income or expense', () {
      final initialIncome = appState.monthIncome;
      final initialExpense = appState.monthExpense;

      appState.addTransaction(
        type: TransactionType.transfer,
        amount: 500000,
        accountId: 'acc-bca',
        toAccountId: 'acc-cash',
        categoryName: 'Transfer Antar Akun',
        date: DateTime.now(),
      );

      expect(appState.monthIncome, initialIncome);
      expect(appState.monthExpense, initialExpense);
    });

    test('Shared account uses categories belonging to account owner per PRD 4.4', () {
      // acc-bca is owned by u-1 (Burhan Mafazi)
      final bcaCategories = appState.getCategoriesForAccount('acc-bca', isIncome: false);
      expect(bcaCategories.contains('Makanan & Minuman'), isTrue);

      // acc-mandiri is owned by u-2 (Sarah Mafazi)
      final mandiriCategories = appState.getCategoriesForAccount('acc-mandiri', isIncome: false);
      expect(mandiriCategories.contains('Dapur & Bahan Masak'), isTrue);
      expect(mandiriCategories.contains('Skincare & Perawatan'), isTrue);
    });

    test('Investment buy decreases cash balance and increases holding position per PRD 5.8', () {
      final initialCash = appState.getAccountById('acc-bca')!.balance;
      final btcAsset = appState.investments.firstWhere((inv) => inv.id == 'inv-btc');
      final initialQty = btcAsset.quantity;

      appState.recordInvestmentTrade(
        assetId: 'inv-btc',
        tradeType: InvestmentTradeType.buy,
        quantity: 0.005,
        pricePerUnit: 1000000000,
        fee: 10000,
        cashAccountId: 'acc-bca',
      );

      final updatedBca = appState.getAccountById('acc-bca')!;
      expect(updatedBca.balance, initialCash - (5000000 + 10000));

      final updatedBtc = appState.investments.firstWhere((inv) => inv.id == 'inv-btc');
      expect(updatedBtc.quantity, closeTo(initialQty + 0.005, 0.0001));
    });

    test('Conflict resolution Use Mine enqueues update to server per PRD Section 5', () {
      expect(appState.conflictCount, 1);
      final initialQueueLength = appState.syncQueue.length;

      appState.resolveConflictUseMine('conflict-1');

      expect(appState.conflictCount, 0);
      expect(appState.syncQueue.length, initialQueueLength + 1);
      expect(appState.syncQueue.first.description.contains('Pakai data lokal'), isTrue);
    });
  });
}
