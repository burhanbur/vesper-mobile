import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../app/theme/app_colors.dart';
import '../data/asset_allocation_repository.dart';
import '../data/asset_allocation_controller.dart';

class AssetAllocationPage extends StatefulWidget {
  const AssetAllocationPage({super.key});
  @override
  State<AssetAllocationPage> createState() => _AssetAllocationPageState();
}

class _AssetAllocationPageState extends State<AssetAllocationPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  AssetAllocationController? controller;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

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
    _tabController.dispose();
    controller?.dispose();
    super.dispose();
  }

  IconData _classIcon(String? assetClass) {
    switch (assetClass) {
      case 'CASH':
        return Icons.account_balance_wallet_outlined;
      case 'STOCK':
        return Icons.trending_up_rounded;
      case 'MUTUAL_FUND':
        return Icons.pie_chart_outline_rounded;
      case 'CRYPTO':
        return Icons.currency_bitcoin_rounded;
      case 'BOND':
        return Icons.account_balance_rounded;
      case 'GOLD':
        return Icons.monetization_on_outlined;
      case 'OTHER':
        return Icons.category_outlined;
      default:
        return Icons.help_outline_rounded;
    }
  }

  Color _classColor(String? assetClass) {
    switch (assetClass) {
      case 'CASH':
        return AppColors.primary;
      case 'STOCK':
        return const Color(0xFF2563EB);
      case 'MUTUAL_FUND':
        return const Color(0xFF7C3AED);
      case 'CRYPTO':
        return const Color(0xFFEA580C);
      case 'BOND':
        return const Color(0xFF0D9488);
      case 'GOLD':
        return const Color(0xFFD97706);
      case 'OTHER':
        return const Color(0xFF64748B);
      default:
        return AppColors.textMuted;
    }
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
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
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

  Widget bar(String? percent, bool hidden, [Color? color]) {
    if (hidden || percent == null) return const SizedBox.shrink();
    final weight = allocationMinor(percent).toInt();
    final activeColor = color ?? AppColors.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Row(
          children: [
            if (weight > 0)
              Expanded(
                flex: weight,
                child: Container(height: 8, color: activeColor),
              ),
            if (weight < 10000)
              Expanded(
                flex: 10000 - weight,
                child: Container(height: 8, color: AppColors.surfaceVariant),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        unselectedLabelColor: AppColors.textSecondary,
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
        tabs: const [
          Tab(text: 'Ringkasan'),
          Tab(text: 'Kelas Aset'),
          Tab(text: 'Instrumen'),
        ],
      ),
    );
  }

  Widget _buildMetricTile(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortfolioHeroCard(
    AllocationSnapshot data,
    AssetAllocationController active,
    AssetAllocationRepository repo,
    AppState state,
    bool hidden,
    String Function(dynamic) money,
  ) {
    final complete = data.complete;
    return Container(
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
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  active.cached || repo.source.offline
                      ? 'Cache snapshot server — dapat usang'
                      : 'Snapshot server — bukan saldo lokal langsung',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: complete
                      ? AppColors.income.withValues(alpha: 0.1)
                      : AppColors.warningLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  complete
                      ? 'Valuasi lengkap'
                      : 'parsial; persentase dan deviasi ditahan',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: complete ? AppColors.income : AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Total Aset Positif',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Total aset positif: ${money(data.json['total_assets'])}',
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tanggal ${DateFormatter.calendarDate(data.json['snapshot_date'])}; diamati ${DateFormatter.timestamp(data.json['observed_at'], timeZone: state.timeZone)}.',
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          const Divider(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  Icons.check_circle_outline_rounded,
                  'Subtotal Aset',
                  money(data.json['known_assets']),
                  AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  Icons.remove_circle_outline_rounded,
                  'Liabilitas Luar',
                  money(data.json['excluded_liabilities']),
                  AppColors.expense,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  Icons.block_outlined,
                  'Akun Dikecualikan',
                  '${data.json['excluded_account_count']}',
                  AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Subtotal aset diketahui: ${money(data.json['known_assets'])}',
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          Text(
            'Liabilitas diketahui di luar pembagi: ${money(data.json['excluded_liabilities'])}. Akun non-inklusi/induk dikecualikan: ${data.json['excluded_account_count']}.',
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiSegmentBar(
    AllocationSnapshot data,
    bool hidden,
    String Function(dynamic, [String]) percent,
  ) {
    if (hidden) {
      return Container(
        height: 12,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(6),
        ),
      );
    }

    final segments = <Widget>[];
    int totalFlex = 0;

    for (final row in data.classes) {
      final weightStr = row['weight_percent'] as String?;
      if (weightStr != null) {
        final weight = allocationMinor(weightStr).toInt();
        if (weight > 0) {
          totalFlex += weight;
          segments.add(
            Expanded(
              flex: weight,
              child: Container(
                height: 12,
                color: _classColor(row['asset_class'] as String?),
              ),
            ),
          );
        }
      }
    }

    if (totalFlex < 10000) {
      segments.add(
        Expanded(
          flex: 10000 - totalFlex,
          child: Container(height: 12, color: AppColors.surfaceVariant),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Row(children: segments),
    );
  }

  Widget _buildDistributionOverviewCard(
    AllocationSnapshot data,
    AssetAllocationRepository repo,
    Map<String, String>? targets,
    bool hidden,
    String Function(dynamic) money,
    String Function(dynamic, [String]) percent,
  ) {
    final activeClasses = data.classes
        .where(
          (c) =>
              c['weight_percent'] != null &&
              allocationMinor(c['weight_percent'] as String) > BigInt.zero,
        )
        .toList();

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
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.donut_large_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Distribusi Kelas Aset',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  _tabController.animateTo(1);
                },
                child: const Text(
                  'Lihat Semua',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildMultiSegmentBar(data, hidden, percent),
          const SizedBox(height: 14),
          if (activeClasses.isEmpty)
            const Text(
              'Belum ada alokasi aset yang terdeteksi.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            )
          else
            Column(
              children: [
                for (final c in activeClasses)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: _classColor(c['asset_class'] as String?),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                allocationLabels[c['asset_class']] ??
                                    (c['asset_class'] as String),
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            Text(
                              percent(c['weight_percent']),
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        if (targets?[c['asset_class']] != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 18, top: 2),
                            child: Text(
                              'deviasi: ${percent(repo.deviation(data, c['asset_class'] as String), ' poin persentase')}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildConcentrationSummaryCard(
    AllocationSnapshot data,
    List<Map<String, dynamic>> positiveInstruments,
    String Function(dynamic, [String]) percent,
  ) {
    final hasConcentration = data.complete && positiveInstruments.isNotEmpty;
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
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.hub_outlined,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Konsentrasi instrumen',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (hasConcentration) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Instrumen terbesar: ${positiveInstruments.first['code'] ?? positiveInstruments.first['instrument_id']} • ${percent(positiveInstruments.first['weight_percent'])} dari aset positif.',
                    style: const TextStyle(
                      fontSize: 12.5,
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
          ] else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'Peringkat konsentrasi belum tersedia atau belum ada instrumen bernilai positif.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(AssetAllocationController active) {
    return Wrap(
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          onPressed: active.loading ? null : active.refresh,
          icon: const Icon(Icons.refresh, size: 18),
          label: Text(active.loading ? 'Memuat…' : 'Perbarui dari server'),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            side: const BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          onPressed: configure,
          icon: const Icon(Icons.tune, size: 18),
          label: const Text('Atur target alokasi'),
        ),
      ],
    );
  }

  Widget _buildMethodologyCard(AllocationSnapshot data) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: AppColors.textSecondary,
              ),
              SizedBox(width: 8),
              Text(
                'Metodologi & Ruang Lingkup',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Aset positif IDR pada akun sendiri yang disertakan dalam total. Kas investasi dihitung sebagai kas; induk, akun yang tidak disertakan dan aset non-IDR dikecualikan. Utang tidak mengurangi pembagi alokasi.',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Bobot = nilai kelas/instrumen ÷ total aset positif × 100%. Dipotong dua desimal; total tampilan dapat kurang dari 100%. Ini bukan pembagian kekayaan bersih.',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
              height: 1.35,
            ),
          ),
          if (!data.complete) ...[
            const SizedBox(height: 6),
            const Text(
              'Ada nilai atau klasifikasi yang belum diketahui. Subtotal diketahui tidak dianggap keseluruhan aset; nilai hilang bukan nol.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.warning,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if ((data.json['warnings'] as List).contains(
                'stale_prices_provisional',
              ) ||
              data.instruments.any((i) => i['stale'] == true)) ...[
            const SizedBox(height: 6),
            const Text(
              'Ada harga sebelum hari penilaian (USANG). Nilai, konsentrasi dan deviasi masih sementara; periksa tanggal/sumber harga.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.warning,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (data.total == BigInt.zero) ...[
            const SizedBox(height: 6),
            const Text(
              'Belum ada aset positif; bobot dan konsentrasi tidak tersedia.',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRingkasanTab(
    AllocationSnapshot data,
    AssetAllocationController active,
    AssetAllocationRepository repo,
    AppState state,
    Map<String, String>? targets,
    List<Map<String, dynamic>> positiveInstruments,
    bool hidden,
    String Function(dynamic) money,
    String Function(dynamic, [String]) percent,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildPortfolioHeroCard(data, active, repo, state, hidden, money),
        const SizedBox(height: 12),
        _buildActionButtons(active),
        const SizedBox(height: 14),
        _buildDistributionOverviewCard(
          data,
          repo,
          targets,
          hidden,
          money,
          percent,
        ),
        const SizedBox(height: 14),
        _buildConcentrationSummaryCard(data, positiveInstruments, percent),
        const SizedBox(height: 16),
        _buildMethodologyCard(data),
      ],
    );
  }

  Widget _buildDeviationBadge(String deviationStr) {
    final devValue = double.tryParse(deviationStr) ?? 0.0;
    final isOver = devValue > 0.001;
    final isUnder = devValue < -0.001;

    final badgeColor = isOver
        ? AppColors.income
        : isUnder
        ? AppColors.warning
        : AppColors.textSecondary;
    final label = isOver
        ? 'Di atas'
        : isUnder
        ? 'Di bawah'
        : 'Sesuai';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: badgeColor,
        ),
      ),
    );
  }

  Widget _buildClassCard(
    Map<String, dynamic> row,
    AllocationSnapshot data,
    AssetAllocationRepository repo,
    Map<String, String>? targets,
    bool hidden,
    String Function(dynamic) money,
    String Function(dynamic, [String]) percent,
  ) {
    final assetClass = row['asset_class'] as String;
    final color = _classColor(assetClass);
    final icon = _classIcon(assetClass);
    final hasTarget = targets?[assetClass] != null;
    final deviation = hasTarget ? repo.deviation(data, assetClass) : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${allocationLabels[assetClass]}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.5,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  percent(row['weight_percent']),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${money(row['market_value'])} • ${percent(row['weight_percent'])}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          if (row['market_value'] == null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Subtotal diketahui: ${money(row['known_amount'])}; ${row['unavailable_count']} komponen belum dinilai.',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          bar(row['weight_percent'] as String?, hidden, color),
          if (hasTarget) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Target: ${percent(targets![assetClass])}; deviasi: ${percent(deviation, ' poin persentase')}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (deviation != null && !hidden) ...[
                    const SizedBox(width: 6),
                    _buildDeviationBadge(deviation),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'Deviasi = bobot tampilan − target. Positif berarti di atas target pilihan sendiri; negatif berarti di bawah.',
              style: TextStyle(fontSize: 10.5, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKelasAsetTab(
    AllocationSnapshot data,
    AssetAllocationRepository repo,
    Map<String, String>? targets,
    bool hidden,
    String Function(dynamic) money,
    String Function(dynamic, [String]) percent,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Per kelas aset',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Bandingkan realisasi aset dengan target pribadi',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
              ),
              onPressed: configure,
              icon: const Icon(Icons.tune, size: 16),
              label: const Text(
                'Atur target alokasi',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (targets == null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: const Text(
              'Belum ada target. Masukkan persentase pilihan sendiri untuk membandingkan deviasi.',
              style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Deviasi = bobot tampilan − target. Positif berarti di atas target pilihan sendiri; negatif berarti di bawah.',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ),
        const SizedBox(height: 12),
        for (final row in data.classes)
          _buildClassCard(row, data, repo, targets, hidden, money, percent),
      ],
    );
  }

  Widget _buildInstrumentCard(
    Map<String, dynamic> row,
    bool hidden,
    String Function(dynamic) money,
    String Function(dynamic, [String]) percent,
  ) {
    final assetClass = row['asset_class'] as String?;
    final color = _classColor(assetClass);
    final isStale = row['stale'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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
                  '${row['code'] ?? row['instrument_id']} • ${row['name'] ?? 'Nama belum tersedia'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (isStale) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warningLight,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Text(
                    'USANG',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  allocationLabels[assetClass] ??
                      assetClass ??
                      'Belum terklasifikasi',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${row['account_count']} akun',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${money(row['market_value'])} • ${percent(row['weight_percent'])}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          if (row['market_value'] == null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Subtotal diketahui: ${money(row['known_amount'])}',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          const SizedBox(height: 6),
          Text(
            'Jumlah unit: ${hidden ? '••••••' : row['quantity']}',
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Harga per ${row['price_date'] ?? 'belum tersedia'} • sumber ${row['price_source'] ?? 'belum tersedia'}${isStale ? ' • USANG' : ''}',
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          if (row['unavailable_reasons'] != null)
            for (final reason in row['unavailable_reasons'] as List)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warningLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Belum dapat dinilai: ${reason.toString().replaceAll('_', ' ')}',
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.warning,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildInstrumenTab(
    AllocationSnapshot data,
    List<Map<String, dynamic>> positiveInstruments,
    bool hidden,
    String Function(dynamic) money,
    String Function(dynamic, [String]) percent,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildConcentrationSummaryCard(data, positiveInstruments, percent),
        const SizedBox(height: 8),
        const Text(
          'Instrumen yang sama digabung lintas akun. Porsi terhadap seluruh aset positif, termasuk kas dan piutang; bukan hanya portofolio investasi. Tidak ada ambang aman atau eksekusi transaksi otomatis.',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textMuted,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const Text(
              'Daftar instrumen',
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
                '${data.instruments.length} Instrumen',
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
        for (final row in data.instruments)
          _buildInstrumentCard(row, hidden, money, percent),
      ],
    );
  }

  Widget _buildEmptyState(
    AssetAllocationController active,
    AssetAllocationRepository repo,
    Map<String, String>? targets,
    bool hidden,
    String Function(dynamic, [String]) percent,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
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
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.pie_chart_outline_rounded,
                  color: AppColors.primary,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Belum Ada Penilaian Tersimpan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Belum ada penilaian tersimpan. Perbarui saat online untuk melihat alokasi; target tetap dapat diatur offline.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 11,
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
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 11,
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
        const SizedBox(height: 16),
        if (targets == null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: const Center(
              child: Text(
                'Belum ada target. Masukkan persentase pilihan sendiri untuk membandingkan deviasi.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        if (targets != null) ...[
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
                  'Target tersimpan; deviasi menunggu penilaian lengkap.',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                for (final e in targets.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          allocationLabels[e.key] ?? e.key,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          percent(e.value),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
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
    );
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
            'Alokasi Aset',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: AppColors.textPrimary,
            ),
          ),
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
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Alokasi Aset',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Atur target alokasi',
            icon: const Icon(Icons.tune_rounded, color: AppColors.textPrimary),
            onPressed: configure,
          ),
          IconButton(
            tooltip: 'Perbarui dari server',
            icon: const Icon(
              Icons.refresh_rounded,
              color: AppColors.textPrimary,
            ),
            onPressed: active.loading ? null : active.refresh,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          if (active.error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.expenseLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.expense.withValues(alpha: 0.3),
                  ),
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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.3),
                  ),
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
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: SizedBox(
                width: double.infinity,
                child: Text(
                  'Sinkronisasi berjalan. Perbarui penilaian setelah selesai.',
                  style: TextStyle(
                    color: AppColors.info,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          if (data == null)
            Expanded(
              child: _buildEmptyState(active, repo, targets, hidden, percent),
            )
          else ...[
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildRingkasanTab(
                    data,
                    active,
                    repo,
                    state,
                    targets,
                    positiveInstruments,
                    hidden,
                    money,
                    percent,
                  ),
                  _buildKelasAsetTab(
                    data,
                    repo,
                    targets,
                    hidden,
                    money,
                    percent,
                  ),
                  _buildInstrumenTab(
                    data,
                    positiveInstruments,
                    hidden,
                    money,
                    percent,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
