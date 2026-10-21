import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../app/theme/app_colors.dart';
import '../data/asset_allocation_repository.dart';
import '../data/asset_allocation_controller.dart';

class AssetAllocationPage extends StatefulWidget {
  const AssetAllocationPage({super.key});
  @override
  State<AssetAllocationPage> createState() => _AssetAllocationPageState();
}

class _AssetAllocationPageState extends State<AssetAllocationPage> {
  AssetAllocationController? controller;
  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppStateScope.of(context), source = state.repository;
    if (source == null ||
        state.currentUserId.isEmpty ||
        state.currentUserId != source.userId) {
      controller?.dispose();
      controller = null;
    } else if (!identical(controller?.repository.source, source)) {
      controller?.dispose();
      controller = AssetAllocationController(
        AssetAllocationRepository(source),
        () =>
            mounted &&
            identical(state.repository, source) &&
            state.currentUserId == source.userId,
      )..addListener(changed);
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  Future<void> configure() async {
    final active = controller!, saved = active.repository.targets;
    final fields = {
      for (final kind in allocationClasses)
        kind: TextEditingController(text: saved?[kind] ?? '0.00'),
    };
    String? error;
    try {
      final route = DialogRoute<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, update) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: Colors.white,
            title: const Text(
              'Target alokasi pribadi',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppColors.textPrimary,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    const Text(
                      'Persen aset positif IDR, total tepat 100%. Disimpan per pengguna di perangkat ini. Target adalah pilihan sendiri, bukan saran transaksi.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    for (final kind in allocationClasses)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TextField(
                          controller: fields[kind],
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: '${allocationLabels[kind]} (%)',
                            labelStyle: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                                width: 1.5,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          error!,
                          style: TextStyle(
                            color: Theme.of(ctx).colorScheme.error,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              if (saved != null)
                TextButton(
                  onPressed: () {
                    if (active.saveTargets(null)) {
                      Navigator.pop(ctx);
                    } else {
                      update(() => error = active.error);
                    }
                  },
                  child: const Text(
                    'Hapus target',
                    style: TextStyle(color: AppColors.expense),
                  ),
                ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  if (active.saveTargets({
                    for (final e in fields.entries) e.key: e.value.text.trim(),
                  })) {
                    Navigator.pop(ctx);
                  } else {
                    update(() => error = active.error);
                  }
                },
                child: const Text('Simpan target'),
              ),
            ],
          ),
        ),
      );
      await Navigator.of(context).push(route);
      await route.completed;
    } finally {
      for (final field in fields.values) {
        field.dispose();
      }
    }
    if (mounted && identical(controller, active)) setState(() {});
  }

  Widget bar(String? percent, bool hidden) {
    if (hidden || percent == null) return const SizedBox.shrink();
    final weight = allocationMinor(percent).toInt();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Row(
          children: [
            if (weight > 0)
              Expanded(
                flex: weight,
                child: Container(
                  height: 8,
                  color: AppColors.primary,
                ),
              ),
            if (weight < 10000)
              Expanded(
                flex: 10000 - weight,
                child: Container(
                  height: 8,
                  color: AppColors.surfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context), active = controller;
    if (active == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Alokasi Aset'),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: const Center(
          child: Text(
            'Masuk untuk membuka alokasi aset.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    final data = active.snapshot,
        repo = active.repository,
        hidden = state.isBalanceHidden;

    String money(dynamic value) {
      if (value == null) return 'Belum tersedia';
      if (hidden) return '••••••';
      final raw = value.toString().trim();
      if (raw.isEmpty) return 'Belum tersedia';

      final isNegative = raw.startsWith('-');
      final clean = isNegative ? raw.substring(1) : raw;
      final parts = clean.split('.');
      final intPart = parts[0];
      final decPart = parts.length > 1 ? parts[1] : null;

      final buffer = StringBuffer();
      for (int i = 0; i < intPart.length; i++) {
        if (i > 0 && (intPart.length - i) % 3 == 0) {
          buffer.write('.');
        }
        buffer.write(intPart[i]);
      }
      final formattedInt = (isNegative ? '-' : '') + buffer.toString();
      if (decPart != null && decPart.isNotEmpty) {
        return '$formattedInt.$decPart IDR';
      }
      return '$formattedInt IDR';
    }

    String percent(dynamic value, [String unit = '%']) => value == null
        ? 'Belum tersedia'
        : hidden
        ? '••••••'
        : '$value$unit';
    final targets = repo.targets;
    final positiveInstruments = data?.rankedInstruments ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Alokasi Aset'),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.accentLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.pie_chart_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Komposisi aset pribadi',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Aset positif IDR pada akun sendiri yang disertakan dalam total. Kas investasi dihitung sebagai kas; induk, akun yang tidak disertakan dan aset non-IDR dikecualikan. Utang tidak mengurangi pembagi alokasi.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                      onPressed: active.loading ? null : active.refresh,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: Text(
                        active.loading ? 'Memuat…' : 'Perbarui dari server',
                      ),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                      onPressed: configure,
                      icon: const Icon(Icons.tune, size: 18),
                      label: const Text('Atur target alokasi'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (active.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.expenseLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.expense.withValues(alpha: 0.3)),
                ),
                child: Text(
                  active.error!,
                  style: const TextStyle(
                    color: AppColors.expense,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          if (repo.source.outbox.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                ),
                child: const Text(
                  'Ada perubahan lokal yang belum tersinkron. Angka server/cache belum mencerminkan perubahan tersebut; tidak ditambah delta lokal.',
                  style: TextStyle(
                    color: AppColors.warning,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          if (repo.source.isSyncing)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Sinkronisasi berjalan. Perbarui penilaian setelah selesai.',
                style: TextStyle(
                  color: AppColors.info,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          if (data == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Belum ada penilaian tersimpan. Perbarui saat online untuk melihat alokasi; target tetap dapat diatur offline.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),

          if (data != null) ...[
            const SizedBox(height: 16),
            // Server Snapshot Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      active.cached || repo.source.offline
                          ? 'Cache snapshot server — dapat usang'
                          : 'Snapshot server — bukan saldo lokal langsung',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tanggal ${data.json['snapshot_date']} UTC; diamati ${data.json['observed_at']}.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    'Status: ${data.complete ? 'valuasi didukung lengkap' : 'parsial; persentase dan deviasi ditahan'}.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: data.complete
                          ? AppColors.income
                          : AppColors.warning,
                    ),
                  ),
                  const Divider(height: 20),
                  Text(
                    'Total aset positif: ${money(data.json['total_assets'])}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Subtotal aset diketahui: ${money(data.json['known_assets'])}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Liabilitas diketahui di luar pembagi: ${money(data.json['excluded_liabilities'])}. Akun non-inklusi/induk dikecualikan: ${data.json['excluded_account_count']}.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Bobot = nilai kelas/instrumen ÷ total aset positif × 100%. Dipotong dua desimal; total tampilan dapat kurang dari 100%. Ini bukan pembagian kekayaan bersih.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      height: 1.3,
                    ),
                  ),
                  if (!data.complete)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'Ada nilai atau klasifikasi yang belum diketahui. Subtotal diketahui tidak dianggap keseluruhan aset; nilai hilang bukan nol.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.warning,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  if ((data.json['warnings'] as List).contains(
                    'stale_prices_provisional',
                  ))
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'Ada harga sebelum hari penilaian. Nilai, konsentrasi dan deviasi masih sementara; periksa tanggal/sumber harga.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.warning,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  if (data.total == BigInt.zero)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'Belum ada aset positif; bobot dan konsentrasi tidak tersedia.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            const Text(
              'Per kelas aset',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            for (final row in data.classes)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.015),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${allocationLabels[row['asset_class']]}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accentLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            percent(row['weight_percent']),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${money(row['market_value'])} • ${percent(row['weight_percent'])}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (row['market_value'] == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Subtotal diketahui: ${money(row['known_amount'])}; ${row['unavailable_count']} komponen belum dinilai.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    bar(row['weight_percent'] as String?, hidden),
                    if (targets?[row['asset_class']] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Target: ${percent(targets![row['asset_class']])}; deviasi: ${percent(repo.deviation(data, row['asset_class'] as String), ' poin persentase')}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Deviasi = bobot tampilan − target. Positif berarti di atas target pilihan sendiri; negatif berarti di bawah.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            const SizedBox(height: 16),
            const Text(
              'Konsentrasi instrumen',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Instrumen yang sama digabung lintas akun. Porsi terhadap seluruh aset positif, termasuk kas dan piutang; bukan hanya portofolio investasi. Tidak ada ambang aman atau eksekusi transaksi otomatis.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            if (data.complete && positiveInstruments.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Instrumen terbesar: ${positiveInstruments.first['code'] ?? positiveInstruments.first['instrument_id']} • ${percent(positiveInstruments.first['weight_percent'])} dari aset positif.',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Gabungan hingga 3 instrumen terbesar: ${percent(data.topThreeWeight)}.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ] else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Peringkat konsentrasi belum tersedia atau belum ada instrumen bernilai positif.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),

            for (final row in data.instruments)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.015),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${row['code'] ?? row['instrument_id']} • ${row['name'] ?? 'Nama belum tersedia'}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${allocationLabels[row['asset_class']]} • ${row['account_count']} akun',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${money(row['market_value'])} • ${percent(row['weight_percent'])}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    if (row['market_value'] == null)
                      Text(
                        'Subtotal diketahui: ${money(row['known_amount'])}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      'Jumlah unit: ${hidden ? '••••••' : row['quantity']}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      'Harga per ${row['price_date'] ?? 'belum tersedia'} • sumber ${row['price_source'] ?? 'belum tersedia'}${row['stale'] == true ? ' • USANG' : ''}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                    for (final reason in row['unavailable_reasons'] as List)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Belum dapat dinilai: ${reason.toString().replaceAll('_', ' ')}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.warning,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],

          if (targets == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Belum ada target. Masukkan persentase pilihan sendiri untuk membandingkan deviasi.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          if (data == null && targets != null) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Target tersimpan; deviasi menunggu penilaian lengkap.',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            for (final e in targets.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '${allocationLabels[e.key]}: ${percent(e.value)}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
