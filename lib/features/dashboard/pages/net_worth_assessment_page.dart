import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../app/theme/app_colors.dart';
import '../models/net_worth_assessment.dart';

/// Owner-scoped read assessment, never a replacement for unsynced local balances.
class NetWorthAssessmentPage extends StatefulWidget {
  const NetWorthAssessmentPage({super.key});

  @override
  State<NetWorthAssessmentPage> createState() => _NetWorthAssessmentPageState();
}

class _NetWorthAssessmentPageState extends State<NetWorthAssessmentPage> {
  NetWorthAssessment? _data;
  String? _error;
  bool _loading = false;
  DateTime? _date;
  Object? _session;
  int _request = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = AppStateScope.of(context).netWorthSessionKey;
    if (_session != session) {
      _session = session;
      ++_request;
      _data = null;
      _error = null;
      _loading = false;
      _date = null;
    }
  }

  Future<void> _load() async {
    final state = AppStateScope.of(context);
    final session = state.netWorthSessionKey;
    final request = ++_request;
    bool active() =>
        mounted && request == _request && session == state.netWorthSessionKey;
    setState(() {
      _loading = true;
      _data = null;
      _error = null;
    });
    try {
      final data = await state.fetchNetWorthAssessment(_date);
      if (active()) setState(() => _data = data);
    } catch (_) {
      if (active()) {
        setState(
          () => _error =
              'Penilaian belum tersedia. Periksa koneksi lalu coba lagi.',
        );
      }
    } finally {
      if (active()) setState(() => _loading = false);
    }
  }

  static String _formatMissingComponent(String raw) {
    switch (raw) {
      case 'attribution_unavailable':
        return 'Atribusi kontribusi & pasar';
      case 'obligations_unavailable':
        return 'Data pinjaman';
      case 'holdings_unavailable':
        return 'Valuasi investasi';
      default:
        return raw.replaceAll('_', ' ');
    }
  }

  static String _formatAmount(String? raw) {
    if (raw == null) return 'Belum tersedia';
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 'Belum tersedia';

    final isNegative = trimmed.startsWith('-');
    final clean = isNegative ? trimmed.substring(1) : trimmed;
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
      return '$formattedInt.$decPart';
    }
    return formattedInt;
  }

  static BigInt _parseCents(String? raw) {
    if (raw == null) return BigInt.zero;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return BigInt.zero;
    final isNegative = trimmed.startsWith('-');
    final clean = isNegative ? trimmed.substring(1) : trimmed;
    final parts = clean.split('.');
    final intPart = BigInt.tryParse(parts[0]) ?? BigInt.zero;
    var decPart = BigInt.zero;
    if (parts.length > 1) {
      final decStr = parts[1].padRight(2, '0').substring(0, 2);
      decPart = BigInt.tryParse(decStr) ?? BigInt.zero;
    }
    final total = intPart * BigInt.from(100) + decPart;
    return isNegative ? -total : total;
  }

  static double _calculateRatio(BigInt part, BigInt total) {
    if (total <= BigInt.zero || part <= BigInt.zero) return 0.0;
    if (part >= total) return 1.0;
    final scaled = (part * BigInt.from(10000)) ~/ total;
    return (scaled.toInt() / 10000.0).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final data = _data;
    String money(String key) => state.isBalanceHidden
        ? '••••••'
        : data?.amounts[key] == null
        ? 'Belum tersedia'
        : 'IDR ${_formatAmount(data!.amounts[key])}';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Penilaian kekayaan pribadi',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Info Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Data server milik Anda saja, bukan total household. Perubahan lokal yang belum tersinkron belum tercakup.',
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
            const SizedBox(height: 12),

            // Date Selector & Action Controls Card
            Container(
              padding: const EdgeInsets.all(12),
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            backgroundColor: AppColors.surfaceVariant
                                .withValues(alpha: 0.5),
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _loading
                              ? null
                              : () async {
                                  final session = state.netWorthSessionKey;
                                  final now = DateTime.now().toUtc();
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate:
                                        _date ??
                                        DateTime(now.year, now.month, now.day),
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(
                                      now.year,
                                      now.month,
                                      now.day,
                                    ),
                                  );
                                  if (picked != null &&
                                      mounted &&
                                      session == state.netWorthSessionKey) {
                                    setState(() {
                                      _date = DateTime.utc(
                                        picked.year,
                                        picked.month,
                                        picked.day,
                                      );
                                      _data = null;
                                      _error = null;
                                    });
                                  }
                                },
                          icon: const Icon(
                            Icons.calendar_today_rounded,
                            size: 15,
                            color: AppColors.primary,
                          ),
                          label: Text(
                            _date == null
                                ? 'Tanggal acuan: terbaru'
                                : 'Tanggal acuan: ${_date!.toIso8601String().substring(0, 10)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _loading ? null : _load,
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text(
                          'Muat penilaian',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_date != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: _loading
                              ? null
                              : () => setState(() {
                                  _date = null;
                                  _data = null;
                                  _error = null;
                                }),
                          icon: const Icon(Icons.replay_rounded, size: 13),
                          label: const Text(
                            'Gunakan tanggal terbaru',
                            style: TextStyle(fontSize: 11.5),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 36),
                child: Center(child: CircularProgressIndicator()),
              ),

            if (_error != null)
              Container(
                margin: const EdgeInsets.only(top: 14),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.expenseLight,
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
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error!,
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

            if (data != null) ...[
              if (data.unavailable)
                Container(
                  margin: const EdgeInsets.only(top: 14),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.history_toggle_off_rounded,
                            size: 22,
                            color: AppColors.warning,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Riwayat Belum Tersedia',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Waktu respons: ${DateFormatter.timestamp(data.observedAt, timeZone: AppStateScope.of(context).timeZone)} (bukan bukti historis)',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Histori belum tersedia: bukti saldo historis belum memadai. Tidak ada titik grafik yang direkayasa.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                // Hero Valuation Card with Visual Asset vs Liability Ratio Bar
                _buildHeroValuationCard(context, data, money),

                const SizedBox(height: 14),

                // Visual Donut Chart: Alokasi Komposisi Aset
                _buildDonutAllocationCard(data, money),

                const SizedBox(height: 14),

                // Rincian Komponen Posisi & Progress Bars Card
                _buildPositionDetailsCard(data, money),

                const SizedBox(height: 14),

                // Daftar Kepemilikan (Holdings) Cards
                if (data.holdings.isNotEmpty) ...[
                  _buildHoldingsSection(context, state, data),
                  const SizedBox(height: 14),
                ],

                // Informasi Audit & Observasi Card
                _buildAuditObservationCard(context, data),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeroValuationCard(
    BuildContext context,
    NetWorthAssessment data,
    String Function(String) money,
  ) {
    final totalAssetsCents = _parseCents(data.amounts['known_assets']);
    final liabBalanceCents = _parseCents(
      data.amounts['known_balance_liabilities'],
    );
    final obligCents = _parseCents(data.amounts['obligation_liabilities']);
    final totalLiabCents = liabBalanceCents + obligCents;

    final posAssets = totalAssetsCents > BigInt.zero
        ? totalAssetsCents
        : BigInt.zero;
    final posLiab = totalLiabCents > BigInt.zero ? totalLiabCents : BigInt.zero;
    final combined = posAssets + posLiab;

    final assetRatio = combined > BigInt.zero
        ? _calculateRatio(posAssets, combined)
        : 1.0;
    final liabRatio = combined > BigInt.zero
        ? _calculateRatio(posLiab, combined)
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppColors.primaryGradientStart,
            AppColors.primaryGradientEnd,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.account_balance_rounded,
                    size: 16,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    data.complete
                        ? 'Net Worth Tercatat'
                        : 'Subtotal Teridentifikasi',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: data.complete
                      ? AppColors.accent.withValues(alpha: 0.25)
                      : AppColors.gold.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  data.complete ? 'Lengkap' : 'Parsial',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: data.complete
                        ? AppColors.accentLight
                        : const Color(0xFFFEF08A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            data.complete
                ? 'Net worth tercatat: ${money('net_worth')}'
                : 'Subtotal diketahui: ${money('known_net_worth')}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          if (data.complete) ...[
            const SizedBox(height: 3),
            Text(
              'Subtotal diketahui: ${money('known_net_worth')}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Visual Split Ratio Bar: Aset vs Kewajiban
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        'Aset: ${(assetRatio * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF87171),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        'Kewajiban: ${(liabRatio * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 7,
              child: Row(
                children: [
                  if (assetRatio > 0)
                    Expanded(
                      flex: (assetRatio * 1000).toInt().clamp(1, 1000),
                      child: Container(color: AppColors.accent),
                    ),
                  if (liabRatio > 0)
                    Expanded(
                      flex: (liabRatio * 1000).toInt().clamp(1, 1000),
                      child: Container(color: const Color(0xFFF87171)),
                    ),
                ],
              ),
            ),
          ),

          if (data.amounts['obligation_liabilities'] != null ||
              data.amounts['receivables_value'] != null) ...[
            const Divider(color: Colors.white24, height: 22),
            Row(
              children: [
                if (data.amounts['obligation_liabilities'] != null)
                  Expanded(
                    child: Text(
                      'Sisa utang: ${money('obligation_liabilities')}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFCA5A5),
                      ),
                    ),
                  ),
                if (data.amounts['receivables_value'] != null)
                  Expanded(
                    child: Text(
                      'Sisa piutang: ${money('receivables_value')}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accentLight,
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

  Widget _buildDonutAllocationCard(
    NetWorthAssessment data,
    String Function(String) money,
  ) {
    final cashCents = _parseCents(data.amounts['cash_balance']);
    final invCashCents = _parseCents(data.amounts['investment_cash_balance']);
    final holdingsCents = _parseCents(data.amounts['holdings_value']);
    final recvCents = _parseCents(data.amounts['receivables_value']);

    final totalAssetsCents =
        (cashCents > BigInt.zero ? cashCents : BigInt.zero) +
        (invCashCents > BigInt.zero ? invCashCents : BigInt.zero) +
        (holdingsCents > BigInt.zero ? holdingsCents : BigInt.zero) +
        (recvCents > BigInt.zero ? recvCents : BigInt.zero);

    final segments = <_AllocationSegment>[];
    if (totalAssetsCents > BigInt.zero) {
      if (cashCents > BigInt.zero) {
        segments.add(
          _AllocationSegment(
            label: 'Kas & Tabungan',
            color: const Color(0xFF0D9488),
            percentage: _calculateRatio(cashCents, totalAssetsCents) * 100,
            formattedAmount: money('cash_balance'),
          ),
        );
      }
      if (invCashCents > BigInt.zero) {
        segments.add(
          _AllocationSegment(
            label: 'Kas Investasi',
            color: const Color(0xFF2563EB),
            percentage: _calculateRatio(invCashCents, totalAssetsCents) * 100,
            formattedAmount: money('investment_cash_balance'),
          ),
        );
      }
      if (holdingsCents > BigInt.zero) {
        segments.add(
          _AllocationSegment(
            label: 'Holdings Efek',
            color: const Color(0xFF7C3AED),
            percentage: _calculateRatio(holdingsCents, totalAssetsCents) * 100,
            formattedAmount: money('holdings_value'),
          ),
        );
      }
      if (recvCents > BigInt.zero) {
        segments.add(
          _AllocationSegment(
            label: 'Piutang',
            color: const Color(0xFFD97706),
            percentage: _calculateRatio(recvCents, totalAssetsCents) * 100,
            formattedAmount: money('receivables_value'),
          ),
        );
      }
    }

    return _DonutAllocationWidget(
      segments: segments,
      centerTitle: 'Komposisi Aset',
      centerValue: data.complete ? 'Lengkap' : 'Teridentifikasi',
    );
  }

  Widget _buildPositionDetailsCard(
    NetWorthAssessment data,
    String Function(String) money,
  ) {
    final knownAssetsCents = _parseCents(data.amounts['known_assets']);
    final cashCents = _parseCents(data.amounts['cash_balance']);
    final invCashCents = _parseCents(data.amounts['investment_cash_balance']);
    final holdingsCents = _parseCents(data.amounts['holdings_value']);
    final recvCents = _parseCents(data.amounts['receivables_value']);

    final liabBalanceCents = _parseCents(
      data.amounts['known_balance_liabilities'],
    );
    final obligCents = _parseCents(data.amounts['obligation_liabilities']);
    final totalLiabCents = liabBalanceCents + obligCents;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              const Text(
                'Rincian Posisi & Alokasi',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.incomeLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Aset diketahui: ${money('known_assets')}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.income,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Asset Components with Visual Bars
              _buildComponentBarItem(
                icon: Icons.account_balance_wallet_rounded,
                iconColor: const Color(0xFF0D9488),
                iconBg: const Color(0xFFE6FFFA),
                label: 'Kas: ${money('cash_balance')}',
                description: 'Saldo kas tunai & rekening bank utama',
                ratio: _calculateRatio(cashCents, knownAssetsCents),
              ),
              const SizedBox(height: 10),

              _buildComponentBarItem(
                icon: Icons.swap_horizontal_circle_rounded,
                iconColor: const Color(0xFF2563EB),
                iconBg: const Color(0xFFEFF6FF),
                label:
                    'Kas akun investasi: ${money('investment_cash_balance')}',
                description: 'Kas mengendap pada rekening sekuritas (RDN)',
                ratio: _calculateRatio(invCashCents, knownAssetsCents),
              ),
              const SizedBox(height: 10),

              _buildComponentBarItem(
                icon: Icons.trending_up_rounded,
                iconColor: const Color(0xFF7C3AED),
                iconBg: const Color(0xFFF3E8FF),
                label: 'Nilai holdings: ${money('holdings_value')}',
                description: 'Valuasi pasar instrumen efek & investasi',
                ratio: _calculateRatio(holdingsCents, knownAssetsCents),
              ),

              if (data.amounts['receivables_value'] != null) ...[
                const SizedBox(height: 10),
                _buildComponentBarItem(
                  icon: Icons.call_received_rounded,
                  iconColor: const Color(0xFFD97706),
                  iconBg: const Color(0xFFFEF3C7),
                  label: 'Sisa piutang: ${money('receivables_value')}',
                  description: 'Hak penerimaan dana dari pihak luar',
                  ratio: _calculateRatio(recvCents, knownAssetsCents),
                ),
              ],

              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Liabilities Components
              const Text(
                'Kewajiban & Pengurang Saldo',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),

              _buildComponentBarItem(
                icon: Icons.credit_card_off_rounded,
                iconColor: AppColors.expense,
                iconBg: AppColors.expenseLight,
                label:
                    'Kewajiban saldo negatif: ${money('known_balance_liabilities')}',
                description: 'Cerukan atau saldo negatif pada rekening',
                ratio: _calculateRatio(
                  liabBalanceCents,
                  totalLiabCents > BigInt.zero ? totalLiabCents : BigInt.one,
                ),
              ),

              if (data.amounts['obligation_liabilities'] != null) ...[
                const SizedBox(height: 10),
                _buildComponentBarItem(
                  icon: Icons.money_off_rounded,
                  iconColor: const Color(0xFFEA580C),
                  iconBg: const Color(0xFFFFEDD5),
                  label: 'Sisa utang: ${money('obligation_liabilities')}',
                  description:
                      'Pinjaman & kewajiban cicilan yang masih berjalan',
                  ratio: _calculateRatio(
                    obligCents,
                    totalLiabCents > BigInt.zero ? totalLiabCents : BigInt.one,
                  ),
                ),
              ],

              const SizedBox(height: 12),
              Text(
                data.complete
                    ? 'Harga manual bertanggal tetap digunakan; periksa penanda harga usang.'
                    : 'Subtotal bukan net worth lengkap. Harga lama tetap masuk subtotal; posisi tanpa harga tidak dinilai nol.',
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.textMuted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildComponentBarItem({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String label,
    required String description,
    required double ratio,
  }) {
    final pctText = '${(ratio * 100).toStringAsFixed(1)}%';

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  pctText,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: iconColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: AppColors.border.withValues(alpha: 0.8),
              valueColor: AlwaysStoppedAnimation<Color>(iconColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHoldingsSection(
    BuildContext context,
    AppState state,
    NetWorthAssessment data,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Daftar Kepemilikan (Holdings)',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AppColors.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${data.holdings.length} Instrumen',
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
        for (final row in data.holdings)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppColors.border),
            ),
            color: Colors.white,
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3E8FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.candlestick_chart_rounded,
                              color: Color(0xFF7C3AED),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            row.instrumentId,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        state.isBalanceHidden
                            ? '••••'
                            : row.marketValue != null
                            ? _formatAmount(row.marketValue)
                            : 'Tidak dinilai',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Harga: ${row.priceDate ?? 'belum tersedia'} · ${row.stale == true ? 'USANG' : row.unavailableReason ?? 'tersedia'} · ${row.priceSource ?? 'sumber belum tersedia'}',
                    style: TextStyle(
                      fontSize: 11,
                      color: row.stale == true
                          ? AppColors.expense
                          : AppColors.textMuted,
                      fontWeight: row.stale == true
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAuditObservationCard(
    BuildContext context,
    NetWorthAssessment data,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Informasi Audit & Observasi',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: AppColors.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tanggal penilaian: ${data.snapshotDate}',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                data.unavailable
                    ? 'Waktu respons: ${DateFormatter.timestamp(data.observedAt, timeZone: AppStateScope.of(context).timeZone)} (bukan bukti historis)'
                    : 'Waktu observasi: ${DateFormatter.timestamp(data.observedAt, timeZone: AppStateScope.of(context).timeZone)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
              if (!data.unavailable) ...[
                const SizedBox(height: 3),
                Text(
                  data.isHistoricalObservation
                      ? 'Observasi historis pertama yang tersimpan; bukan saldo akhir hari.'
                      : 'Observasi saldo tercatat saat ini; bukan saldo akhir hari.',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
              const SizedBox(height: 3),
              Text(
                'Komponen belum tersedia: ${data.missingComponents.isEmpty ? 'Tidak ada' : data.missingComponents.map(_formatMissingComponent).join(', ')}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Akun dikecualikan: ${data.excludedAccountCount}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                data.complete
                    ? 'Mencakup aset dan kewajiban yang tercatat. Data yang belum dicatat dan atribusi kontribusi versus perubahan pasar tidak tercakup.'
                    : 'Observasi ini masih parsial. Periksa komponen belum tersedia; observasi lama tidak ditulis ulang setelah penambahan utang/piutang.',
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.textMuted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AllocationSegment {
  final String label;
  final Color color;
  final double percentage;
  final String formattedAmount;

  const _AllocationSegment({
    required this.label,
    required this.color,
    required this.percentage,
    required this.formattedAmount,
  });
}

class _DonutAllocationWidget extends StatefulWidget {
  final List<_AllocationSegment> segments;
  final String centerTitle;
  final String centerValue;

  const _DonutAllocationWidget({
    required this.segments,
    required this.centerTitle,
    required this.centerValue,
  });

  @override
  State<_DonutAllocationWidget> createState() => _DonutAllocationWidgetState();
}

class _DonutAllocationWidgetState extends State<_DonutAllocationWidget> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final sections = <PieChartSectionData>[];
    if (widget.segments.isEmpty) {
      sections.add(
        PieChartSectionData(
          value: 100,
          color: AppColors.border,
          radius: 30,
          showTitle: false,
        ),
      );
    } else {
      for (var i = 0; i < widget.segments.length; i++) {
        final seg = widget.segments[i];
        final isTouched = i == _touchedIndex;
        sections.add(
          PieChartSectionData(
            value: seg.percentage.clamp(0.01, 100.0),
            color: seg.color,
            radius: isTouched ? 38 : 30,
            showTitle: false,
          ),
        );
      }
    }

    final activeSegment =
        _touchedIndex >= 0 && _touchedIndex < widget.segments.length
        ? widget.segments[_touchedIndex]
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Alokasi Komposisi Aset',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 180,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sections: sections,
                        centerSpaceRadius: 52,
                        sectionsSpace: 3,
                        pieTouchData: PieTouchData(
                          touchCallback: (event, response) {
                            setState(() {
                              if (!event.isInterestedForInteractions ||
                                  response == null ||
                                  response.touchedSection == null) {
                                _touchedIndex = -1;
                                return;
                              }
                              _touchedIndex =
                                  response.touchedSection!.touchedSectionIndex;
                            });
                          },
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 60),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            activeSegment?.label ?? widget.centerTitle,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            activeSegment != null
                                ? '${activeSegment.percentage.toStringAsFixed(1)}%'
                                : widget.centerValue,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  for (var i = 0; i < widget.segments.length; i++)
                    _buildLegendPill(
                      widget.segments[i],
                      isSelected: i == _touchedIndex,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendPill(_AllocationSegment seg, {required bool isSelected}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? seg.color.withValues(alpha: 0.15)
            : AppColors.surfaceVariant.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected
              ? seg.color
              : AppColors.border.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: seg.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            '${seg.label} (${seg.percentage.toStringAsFixed(1)}%)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? seg.color : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
