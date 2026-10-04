import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/features/accounts/models/account.dart';
import 'package:vesper_mobile/features/categories/models/category.dart';

void main() {
  group('Categories & Account Types Unit Tests', () {
    test('Initial categories are properly loaded into AppState', () {
      final state = AppState();
      expect(state.categories.isNotEmpty, isTrue);
      expect(state.expenseCategories.isNotEmpty, isTrue);
      expect(state.incomeCategories.isNotEmpty, isTrue);

      // Verify specific default categories
      final foodCat = state.getCategoryByName('Makanan & Minuman');
      expect(foodCat, isNotNull);
      expect(foodCat!.type, CategoryType.expense);
      expect(foodCat.isDefault, isTrue);

      final salaryCat = state.getCategoryByName('Gaji Pokok');
      expect(salaryCat, isNotNull);
      expect(salaryCat!.type, CategoryType.income);
      expect(salaryCat.isDefault, isTrue);
    });

    test('Add, update, and delete custom category in AppState', () {
      final state = AppState();
      final initialCount = state.categories.length;

      // 1. Add custom category
      state.addCategory(
        name: 'Langganan Netflix & Spotify',
        type: CategoryType.expense,
        icon: Icons.movie_filter_rounded,
        color: const Color(0xFFE11D48),
      );

      expect(state.categories.length, initialCount + 1);
      final added = state.getCategoryByName('Langganan Netflix & Spotify');
      expect(added, isNotNull);
      expect(added!.isDefault, isFalse);

      // Verify it syncs with owner categories for account
      final accCategories = state.getCategoriesForAccount('acc-bca', isIncome: false);
      expect(accCategories.contains('Langganan Netflix & Spotify'), isTrue);

      // 2. Update category
      state.updateCategory(
        id: added.id,
        name: 'Langganan Streaming Hiburan',
        color: const Color(0xFF7C3AED),
      );

      final updated = state.getCategoryByName('Langganan Streaming Hiburan');
      expect(updated, isNotNull);
      expect(updated!.color, const Color(0xFF7C3AED));

      // 3. Delete custom category
      final deleted = state.deleteCategory(added.id);
      expect(deleted, isTrue);
      expect(state.getCategoryByName('Langganan Streaming Hiburan'), isNull);

      // 4. Default categories cannot be deleted
      final defaultCat = state.getCategoryByName('Makanan & Minuman');
      expect(defaultCat, isNotNull);
      final deleteDefaultResult = state.deleteCategory(defaultCat!.id);
      expect(deleteDefaultResult, isFalse);
      expect(state.getCategoryByName('Makanan & Minuman'), isNotNull);
    });

    test('AccountTypeDefinition provides metadata for all AccountType values', () {
      for (final type in AccountType.values) {
        final def = AccountTypeDefinition.getDefinition(type);
        expect(def.label.isNotEmpty, isTrue);
        expect(def.description.isNotEmpty, isTrue);
        expect(def.categoryGroup.isNotEmpty, isTrue);
      }

      // Check creditCard type
      final ccDef = AccountTypeDefinition.getDefinition(AccountType.creditCard);
      expect(ccDef.label, 'Kartu Kredit / Paylater');
      expect(ccDef.isLiability, isTrue);
      expect(ccDef.isLiquid, isFalse);

      // Check bank type
      final bankDef = AccountTypeDefinition.getDefinition(AccountType.bank);
      expect(bankDef.label, 'Rekening Bank');
      expect(bankDef.isLiquid, isTrue);
    });
  });
}
