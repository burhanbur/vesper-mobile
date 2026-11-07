import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../app/theme/app_colors.dart';
import '../data/portfolio_controller.dart';
import '../data/portfolio_repository.dart';
import 'investment_lifecycle_page.dart';

class PortfolioPage extends StatefulWidget {
  const PortfolioPage({super.key});
  @override
  State<PortfolioPage> createState() => _PortfolioPageState();
}

class _PortfolioPageState extends State<PortfolioPage> {
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
    // Server snapshots are reference calendar dates with a UTC-day cutoff.
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

  void _manageInvestments() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const InvestmentLifecyclePage()),
    );
  }

  Widget _emptyPortfolio({bool noAccounts = false}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: AppColors.accentLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.pie_chart_outline_rounded,
              size: 36,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            noAccounts
                ? 'Siapkan portofolio Anda'
                : 'Belum ada posisi investasi',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            noAccounts ? 'Belum ada akun investasi milik Anda.' : 'Tidak ada posisi untuk akun dan periode ini. Kelola instrumen dan transaksi investasi Anda.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _manageInvestments,
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: const Text('Kelola investasi'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
        title: const Text(
          'Portofolio investasi',
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
              label: const Text('Kelola'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
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
                      Icons.account_balance_wallet_outlined,
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
                String amount(String? value) => hidden
                    ? '••••••'
                    : value == null
                    ? 'Harga belum tersedia'
                    : 'IDR $value';
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  children: [
                    const Text(
                      'Akun & periode',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (accounts.isEmpty)
                      _emptyPortfolio(noAccounts: true)
                    else ...[
                      // Compact selection controls; section headings stay outside.
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(18),
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
                            DropdownButtonFormField<String>(
                              key: ValueKey(controller.accountId),
                              initialValue: controller.accountId,
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
                                  vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              isExpanded: true,
                              items: accounts
                                  .map(
                                    (a) => DropdownMenuItem(
                                      value: a.id,
                                      child: Text(
                                        a.name,
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
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ActionChip(
                                  avatar: Icon(
                                    Icons.pie_chart_outline_rounded,
                                    size: 16,
                                    color: controller.date == null
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                  ),
                                  label: const Text('Saat ini'),
                                  backgroundColor: controller.date == null
                                      ? AppColors.accentLight
                                      : AppColors.surfaceVariant,
                                  onPressed: () => unawaited(
                                    controller.select(
                                      controller.accountId,
                                      null,
                                    ),
                                  ),
                                ),
                                ActionChip(
                                  avatar: const Icon(
                                    Icons.calendar_today_rounded,
                                    size: 15,
                                    color: AppColors.textSecondary,
                                  ),
                                  label: Text(
                                    controller.date == null
                                        ? 'Snapshot'
                                        : 'Snapshot ${controller.date}',
                                  ),
                                  backgroundColor: controller.date != null
                                      ? AppColors.accentLight
                                      : AppColors.surfaceVariant,
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
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Section Header
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
                              controller.date == null
                                  ? 'Posisi investasi'
                                  : 'Posisi per ${controller.date} — snapshot',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (controller.loading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: LinearProgressIndicator(),
                        ),
                      if (controller.error != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: AppColors.expenseLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            controller.error!,
                            style: const TextStyle(
                              color: AppColors.expense,
                              fontSize: 12,
                            ),
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
                        if (read.positions.isEmpty) _emptyPortfolio(),
                        for (final position in read.positions)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
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
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        position.code,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        position.name,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
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
                                        'Jumlah: ${hidden ? '••••••' : position.quantity}',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceVariant.withValues(
                                      alpha: 0.4,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Harga modal rata-rata: ${amount(position.average)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      if (controller.date != null) ...[
                                        const SizedBox(height: 6),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Harga pasar: ${amount(position.marketPrice)}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textMuted,
                                              ),
                                            ),
                                            Text(
                                              'Nilai pasar: ${amount(position.marketValue)}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Laba/rugi belum terealisasi: ${amount(position.unrealizedPl)}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.accentDark,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ] else if (!controller.loading)
                        Container(
                          padding: const EdgeInsets.all(28),
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
                    const SizedBox(height: 16),
                    ExpansionTile(
                      key: const ValueKey('portfolio-data-help'),
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(bottom: 12),
                      leading: const Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      title: const Text(
                        'Tentang data portofolio',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      children: [
                        const Text(
                          'Hanya baca • Data server, bukan ledger lokal tersinkron lengkap. '
                          'Harga bukan real-time. Snapshot menggunakan batas hari UTC.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (read != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Cache diambil: ${DateFormatter.formatFull(read.fetchedAt, timeZone: AppStateScope.of(context).timeZone)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            controller.stale
                                ? 'Data cache usang / belum diverifikasi ulang.'
                                : 'Terakhir berhasil dimuat dari server; bukan harga real-time.',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                );
              },
            ),
    );
  }
}
