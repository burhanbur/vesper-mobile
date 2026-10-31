import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/core/widgets/app_toast.dart';

void main() {
  tearDown(() {
    AppToast.dismiss();
  });

  testWidgets('AppToast renders above modal bottom sheet', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showModalBottomSheet<void>(
                  context: context,
                  builder: (sheetCtx) => Container(
                    height: 300,
                    color: Colors.white,
                    child: Center(
                      child: ElevatedButton(
                        onPressed: () {
                          AppToast.showError(
                            sheetCtx,
                            'Terjadi kesalahan sistem!',
                          );
                        },
                        child: const Text('Trigger Error in Sheet'),
                      ),
                    ),
                  ),
                );
              },
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      ),
    );

    // Open sheet
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    // Trigger toast from inside sheet
    await tester.tap(find.text('Trigger Error in Sheet'));
    await tester.pump();

    // Verify toast is visible in root overlay
    expect(find.text('Terjadi kesalahan sistem!'), findsOneWidget);

    // Dismiss toast
    AppToast.dismiss();
    await tester.pump();
    expect(find.text('Terjadi kesalahan sistem!'), findsNothing);
  });

  testWidgets('AppToast auto-dismisses after duration', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                AppToast.showSuccess(
                  context,
                  'Data berhasil disimpan!',
                  duration: const Duration(seconds: 2),
                );
              },
              child: const Text('Show Success'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show Success'));
    await tester.pump();
    expect(find.text('Data berhasil disimpan!'), findsOneWidget);

    // Advance clock past duration
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Data berhasil disimpan!'), findsNothing);
  });
}
