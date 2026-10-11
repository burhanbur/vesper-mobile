import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/features/categories/pages/categories_page.dart';

void main() {
  testWidgets('category tabs use equal-width inset indicators and switch', (
    tester,
  ) async {
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
    expect(tabBar.isScrollable, isFalse);
    expect(tabBar.indicatorSize, TabBarIndicatorSize.tab);
    expect(tabBar.padding, const EdgeInsets.all(4));
    expect(tabBar.indicatorPadding, EdgeInsets.zero);
    expect(tabBar.tabs, hasLength(2));
    await tester.tap(find.textContaining('Pemasukan'));
    await tester.pumpAndSettle();
    expect(tabBar.controller!.index, 1);
    expect(tester.takeException(), isNull);
  });
}
