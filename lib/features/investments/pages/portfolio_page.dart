import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../data/portfolio_controller.dart';
import '../data/portfolio_repository.dart';
import 'investment_lifecycle_page.dart';

class PortfolioPage extends StatefulWidget {
  const PortfolioPage({super.key});
  @override
  State<PortfolioPage> createState() => _PortfolioPageState();
}

class _PortfolioPageState extends State<PortfolioPage> {
  static const List<Color> _allocationPalette = [
    Color(0xFF10B981),
    Color(0xFF8B5CF6),
    Color(0xFF3B82F6),
    Color(0xFFF59E0B),
    Color(0xFF06B6D4),
    Color(0xFFEC4899),
  ];

  PortfolioController? _controller;
  String? _scopeKey;
  bool? _offline;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppStateScope.of(context);
    final source = state.repository;
    final userId = state.currentUserId;
    final valid =
        source != null && userId.isNotEmpty && source.userId == userId;
    if (!valid || !identical(_controller?.repository.source, source)) {
      _controller?.dispose();
      _controller = valid
          ? PortfolioController(
              PortfolioRepository(source),
              () =>
                  identical(state.repository, source) &&
                  state.currentUserId == userId,
            )
          : null;
      _scopeKey = null;
    }
    final controller = _controller;
    if (controller == null) return;
    final accounts = controller.repository.accounts;
    final id = accounts.any((a) => a.id == controller.accountId)
        ? controller.accountId
        : accounts.firstOrNull?.id;
    final key = '$userId:${accounts.map((a) => a.id).join(',')}:$id';
    if (_scopeKey != key || _offline != state.isOfflineMode) {
      _scopeKey = key;
      _offline = state.isOfflineMode;
      unawaited(controller.select(id, controller.date));
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _chooseDate(PortfolioController controller) async {
    final now = DateTime.now().toUtc();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(controller.date ?? '') ?? now,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (!mounted || picked == null || !identical(_controller, controller)) {
      return;
    }
    final date =
        '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    await controller.select(controller.accountId, date);
  }

  void _manageInvestments({int initialTab = 0}) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => InvestmentLifecyclePage(initialTab: initialTab),
      ),
    );
  }

  static (BigInt, int) _parseExactDecimal(String? raw) {
    if (raw == null || raw.trim().isEmpty) return (BigInt.zero, 0);
    final clean = raw.trim();
    final negative = clean.startsWith('-');
    final unsigned = negative ? clean.substring(1) : clean;
    final parts = unsigned.split('.');
    final whole = parts[0];
    final frac = parts.length > 1 ? parts[1] : '';
    final digits = BigInt.tryParse('$whole$frac') ?? BigInt.zero;
    return (negative ? -digits : digits, frac.length);
  }

  static BigInt _parseMinor(String? decimalStr) {
    if (decimalStr == null || decimalStr.trim().isEmpty) return BigInt.zero;
    final (digits, scale) = _parseExactDecimal(decimalStr);
    if (scale == 2) return digits;
    if (scale < 2) return digits * BigInt.from(10).pow(2 - scale);
    final denom = BigInt.from(10).pow(scale - 2);
    final half = denom ~/ BigInt.two;
    return digits.isNegative
        ? (digits - half) ~/ denom
        : (digits + half) ~/ denom;
  }

  static BigInt _multiplyToMinor(String qtyStr, String priceStr) {
    final (qInt, qScale) = _parseExactDecimal(qtyStr);
    final (pInt, pScale) = _parseExactDecimal(priceStr);
    final numerator = qInt * pInt * BigInt.from(100);
    final totalScale = qScale + pScale;
    if (totalScale == 0) return numerator;
    final denom = BigInt.from(10).pow(totalScale);
    final half = denom ~/ BigInt.two;
    return numerator.isNegative
        ? (numerator - half) ~/ denom
        : (numerator + half) ~/ denom;
  }

  /// Lossless formatting of arbitrary-precision decimal strings (no floating point).
  static String _formatLosslessDecimal(String raw) {
    final clean = raw.trim();
    final match = RegExp(r'^(-)?(\d+)(?:\.(\d+))?$').firstMatch(clean);
    if (match == null) return clean;

    final negative = match.group(1) != null;
    final intPart = (BigInt.tryParse(match.group(2)!) ?? BigInt.zero)
        .toString();
    final groupedInt = intPart.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]}.',
    );
    final rawFrac = match.group(3) ?? '';
    final trimmedFrac = rawFrac.replaceFirst(RegExp(r'0+$'), '');
    final isZero = intPart == '0' && trimmedFrac.isEmpty;
    final sign = negative && !isZero ? '-' : '';
    return trimmedFrac.isEmpty
        ? '$sign$groupedInt'
        : '$sign$groupedInt,$trimmedFrac';
  }

  static String _formatLosslessRupiah(String raw) {
    final formatted = _formatLosslessDecimal(raw);
    if (formatted.startsWith('-')) {
      return '-Rp ${formatted.substring(1)}';
    }
    return 'Rp $formatted';
  }

  static String _formatSignedMinorRupiah(BigInt minor) {
    if (minor > BigInt.zero) {
      return '+${CurrencyFormatter.formatMinorRupiah(minor)}';
    }
    return CurrencyFormatter.formatMinorRupiah(minor);
  }

  /// Exact percentage string with 1 decimal place using BigInt arithmetic.
  static String? _formatPercent(
    BigInt numerator,
    BigInt denominator, {
    bool signed = false,
  }) {
    if (denominator <= BigInt.zero) return null;
    final scaled = (numerator.abs() * BigInt.from(1000)) ~/ denominator;
    final whole = scaled ~/ BigInt.from(10);
    final tenth = scaled % BigInt.from(10);
    final prefix = numerator.isNegative
        ? '-'
        : (signed && numerator > BigInt.zero ? '+' : '');
    return tenth == BigInt.zero ? '$prefix$whole%' : '$prefix$whole,$tenth%';
  }

  Widget _buildEmptyPortfolio({bool noAccounts = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.accentLight.withValues(alpha: 0.7),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.pie_chart_outline_rounded,
              size: 38,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            noAccounts
                ? 'Siapkan Portofolio Investasi Anda'
                : 'Belum ada posisi investasi',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            noAccounts
                ? 'Belum ada akun investasi milik Anda. Buat akun bertipe Investasi terlebih dahulu, lalu catat pembelian aset untuk memantau nilai & untung/rugi portofolio di sini.'
                : 'Akun ini belum memiliki posisi aset pada periode ini. Catat transaksi beli atau tambahkan instrumen melalui menu Kelola investasi.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
          if (noAccounts) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: const Column(
                children: [
                  _SetupStepRow(
                    step: '1',
                    text: 'Buat akun bertipe Investasi (mis. Bibit, Stockbit)',
                  ),
                  SizedBox(height: 8),
                  _SetupStepRow(
                    step: '2',
                    text: 'Tambahkan instrumen & catat transaksi Beli / Jual',
                  ),
                  SizedBox(height: 8),
                  _SetupStepRow(
                    step: '3',
                    text: 'Pantau holdings, komposisi & valuasi di halaman ini',
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _manageInvestments,
            icon: const Icon(Icons.tune_rounded, size: 17),
            label: const Text(
              'Kelola investasi',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSummary({
    required PortfolioAccount? account,
    required PortfolioRead? read,
    required String? snapshotDate,
    required bool hidden,
  }) {
    final isSnapshot = snapshotDate != null;
    final positions = read?.positions ?? const <PortfolioPosition>[];
    var totalCostBasis = BigInt.zero;
    var totalMarketValue = BigInt.zero;
    var totalUnrealizedPl = BigInt.zero;
    var pricedCount = 0;
    var hasPlCount = 0;

    for (final pos in positions) {
      totalCostBasis += _multiplyToMinor(pos.quantity, pos.average);
      if (pos.marketValue != null) {
        totalMarketValue += _parseMinor(pos.marketValue);
        pricedCount++;
      }
      if (pos.unrealizedPl != null) {
        totalUnrealizedPl += _parseMinor(pos.unrealizedPl);
        hasPlCount++;
      }
    }

    final hasMarketVal = isSnapshot && pricedCount > 0;
    final hasPl = isSnapshot && hasPlCount > 0;
    final isPlPositive = totalUnrealizedPl >= BigInt.zero;
    final plPercent = hasPl
        ? _formatPercent(totalUnrealizedPl, totalCostBasis, signed: true)
        : null;

    final String headlineLabel;
    final String headlineValue;
    if (hasMarketVal) {
      headlineLabel = 'ESTIMASI NILAI PASAR';
      headlineValue = hidden
          ? '••••••'
          : CurrencyFormatter.formatMinorRupiah(totalMarketValue);
    } else if (positions.isNotEmpty) {
      headlineLabel = isSnapshot
          ? 'TOTAL MODAL (HARGA PASAR BELUM TERSEDIA)'
          : 'TOTAL MODAL DIINVESTASIKAN';
      headlineValue = hidden
          ? '••••••'
          : CurrencyFormatter.formatMinorRupiah(totalCostBasis);
    } else {
      headlineLabel = 'SALDO AKUN INVESTASI';
      headlineValue = hidden
          ? '••••••'
          : (account?.balance != null
                ? CurrencyFormatter.formatCurrency(
                    account!.balance,
                    currency: account.currency,
                  )
                : 'Rp 0');
    }

    final accountTitle = account == null
        ? 'Akun Investasi'
        : account.parentName != null
        ? '${account.parentName} › ${account.name}'
        : account.name;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F3E33),
            Color(0xFF1B5E4B),
            Color(0xFF0D9488),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.24),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_balance_wallet_rounded,
                size: 14,
                color: AppColors.accentLight,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  accountTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isSnapshot
                      ? const Color(0xFFF59E0B).withValues(alpha: 0.28)
                      : Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSnapshot
                        ? const Color(0xFFFDE68A).withValues(alpha: 0.4)
                        : Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  isSnapshot ? 'SNAPSHOT' : 'HOLDINGS AKTIF',
                  style: TextStyle(
                    color: isSnapshot ? const Color(0xFFFDE68A) : Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            headlineLabel,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              headlineValue,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _HeroStatColumn(
                    dotColor: const Color(0xFF10B981),
                    label: isSnapshot ? 'Total Modal' : 'Aset Dipegang',
                    value: isSnapshot
                        ? (hidden
                              ? '••••••'
                              : CurrencyFormatter.formatMinorRupiah(
                                  totalCostBasis,
                                ))
                        : '${positions.length} Instrumen',
                  ),
                ),
                Container(
                  width: 1,
                  height: 28,
                  color: Colors.white.withValues(alpha: 0.18),
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                ),
                Expanded(
                  child: isSnapshot
                      ? _HeroStatColumn(
                          dotColor: hasPl
                              ? (isPlPositive
                                    ? const Color(0xFF34D399)
                                    : const Color(0xFFF87171))
                              : const Color(0xFFFDE68A),
                          label: 'Laba / Rugi',
                          value: !hasPl
                              ? 'Belum tersedia'
                              : hidden
                              ? '••••••'
                              : plPercent != null
                              ? '${_formatSignedMinorRupiah(totalUnrealizedPl)} ($plPercent)'
                              : _formatSignedMinorRupiah(totalUnrealizedPl),
                          valueColor: hasPl
                              ? (isPlPositive
                                    ? const Color(0xFF34D399)
                                    : const Color(0xFFF87171))
                              : Colors.white70,
                        )
                      : _HeroStatColumn(
                          dotColor: const Color(0xFFA78BFA),
                          label: 'Saldo Akun',
                          value: hidden
                              ? '••••••'
                              : (account?.balance != null
                                    ? CurrencyFormatter.formatCurrency(
                                        account!.balance,
                                        currency: account.currency,
                                      )
                                    : '—'),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _QuickActionTile(
            icon: Icons.swap_vert_rounded,
            title: 'Transaksi',
            subtitle: 'Beli / Jual',
            onTap: () => _manageInvestments(initialTab: 0),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickActionTile(
            icon: Icons.show_chart_rounded,
            title: 'Instrumen',
            subtitle: 'Aset & Harga',
            onTap: () => _manageInvestments(initialTab: 2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickActionTile(
            icon: Icons.history_rounded,
            title: 'Riwayat',
            subtitle: 'Mutasi',
            onTap: () => _manageInvestments(initialTab: 3),
          ),
        ),
      ],
    );
  }

  Widget _buildAllocationCard(
    List<PortfolioPosition> positions, {
    required bool isSnapshot,
    required bool hidden,
  }) {
    final weights = <({PortfolioPosition pos, BigInt value, Color color})>[];
    var total = BigInt.zero;
    for (var i = 0; i < positions.length; i++) {
      final pos = positions[i];
      final rawVal = isSnapshot && pos.marketValue != null
          ? _parseMinor(pos.marketValue)
          : _multiplyToMinor(pos.quantity, pos.average);
      final value = rawVal > BigInt.zero ? rawVal : BigInt.zero;
      total += value;
      weights.add((
        pos: pos,
        value: value,
        color: _allocationPalette[i % _allocationPalette.length],
      ));
    }
    if (total <= BigInt.zero) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Komposisi Aset',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                isSnapshot ? 'Berdasarkan nilai pasar' : 'Berdasarkan modal',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 9,
              child: Row(
                children: [
                  for (final item in weights)
                    if (item.value > BigInt.zero)
                      Expanded(
                        flex: ((item.value * BigInt.from(1000)) ~/ total)
                            .toInt()
                            .clamp(1, 1000),
                        child: Container(color: item.color),
                      ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              for (final item in weights)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: item.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${item.pos.code} ${hidden ? '••%' : (_formatPercent(item.value, total) ?? '0%')}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPositionCard({
    required PortfolioPosition position,
    required Color accentColor,
    required BigInt totalAccountValue,
    required bool isSnapshot,
    required bool hidden,
  }) {
    final costBasis = _multiplyToMinor(position.quantity, position.average);
    final marketValMinor = position.marketValue != null
        ? _parseMinor(position.marketValue)
        : null;
    final unrealizedMinor = position.unrealizedPl != null
        ? _parseMinor(position.unrealizedPl)
        : null;
    final basisForWeight = isSnapshot && marketValMinor != null
        ? marketValMinor
        : costBasis;
    final weightLabel = totalAccountValue > BigInt.zero
        ? _formatPercent(basisForWeight, totalAccountValue)
        : null;
    final plPercent = unrealizedMinor != null
        ? _formatPercent(unrealizedMinor, costBasis, signed: true)
        : null;
    final isPlPositive = (unrealizedMinor ?? BigInt.zero) >= BigInt.zero;

    final String topValue;
    final String topLabel;
    if (isSnapshot) {
      topLabel = 'Nilai pasar';
      topValue = hidden
          ? '••••••'
          : (position.marketValue != null
                ? _formatLosslessRupiah(position.marketValue!)
                : 'Harga belum tersedia');
    } else {
      topLabel = 'Total modal';
      topValue = hidden
          ? '••••••'
          : CurrencyFormatter.formatMinorRupiah(costBasis);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accentColor.withValues(alpha: 0.25)),
                ),
                child: Text(
                  position.code,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      position.name,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (weightLabel != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Porsi ${hidden ? '••%' : weightLabel}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    topLabel,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    topValue,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: isSnapshot && position.marketValue == null
                          ? AppColors.textMuted
                          : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Column(
              children: [
                _PositionMetricRow(
                  label: 'Jumlah unit',
                  value: hidden
                      ? '••••••'
                      : _formatLosslessDecimal(position.quantity),
                ),
                const Divider(height: 12, color: AppColors.borderSubtle),
                _PositionMetricRow(
                  label: 'Harga modal rata-rata',
                  value: hidden
                      ? '••••••'
                      : _formatLosslessRupiah(position.average),
                ),
                if (isSnapshot) ...[
                  const Divider(height: 12, color: AppColors.borderSubtle),
                  _PositionMetricRow(
                    label: 'Harga pasar',
                    value: hidden
                        ? '••••••'
                        : (position.marketPrice != null
                              ? _formatLosslessRupiah(position.marketPrice!)
                              : 'Harga belum tersedia'),
                    muted: position.marketPrice == null,
                  ),
                  const Divider(height: 12, color: AppColors.borderSubtle),
                  _PositionMetricRow(
                    label: 'Laba/rugi belum terealisasi',
                    value: hidden
                        ? '••••••'
                        : (position.unrealizedPl != null
                              ? (plPercent != null
                                    ? '${_formatLosslessRupiah(position.unrealizedPl!)} ($plPercent)'
                                    : _formatLosslessRupiah(
                                        position.unrealizedPl!,
                                      ))
                              : 'Harga belum tersedia'),
                    valueColor: position.unrealizedPl == null
                        ? AppColors.textMuted
                        : (isPlPositive ? AppColors.income : AppColors.expense),
                    bold: position.unrealizedPl != null,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final hidden = AppStateScope.of(context).isBalanceHidden;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text(
          'Portofolio Investasi',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.tonalIcon(
              onPressed: _manageInvestments,
              icon: const Icon(Icons.tune_rounded, size: 16),
              label: const Text(
                'Kelola',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
      body: controller == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 48,
                      color: AppColors.textMuted.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Masuk dan siapkan data akun untuk melihat portofolio.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListenableBuilder(
              listenable: controller,
              builder: (context, _) {
                final accounts = controller.repository.accounts;
                final read = controller.read;
                final selectedAccount = accounts
                    .where((a) => a.id == controller.accountId)
                    .firstOrNull;
                final isSnapshot = controller.date != null;
                final positions = read?.positions ?? const <PortfolioPosition>[];

                var totalAccountVal = BigInt.zero;
                for (final pos in positions) {
                  final v = isSnapshot && pos.marketValue != null
                      ? _parseMinor(pos.marketValue)
                      : _multiplyToMinor(pos.quantity, pos.average);
                  if (v > BigInt.zero) totalAccountVal += v;
                }

                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async {
                    if (accounts.isNotEmpty) {
                      await controller.select(
                        controller.accountId,
                        controller.date,
                      );
                    }
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                      if (accounts.isEmpty)
                        _buildEmptyPortfolio(noAccounts: true)
                      else ...[
                        // 1. Account & Mode Selector Card (always visible at top)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
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
                              DropdownButtonFormField<String>(
                                key: ValueKey(
                                  '${controller.accountId}:${accounts.map((a) => a.id).join(',')}',
                                ),
                                initialValue:
                                    accounts.any(
                                      (a) => a.id == controller.accountId,
                                    )
                                    ? controller.accountId
                                    : null,
                                decoration: InputDecoration(
                                  labelText: 'Akun investasi',
                                  isDense: true,
                                  prefixIcon: const Icon(
                                    Icons.account_balance_rounded,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: AppColors.border,
                                    ),
                                  ),
                                ),
                                isExpanded: true,
                                items: accounts
                                    .map(
                                      (a) => DropdownMenuItem(
                                        value: a.id,
                                        child: Text(
                                          a.parentName != null
                                              ? '${a.parentName} › ${a.name}'
                                              : a.name,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (id) => unawaited(
                                  controller.select(id, controller.date),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  ActionChip(
                                    avatar: Icon(
                                      Icons.pie_chart_outline_rounded,
                                      size: 16,
                                      color: !isSnapshot
                                          ? AppColors.primary
                                          : AppColors.textSecondary,
                                    ),
                                    label: Text(
                                      'Saat ini',
                                      style: TextStyle(
                                        fontWeight: !isSnapshot
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: !isSnapshot
                                            ? AppColors.primary
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                    backgroundColor: !isSnapshot
                                        ? AppColors.accentLight
                                        : AppColors.surfaceVariant,
                                    side: BorderSide(
                                      color: !isSnapshot
                                          ? AppColors.primary.withValues(
                                              alpha: 0.3,
                                            )
                                          : Colors.transparent,
                                    ),
                                    onPressed: () => unawaited(
                                      controller.select(
                                        controller.accountId,
                                        null,
                                      ),
                                    ),
                                  ),
                                  ActionChip(
                                    avatar: Icon(
                                      Icons.calendar_today_rounded,
                                      size: 15,
                                      color: isSnapshot
                                          ? AppColors.primary
                                          : AppColors.textSecondary,
                                    ),
                                    label: Text(
                                      !isSnapshot
                                          ? 'Snapshot'
                                          : 'Snapshot ${DateFormatter.calendarDate(controller.date)}',
                                      style: TextStyle(
                                        fontWeight: isSnapshot
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: isSnapshot
                                            ? AppColors.primary
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                    backgroundColor: isSnapshot
                                        ? AppColors.accentLight
                                        : AppColors.surfaceVariant,
                                    side: BorderSide(
                                      color: isSnapshot
                                          ? AppColors.primary.withValues(
                                              alpha: 0.3,
                                            )
                                          : Colors.transparent,
                                    ),
                                    onPressed: () => _chooseDate(controller),
                                  ),
                                  ActionChip(
                                    avatar: const Icon(
                                      Icons.refresh_rounded,
                                      size: 16,
                                      color: AppColors.textSecondary,
                                    ),
                                    label: const Text('Muat ulang'),
                                    backgroundColor: AppColors.surfaceVariant,
                                    onPressed: controller.loading
                                        ? null
                                        : () => unawaited(
                                            controller.select(
                                              controller.accountId,
                                              controller.date,
                                            ),
                                          ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isSnapshot
                                    ? 'Menampilkan estimasi nilai pasar & potensi untung/rugi pada ${DateFormatter.calendarDate(controller.date)}.'
                                    : 'Menampilkan daftar aset aktif yang dipegang & total modal rata-rata akun ini.',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textSecondary,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // 2. Hero Summary Card
                        _buildHeroSummary(
                          account: selectedAccount,
                          read: read,
                          snapshotDate: controller.date,
                          hidden: hidden,
                        ),
                        const SizedBox(height: 12),

                        // 3. Quick Action Shortcuts to Investment Lifecycle
                        _buildQuickActions(),
                        const SizedBox(height: 14),

                        // 4. Portfolio Composition Bar
                        if (positions.isNotEmpty) ...[
                          _buildAllocationCard(
                            positions,
                            isSnapshot: isSnapshot,
                            hidden: hidden,
                          ),
                          const SizedBox(height: 16),
                        ],

                        // 5. Section Header: Posisi Investasi
                        Row(
                          children: [
                            const Icon(
                              Icons.donut_small_rounded,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                !isSnapshot
                                    ? 'Posisi Aset (${positions.length})'
                                    : 'Posisi per ${DateFormatter.calendarDate(controller.date)} — Snapshot',
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        if (controller.loading)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: LinearProgressIndicator(
                              color: AppColors.primary,
                            ),
                          ),
                        if (controller.error != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: AppColors.expenseLight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.expense.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  size: 18,
                                  color: AppColors.expense,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    controller.error!,
                                    style: const TextStyle(
                                      color: AppColors.expense,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            read == null
                                ? 'Data server • Hanya baca'
                                : controller.stale
                                ? 'Cache belum diverifikasi • Bukan real-time'
                                : 'Data server • Bukan real-time',
                            style: TextStyle(
                              fontSize: 12,
                              color: read != null && controller.stale
                                  ? AppColors.warning
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),

                        if (read != null) ...[
                          if (positions.isEmpty) _buildEmptyPortfolio(),
                          for (var i = 0; i < positions.length; i++)
                            _buildPositionCard(
                              position: positions[i],
                              accentColor:
                                  _allocationPalette[i %
                                      _allocationPalette.length],
                              totalAccountValue: totalAccountVal,
                              isSnapshot: isSnapshot,
                              hidden: hidden,
                            ),
                        ] else if (!controller.loading)
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Center(
                              child: Text(
                                'Belum ada cache portofolio untuk pilihan ini.',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                      ],
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ExpansionTile(
                          key: const ValueKey('portfolio-data-help'),
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 2,
                          ),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            14,
                            0,
                            14,
                            14,
                          ),
                          shape: const Border(),
                          collapsedShape: const Border(),
                          leading: const Icon(
                            Icons.info_outline_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          title: const Text(
                            'Tentang data portofolio',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          children: [
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Hanya baca • Data server, bukan ledger lokal tersinkron lengkap. '
                                'Harga bukan real-time. Snapshot menggunakan batas hari UTC.',
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            if (read != null) ...[
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Cache diambil: ${DateFormatter.formatFull(read.fetchedAt, timeZone: AppStateScope.of(context).timeZone)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  controller.stale
                                      ? 'Data cache usang / belum diverifikasi ulang.'
                                      : 'Terakhir berhasil dimuat dari server; bukan harga real-time.',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
              },
            ),
    );
  }
}

class _HeroStatColumn extends StatelessWidget {
  final Color dotColor;
  final String label;
  final String value;
  final Color valueColor;

  const _HeroStatColumn({
    required this.dotColor,
    required this.label,
    required this.value,
    this.valueColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: valueColor,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.accentLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: AppColors.primary),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PositionMetricRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool muted;
  final bool bold;

  const _PositionMetricRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.muted = false,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
              color:
                  valueColor ??
                  (muted ? AppColors.textMuted : AppColors.textPrimary),
            ),
          ),
        ),
      ],
    );
  }
}

class _SetupStepRow extends StatelessWidget {
  final String step;
  final String text;

  const _SetupStepRow({required this.step, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: Text(
            step,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
