import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/features/accounts/models/account.dart';
import 'package:vesper_mobile/features/categories/models/category.dart';
import 'package:vesper_mobile/core/network/api_client.dart';

import '../fixtures/cached_finance.dart';

void main() {
  group('Categories & Account Types Unit Tests', () {
    test('Categories come from cached server records, not demo defaults', () {
      final empty = AppState();
      expect(empty.categories, isEmpty);
      empty.dispose();
      final state = cachedFinanceState();
      addTearDown(state.dispose);
      expect(state.expenseCategories.single.name, 'Food');
      expect(state.incomeCategories.single.name, 'Salary');
      expect(state.getCategoriesForAccount('cash', isIncome: false), ['Food']);
    });

    test(
      'Category mutations are durable and pending edits cannot be overwritten',
      () {
        final state = cachedFinanceState()..toggleOfflineMode();
        addTearDown(state.dispose);
        state.addCategory(
          name: 'Streaming',
          type: CategoryType.expense,
          icon: Icons.movie_filter_rounded,
          color: const Color(0xFFE11D48),
        );
        final added = state.getCategoryByName('Streaming')!;
        expect(state.repository!.store.read()['outbox'], hasLength(1));
        expect(
          () => state.updateCategory(id: added.id, name: 'Edited'),
          throwsA(isA<ApiFailure>()),
        );
        state.updateCategory(id: 'food', name: 'Meals');
        expect(state.getCategoryByName('Meals'), isNotNull);
        expect(state.deleteCategory('salary'), isTrue);
        expect(state.getCategoryByName('Salary'), isNull);
        expect(state.repository!.outbox, hasLength(3));
      },
    );

    test(
      'AccountTypeDefinition provides metadata for all AccountType values',
      () {
        for (final type in AccountType.values) {
          final def = AccountTypeDefinition.getDefinition(type);
          expect(def.label.isNotEmpty, isTrue);
          expect(def.description.isNotEmpty, isTrue);
          expect(def.categoryGroup.isNotEmpty, isTrue);
        }

        // Check creditCard type
        final ccDef = AccountTypeDefinition.getDefinition(
          AccountType.creditCard,
        );
        expect(ccDef.label, 'Kartu Kredit / Paylater');
        expect(ccDef.isLiability, isTrue);
        expect(ccDef.isLiquid, isFalse);

        // Check bank type
        final bankDef = AccountTypeDefinition.getDefinition(AccountType.bank);
        expect(bankDef.label, 'Rekening Bank');
        expect(bankDef.isLiquid, isTrue);
      },
    );
  });
}
