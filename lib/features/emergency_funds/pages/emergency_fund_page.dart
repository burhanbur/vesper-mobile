import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/currency_amount_input.dart';
import '../../../core/widgets/nominal_quick_keys.dart';
import '../data/emergency_fund_controller.dart';
import '../data/emergency_fund_repository.dart';

class EmergencyFundPage extends StatefulWidget {
  const EmergencyFundPage({super.key});
  @override
  State<EmergencyFundPage> createState() => _EmergencyFundPageState();
}

class _EmergencyFundPageState extends State<EmergencyFundPage> {
  static const List<Color> _accountPalette = [
    Color(0xFF10B981),
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
    Color(0xFFF59E0B),
    Color(0xFF06B6D4),
  ];

  EmergencyFundController? controller;
  String? message;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppStateScope.of(context);
    final source = state.repository;
    final user = state.currentUserId;
    if (source == null || user.isEmpty || source.userId != user) {
      controller?.dispose();
      controller = null;
      message = null;
    } else if (!identical(controller?.repository.source, source)) {
      controller?.dispose();
      message = null;
      controller = EmergencyFundController(
        EmergencyFundRepository(source),
        () =>
            mounted &&
            identical(state.repository, source) &&
            user == state.currentUserId,
        state.emergencyPlanSaved,
      );
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    String? prefixText,
  }) {
    return InputDecoration(
      labelText: label,
      prefixText: prefixText,
      prefixIcon: Icon(icon, size: 19, color: AppColors.primary),
      labelStyle: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 13,
      ),
      filled: true,
      fillColor: AppColors.background,
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
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Future<void> configure() async {
    final active = controller!;
    final repo = active.repository;
    final plan = repo.plan;
    var mode = '${plan?['baseline_mode'] ?? 'MANUAL'}';
    var history = plan?['history_months'] as int? ?? 3;
    String? goalId = plan?['goal_id'] as String?;
    if (!repo.privateGoals.any((g) => g['id'] == goalId)) goalId = null;
    final accountIds = (plan?['account_ids'] as List? ?? const [])
        .cast<String>()
        .where((id) => repo.accounts.any((a) => a['id'] == id))
        .toSet();
    final categoryIds = (plan?['category_ids'] as List? ?? const [])
        .cast<String>()
        .where((id) => repo.categories.any((c) => c['id'] == id))
        .toSet();
    final manual = TextEditingController(
      text: CurrencyAmountInput.fromDecimal(
        plan?['manual_baseline'] as String? ?? '',
      ),
    );
    final months = TextEditingController(
      text: '${plan?['coverage_months'] ?? 6}',
    );
    String? error;
    bool saved = false;
    try {
      final route = ModalBottomSheetRoute<void>(
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
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.accentLight,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.health_and_safety_rounded,
                                size: 20,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Atur dana darurat',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 20),
                              onPressed: () => Navigator.pop(ctx),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      ),
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DropdownButtonFormField<String>(
                                initialValue: mode,
                                isExpanded: true,
                                decoration: _fieldDecoration(
                                  label: 'Baseline pengeluaran wajib',
                                  icon: Icons.calculate_rounded,
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'MANUAL',
                                    child: Text(
                                      'Manual — nominal per bulan',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'HISTORY',
                                    child: Text(
                                      'Estimasi dari histori',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                                onChanged: (v) => update(() => mode = v!),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: manual,
                                inputFormatters: const [CurrencyAmountInput()],
                                enabled: mode == 'MANUAL',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: _fieldDecoration(
                                  label: 'Pengeluaran wajib per bulan (IDR)',
                                  icon: Icons.payments_rounded,
                                  prefixText: 'Rp ',
                                ),
                              ),
                              if (mode == 'MANUAL')
                                NominalQuickKeys(
                                  controller: manual,
                                  mode: NominalFormatMode.currencyAmountInput,
                                  keyPrefix: 'emergency_manual',
                                ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: months,
                                      keyboardType: TextInputType.number,
                                      decoration: _fieldDecoration(
                                        label: 'Target cakupan (1–60 bulan)',
                                        icon: Icons.shield_rounded,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<int>(
                                initialValue: history,
                                isExpanded: true,
                                decoration: _fieldDecoration(
                                  label: 'Jendela histori',
                                  icon: Icons.history_rounded,
                                ),
                                items: [
                                  for (final n in [3, 6, 12])
                                    DropdownMenuItem(
                                      value: n,
                                      child: Text(
                                        '$n bulan kalender penuh',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                                onChanged: (v) => update(() => history = v!),
                              ),
                              const SizedBox(height: 16),
                              _SheetSectionTitle(
                                title: 'Kategori pengeluaran wajib',
                                badge: '${categoryIds.length} dipilih',
                              ),
                              const SizedBox(height: 6),
                              Material(
                                color: AppColors.background,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: const BorderSide(
                                    color: AppColors.borderSubtle,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: repo.categories.isEmpty
                                    ? const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: Text(
                                          'Belum ada kategori pengeluaran.',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      )
                                    : Column(
                                        children: [
                                          for (final c in repo.categories)
                                            CheckboxListTile(
                                              dense: true,
                                              activeColor: AppColors.primary,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                  ),
                                              title: Text(
                                                '${c['name']}',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              value: categoryIds.contains(
                                                c['id'],
                                              ),
                                              onChanged: (v) => update(() {
                                                if (v == true) {
                                                  categoryIds.add(
                                                    c['id'] as String,
                                                  );
                                                } else {
                                                  categoryIds.remove(c['id']);
                                                }
                                              }),
                                            ),
                                        ],
                                      ),
                              ),
                              const SizedBox(height: 16),
                              _SheetSectionTitle(
                                title: 'Akun kas likuid yang dihitung',
                                badge: '${accountIds.length} dipilih',
                              ),
                              const SizedBox(height: 6),
                              Material(
                                color: AppColors.background,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: const BorderSide(
                                    color: AppColors.borderSubtle,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: repo.accounts.isEmpty
                                    ? const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: Text(
                                          'Belum ada akun kas IDR yang memenuhi syarat.',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      )
                                    : Column(
                                        children: [
                                          for (final a in repo.accounts)
                                            CheckboxListTile(
                                              dense: true,
                                              activeColor: AppColors.primary,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                  ),
                                              title: Text(
                                                '${AppStateScope.of(context).accountDisplayNameById(a['id'] as String, fallback: '${a['name']}')}${a['is_visible'] == false ? ' (tersembunyi)' : ''}',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              value: accountIds.contains(
                                                a['id'],
                                              ),
                                              onChanged: (v) => update(() {
                                                if (v == true) {
                                                  accountIds.add(
                                                    a['id'] as String,
                                                  );
                                                } else {
                                                  accountIds.remove(a['id']);
                                                }
                                              }),
                                            ),
                                        ],
                                      ),
                              ),
                              const SizedBox(height: 14),
                              DropdownButtonFormField<String>(
                                initialValue: goalId,
                                isExpanded: true,
                                decoration: _fieldDecoration(
                                  label: 'Goal dana darurat (opsional)',
                                  icon: Icons.flag_rounded,
                                ),
                                items: [
                                  const DropdownMenuItem<String>(
                                    value: null,
                                    child: Text(
                                      'Hanya kas yang belum dialokasikan',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  for (final g in repo.privateGoals)
                                    DropdownMenuItem(
                                      value: g['id'] as String,
                                      child: Text(
                                        '${g['name']}',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                                onChanged: (v) => update(() => goalId = v),
                              ),
                              if (error != null)
                                Container(
                                  margin: const EdgeInsets.only(top: 10),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.expenseLight,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.error_outline_rounded,
                                        size: 18,
                                        color: AppColors.expense,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          error!,
                                          style: const TextStyle(
                                            color: AppColors.expense,
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(ctx),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  side: const BorderSide(
                                    color: AppColors.border,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text('Batal'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: saved
                                    ? null
                                    : () {
                                        final ok = active.save(
                                          () => repo.save(
                                            mode: mode,
                                            manualBaseline:
                                                CurrencyAmountInput.toDecimal(
                                                  manual.text.trim(),
                                                ),
                                            coverageMonths:
                                                int.tryParse(
                                                  months.text.trim(),
                                                ) ??
                                                0,
                                            historyMonths: history,
                                            accountIds: accountIds.toList()
                                              ..sort(),
                                            categoryIds: categoryIds.toList()
                                              ..sort(),
                                            goalId: goalId,
                                          ),
                                        );
                                        if (ok) {
                                          saved = true;
                                          Navigator.pop(ctx);
                                        } else {
                                          update(() => error = active.error);
                                        }
                                      },
                                child: const Text('Simpan lokal'),
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
      await Navigator.of(context).push(route);
      await route.completed;
    } finally {
      manual.dispose();
      months.dispose();
    }
    if (mounted && identical(controller, active)) {
      setState(() {
        if (saved) {
          message = 'Rencana tersimpan lokal; sinkronisasi mengikuti koneksi.';
        }
      });
    }
  }

  Widget _buildEmptySetupCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
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
        borderRadius: BorderRadius.circular(22),
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
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.health_and_safety_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Siapkan Dana Darurat',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tentukan kebutuhan wajib bulanan dan akun kas likuid untuk memantau kecukupan dana daruratmu.',
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              onPressed: configure,
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: const Text(
                'Atur dana darurat',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBanner({
    required IconData icon,
    required String text,
    required Color color,
    required Color bg,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final active = controller;
    if (active == null || !active.isCurrent()) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          scrolledUnderElevation: 0,
          foregroundColor: AppColors.textPrimary,
          title: const Text(
            'Dana Darurat',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        body: const Center(
          child: Text(
            'Masuk untuk membuka rencana dana darurat.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final repo = active.repository;
    final plan = repo.plan;
    EmergencyAssessment? result;
    String? assessmentError;
    if (plan != null) {
      try {
        result = repo.assess(plan, timeZone: state.timeZone);
      } catch (_) {
        assessmentError =
            'Data perhitungan belum valid. Tinjau pengaturan dan sinkronkan ulang.';
      }
    }
    final hidden = state.isBalanceHidden;
    String money(BigInt? value) => value == null
        ? 'Belum tersedia'
        : hidden
        ? '••••••'
        : CurrencyFormatter.formatMinorRupiah(value);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text(
          'Dana Darurat',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          if (plan != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: FilledButton.tonalIcon(
                onPressed: configure,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.tune_rounded, size: 16),
                label: const Text(
                  'Ubah pengaturan',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Sinkronkan rencana',
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
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          await state.refresh();
          if (mounted) setState(() {});
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            if (plan == null) _buildEmptySetupCard(),

            if (assessmentError != null)
              _buildBanner(
                icon: Icons.error_outline_rounded,
                text: assessmentError,
                color: AppColors.expense,
                bg: AppColors.expenseLight,
              ),

            if (result case final r?) ...[
              // 1. Hero Coverage Card
              _buildHeroCoverageCard(
                plan: plan!,
                r: r,
                hidden: hidden,
                money: money,
              ),
              const SizedBox(height: 12),

              // Warnings (if any)
              for (final warning in r.warnings)
                _buildBanner(
                  icon: Icons.warning_amber_rounded,
                  text: warning,
                  color: AppColors.warning,
                  bg: AppColors.warningLight,
                ),

              // 2. Clean 2-Card Key Metrics Row
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.receipt_long_rounded,
                      iconColor: AppColors.primary,
                      iconBg: AppColors.accentLight,
                      label: 'Wajib / Bulan',
                      value: money(r.baseline),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      icon: (r.remaining != null && r.remaining! > BigInt.zero)
                          ? Icons.trending_up_rounded
                          : Icons.check_circle_rounded,
                      iconColor:
                          (r.remaining != null && r.remaining! > BigInt.zero)
                          ? AppColors.expense
                          : AppColors.income,
                      iconBg:
                          (r.remaining != null && r.remaining! > BigInt.zero)
                          ? AppColors.expenseLight
                          : AppColors.incomeLight,
                      label: 'Status Target',
                      value: 'Kekurangan target: ${money(r.remaining)}',
                      compactValue: true,
                      valueColor:
                          (r.remaining != null && r.remaining! > BigInt.zero)
                          ? AppColors.expense
                          : AppColors.income,
                    ),
                  ),
                ],
              ),

              // 3. History Period & Categories Strip (only in HISTORY mode)
              if (plan['baseline_mode'] == 'HISTORY') ...[
                const SizedBox(height: 12),
                Container(
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
                          const Icon(
                            Icons.calendar_month_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Histori ${r.historyMonths} bulan: ${DateFormatter.formatShort(state.timeZone.at(r.historyStart))} – ${DateFormatter.formatShort(state.timeZone.at(r.historyEnd.subtract(const Duration(microseconds: 1))))}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final c in repo.categories.where(
                            (c) => (plan['category_ids'] as List).contains(
                              c['id'],
                            ),
                          ))
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${c['name']}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              // 4. Liquid Funds Breakdown Card + Visual Bar
              const SizedBox(height: 18),
              Row(
                children: [
                  const Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Sumber Dana Likuid',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    '${r.accounts.length} Akun',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildLiquidAccountsCard(r: r, hidden: hidden, money: money),
            ],

            if (!repo.complete)
              _buildBanner(
                icon: Icons.cloud_sync_rounded,
                text:
                    'Sinkronkan untuk memuat rencana dari perangkat lain. Pengaturan baru tetap dapat disimpan offline.',
                color: AppColors.warning,
                bg: AppColors.warningLight,
              ),
            if (message != null)
              _buildBanner(
                icon: Icons.check_circle_rounded,
                text: message!,
                color: AppColors.income,
                bg: AppColors.incomeLight,
              ),
            if (active.error != null)
              _buildBanner(
                icon: Icons.error_outline_rounded,
                text: active.error!,
                color: AppColors.expense,
                bg: AppColors.expenseLight,
              ),
            if (state.dataError != null)
              _buildBanner(
                icon: Icons.cloud_off_rounded,
                text: state.dataError!,
                color: AppColors.expense,
                bg: AppColors.expenseLight,
              ),

            for (final item in repo.queue)
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rencana: ${item['status']} — ${item['error'] ?? 'menunggu sinkronisasi'}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warning,
                      ),
                    ),
                    if (['conflict', 'rejected'].contains(item['status']))
                      Wrap(
                        spacing: 6,
                        children: [
                          TextButton(
                            onPressed: () {
                              active.save(
                                () => repo.recover(item['id'] as String),
                              );
                              setState(() {});
                            },
                            child: const Text(
                              'Coba ulang dengan validasi server',
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              active.save(
                                () => repo.recover(
                                  item['id'] as String,
                                  discard: true,
                                ),
                              );
                              setState(() {});
                            },
                            child: const Text(
                              'Gunakan server / batalkan perubahan lokal',
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),

            // 5. Collapsible Notes at the bottom (keeps main UI clean!)
            const SizedBox(height: 16),
            Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: const ExpansionTile(
                tilePadding: EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                childrenPadding: EdgeInsets.fromLTRB(14, 0, 14, 14),
                shape: Border(),
                collapsedShape: Border(),
                leading: Icon(
                  Icons.info_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                title: Text(
                  'Cara perhitungan dana darurat',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                children: [
                  Text(
                    'Dana yang dihitung adalah kas bebas alokasi ditambah alokasi goal darurat terpilih dari akun kas IDR milik sendiri. Investasi, akun nonkas, mata uang asing, akun anggota lain, dan alokasi goal lain tidak dihitung. Pengaturan ini tidak memindahkan uang.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCoverageCard({
    required Map<String, dynamic> plan,
    required EmergencyAssessment r,
    required bool hidden,
    required String Function(BigInt?) money,
  }) {
    final targetMonths = plan['coverage_months'] as int? ?? 6;
    final coverageText = r.coverageHundredths == null
        ? 'Belum tersedia'
        : hidden
        ? '••••••'
        : '${r.coverageHundredths! ~/ BigInt.from(100)}.${(r.coverageHundredths! % BigInt.from(100)).toString().padLeft(2, '0')} bulan';

    double? progressRatio;
    if (r.coverageHundredths != null && !hidden && targetMonths > 0) {
      final currentMonths =
          (r.coverageHundredths! ~/ BigInt.from(100)).toInt() +
          ((r.coverageHundredths! % BigInt.from(100)).toInt() / 100.0);
      progressRatio = (currentMonths / targetMonths).clamp(0.0, 1.0);
    }

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
        borderRadius: BorderRadius.circular(22),
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
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.health_and_safety_rounded,
                    size: 15,
                    color: AppColors.accentLight,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'STATUS DANA DARURAT',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  plan['baseline_mode'] == 'MANUAL'
                      ? 'Baseline manual — diisi sendiri'
                      : 'Baseline estimasi — histori lokal',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'Cakupan saat ini: $coverageText',
              style: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.4,
              ),
            ),
          ),
          if (progressRatio != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progressRatio,
                minHeight: 9,
                backgroundColor: Colors.white.withValues(alpha: 0.18),
                valueColor: AlwaysStoppedAnimation<Color>(
                  progressRatio >= 1.0
                      ? const Color(0xFF34D399)
                      : const Color(0xFF6EE7B7),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(progressRatio * 100).toStringAsFixed(0)}% tercapai',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Target $targetMonths bulan',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _HeroStat(
                    dotColor: const Color(0xFF34D399),
                    label: 'Dana Likuid',
                    value: money(r.liquid),
                  ),
                ),
                Container(
                  width: 1,
                  height: 28,
                  color: Colors.white.withValues(alpha: 0.18),
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                ),
                Expanded(
                  child: _HeroStat(
                    dotColor: const Color(0xFFA78BFA),
                    label: 'Target $targetMonths Bulan',
                    value: money(r.target),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiquidAccountsCard({
    required EmergencyAssessment r,
    required bool hidden,
    required String Function(BigInt?) money,
  }) {
    if (r.accounts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: Text(
            'Belum ada akun kas likuid yang dipilih.',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ),
      );
    }

    final totalLiquid = r.accounts.fold<BigInt>(
      BigInt.zero,
      (sum, a) => sum + (a.total > BigInt.zero ? a.total : BigInt.zero),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (totalLiquid > BigInt.zero && !hidden) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: [
                    for (var i = 0; i < r.accounts.length; i++)
                      if (r.accounts[i].total > BigInt.zero)
                        Expanded(
                          flex:
                              ((r.accounts[i].total * BigInt.from(1000)) ~/
                                      totalLiquid)
                                  .toInt()
                                  .clamp(1, 1000),
                          child: Container(
                            color: _accountPalette[i % _accountPalette.length],
                          ),
                        ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          for (var i = 0; i < r.accounts.length; i++) ...[
            if (i > 0) const Divider(height: 16, color: AppColors.borderSubtle),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: _accountPalette[i % _accountPalette.length],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              r.accounts[i].name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            money(r.accounts[i].total),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            'Kas bebas: ${money(r.accounts[i].free)}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          if (r.accounts[i].earmarked > BigInt.zero)
                            Text(
                              '• Goal darurat: ${money(r.accounts[i].earmarked)}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.accentDark,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final Color dotColor;
  final String label;
  final String value;

  const _HeroStat({
    required this.dotColor,
    required this.label,
    required this.value,
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
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String value;
  final bool compactValue;
  final Color? valueColor;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.value,
    this.compactValue = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
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
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 15, color: iconColor),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: compactValue ? 13 : 15,
                fontWeight: FontWeight.w800,
                color: valueColor ?? AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetSectionTitle extends StatelessWidget {
  final String title;
  final String badge;

  const _SheetSectionTitle({required this.title, required this.badge});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.accentLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            badge,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}
