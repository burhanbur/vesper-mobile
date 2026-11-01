import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../bills/pages/bills_page.dart';
import '../../obligations/pages/obligations_page.dart';
import '../data/cash_flow_controller.dart';
import '../data/cash_flow_repository.dart';

class CashFlowPage extends StatefulWidget {
  const CashFlowPage({super.key});
  @override
  State<CashFlowPage> createState() => _CashFlowPageState();
}

class _CashFlowPageState extends State<CashFlowPage> {
  CashFlowController? controller;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppStateScope.of(context), source = state.repository;
    if (source == null ||
        state.currentUserId.isEmpty ||
        state.currentUserId != source.userId) {
      controller = null;
    } else if (!identical(controller?.repository.source, source)) {
      controller = CashFlowController(
        CashFlowRepository(source),
        () =>
            mounted &&
            identical(state.repository, source) &&
            state.currentUserId == source.userId,
      );
    }
  }

  Future<void> configure() async {
    final active = controller!,
        repo = active.repository,
        config = active.repository.assumptions;
    var count = config['days'] as int,
        offset = config['utc_offset_minutes'] as int;
    var estimates = config['include_estimates'] == true,
        overdue = config['include_overdue'] == true,
        receivables = config['include_receivables'] == true,
        reserves = config['reserve_goals'] == true;
    final ids = (config['account_ids'] as List)
        .cast<String>()
        .where((id) => repo.accounts.any((a) => a['id'] == id))
        .toSet();
    final mappings = Map<String, String>.from(config['debt_accounts'] as Map)
      ..removeWhere(
        (key, value) =>
            !repo.accounts.any((a) => a['id'] == value) ||
            !repo.debts.any((d) => d['id'] == key),
      );
    String? error;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('Asumsi proyeksi'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Disimpan hanya per pengguna/perangkat. Tidak mengubah saldo, jadwal asli, atau memindahkan uang.',
                  ),
                  DropdownButtonFormField<int>(
                    initialValue: count,
                    decoration: const InputDecoration(
                      labelText: 'Horizon termasuk hari ini',
                    ),
                    items: [
                      for (final d in [7, 30, 60, 90])
                        DropdownMenuItem(value: d, child: Text('$d hari')),
                    ],
                    onChanged: (v) => update(() => count = v!),
                  ),
                  DropdownButtonFormField<int>(
                    initialValue: offset,
                    decoration: const InputDecoration(
                      labelText: 'Zona hari proyeksi (tanpa DST)',
                    ),
                    items: [
                      for (final e in {
                        0: 'GMT+00:00',
                        420: 'WIB',
                        480: 'WITA',
                        540: 'WIT',
                      }.entries)
                        DropdownMenuItem(value: e.key, child: Text(e.value)),
                    ],
                    onChanged: (v) => update(() => offset = v!),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Sertakan nominal perkiraan tagihan'),
                    value: estimates,
                    onChanged: (v) => update(() => estimates = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Bawa tunggakan ke hari pertama'),
                    value: overdue,
                    onChanged: (v) => update(() => overdue = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Asumsikan piutang dibayar sesuai jadwal',
                    ),
                    value: receivables,
                    onChanged: (v) => update(() => receivables = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Sisihkan alokasi goal yang terdanai'),
                    value: reserves,
                    onChanged: (v) => update(() => reserves = v),
                  ),
                  const Text('Akun kas IDR untuk skenario ini'),
                  for (final a in repo.accounts)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${a['name']}'),
                      value: ids.contains(a['id']),
                      onChanged: (v) => update(() {
                        if (v == true) {
                          ids.add(a['id'] as String);
                        } else {
                          ids.remove(a['id']);
                        }
                      }),
                    ),
                  const Text(
                    'Akun pembayaran/penerimaan pinjaman tanpa tagihan aktif. Jika sudah ditautkan ke Tagihan & Jadwal, akun pada tagihan dipakai. Pilih akun di luar pilihan skenario bila pembayaran dilakukan dari akun tersebut. Pokok dihitung sekali.',
                  ),
                  for (final debt in repo.debts)
                    DropdownButtonFormField<String>(
                      key: ValueKey(
                        '${debt['id']}:${mappings[debt['id']]}:${ids.join(',')}',
                      ),
                      initialValue: mappings[debt['id']],
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: '${debt['counterparty']} (${debt['kind']})',
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Belum ditetapkan'),
                        ),
                        for (final a in repo.accounts)
                          DropdownMenuItem(
                            value: a['id'] as String,
                            child: Text('${a['name']}'),
                          ),
                      ],
                      onChanged: (v) => update(() {
                        if (v == null) {
                          mappings.remove(debt['id']);
                        } else {
                          mappings['${debt['id']}'] = v;
                        }
                      }),
                    ),
                  if (error != null)
                    Text(
                      error!,
                      style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                final ok = active.save({
                  'days': count,
                  'utc_offset_minutes': offset,
                  'include_estimates': estimates,
                  'include_overdue': overdue,
                  'include_receivables': receivables,
                  'reserve_goals': reserves,
                  'account_ids': ids.toList(),
                  'debt_accounts': mappings,
                });
                if (ok) {
                  Navigator.pop(ctx);
                } else {
                  update(() => error = active.error);
                }
              },
              child: const Text('Simpan asumsi'),
            ),
          ],
        ),
      ),
    );
    if (mounted && identical(controller, active)) setState(() {});
  }

  Future<void> open(Widget page) async {
    await Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => page));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context), active = controller;
    if (active == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: const Text(
            'Proyeksi Arus Kas',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        body: const Center(
          child: Text('Masuk untuk membuka proyeksi arus kas.'),
        ),
      );
    }
    CashFlowForecast? result;
    String? error;
    try {
      result = active.repository.forecast();
    } catch (e) {
      error = e.toString();
    }
    String money(BigInt value) => state.isBalanceHidden
        ? '••••••'
        : CurrencyFormatter.formatMinorRupiah(value);
    final config = active.repository.assumptions;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Proyeksi Arus Kas',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: state.isBalanceHidden
                ? 'Tampilkan saldo'
                : 'Sembunyikan saldo',
            icon: Icon(
              state.isBalanceHidden
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
            onPressed: () => setState(() => state.toggleHideBalance()),
          ),
          IconButton(
            tooltip: 'Sinkronkan',
            icon: const Icon(Icons.sync_rounded),
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
          _buildScenarioHeader(context, config),
          if (error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.expense.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.expense.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.expense,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      error,
                      style: const TextStyle(
                        color: AppColors.expense,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (state.dataError != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.warning,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      state.dataError!,
                      style: const TextStyle(
                        color: AppColors.warning,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (result case final r?) ...[
            const SizedBox(height: 14),
            _buildHeroForecastCard(r, money, state),
            const SizedBox(height: 18),
            _buildAccountsSection(r, money),
            const SizedBox(height: 14),
            _buildTimelineCard(r, money),
            const SizedBox(height: 12),
            _buildCommitmentsCard(r, money),
            if (r.warnings.isNotEmpty) ...[
              const SizedBox(height: 18),
              _buildWarningsSection(r.warnings),
            ],
          ],
          const SizedBox(height: 20),
          _buildActionButtons(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildScenarioHeader(
    BuildContext context,
    Map<String, dynamic> config,
  ) {
    return Container(
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_graph_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Skenario Arus Kas',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Simulasi likuiditas & komitmen mendatang',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildParamChip(
                Icons.timelapse_rounded,
                '${config['days']} Hari',
                AppColors.primary,
              ),
              _buildParamChip(
                Icons.schedule_rounded,
                DateFormatter.fixedZone(config['utc_offset_minutes'] as int),
                AppColors.textSecondary,
              ),
              _buildParamChip(
                Icons.calculate_outlined,
                config['include_estimates'] == true
                    ? 'Perkiraan: Ya'
                    : 'Perkiraan: Tidak',
                config['include_estimates'] == true
                    ? AppColors.income
                    : AppColors.textMuted,
              ),
              _buildParamChip(
                Icons.history_rounded,
                config['include_overdue'] == true
                    ? 'Tunggakan: Bawa'
                    : 'Tunggakan: Abaikan',
                config['include_overdue'] == true
                    ? AppColors.warning
                    : AppColors.textMuted,
              ),
              _buildParamChip(
                Icons.call_received_rounded,
                config['include_receivables'] == true
                    ? 'Piutang: Masuk'
                    : 'Piutang: Tidak',
                AppColors.info,
              ),
              _buildParamChip(
                Icons.flag_outlined,
                config['reserve_goals'] == true
                    ? 'Goal: Sisihkan'
                    : 'Goal: Bebas',
                AppColors.investment,
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: configure,
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: const Text('Ubah asumsi proyeksi'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Material(
            color: Colors.transparent,
            child: Theme(
              data: Theme.of(context)
                  .copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
                title: const Text(
                  'Catatan metodologi skenario',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '• Saldo aktual sebagai pembuka; komitmen berikutnya hanya proyeksi.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '• Pengeluaran dimodelkan mendahului pemasukan di hari yang sama untuk menjaga prinsip kehati-hatian.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '• Alokasi goal dibekukan pada nilai pembuka agar rencana tabungan terlindungi.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '• Pembayaran yang sudah dicatat perlu ditautkan di Tagihan & Jadwal agar tidak dihitung ganda.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParamChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroForecastCard(
    CashFlowForecast r,
    String Function(BigInt) money,
    AppState state,
  ) {
    final totalInflow = r.days.fold(BigInt.zero, (s, d) => s + d.inflow);
    final totalOutflow = r.days.fold(BigInt.zero, (s, d) => s + d.outflow);
    final netFlow = totalInflow - totalOutflow;

    return Container(
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
          // Status Banner at top
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: r.firstShortfall == null
                  ? AppColors.income.withValues(alpha: 0.08)
                  : AppColors.warningLight.withValues(alpha: 0.7),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
              ),
              border: Border(
                bottom: BorderSide(
                  color: r.firstShortfall == null
                      ? AppColors.income.withValues(alpha: 0.2)
                      : AppColors.warning.withValues(alpha: 0.3),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  r.firstShortfall == null
                      ? Icons.check_circle_rounded
                      : Icons.warning_amber_rounded,
                  size: 18,
                  color: r.firstShortfall == null
                      ? AppColors.income
                      : AppColors.warning,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.firstShortfall == null
                            ? 'Likuiditas Terjaga • Bebas Defisit'
                            : 'Potensi kekurangan gabungan pertama',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: r.firstShortfall == null
                              ? AppColors.income
                              : AppColors.warning,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        r.firstShortfall == null
                            ? 'Tidak ada kekurangan gabungan pada komitmen yang dimodelkan.'
                            : '${r.firstShortfall!.date} • ${money(r.firstShortfall!.low)}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: r.firstShortfall == null
                              ? AppColors.textSecondary
                              : AppColors.warning,
                          fontWeight: r.firstShortfall == null
                              ? FontWeight.normal
                              : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main Hero Numbers
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Proyeksi penutup: ${money(r.closing)}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: r.closing < BigInt.zero
                                  ? AppColors.expense
                                  : AppColors.income,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Periode ${r.start} sampai ${r.end}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Titik Terendah',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'Minimum konservatif: ${money(r.minimum)}',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: r.minimum < BigInt.zero
                                  ? AppColors.expense
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 3 Core Metrics Grid
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        Icons.account_balance_wallet_outlined,
                        'Saldo aktual gabungan: ${money(r.actual)}',
                        AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetricTile(
                        Icons.flag_outlined,
                        'Alokasi goal terdanai: ${money(r.reserved)}',
                        AppColors.investment,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetricTile(
                        Icons.savings_outlined,
                        'Kas tersedia pembuka: ${money(r.available)}',
                        AppColors.income,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Inflow vs Outflow Mini-Bar
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(
                              Icons.arrow_downward_rounded,
                              size: 15,
                              color: AppColors.income,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                'Masuk: ${money(totalInflow)}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.income,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(height: 18, width: 1, color: AppColors.border),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(
                              Icons.arrow_upward_rounded,
                              size: 15,
                              color: AppColors.expense,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                'Keluar: ${money(totalOutflow)}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.expense,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(height: 18, width: 1, color: AppColors.border),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              netFlow >= BigInt.zero
                                  ? Icons.trending_up_rounded
                                  : Icons.trending_down_rounded,
                              size: 15,
                              color: netFlow >= BigInt.zero
                                  ? AppColors.income
                                  : AppColors.expense,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                'Net: ${money(netFlow)}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: netFlow >= BigInt.zero
                                      ? AppColors.income
                                      : AppColors.expense,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${r.paidExcluded} kejadian/pokok lunas dan ${r.skippedExcluded} kejadian dilewati tidak ditambahkan kembali.',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Dihitung ${DateFormatter.formatFull(r.assessedAt, timeZone: state.timeZone)}.',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(IconData icon, String fullText, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 6),
          Text(
            fullText,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountsSection(
    CashFlowForecast r,
    String Function(BigInt) money,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.account_balance_wallet_outlined,
              size: 18,
              color: AppColors.primary,
            ),
            const SizedBox(width: 8),
            const Text(
              'Per akun — tanpa transfer otomatis',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${r.accounts.length} Akun',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (final a in r.accounts)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
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
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.account_balance_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        a.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: a.firstShortfall == null
                            ? AppColors.income.withValues(alpha: 0.1)
                            : AppColors.warningLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        a.firstShortfall == null
                            ? 'Aman'
                            : 'Defisit Terdeteksi',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: a.firstShortfall == null
                              ? AppColors.income
                              : AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Aktual: ${money(a.actual)}; tersedia: ${money(a.available)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Penutup: ${money(a.days.last.closing)}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: a.days.last.closing < BigInt.zero
                        ? AppColors.expense
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  a.firstShortfall == null
                      ? 'Tidak ada kekurangan pada skenario akun ini.'
                      : 'Potensi kekurangan ${a.firstShortfall!.date}: ${money(a.firstShortfall!.low)}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: a.firstShortfall == null
                        ? FontWeight.normal
                        : FontWeight.w600,
                    color: a.firstShortfall == null
                        ? AppColors.textMuted
                        : AppColors.warning,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTimelineCard(CashFlowForecast r, String Function(BigInt) money) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.calendar_month_rounded,
            color: AppColors.primary,
            size: 20,
          ),
        ),
        title: const Text(
          'Timeline harian gabungan',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          '${r.days.length} hari proyeksi kas gabungan',
          style: const TextStyle(
            fontSize: 11.5,
            color: AppColors.textSecondary,
          ),
        ),
        children: [
          for (final d in r.days)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: d.low < BigInt.zero
                    ? AppColors.expense.withValues(alpha: 0.04)
                    : AppColors.surfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: d.low < BigInt.zero
                      ? AppColors.expense.withValues(alpha: 0.3)
                      : AppColors.borderSubtle,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          d.date,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (d.inflow > BigInt.zero) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.income.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '+${money(d.inflow)}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.income,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      if (d.outflow > BigInt.zero) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.expense.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '-${money(d.outflow)}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.expense,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Pembuka ${money(d.opening)}\nMasuk ${money(d.inflow)} • keluar ${money(d.outflow)}\nMinimum ${money(d.low)} • penutup ${money(d.closing)}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildCommitmentsCard(
    CashFlowForecast r,
    String Function(BigInt) money,
  ) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.accentDark.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.receipt_long_rounded,
            color: AppColors.accentDark,
            size: 20,
          ),
        ),
        title: Text(
          'Komitmen & asumsi (${r.entries.length})',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: const Text(
          'Jadwal tagihan & kewajiban mendatang',
          style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
        ),
        children: [
          if (r.entries.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Belum ada komitmen dalam horizon ini; pengeluaran yang tidak dijadwalkan belum dimodelkan.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ),
          for (final e in r.entries)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: e.income
                          ? AppColors.income.withValues(alpha: 0.1)
                          : AppColors.expense.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      e.income
                          ? Icons.arrow_downward_rounded
                          : Icons.arrow_upward_rounded,
                      size: 16,
                      color: e.income ? AppColors.income : AppColors.expense,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${e.title} • ${e.income ? 'masuk' : 'keluar'} ${money(e.amount)}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${e.date} • jatuh tempo ${e.dueDate}\n${e.source}${e.assumption ? ' • ASUMSI' : ''}${e.overdue ? ' • TUNGGAKAN' : ''}\nAkun: ${r.accounts.firstWhere((a) => a.id == e.accountId, orElse: () => ForecastAccount(e.accountId, 'Akun', BigInt.zero, BigInt.zero, const [])).name}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildWarningsSection(List<String> warnings) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warningLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: AppColors.warning,
              ),
              SizedBox(width: 8),
              Text(
                'Batas dan kelengkapan data',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final warning in warnings)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(color: AppColors.warning)),
                  Expanded(
                    child: Text(
                      warning,
                      style: const TextStyle(
                        fontSize: 11.5,
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
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => open(const BillsPage()),
            icon: const Icon(Icons.calendar_month_rounded, size: 18),
            label: const Text('Buka Tagihan & Jadwal'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => open(const ObligationsPage()),
            icon: const Icon(Icons.handshake_outlined, size: 18),
            label: const Text('Buka Utang & Piutang'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
