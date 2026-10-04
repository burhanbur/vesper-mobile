import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/app.dart';

void main() {
  testWidgets('Bottom navigation and Quick Action Sheet test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const VesperApp());
    await tester.pumpAndSettle();

    // 1. Verify Home elements
    expect(find.text('Total Kekayaan'), findsOneWidget);
    expect(find.text('Neraca Bulan Berjalan'), findsOneWidget);

    // 2. Tap Transaksi Tab
    await tester.tap(find.text('Transaksi'));
    await tester.pumpAndSettle();
    expect(find.text('Riwayat Transaksi'), findsNothing); // Title is 'Transaksi'
    expect(find.text('Pemasukan'), findsWidgets);
    expect(find.text('Pengeluaran'), findsWidgets);

    // 3. Tap Grup Tab (Highlight Ruang Bersama & Pasangan)
    await tester.tap(find.text('Grup'));
    await tester.pumpAndSettle();
    expect(find.text('Siapa Bayar Apa Bulan Ini'), findsOneWidget);
    expect(find.text('Daftar Anggota Grup'), findsOneWidget);

    // 4. Tap Lainnya Tab
    await tester.tap(find.text('Lainnya'));
    await tester.pumpAndSettle();
    expect(find.text('Lainnya & Pengaturan'), findsOneWidget);
    expect(find.text('Budget & Perencanaan'), findsOneWidget);
    expect(find.text('Kelola Akun & Kantong (Pockets)'), findsOneWidget);

    // 5. Tap Center Action Button (+)
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Aksi Cepat'), findsOneWidget);
    expect(find.text('Catat Pengeluaran'), findsOneWidget);
    expect(find.text('Catat Pemasukan'), findsOneWidget);
    expect(find.text('Transfer Antar Akun / Utang'), findsOneWidget);
  });
}
