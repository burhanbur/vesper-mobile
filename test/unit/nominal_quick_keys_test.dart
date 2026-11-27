import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/core/widgets/nominal_quick_keys.dart';

void main() {
  test('appendNominalZeros formats correctly across all modes and guards edge cases', () {
    final c1 = TextEditingController(text: 'Rp 5');
    appendNominalZeros(c1, '000', mode: NominalFormatMode.rupiahWithPrefix);
    expect(c1.text, 'Rp 5.000');
    appendNominalZeros(c1, '00', mode: NominalFormatMode.rupiahWithPrefix);
    expect(c1.text, 'Rp 500.000');
    c1.dispose();

    final c2 = TextEditingController(text: '25');
    appendNominalZeros(c2, '000', mode: NominalFormatMode.groupedNumber);
    expect(c2.text, '25.000');
    c2.dispose();

    final c3 = TextEditingController(text: '12,5');
    appendNominalZeros(c3, '000', mode: NominalFormatMode.currencyAmountInput);
    expect(c3.text, '12.000,5');
    c3.dispose();

    // Empty / zero input stays unchanged
    final empty = TextEditingController(text: '');
    appendNominalZeros(empty, '000', mode: NominalFormatMode.rupiahWithPrefix);
    expect(empty.text, '');
    empty.dispose();
  });

  testWidgets('NominalQuickKeys buttons append 00 and 000 on tap', (tester) async {
    final controller = TextEditingController(text: 'Rp 15');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              TextField(controller: controller),
              NominalQuickKeys(
                controller: controller,
                mode: NominalFormatMode.rupiahWithPrefix,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('nominal_quick_000')));
    await tester.pump();
    expect(controller.text, 'Rp 15.000');

    await tester.tap(find.byKey(const ValueKey('nominal_quick_00')));
    await tester.pump();
    expect(controller.text, 'Rp 1.500.000');
  });
}
