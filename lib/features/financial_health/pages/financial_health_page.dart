import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../bills/pages/bills_page.dart';
import '../../emergency_funds/pages/emergency_fund_page.dart';
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
                    labelText: 'Periode evaluasi (bulan penuh)',
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

  void showDetails(String title, List<Widget> children) {
    final state = AppStateScope.of(context);
    final session = state.netWorthSessionKey;
    final hidden = state.isBalanceHidden;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        final current = AppStateScope.of(ctx);
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(ctx).height * .85,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Tutup',
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (current.netWorthSessionKey == session &&
                      current.isBalanceHidden == hidden)
                    ...children
                  else
                    detailText(
                      'Tampilan telah berubah. Buka kembali rincian untuk melanjutkan.',
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget detailText(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        height: 1.5,
        color: AppColors.textSecondary,
      ),
    ),
  );

  Widget metric(
    String id,
    String title,
    String value,
    String subtitle,
    IconData icon,
    String formula,
    List<String> details,
  ) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: AppColors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      key: ValueKey('health_$id'),
      onTap: () => showDetails(title, [
        Text(
          value,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 16),
        detailText(formula),
        for (final detail in details) detailText(detail),
        detailText(
          'Nilai ditampilkan dua desimal tanpa pembulatan naik. Nilai tidak tersedia berarti belum dapat dihitung, bukan nol.',
        ),
      ]),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, size: 19, color: AppColors.accentDark),
                const Spacer(),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.textMuted,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 38),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: value == 'Belum tersedia' ? 18 : 25,
                fontWeight: FontWeight.w700,
                color: value == 'Belum tersedia'
                    ? AppColors.textMuted
                    : AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context), repo = repository;
    if (repo == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Indikator Keuangan')),
        body: const Center(
          child: Text('Masuk untuk membuka indikator keuangan.'),
        ),
      );
    }
    HealthAssessment? result;
    String? error;
    try {
      result = repo.assess(timeZone: state.timeZone);
    } catch (e) {
      error = e.toString();
    }
    String money(BigInt? value) => value == null
        ? 'Belum tersedia'
        : state.isBalanceHidden
        ? '••••••'
        : CurrencyFormatter.formatMinorRupiah(value);
    String ratio(BigInt? value, String unit) => value == null
        ? 'Belum tersedia'
        : state.isBalanceHidden
        ? '••••••'
        : '${healthDecimal(value).replaceAll('.', ',')}$unit';
    void open(Widget page) =>
        Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => page));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Indikator Keuangan'),
        actions: [
          IconButton(
            tooltip: 'Sinkronkan indikator',
            onPressed: state.loading
                ? null
                : () async {
                    await state.refresh();
                    if (mounted) setState(() {});
                  },
            icon: const Icon(Icons.sync_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (error != null) detailText(error),
          if (result case final r?) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${r.months} bulan penuh',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: configure,
                  child: const Text('Ubah asumsi'),
                ),
              ],
            ),
            Text(
              '${DateFormatter.formatShort(state.timeZone.at(r.start))} – ${DateFormatter.formatShort(state.timeZone.at(r.end.subtract(const Duration(microseconds: 1))))}',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Berdasarkan catatan pribadi. Ketuk angka untuk melihat perhitungannya.',
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: AppColors.textMuted,
              ),
            ),
            if (r.warnings.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Material(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    key: const ValueKey('health_notes'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => showDetails('Catatan data', [
                      for (final warning in r.warnings) detailText(warning),
                    ]),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: AppColors.accentDark,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${r.warnings.length} catatan tentang kelengkapan data',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: AppColors.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            LayoutBuilder(
              builder: (context, constraints) {
                final cards = [
                  metric(
                    'saving',
                    'Rasio tabungan',
                    ratio(r.savingPercent, '%'),
                    'Pemasukan yang tersisa.',
                    Icons.savings_outlined,
                    '(Pemasukan − pengeluaran) ÷ pemasukan × 100%.',
                    [
                      'Pemasukan: ${money(r.income)}\nPengeluaran: ${money(r.expenses)}',
                      'Transfer, pokok utang dan jual/beli investasi dikecualikan. Bunga dan biaya termasuk pengeluaran. Rasio ini bukan pertumbuhan aset.',
                    ],
                  ),
                  metric(
                    'debt',
                    'Beban pembayaran utang',
                    ratio(r.debtPercent, '%'),
                    'Pemasukan untuk membayar utang.',
                    Icons.credit_card_outlined,
                    '(Pokok + bunga + biaya pelunasan aktual) ÷ pemasukan × 100%.',
                    [
                      'Pembayaran aktual: ${money(r.debtService)}\nPokok dibayar: ${money(r.debtPrincipal)}',
                      'Hanya utang yang dibayar dari akun terpilih. Piutang dan pembayaran yang dibalik dikecualikan. Nilai dapat melebihi 100%.',
                    ],
                  ),
                  metric(
                    'liquidity',
                    'Likuiditas kas bebas',
                    ratio(r.liquidityMonths, ' bulan'),
                    'Cakupan kebutuhan rutin.',
                    Icons.account_balance_wallet_outlined,
                    'Kas bebas ÷ rata-rata bulanan (pengeluaran + pokok utang dibayar).',
                    [
                      'Kas bebas saat ini: ${money(r.freeCash)}',
                      'Saldo positif dikurangi alokasi tujuan sekali per akun. Rata-rata mencakup bulan tanpa catatan. Ini bukan prediksi saldo bank.',
                    ],
                  ),
                  metric(
                    'emergency',
                    'Cakupan dana darurat',
                    ratio(r.emergencyMonths, ' bulan'),
                    'Cakupan pengeluaran wajib.',
                    Icons.shield_outlined,
                    'Dana likuid ÷ baseline pengeluaran wajib bulanan.',
                    [
                      'Dana likuid: ${money(r.emergency?.liquid)}\nKebutuhan bulanan: ${money(r.emergency?.baseline)}',
                      'Mengikuti akun, kategori dan tujuan terpilih di Dana Darurat, terpisah dari asumsi arus kas halaman ini.',
                      if (r.emergency case final e?)
                        repo.emergency.plan?['baseline_mode'] == 'MANUAL'
                            ? 'Kebutuhan bulanan diisi manual.'
                            : 'Periode baseline: ${DateFormatter.formatShort(e.historyStart)} – ${DateFormatter.formatShort(e.historyEnd.subtract(const Duration(days: 1)))}.',
                    ],
                  ),
                ];
                if (constraints.maxWidth < 350 ||
                    MediaQuery.textScalerOf(context).scale(14) > 19) {
                  return Column(
                    children: [
                      for (final card in cards)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: SizedBox(width: double.infinity, child: card),
                        ),
                    ],
                  );
                }
                return Column(
                  children: [
                    for (var i = 0; i < cards.length; i += 2)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: cards[i]),
                              const SizedBox(width: 12),
                              Expanded(child: cards[i + 1]),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            ListTile(
              key: const ValueKey('health_basis'),
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Dasar perhitungan',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '${r.accountNames.length} akun · ${r.transactionCount} transaksi',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => showDetails('Dasar perhitungan', [
                detailText(
                  'Zona waktu: ${state.timeZone.label}\nDihitung ${DateFormatter.formatFull(r.assessedAt, timeZone: state.timeZone)}',
                ),
                detailText(
                  'Pemasukan tercatat pada ${r.incomeMonths}/${r.months} bulan. Pengeluaran tercatat pada ${r.expenseMonths}/${r.months} bulan.',
                ),
                detailText(
                  repo.assumptions['include_dividends'] == true
                      ? 'Dividen neto termasuk pemasukan.'
                      : 'Dividen tidak termasuk pemasukan.',
                ),
                ExpansionTile(
                  title: Text(
                    'Akun terpilih (${r.accountNames.length})',
                    style: const TextStyle(fontSize: 14),
                  ),
                  children: [
                    for (final name in r.accountNames)
                      ListTile(
                        dense: true,
                        title: Text(name, style: const TextStyle(fontSize: 13)),
                      ),
                  ],
                ),
                detailText(
                  'Saldo kas memakai kondisi saat ini. Dana Darurat tetap mengikuti periode dan asumsi rencananya sendiri.',
                ),
              ]),
            ),
            const Divider(color: AppColors.borderSubtle),
            Wrap(
              spacing: 12,
              children: [
                TextButton.icon(
                  onPressed: () => open(const EmergencyFundPage()),
                  icon: const Icon(Icons.shield_outlined, size: 18),
                  label: const Text('Dana darurat'),
                ),
                TextButton.icon(
                  onPressed: () => open(const BillsPage()),
                  icon: const Icon(Icons.event_note_outlined, size: 18),
                  label: const Text('Tagihan'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
