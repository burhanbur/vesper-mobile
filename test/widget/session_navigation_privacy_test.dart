import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/app.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/features/auth/pages/login_page.dart';

void main() {
  testWidgets('identity changes remove previous-user dialogs and routes', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(const VesperApp());
    await tester.pumpAndSettle();
    final state = tester
        .widget<AppStateScope>(find.byType(AppStateScope))
        .notifier!;
    final context = tester.element(find.byType(LoginPage));
    showDialog<void>(
      context: context,
      builder: (_) =>
          const AlertDialog(content: Text('previous user private draft')),
    );
    await tester.pumpAndSettle();
    expect(find.text('previous user private draft'), findsOneWidget);
    state.currentUserId = 'different-user';
    state.setFlowStep(AppFlowStep.auth);
    await tester.pumpAndSettle();
    expect(find.text('previous user private draft'), findsNothing);
    expect(find.byType(LoginPage), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
