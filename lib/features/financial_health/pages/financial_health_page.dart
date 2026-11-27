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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 16, 12),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.health_and_safety_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Asumsi indikator',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant.withValues(
                                alpha: 0.6,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  size: 15,
                                  color: AppColors.textMuted,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Disimpan hanya di perangkat ini. Tidak mengubah transaksi atau pengaturan Dana Darurat.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textMuted,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
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
                                DropdownMenuItem(
                                  value: m,
                                  child: Text('$m bulan'),
                                ),
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
                            'Rekening kas IDR yang dihitung:',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
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
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: AppColors.border)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Batal'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
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
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
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
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        final current = AppStateScope.of(ctx);
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Tutup',
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded, size: 20),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const Divider(height: 16, color: AppColors.border),
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
        );
      },
    );
  }

  Widget _detailMetricsCard(List<(String, String)> rows) {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              const Divider(height: 14, color: AppColors.borderSubtle),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    rows[i].$1,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    rows[i].$2,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailFormulaBox(String formula) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.functions_rounded,
            size: 16,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              formula,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget detailText(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12.5,
        height: 1.45,
        color: AppColors.textSecondary,
      ),
    ),
  );

  Widget _buildPillarCard({
    required Key key,
    required String title,
    required String valueText,
    required double progressValue,
    required Color barColor,
    required VoidCallback onTap,
    String? subtitle,
  }) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: key,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    valueText,
                    style: TextStyle(
                      fontSize: valueText == 'Belum tersedia' ? 12 : 14,
                      fontWeight: FontWeight.w800,
                      color: valueText == 'Belum tersedia'
                          ? AppColors.textMuted
                          : barColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progressValue.clamp(0.0, 1.0),
                  minHeight: 7,
                  backgroundColor: const Color(0xFFF1F5F9),
                  valueColor: AlwaysStoppedAnimation<Color>(barColor),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  int _calculateHealthScore(HealthAssessment r) {
    var score = 0;
    // 1. Rasio Tabungan (max 25)
    if (r.savingPercent != null) {
      final pct = r.savingPercent!.toDouble() / 100.0;
      if (pct >= 20.0) {
        score += 25;
      } else if (pct > 0) {
        score += (pct / 20.0 * 25).round();
      }
    } else {
      score += 20;
    }

    // 2. Disiplin Anggaran & Likuiditas (max 25)
    if (r.liquidityMonths != null) {
      final lm = r.liquidityMonths!.toDouble() / 100.0;
      if (lm >= 3.0) {
        score += 25;
      } else if (lm > 0) {
        score += (lm / 3.0 * 25).round();
      }
    } else {
      score += 25;
    }

    // 3. Dana Darurat (max 25)
    if (r.emergencyMonths != null) {
      final em = r.emergencyMonths!.toDouble() / 100.0;
      if (em >= 6.0) {
        score += 25;
      } else if (em > 0) {
        score += (em / 6.0 * 25).round();
      }
    } else {
      score += 25;
    }

    // 4. Kesehatan Utang (max 25)
    if (r.debtPercent != null) {
      final dp = r.debtPercent!.toDouble() / 100.0;
      if (dp <= 0.0) {
        score += 25;
      } else if (dp <= 30.0) {
        score += (25 - (dp / 30.0 * 10)).round();
      } else if (dp <= 50.0) {
        score += (15 - ((dp - 30.0) / 20.0 * 15)).round();
      }
    } else {
      score += 25;
    }

    return score.clamp(0, 100);
  }

  String _getStatusLabel(int score) {
    if (score >= 80) return 'SANGAT BAGUS';
    if (score >= 65) return 'BAGUS';
    if (score >= 50) return 'CUKUP';
    return 'PERLU PERHATIAN';
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return const Color(0xFF65A30D);
    if (score >= 65) return AppColors.income;
    if (score >= 50) return AppColors.warning;
    return AppColors.expense;
  }

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
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Indikator Keuangan',
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
            onPressed: () => setState(() => state.toggleHideBalance()),
            icon: Icon(
              state.isBalanceHidden
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
          ),
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          if (error != null) detailText(error),
          if (result case final r?) ...[
            // Period & Ubah Asumsi Header (placed at top)
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${r.months} bulan penuh',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${DateFormatter.formatShort(state.timeZone.at(r.start))} – ${DateFormatter.formatShort(state.timeZone.at(r.end.subtract(const Duration(microseconds: 1))))}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: configure,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                  child: const Text('Ubah asumsi'),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // 1. Circular Score Gauge at Top
            Builder(
              builder: (_) {
                final score = _calculateHealthScore(r);
                final scoreColor = _getScoreColor(score);
                return Column(
                  children: [
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 14),
                        child: SizedBox(
                          width: 156,
                          height: 156,
                          child: CustomPaint(
                            painter: _ScoreGaugePainter(
                              progress: (score / 100.0).clamp(0.0, 1.0),
                              color: scoreColor,
                            ),
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      state.isBalanceHidden ? '•••' : '$score',
                                      style: TextStyle(
                                        fontSize: 44,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -1.5,
                                        color: scoreColor,
                                        height: 1.0,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      '/ 100',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Column(
                        children: [
                          const Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            children: [
                              Icon(
                                Icons.monitor_heart_rounded,
                                color: Color(0xFFEF4444),
                                size: 22,
                              ),
                              Text(
                                'Skor Kesehatan Finansial',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'Ringkasan tabungan, likuiditas kas, dana darurat, dan beban utang.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: scoreColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: scoreColor.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              _getStatusLabel(score),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: scoreColor,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),

            // 3. The 4 Category Progress Bars
            _buildPillarCard(
              key: const ValueKey('health_saving'),
              title: 'Rasio Tabungan',
              valueText: ratio(r.savingPercent, '%'),
              progressValue: (r.savingPercent?.toDouble() ?? 0) / 10000.0,
              barColor: const Color(0xFF84CC16),
              subtitle: 'Porsi pemasukan yang tersisa',
              onTap: () => showDetails('Rasio tabungan', [
                Text(
                  ratio(r.savingPercent, '%'),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 14),
                _detailMetricsCard([
                  ('Pemasukan', money(r.income)),
                  ('Pengeluaran', money(r.expenses)),
                ]),
                _detailFormulaBox(
                  '(Pemasukan − pengeluaran) ÷ pemasukan × 100%',
                ),
                detailText(
                  'Transfer, pokok utang, dan jual/beli investasi tidak masuk hitungan. Bunga dan biaya termasuk pengeluaran.',
                ),
              ]),
            ),
            const SizedBox(height: 10),

            _buildPillarCard(
              key: const ValueKey('health_liquidity'),
              title: 'Likuiditas Kas',
              valueText: ratio(r.liquidityMonths, ' bulan'),
              progressValue: (r.liquidityMonths?.toDouble() ?? 0) / 300.0,
              barColor: const Color(0xFF8B5CF6),
              subtitle: 'Cakupan kas bebas untuk kebutuhan rutin',
              onTap: () => showDetails('Likuiditas kas bebas', [
                Text(
                  ratio(r.liquidityMonths, ' bulan'),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 14),
                _detailMetricsCard([
                  ('Kas bebas saat ini', money(r.freeCash)),
                ]),
                _detailFormulaBox(
                  'Kas bebas ÷ rata-rata bulanan (pengeluaran + pokok utang dibayar)',
                ),
                detailText(
                  'Saldo positif dikurangi alokasi tujuan sekali per akun.',
                ),
              ]),
            ),
            const SizedBox(height: 10),

            _buildPillarCard(
              key: const ValueKey('health_emergency'),
              title: 'Dana Darurat',
              valueText: ratio(r.emergencyMonths, ' bulan'),
              progressValue: r.emergencyMonths != null
                  ? (r.emergencyMonths!.toDouble() / 600.0)
                  : 0.0,
              barColor: const Color(0xFF3B82F6),
              subtitle: r.emergencyMonths != null
                  ? '${ratio(r.emergencyMonths, ' bulan')} per hari ini'
                  : 'Cakupan pengeluaran wajib',
              onTap: () => showDetails('Cakupan dana darurat', [
                Text(
                  ratio(r.emergencyMonths, ' bulan'),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 14),
                _detailMetricsCard([
                  ('Dana likuid', money(r.emergency?.liquid)),
                  ('Kebutuhan bulanan', money(r.emergency?.baseline)),
                  if (r.emergency case final e?)
                    (
                      'Sumber kebutuhan',
                      repo.emergency.plan?['baseline_mode'] == 'MANUAL'
                          ? 'Manual'
                          : '${DateFormatter.formatShort(state.timeZone.at(e.historyStart))} – ${DateFormatter.formatShort(state.timeZone.at(e.historyEnd.subtract(const Duration(microseconds: 1))))}',
                    ),
                ]),
                _detailFormulaBox(
                  'Dana likuid ÷ kebutuhan pengeluaran wajib bulanan',
                ),
                detailText(
                  'Mengikuti pengaturan akun dan kategori di halaman Dana Darurat.',
                ),
              ]),
            ),
            const SizedBox(height: 10),

            _buildPillarCard(
              key: const ValueKey('health_debt'),
              title: 'Kesehatan Utang',
              valueText: ratio(r.debtPercent, '%'),
              progressValue: r.debtPercent == null
                  ? 1.0
                  : (1.0 - (r.debtPercent!.toDouble() / 5000.0)).clamp(
                      0.0,
                      1.0,
                    ),
              barColor: const Color(0xFFF43F5E),
              subtitle: 'Porsi pemasukan untuk cicilan utang',
              onTap: () => showDetails('Beban pembayaran utang', [
                Text(
                  ratio(r.debtPercent, '%'),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 14),
                _detailMetricsCard([
                  ('Pembayaran aktual', money(r.debtService)),
                  ('Pokok dibayar', money(r.debtPrincipal)),
                ]),
                _detailFormulaBox(
                  '(Pokok + bunga + biaya pelunasan aktual) ÷ pemasukan × 100%',
                ),
                detailText(
                  'Hanya menghitung utang dari rekening terpilih; piutang dan koreksi dikecualikan.',
                ),
              ]),
            ),
            const SizedBox(height: 16),

            // 4. Bottom Metric Cards (Dark & Light matching Screenshot 2)
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF18181B),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'YANG DITABUNG',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white70,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            r.income != null && r.expenses != null
                                ? (state.isBalanceHidden
                                      ? '•••••'
                                      : money(r.income! - r.expenses!))
                                : 'Belum ada',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF8CE600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F4F5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'RASIO MENABUNG',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            state.isBalanceHidden
                                ? '•••••'
                                : r.savingPercent != null
                                ? '${(r.savingPercent!.toDouble() / 100.0).toStringAsFixed(1).replaceAll('.', ',')}%'
                                : '0%',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (r.warnings.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
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
            const SizedBox(height: 8),

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

class _ScoreGaugePainter extends CustomPainter {
  final double progress;
  final Color color;

  _ScoreGaugePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 24) / 2;
    const strokeWidth = 14.0;

    // Background circle track
    final bgPaint = Paint()
      ..color = color.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, bgPaint);

    // Foreground progress arc
    if (progress > 0) {
      final fgPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      // Start at top (-90 degrees)
      const startAngle = -3.141592653589793 / 2;
      final sweepAngle = 2 * 3.141592653589793 * progress;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        fgPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ScoreGaugePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
