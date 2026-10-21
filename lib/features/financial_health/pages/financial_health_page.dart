import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../bills/pages/bills_page.dart';
import '../../emergency_funds/pages/emergency_fund_page.dart';
import '../../goals/data/goals_repository.dart';
import '../data/financial_health_repository.dart';

class FinancialHealthPage extends StatefulWidget {
  const FinancialHealthPage({super.key});
  @override
  State<FinancialHealthPage> createState() => _FinancialHealthPageState();
}

class _FinancialHealthPageState extends State<FinancialHealthPage> {
  FinancialHealthRepository? repository;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppStateScope.of(context), source = state.repository;
    if (source == null ||
        state.currentUserId.isEmpty ||
        source.userId != state.currentUserId) {
      repository = null;
    } else if (!identical(repository?.source, source)) {
      repository = FinancialHealthRepository(source);
    }
  }

  Future<void> configure() async {
    final repo = repository!, state = AppStateScope.of(context);
    final config = repo.assumptions;
    var months = config['months'] as int,
        dividends = config['include_dividends'] == true;
    final ids = (config['account_ids'] as List)
        .cast<String>()
        .where((id) => repo.accounts.any((a) => a['id'] == id))
        .toSet();
    String? error;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          actionsOverflowButtonSpacing: 8,
          backgroundColor: Colors.white,
          title: const Text(
            'Asumsi indikator',
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
                  'Disimpan hanya pada perangkat dan pengguna ini. Tidak mengubah transaksi atau pengaturan Dana Darurat.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  initialValue: months,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Bulan UTC yang sudah selesai',
                    labelStyle: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  items: [
                    for (final m in [3, 6, 12])
                      DropdownMenuItem(value: m, child: Text('$m bulan')),
                  ],
                  onChanged: (v) => update(() => months = v!),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Sertakan dividen neto sebagai pemasukan',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  value: dividends,
                  onChanged: (v) => update(() => dividends = v),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Akun untuk arus kas dan likuiditas; akun investasi, induk, non-IDR, milik orang lain dan akun pemetaan utang tidak disertakan.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 6),
                for (final a in repo.accounts)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${a['name']}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    value: ids.contains(a['id']),
                    onChanged: (v) => update(() {
                      if (v == true) {
                        ids.add(a['id'] as String);
                      } else {
                        ids.remove(a['id']);
                      }
                    }),
                  ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
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
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                try {
                  if (!mounted ||
                      !identical(repository, repo) ||
                      !identical(state.repository, repo.source) ||
                      state.currentUserId != repo.source.userId) {
                    throw const ApiFailure('Sesi telah berubah.');
                  }
                  repo.saveAssumptions(
                    months: months,
                    includeDividends: dividends,
                    accountIds: ids.toList(),
                  );
                  Navigator.pop(ctx);
                } catch (e) {
                  update(() => error = e.toString());
                }
              },
              child: const Text('Simpan asumsi'),
            ),
          ],
        ),
      ),
    );
    if (mounted && identical(repository, repo)) setState(() {});
  }

  Future<void> open(Widget page) async {
    await Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => page));
    if (mounted) setState(() {});
  }

  Widget indicator(
    String title,
    String value,
    String formula,
    List<String> details,
  ) => Container(
    margin: const EdgeInsets.only(bottom: 14),
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
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: value == 'Belum tersedia'
                ? AppColors.textMuted
                : AppColors.primary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            formula,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (final text in details)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context), repo = repository;
    if (repo == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Indikator Keuangan'),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: const Center(
          child: Text(
            'Masuk untuk membuka indikator keuangan.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    HealthAssessment? result;
    String? error;
    try {
      result = repo.assess();
    } catch (e) {
      error = e.toString();
    }
    String money(BigInt? v) => v == null
        ? 'Belum tersedia'
        : state.isBalanceHidden
        ? '••••••'
        : '${healthDecimal(v)} IDR';
    String ratio(BigInt? v, String unit) => v == null
        ? 'Belum tersedia'
        : state.isBalanceHidden
        ? '••••••'
        : '${healthDecimal(v)}$unit';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Indikator Keuangan'),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        actions: [
          IconButton(
            tooltip: 'Sinkronkan indikator',
            icon: const Icon(Icons.sync),
            onPressed: state.loading
                ? null
                : () async {
                    await state.refresh();
                    if (mounted) setState(() {});
                  },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header Intro Card
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
                        Icons.health_and_safety_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Lihat angka dan dasar perhitungannya',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Ringkasan catatan pribadi, tanpa skor gabungan atau rekomendasi finansial. Nilai tidak tersedia berarti belum dapat dinilai, bukan nol.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  onPressed: configure,
                  icon: const Icon(Icons.tune, size: 18),
                  label: const Text('Ubah asumsi'),
                ),
              ],
            ),
          ),

          if (state.dataError != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                state.dataError!,
                style: const TextStyle(color: AppColors.expense),
              ),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                error,
                style: const TextStyle(color: AppColors.expense),
              ),
            ),

          if (result case final r?) ...[
            const SizedBox(height: 16),
            // Audit Card
            Container(
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Dasar perhitungan & periode',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Periode arus kas: ${goalDay(r.start)} sampai ${goalDay(r.end.subtract(const Duration(days: 1)))} UTC; ${r.months} bulan penuh.',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Snapshot perhitungan: ${r.assessedAt.toIso8601String()}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Akun: ${r.accountNames.isEmpty ? 'Belum dipilih' : r.accountNames.join(', ')}. ${r.transactionCount} transaksi pemasukan/pengeluaran dihitung.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Dividen neto: ${repo.assumptions['include_dividends'] == true ? 'termasuk' : 'tidak termasuk'} pemasukan.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            indicator(
              'Rasio tabungan',
              ratio(r.savingPercent, '%'),
              '(Pemasukan − pengeluaran) ÷ pemasukan × 100%.',
              [
                'Pemasukan: ${money(r.income)}. Pengeluaran: ${money(r.expenses)}.',
                'Surplus arus kas tercatat; transfer, pokok utang dan jual/beli investasi dikecualikan. Bunga/biaya tetap masuk pengeluaran. Bukan ukuran pertumbuhan aset.',
              ],
            ),
            indicator(
              'Beban pembayaran utang',
              ratio(r.debtPercent, '%'),
              '(Pokok + bunga + biaya pelunasan utang aktual) ÷ pemasukan × 100%.',
              [
                'Pembayaran aktual: ${money(r.debtService)}; pokok: ${money(r.debtPrincipal)}.',
                'Hanya utang yang dibayar dari akun terpilih pada periode tersebut. Piutang dan pembayaran yang dibalik dikecualikan. Nilai dapat melebihi 100%.',
              ],
            ),
            indicator(
              'Likuiditas kas bebas',
              ratio(r.liquidityMonths, ' bulan'),
              'Kas bebas saat ini ÷ ((pengeluaran + pokok utang dibayar) ÷ jumlah bulan).',
              [
                'Kas bebas: ${money(r.freeCash)}.',
                'Saldo positif dikurangi alokasi goal sekali per akun. Rata-rata mencakup bulan tanpa catatan. Bukan prediksi saldo atau jaminan dana bank tersedia.',
              ],
            ),
            indicator(
              'Cakupan dana darurat',
              ratio(r.emergencyMonths, ' bulan'),
              'Dana likuid ÷ baseline pengeluaran wajib bulanan (Dana Darurat).',
              [
                'Dana likuid: ${money(r.emergency?.liquid)}. Baseline: ${money(r.emergency?.baseline)}.',
                'Mengikuti akun, kategori dan goal terpilih di Dana Darurat, terpisah dari asumsi arus kas di atas.',
                if (r.emergency case final e?)
                  repo.emergency.plan?['baseline_mode'] == 'MANUAL'
                      ? 'Baseline manual, diisi sendiri; tidak dihitung dari histori transaksi.'
                      : 'Periode baseline estimasi: ${goalDay(e.historyStart)} sampai ${goalDay(e.historyEnd.subtract(const Duration(days: 1)))} UTC.',
              ],
            ),

            const SizedBox(height: 6),
            const Text(
              'Persentase dan bulan ditampilkan dua desimal, dipotong menuju nol tanpa pembulatan naik. Pemasukan nol atau kebutuhan bulanan nol tidak menghasilkan rasio tak terbatas.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
                height: 1.35,
              ),
            ),

            if (r.warnings.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Kelengkapan dan batas data',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final warning in r.warnings)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              size: 16,
                              color: AppColors.warning,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                warning,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],

          const SizedBox(height: 16),
          // Related navigation card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Perencanaan & Jadwal Terkait',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => open(const EmergencyFundPage()),
                  icon: const Icon(Icons.shield_outlined, size: 18),
                  label: const Text('Buka Dana Darurat'),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Tagihan yang belum dibayar dan jadwal cicilan tidak dihitung sebagai pembayaran aktual. Menautkan pembayaran yang sudah dicatat tidak menambah pengeluaran.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => open(const BillsPage()),
                  icon: const Icon(Icons.calendar_month_outlined, size: 18),
                  label: const Text('Buka Tagihan & Jadwal'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
