import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/app/theme/app_colors.dart';
import 'package:vesper_mobile/app/theme/app_theme.dart';
import 'package:vesper_mobile/app/widgets/app_lock_gate.dart';
import 'package:vesper_mobile/app/widgets/main_shell.dart';
import 'package:vesper_mobile/core/security/app_lock_controller.dart';
import 'package:vesper_mobile/features/auth/data/auth_repository.dart';
import 'package:vesper_mobile/features/settings/pages/security_page.dart';
import 'package:vesper_mobile/features/transactions/pages/transactions_page.dart';

import '../fixtures/cached_finance.dart';
import '../fixtures/security_fakes.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    theme: AppTheme.lightTheme,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: const TextScaler.linear(2)),
      child: child!,
    ),
    home: child,
  );

  void smallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  test('body and status text colors meet 4.5:1 contrast on their surfaces', () {
    for (final pair in [
      (AppColors.textPrimary, AppColors.background),
      (AppColors.textSecondary, AppColors.surfaceVariant),
      (AppColors.textMuted, AppColors.surfaceVariant),
      (AppColors.income, AppColors.incomeLight),
      (AppColors.expense, AppColors.expenseLight),
      (AppColors.warning, AppColors.warningLight),
      (AppColors.info, AppColors.infoLight),
      (AppColors.accentDark, AppColors.accentLight),
    ]) {
      final a = pair.$1.computeLuminance(), b = pair.$2.computeLuminance();
      final contrast =
          (a > b ? a + 0.05 : b + 0.05) / (a > b ? b + 0.05 : a + 0.05);
      expect(contrast, greaterThanOrEqualTo(4.5), reason: '$pair: $contrast');
    }
  });

  testWidgets(
    'transaction list supports 200% text, named controls and minimum tap targets',
    (tester) async {
      smallScreen(tester);
      final state = cachedFinanceState();
      addTearDown(state.dispose);
      state.repository!.atomic(() {
        state.repository!.entities['transactions'] = {
          'long': {
            'id': 'long',
            'account_id': 'cash',
            'category_id': 'food',
            'type': 'EXPENSE',
            'amount': '9007199254740993.00',
            'transacted_at': DateTime.now().toUtc().toIso8601String(),
            'description':
                'Household shopping with a long readable description',
          },
        };
      });
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        AppStateScope(state: state, child: host(const TransactionsPage())),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Cari transaksi'), findsOneWidget);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await tester.tap(find.byTooltip('Cari transaksi'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'shopping');
      await tester.pumpAndSettle();
      expect(find.byTooltip('Hapus pencarian'), findsOneWidget);
      expect(find.byTooltip('Tutup pencarian'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      semantics.dispose();
    },
  );

  testWidgets('security and lock screens remain usable at 200% text', (
    tester,
  ) async {
    smallScreen(tester);
    final lock = AppLockController(
      storage: MemorySecurityStorage(),
      authenticator: FakeDeviceAuthenticator(),
    );
    await lock.initialize();
    addTearDown(lock.dispose);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      AppLockScope(
        controller: lock,
        child: host(
          SecurityPage(auth: AuthRepository(), onLogout: () async {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await tester.scrollUntilVisible(find.text('Logout perangkat ini'), 200);
    expect(tester.takeException(), isNull);
    await lock.setEnabled(true);
    lock.lock();
    await tester.pumpWidget(
      host(
        AppLockGate(
          controller: lock,
          child: const Scaffold(body: Text('private')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('private'), findsNothing);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    await tester.pumpWidget(const SizedBox());
    semantics.dispose();
  });

  testWidgets(
    'main navigation exposes quick action label and selection at 200% text',
    (tester) async {
      smallScreen(tester);
      final state = cachedFinanceState()..currentUserId = 'user';
      state.toggleOfflineMode();
      addTearDown(state.dispose);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        AppStateScope(state: state, child: host(const MainShell())),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.bySemanticsLabel('Aksi cepat'), findsOneWidget);
      await tester.tap(find.text('Transaksi'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await tester.pumpWidget(const SizedBox());
      semantics.dispose();
    },
  );
}
