import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/currency_amount_input.dart';
import '../../../core/widgets/nominal_quick_keys.dart';
import '../data/goals_controller.dart';
import '../data/goals_repository.dart';
import '../widgets/goals_overview.dart';

class GoalsPage extends StatefulWidget {
  const GoalsPage({super.key});
  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  GoalsController? controller;
  String? message;
  String _filter = 'ALL'; // ALL, ACTIVE, COMPLETED

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
      controller = GoalsController(
        GoalsRepository(source),
        () =>
            mounted &&
            identical(state.repository, source) &&
            state.currentUserId == user,
        state.goalsSaved,
      );
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  static String _formatAmount(BigInt minor, String currency) {
    if (currency == 'IDR') return CurrencyFormatter.formatMinorRupiah(minor);
    return '${goalMoney(minor)} $currency';
  }

  static String _countdownLabel(String? isoTargetDate, DateTime today) {
    if (isoTargetDate == null) return '';
    final parsed = DateTime.tryParse('${isoTargetDate}T00:00:00Z');
    if (parsed == null) return '';
    final targetDay = DateTime.utc(parsed.year, parsed.month, parsed.day);
    final currentDay = DateTime.utc(today.year, today.month, today.day);
    final diff = targetDay.difference(currentDay).inDays;
    if (diff == 0) return 'Tenggat hari ini';
    if (diff > 0) return '$diff hari lagi';
    return 'Lewat ${diff.abs()} hari';
  }

