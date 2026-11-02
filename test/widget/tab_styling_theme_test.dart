import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/app/theme/app_colors.dart';
import 'package:vesper_mobile/database/local_store.dart';
import 'package:vesper_mobile/features/asset_allocation/data/asset_allocation_repository.dart';
import 'package:vesper_mobile/features/asset_allocation/pages/asset_allocation_page.dart';
import 'package:vesper_mobile/features/auth/pages/login_page.dart';
import 'package:vesper_mobile/features/cash_flow/pages/cash_flow_page.dart';
import 'package:vesper_mobile/features/categories/pages/categories_page.dart';
import 'package:vesper_mobile/features/household/pages/household_page.dart';
import 'package:vesper_mobile/features/household/widgets/household_unavailable_view.dart';
import 'package:vesper_mobile/features/sync/data/finance_repository.dart';

import '../fixtures/cached_finance.dart';
import '../unit/asset_allocation_test.dart'
    show AllocationClient, allocationFixture, allocationTargets;

void main() {
  testWidgets(
    'LoginPage TabBar uses theme green indicator and white active label',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginPage()));
      await tester.pumpAndSettle();

      final tabBar = tester.widget<TabBar>(find.byType(TabBar));
      final decoration = tabBar.indicator as BoxDecoration;
      expect(decoration.color, AppColors.primary);
      expect(tabBar.labelColor, Colors.white);
      expect(tabBar.unselectedLabelColor, AppColors.textSecondary);
    },
  );

  testWidgets(
    'AssetAllocationPage TabBar uses theme green indicator and white active label',
    (tester) async {
      final store = LocalStore(sqlite3.openInMemory());
      final source = FinanceRepository(AllocationClient(), store, 'owner')
        ..offline = true;
      source.atomic(() {
        source.state['asset_allocation_cache'] = {
          'schema': 1,
          'user_id': 'owner',
          'snapshot': allocationFixture(),
        };
      });
      AssetAllocationRepository(source).saveTargets(allocationTargets());
      final state = AppState(repository: source)..currentUserId = 'owner';
      state.toggleOfflineMode();
      addTearDown(() {
        state.dispose();
        store.close();
      });
      await tester.pumpWidget(
        AppStateScope(
          state: state,
          child: const MaterialApp(home: AssetAllocationPage()),
        ),
      );
      await tester.pumpAndSettle();

      final tabBar = tester.widget<TabBar>(find.byType(TabBar));
      final decoration = tabBar.indicator as BoxDecoration;
      expect(decoration.color, AppColors.primary);
      expect(tabBar.labelColor, Colors.white);
      expect(tabBar.unselectedLabelColor, AppColors.textSecondary);
    },
  );

  testWidgets(
    'CashFlowPage TabBar uses theme green indicator and white active label',
    (tester) async {
      final state = cachedFinanceState()..currentUserId = 'user';
      addTearDown(state.dispose);
      await tester.pumpWidget(
        AppStateScope(
          state: state,
          child: const MaterialApp(home: CashFlowPage()),
        ),
      );
      await tester.pumpAndSettle();

      final tabBar = tester.widget<TabBar>(find.byType(TabBar));
      final decoration = tabBar.indicator as BoxDecoration;
      expect(decoration.color, AppColors.primary);
      expect(tabBar.labelColor, Colors.white);
      expect(tabBar.unselectedLabelColor, AppColors.textSecondary);
    },
  );

  testWidgets(
    'CategoriesPage TabBar uses theme green indicator and white active label',
    (tester) async {
      final state = AppState();
      addTearDown(state.dispose);
      await tester.pumpWidget(
        AppStateScope(
          state: state,
          child: const MaterialApp(home: CategoriesPage()),
        ),
      );
      await tester.pumpAndSettle();

      final tabBar = tester.widget<TabBar>(find.byType(TabBar));
      final decoration = tabBar.indicator as BoxDecoration;
      expect(decoration.color, AppColors.primary);
      expect(tabBar.labelColor, Colors.white);
      expect(tabBar.unselectedLabelColor, AppColors.textSecondary);
    },
  );

  testWidgets(
    'HouseholdUnavailableView TabBar uses theme green indicator and white active label',
    (tester) async {
      final state = cachedFinanceState()..currentUserId = 'user';
      state.repository!.atomic(() {
        state.repository!.entities['groups'] = {
          'group': {'id': 'group', 'name': 'Our group', 'code': 'INVITE123456'},
        };
      });
      addTearDown(state.dispose);
      await tester.pumpWidget(
        AppStateScope(
          state: state,
          child: const MaterialApp(home: HouseholdPage()),
        ),
      );
      await tester.pumpAndSettle();

      // Renders HouseholdUnavailableView TabBar
      expect(find.byType(HouseholdUnavailableView), findsOneWidget);
      final tabBar = tester.widget<TabBar>(find.byType(TabBar));
      final decoration = tabBar.indicator as BoxDecoration;
      expect(decoration.color, AppColors.primary);
      expect(tabBar.labelColor, Colors.white);
      expect(tabBar.unselectedLabelColor, AppColors.textSecondary);
    },
  );
}
