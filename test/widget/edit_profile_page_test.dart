import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/features/settings/pages/edit_profile_page.dart';
import 'package:vesper_mobile/features/settings/pages/settings_page.dart';

void main() {
  testWidgets('EditProfilePage renders initial user data and updates name preview', (tester) async {
    final state = AppState();
    state.userName = 'Burhanudin';
    state.userEmail = 'burhan@example.com';
    state.userPhone = '08123456789';

    await tester.pumpWidget(
      AppStateScope(
        state: state,
        child: const MaterialApp(
          home: EditProfilePage(),
        ),
      ),
    );

    expect(find.text('Edit Profil'), findsOneWidget);
    expect(find.text('burhan@example.com'), findsNWidgets(2));
    expect(find.text('Burhanudin'), findsWidgets);
    expect(find.text('08123456789'), findsOneWidget);

    // Enter new name and check preview updates
    await tester.enterText(find.widgetWithText(TextFormField, 'Nama Lengkap'), 'Budi Santoso');
    await tester.pump();
    expect(find.text('Budi Santoso'), findsWidgets);
  });

  testWidgets('SettingsPage pencil icon navigates to EditProfilePage', (tester) async {
    final state = AppState();
    state.userName = 'Burhanudin';
    state.userEmail = 'burhan@example.com';

    await tester.pumpWidget(
      AppStateScope(
        state: state,
        child: const MaterialApp(
          home: SettingsPage(),
        ),
      ),
    );

    final pencilIcon = find.byTooltip('Ubah Profil');
    expect(pencilIcon, findsOneWidget);

    await tester.tap(pencilIcon);
    await tester.pumpAndSettle();

    expect(find.byType(EditProfilePage), findsOneWidget);
    expect(find.text('Edit Profil'), findsOneWidget);
  });
}