  Future<void> edit({Map<String, dynamic>? goal}) async {
    final active = controller!;
    final repo = active.repository;
    final name = TextEditingController(text: goal?['name'] as String?);
    final target = TextEditingController(
      text: CurrencyAmountInput.fromDecimal(
        goal?['target_amount'] as String? ?? '',
      ),
    );
    var targetDateIso =
        goal?['target_date'] as String? ??
        goalDay(
          AppStateScope.of(context).timeZone
              .calendarDate(DateTime.now())
              .add(const Duration(days: 365)),
        );
    final dateDisplay = TextEditingController(
      text: DateFormatter.calendarDate(targetDateIso),
    );
    final currency = TextEditingController(
      text: goal?['currency'] as String? ?? 'IDR',
    );
    String? group = goal?['group_id'] as String?, error;
    bool saved = false;
    try {
      final route = ModalBottomSheetRoute<void>(
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, update) => Material(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
              top: false,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.88,
                ),
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
                                Icons.flag_rounded,
                                size: 20,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                goal == null ? 'Buat goal baru' : 'Ubah goal',
                                style: const TextStyle(
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
                              TextField(
                                controller: name,
                                maxLength: 120,
                                decoration: _fieldDecoration(
                                  label: 'Nama goal',
                                  hint: 'Contoh: Dana Nikah, Liburan Jepang',
                                  icon: Icons.edit_rounded,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: target,
                                inputFormatters: const [CurrencyAmountInput()],
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: _fieldDecoration(
                                  label: 'Target nominal',
                                  icon: Icons.payments_rounded,
                                  prefixText:
                                      currency.text.trim().toUpperCase() ==
                                          'IDR'
                                      ? 'Rp '
                                      : '${currency.text.trim().toUpperCase()} ',
                                ),
                              ),
                              NominalQuickKeys(
                                controller: target,
                                mode: NominalFormatMode.currencyAmountInput,
                                keyPrefix: 'goal_target',
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: currency,
                                onChanged: (_) => update(() {}),
                                enabled: goal == null,
                                maxLength: 3,
                                textCapitalization:
                                    TextCapitalization.characters,
                                decoration: _fieldDecoration(
                                  label: 'Mata uang',
                                  icon: Icons.currency_exchange_rounded,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: dateDisplay,
                                readOnly: true,
                                onTap: () async {
                                  final current =
                                      DateTime.tryParse(targetDateIso) ??
                                      DateTime.now().add(
                                        const Duration(days: 365),
                                      );
                                  final picked = await showDatePicker(
                                    context: ctx,
                                    initialDate: current,
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                    helpText: 'PILIH TANGGAL TARGET',
                                  );
                                  if (picked != null) {
                                    update(() {
                                      targetDateIso = goalDay(picked);
                                      dateDisplay.text =
                                          DateFormatter.calendarDate(
                                            targetDateIso,
                                          );
                                    });
                                  }
                                },
                                decoration: _fieldDecoration(
                                  label: 'Tanggal target',
                                  icon: Icons.calendar_today_rounded,
                                  suffixIcon: const Icon(
                                    Icons.arrow_drop_down_rounded,
                                    size: 24,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              if (goal == null) ...[
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  initialValue: group,
                                  isExpanded: true,
                                  decoration: _fieldDecoration(
                                    label: 'Kepemilikan & visibilitas',
                                    icon: Icons.groups_rounded,
                                  ),
                                  items: [
                                    const DropdownMenuItem<String>(
                                      value: null,
                                      child: Text(
                                        'Pribadi — hanya saya',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    for (final g
                                        in repo.source
                                            .rows('groups')
                                            .where(
                                              (g) => repo.member(
                                                g['id'] as String,
                                              ),
                                            ))
                                      DropdownMenuItem(
                                        value: g['id'] as String,
                                        child: Text(
                                          'Rumah tangga: ${g['name']}',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                  onChanged: (v) => update(() => group = v),
                                ),
                              ],
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.info_rounded,
                                      size: 16,
                                      color: AppColors.textSecondary,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Alokasi hanya menyisihkan dana; saldo tetap dapat dibelanjakan. Mata uang dan cakupan tidak berubah setelah dibuat.',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: AppColors.textSecondary,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (error != null) _buildInlineError(error!),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
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
                                        final ok = active.save(() {
                                          if (goal == null) {
                                            repo.create(
                                              name: name.text,
                                              target:
                                                  CurrencyAmountInput.toDecimal(
                                                    target.text.trim(),
                                                  ),
                                              currency: currency.text
                                                  .trim()
                                                  .toUpperCase(),
                                              targetDate: targetDateIso.trim(),
                                              groupId: group,
                                            );
                                          } else {
                                            repo.update(
                                              goal['id'] as String,
                                              name: name.text,
                                              target:
                                                  CurrencyAmountInput.toDecimal(
                                                    target.text.trim(),
                                                  ),
                                              targetDate: targetDateIso.trim(),
                                              status: goal['status'] as String,
                                            );
                                          }
                                        });
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
        ),
      );
      await Navigator.of(context).push(route);
      await route.completed;
    } finally {
      name.dispose();
      target.dispose();
      dateDisplay.dispose();
      currency.dispose();
    }
    if (mounted && identical(controller, active)) {
      setState(() {
        if (saved) {
          message = 'Goal tersimpan lokal; sinkronisasi menunggu koneksi.';
        }
      });
    }
  }

  Future<void> allocation(
    String goalId, {
    Map<String, dynamic>? existing,
  }) async {
    final active = controller!;
    final repo = active.repository;
    final goal = repo.goals.where((g) => g['id'] == goalId).firstOrNull;
    String? account = existing?['account_id'] as String?, error;
    final amount = TextEditingController(
      text: CurrencyAmountInput.fromDecimal(
        existing?['amount'] as String? ?? '0.00',
      ),
    );
    bool saved = false;
    final accounts = repo.cashAccounts
        .where((a) => goal != null && a['currency'] == goal['currency'])
        .toList();
    final currencyCode = (goal?['currency'] as String?) ?? 'IDR';

    try {
      final route = ModalBottomSheetRoute<void>(
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, update) => Material(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
              top: false,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.85,
                ),
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
                                Icons.account_balance_wallet_rounded,
                                size: 20,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Atur alokasi dana',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 18,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  if (goal != null)
                                    Text(
                                      '${goal['name']}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                ],
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
                              if (existing == null) ...[
                                DropdownButtonFormField<String>(
                                  initialValue: account,
                                  isExpanded: true,
                                  decoration: _fieldDecoration(
                                    label: 'Akun / kantong milik saya',
                                    icon: Icons.account_balance_rounded,
                                  ),
                                  items: [
                                    for (final a in accounts)
                                      DropdownMenuItem(
                                        value: a['id'] as String,
                                        child: Text(
                                          AppStateScope.of(
                                            context,
                                          ).accountDisplayNameById(
                                            a['id'] as String,
                                            fallback: '${a['name']}',
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                  onChanged: (v) => update(() {
                                    account = v;
                                    final old = repo.allocations
                                        .where(
                                          (a) =>
                                              a['goal_id'] == goalId &&
                                              a['account_id'] == v &&
                                              a['user_id'] ==
                                                  repo.source.userId,
                                        )
                                        .firstOrNull;
                                    amount.text =
                                        CurrencyAmountInput.fromDecimal(
                                          '${old?['amount'] ?? '0.00'}',
                                        );
                                  }),
                                ),
                                const SizedBox(height: 12),
                              ],
                              if (account != null)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentLight,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.2,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.savings_rounded,
                                        size: 16,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Dana belum dialokasikan: ${_formatAmount(repo.available(account!), currencyCode)}',
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              TextField(
                                controller: amount,
                                inputFormatters: const [CurrencyAmountInput()],
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: _fieldDecoration(
                                  label: 'Total alokasi dari akun ini',
                                  icon: Icons.payments_rounded,
                                  prefixText: currencyCode == 'IDR'
                                      ? 'Rp '
                                      : '$currencyCode ',
                                ),
                              ),
                              NominalQuickKeys(
                                controller: amount,
                                mode: NominalFormatMode.currencyAmountInput,
                                keyPrefix: 'goal_allocation',
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.info_rounded,
                                      size: 16,
                                      color: AppColors.textSecondary,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Isi total baru, bukan tambahan. Isi 0 untuk menarik alokasi. Tidak ada uang berpindah atau pengeluaran dibuat.',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: AppColors.textSecondary,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (error != null) _buildInlineError(error!),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
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
                                          () => repo.allocate(
                                            goalId,
                                            account ?? '',
                                            CurrencyAmountInput.toDecimal(
                                              amount.text.trim(),
                                            ),
                                          ),
                                        );
                                        if (ok) {
                                          saved = true;
                                          Navigator.pop(ctx);
                                        } else {
                                          update(() => error = active.error);
                                        }
                                      },
                                child: const Text('Simpan alokasi'),
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
        ),
      );
      await Navigator.of(context).push(route);
      await route.completed;
    } finally {
      amount.dispose();
    }
    if (mounted && identical(controller, active)) {
      setState(() {
        if (saved) {
          message = 'Alokasi tersimpan lokal; saldo kas tidak berubah.';
        }
      });
    }
  }

  Future<void> remove(Map<String, dynamic> goal) async {
    final active = controller!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actionsOverflowButtonSpacing: 8,
        backgroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.archive_rounded, color: AppColors.expense, size: 22),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Arsipkan goal?',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          'Seluruh alokasi goal ini dilepas setelah sinkronisasi diterima server. Saldo dan transaksi tidak berubah.',
          style: TextStyle(
            fontSize: 13,
            height: 1.45,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.expense,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Arsipkan'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true || !identical(controller, active)) return;
    active.save(() => active.repository.remove(goal['id'] as String));
    setState(() {});
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    String? hint,
    String? prefixText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixText: prefixText,
      prefixIcon: Icon(icon, size: 19, color: AppColors.primary),
      suffixIcon: suffixIcon,
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

  Widget _buildInlineError(String text) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.expenseLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.expense.withValues(alpha: 0.25)),
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
              text,
              style: const TextStyle(
                color: AppColors.expense,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
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
        children: [
          Icon(icon, size: 18, color: color),
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

  Widget _buildFilterBar({
    required int totalCount,
    required int activeCount,
    required int completedCount,
  }) {
    Widget chip(String key, String label) {
      final selected = _filter == key;
      return ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
        selected: selected,
        selectedColor: AppColors.primary,
        backgroundColor: Colors.white,
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.border,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        showCheckmark: false,
        onSelected: (_) => setState(() => _filter = key),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        chip('ALL', 'Semua ($totalCount)'),
        chip('ACTIVE', 'Aktif ($activeCount)'),
        chip('COMPLETED', 'Selesai ($completedCount)'),
      ],
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
            'Goal & Target',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        body: const Center(
          child: Text(
            'Masuk untuk membuka goal.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    final repo = active.repository;
    final allGoals = repo.goals;
    final progressesById = <String, GoalProgress>{
      for (final goal in allGoals) goal['id'] as String: repo.progress(goal),
    };
    final activeCount = allGoals
        .where((g) => g['status'] != 'COMPLETED')
        .length;
    final completedCount = allGoals.length - activeCount;
    final filteredGoals = allGoals.where((g) {
      if (_filter == 'ACTIVE') return g['status'] != 'COMPLETED';
      if (_filter == 'COMPLETED') return g['status'] == 'COMPLETED';
      return true;
    }).toList();

    final groupNames = <String, String>{
      for (final g in repo.source.rows('groups'))
        if (g['id'] is String && g['name'] is String)
          g['id'] as String: g['name'] as String,
    };
    final accountNames = <String, String>{
      for (final a in repo.source.rows('accounts'))
        if (a['id'] is String && a['name'] is String)
          a['id'] as String: a['name'] as String,
    };

    final pending = repo.source.outbox
        .where((e) => ['goals', 'goal_allocations'].contains(e['entity_type']))
        .toList();
    final today = state.timeZone.calendarDate(DateTime.now());

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text(
          'Goal & Target',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Buat goal',
            onPressed: () => edit(),
            icon: const Icon(Icons.add_rounded),
          ),
          IconButton(
            tooltip: 'Sinkronkan goal',
            onPressed: state.loading
                ? null
                : () async {
                    await state.refresh();
                    if (mounted) setState(() {});
                  },
            icon: const Icon(Icons.sync_rounded),
          ),
          const SizedBox(width: 6),
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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            // 1. Hero Summary Card
            GoalsOverview(
              progresses: [
                for (final goal in allGoals) progressesById[goal['id']]!,
              ],
              hidden: state.isBalanceHidden,
              onCreate: () => edit(),
            ),

            // 2. Status / Feedback Banners
            if (!repo.complete)
              _buildBanner(
                icon: Icons.cloud_sync_rounded,
                text:
                    'Sinkronkan riwayat awal sebelum menambah alokasi. Goal pribadi dapat dibuat offline.',
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

            if (pending.isNotEmpty) ...[
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.sync_problem_rounded,
                          size: 16,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${pending.length} perubahan goal menunggu sinkronisasi / penyelesaian konflik.',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    for (final item in pending)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item['status']} — ${item['error'] ?? item['operation']}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
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
                  ],
                ),
              ),
            ],

            // 3. Goals Header + Filter Bar
            if (allGoals.isNotEmpty) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(
                    Icons.track_changes_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Target kamu',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildFilterBar(
                totalCount: allGoals.length,
                activeCount: activeCount,
                completedCount: completedCount,
              ),
              const SizedBox(height: 12),
            ],

            if (allGoals.isNotEmpty && filteredGoals.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 28,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.filter_list_off_rounded,
                      size: 32,
                      color: AppColors.textMuted.withValues(alpha: 0.6),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tidak ada goal pada filter ini.',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

            // 4. Goal Cards
            for (final goal in filteredGoals)
              _buildGoalCard(
                context: context,
                active: active,
                repo: repo,
                goal: goal,
                progress: progressesById[goal['id']]!,
                hidden: state.isBalanceHidden,
                groupNames: groupNames,
                accountNames: accountNames,
                today: today,
              ),

            // 5. Orphan Allocations (former household goals)
            for (final a in repo.allocations.where(
              (a) =>
                  a['user_id'] == repo.source.userId &&
                  !allGoals.any((g) => g['id'] == a['goal_id']) &&
                  goalMinor('${a['amount']}') > BigInt.zero,
            ))
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.warningLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.link_off_rounded,
                        size: 18,
                        color: AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Alokasi saya — goal tidak tersedia',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            state.isBalanceHidden
                                ? '••••••'
                                : CurrencyFormatter.formatCurrency(a['amount']),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          allocation(a['goal_id'] as String, existing: a),
                      child: const Text('Tarik alokasi'),
                    ),
                  ],
                ),
              ),

            // 6. Collapsible Allocation Guide (placed cleanly at the bottom)
            const SizedBox(height: 12),
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
                  'Cara kerja alokasi',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                children: [
                  Text(
                    'Alokasi bukan pengeluaran dan tidak mengunci kas. Dana yang sama dihitung sekali, alokasi tertua lebih dulu. Progres saya memakai saldo lokal; kontribusi anggota memakai snapshot server terakhir.',
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

  Widget _buildGoalCard({
    required BuildContext context,
    required GoalsController active,
    required GoalsRepository repo,
    required Map<String, dynamic> goal,
    required GoalProgress progress,
    required bool hidden,
    required Map<String, String> groupNames,
    required Map<String, String> accountNames,
    required DateTime today,
  }) {
    final currency = (goal['currency'] as String?) ?? 'IDR';
    String money(BigInt value) =>
        hidden ? '••••••' : _formatAmount(value, currency);

    final mine = goal['user_id'] == repo.source.userId;
    final isCompleted = goal['status'] == 'COMPLETED';
    final isAchievedOrDone = isCompleted || progress.achieved;

    final statusText = isCompleted
        ? 'Selesai'
        : progress.achieved
        ? 'Target tercapai'
        : progress.overdue
        ? 'Melewati tenggat'
        : progress.onTrack
        ? 'Sesuai jalur'
        : 'Tertinggal';

    final statusColor = isAchievedOrDone
        ? AppColors.income
        : progress.overdue
        ? AppColors.expense
        : progress.onTrack
        ? AppColors.primary
        : AppColors.warning;

    final groupId = goal['group_id'] as String?;
    final scopeLabel = groupId == null
        ? 'Pribadi — hanya saya'
        : 'Rumah tangga${groupNames[groupId] != null ? ' • ${groupNames[groupId]}' : ''}';
    final countdown = _countdownLabel(goal['target_date'] as String?, today);
    final goalAllocations = repo.allocations
        .where((a) => a['goal_id'] == goal['id'])
        .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isAchievedOrDone
              ? AppColors.income.withValues(alpha: 0.35)
              : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Icon + Name/Scope + Status Pill
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  isAchievedOrDone
                      ? Icons.emoji_events_rounded
                      : Icons.flag_rounded,
                  size: 22,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${goal['name']}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$scopeLabel • ${mine ? 'Saya pembuat' : 'Dibuat anggota'}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Progress Headline + Percentage
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Didukung saldo: ${money(progress.funded)}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Target ${money(progress.target)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (!hidden)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${progress.percent}%',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13.5,
                      color: statusColor,
                    ),
                  ),
                ),
            ],
          ),
          if (!hidden) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (progress.percent / 100).clamp(0.0, 1.0),
                minHeight: 9,
                backgroundColor: AppColors.surfaceVariant,
                color: statusColor,
              ),
            ),
          ],
          const SizedBox(height: 10),

          // Target date & Countdown strip
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 13,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Tenggat ${DateFormatter.calendarDate(goal['target_date'])}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (countdown.isNotEmpty && !isCompleted)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: progress.overdue
                        ? AppColors.expenseLight
                        : AppColors.infoLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    countdown,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: progress.overdue
                          ? AppColors.expense
                          : AppColors.info,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Structured 2-column metrics card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _MetricBlock(
                        label: 'Total alokasi',
                        value: money(progress.pledged),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 28,
                      color: AppColors.border,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    Expanded(
                      child: _MetricBlock(
                        label: 'Target nabung / bulan',
                        value: money(progress.monthly),
                      ),
                    ),
                  ],
                ),
                if (progress.shortfall > BigInt.zero) ...[
                  const Divider(height: 14, color: AppColors.borderSubtle),
                  Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 15,
                        color: AppColors.expense,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Kekurangan dukungan saldo: ${money(progress.shortfall)}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.expense,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const Divider(height: 14, color: AppColors.borderSubtle),
                Text(
                  'Patokan hari ini: ${money(progress.expected)} (sejak ${DateFormatter.calendarDate(goal['start_date'])})',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),

          // Allocations List
          if (goalAllocations.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Sumber alokasi',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            for (final a in goalAllocations)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      a['user_id'] == repo.source.userId
                          ? Icons.account_balance_wallet_rounded
                          : Icons.person_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a['user_id'] == repo.source.userId
                                ? 'Alokasi saya${accountNames[a['account_id']] != null ? ' • ${accountNames[a['account_id']]}' : ''}'
                                : 'Kontribusi anggota',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            hidden
                                ? '••••••'
                                : (currency == 'IDR'
                                      ? CurrencyFormatter.formatCurrency(
                                          a['amount'],
                                        )
                                      : '${a['amount']} $currency'),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                          if (a['user_id'] != repo.source.userId)
                            Text(
                              'Snapshot: ${DateFormatter.timestamp(a['backing_checked_at'], timeZone: AppStateScope.of(context).timeZone)}',
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: AppColors.textMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (a['user_id'] == repo.source.userId)
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                        ),
                        onPressed: () =>
                            allocation(goal['id'] as String, existing: a),
                        child: const Text(
                          'Ubah / tarik',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],

          const SizedBox(height: 12),

          // Action Row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accentLight,
                  foregroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                onPressed: () => allocation(goal['id'] as String),
                icon: const Icon(Icons.savings_rounded, size: 16),
                label: const Text(
                  'Alokasikan dana',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                ),
              ),
              if (mine) ...[
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  onPressed: () {
                    active.save(
                      () => repo.update(
                        goal['id'] as String,
                        name: goal['name'] as String,
                        target: goal['target_amount'] as String,
                        targetDate: goal['target_date'] as String,
                        status: isCompleted ? 'ACTIVE' : 'COMPLETED',
                      ),
                    );
                    setState(() {});
                  },
                  icon: Icon(
                    isCompleted
                        ? Icons.replay_rounded
                        : Icons.check_circle_rounded,
                    size: 16,
                  ),
                  label: Text(
                    isCompleted ? 'Buka kembali' : 'Tandai selesai',
                    style: const TextStyle(fontSize: 12.5),
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
                  onPressed: () => edit(goal: goal),
                  icon: const Icon(Icons.edit_rounded, size: 15),
                  label: const Text(
                    'Ubah goal',
                    style: TextStyle(fontSize: 12.5),
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.expense,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                  ),
                  onPressed: () => remove(goal),
                  icon: const Icon(Icons.archive_rounded, size: 15),
                  label: const Text(
                    'Arsipkan',
                    style: TextStyle(fontSize: 12.5),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricBlock extends StatelessWidget {
  final String label;
  final String value;

  const _MetricBlock({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
