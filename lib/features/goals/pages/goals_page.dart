import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../app/theme/app_colors.dart';
import '../data/goals_controller.dart';
import '../data/goals_repository.dart';

class GoalsPage extends StatefulWidget {
  const GoalsPage({super.key});
  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  GoalsController? controller;
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

  Future<void> edit({Map<String, dynamic>? goal}) async {
    final active = controller!;
    final repo = active.repository;
    final name = TextEditingController(text: goal?['name'] as String?);
    final target = TextEditingController(
      text: goal?['target_amount'] as String?,
    );
    final date = TextEditingController(
      text:
          goal?['target_date'] as String? ??
          goalDay(DateTime.now().toUtc().add(const Duration(days: 365))),
    );
    final currency = TextEditingController(
      text: goal?['currency'] as String? ?? 'IDR',
    );
    String? group = goal?['group_id'] as String?, error;
    bool saved = false;
    try {
      final route = DialogRoute<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, update) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            actionsOverflowButtonSpacing: 8,
            backgroundColor: Colors.white,
            title: Text(
              goal == null ? 'Buat goal' : 'Ubah goal',
              style: const TextStyle(
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
                  TextField(
                    controller: name,
                    maxLength: 120,
                    decoration: InputDecoration(
                      labelText: 'Nama goal',
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
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: target,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Target nominal (contoh: 1000000.00)',
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
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: currency,
                    enabled: goal == null,
                    maxLength: 3,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: 'Mata uang',
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
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: date,
                    decoration: InputDecoration(
                      labelText: 'Tanggal target UTC (YYYY-MM-DD)',
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
                  ),
                  if (goal == null) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: group,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Kepemilikan & visibilitas',
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
                                .where((g) => repo.member(g['id'] as String)))
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
                  const Text(
                    'Alokasi hanya menyisihkan dana; saldo tetap dapat dibelanjakan. Mata uang dan cakupan tidak berubah setelah dibuat.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
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
                onPressed: saved
                    ? null
                    : () {
                        final ok = active.save(() {
                          if (goal == null) {
                            repo.create(
                              name: name.text,
                              target: target.text.trim(),
                              currency: currency.text.trim().toUpperCase(),
                              targetDate: date.text.trim(),
                              groupId: group,
                            );
                          } else {
                            repo.update(
                              goal['id'] as String,
                              name: name.text,
                              target: target.text.trim(),
                              targetDate: date.text.trim(),
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
            ],
          ),
        ),
      );
      await Navigator.of(context).push(route);
      await route.completed;
    } finally {
      name.dispose();
      target.dispose();
      date.dispose();
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
      text: existing?['amount'] as String? ?? '0.00',
    );
    bool saved = false;
    final accounts = repo.cashAccounts
        .where((a) => goal != null && a['currency'] == goal['currency'])
        .toList();
    try {
      final route = DialogRoute<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, update) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            actionsOverflowButtonSpacing: 8,
            backgroundColor: Colors.white,
            title: const Text(
              'Atur alokasi dana',
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
                  if (existing == null) ...[
                    DropdownButtonFormField<String>(
                      initialValue: account,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Akun / kantong milik saya',
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
                        for (final a in accounts)
                          DropdownMenuItem(
                            value: a['id'] as String,
                            child: Text(
                              '${a['name']}',
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
                                  a['user_id'] == repo.source.userId,
                            )
                            .firstOrNull;
                        amount.text = '${old?['amount'] ?? '0.00'}';
                      }),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (account != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        'Dana belum dialokasikan: ${goalMoney(repo.available(account!))} ${goal?['currency'] ?? ''}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  TextField(
                    controller: amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Total alokasi dari akun ini',
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
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Isi total baru, bukan tambahan. Isi 0 untuk menarik alokasi. Tidak ada uang berpindah atau pengeluaran dibuat.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
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
                onPressed: saved
                    ? null
                    : () {
                        final ok = active.save(
                          () => repo.allocate(
                            goalId,
                            account ?? '',
                            amount.text.trim(),
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
            ],
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        actionsOverflowButtonSpacing: 8,
        backgroundColor: Colors.white,
        title: const Text(
          'Arsipkan goal?',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        content: const Text(
          'Seluruh alokasi goal ini dilepas setelah sinkronisasi diterima server. Saldo dan transaksi tidak berubah.',
          style: TextStyle(
            fontSize: 13,
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

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final active = controller;
    if (active == null || !active.isCurrent()) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Goal & Target'),
          backgroundColor: Colors.white,
          elevation: 0,
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
    final pending = repo.source.outbox
        .where((e) => ['goals', 'goal_allocations'].contains(e['entity_type']))
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Goal & Target'),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        actions: [
          IconButton(
            tooltip: 'Sinkronkan goal',
            onPressed: state.loading
                ? null
                : () async {
                    await state.refresh();
                    if (mounted) setState(() {});
                  },
            icon: const Icon(Icons.sync),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => edit(),
        icon: const Icon(Icons.add),
        label: const Text('Buat goal'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          // Header Info Banner
          Container(
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
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.flag_circle_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Alokasi bukan pengeluaran dan tidak mengunci kas. Dana yang sama dihitung sekali, alokasi tertua lebih dulu. Progres saya memakai saldo lokal; kontribusi anggota memakai snapshot server terakhir.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (!repo.complete)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                ),
                child: const Text(
                  'Sinkronkan riwayat awal sebelum menambah alokasi. Goal pribadi dapat dibuat offline.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.warning,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          if (message != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                message!,
                style: const TextStyle(
                  color: AppColors.income,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          if (active.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                active.error!,
                style: const TextStyle(color: AppColors.expense),
              ),
            ),
          if (state.dataError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                state.dataError!,
                style: const TextStyle(color: AppColors.expense),
              ),
            ),

          if (pending.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '${pending.length} perubahan goal menunggu sinkronisasi / penyelesaian konflik.',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            for (final item in pending)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item['status']} — ${item['error'] ?? item['operation']}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  if (['conflict', 'rejected'].contains(item['status']))
                    Wrap(
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

          if (repo.goals.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'Belum ada goal. Buat target pertama kamu.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),

          const SizedBox(height: 12),
          for (final goal in repo.goals)
            Builder(
              builder: (context) {
                final progress = repo.progress(goal);
                final hidden = state.isBalanceHidden;
                String money(BigInt value) => hidden
                    ? '••••••'
                    : '${goalMoney(value)} ${goal['currency']}';
                final mine = goal['user_id'] == repo.source.userId;

                final statusText = goal['status'] == 'COMPLETED'
                    ? 'Selesai (penanda pencapaian)'
                    : progress.achieved
                    ? 'Target tercapai'
                    : progress.overdue
                    ? 'Melewati tenggat'
                    : progress.onTrack
                    ? 'Sesuai jalur'
                    : 'Tertinggal';

                final statusColor = (goal['status'] == 'COMPLETED' || progress.achieved)
                    ? AppColors.income
                    : progress.overdue
                    ? AppColors.expense
                    : AppColors.primary;

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.015),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${goal['name']}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
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
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${goal['group_id'] == null ? 'Pribadi — hanya saya' : 'Rumah tangga — anggota aktif'} • ${mine ? 'Saya pembuat' : 'Dibuat anggota'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Target ${goal['target_date']} UTC • $statusText',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (!hidden) ...[
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progress.percent / 100,
                                  minHeight: 8,
                                  backgroundColor: AppColors.surfaceVariant,
                                  color: statusColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${progress.percent}%',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                      Text(
                        'Didukung saldo: ${money(progress.funded)} / ${money(progress.target)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Total alokasi: ${money(progress.pledged)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (progress.shortfall > BigInt.zero)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Kekurangan dukungan saldo: ${money(progress.shortfall)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.expense,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        'Perlu ${money(progress.monthly)} per bulan kalender tersisa (termasuk bulan ini).',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Patokan hari ini: ${money(progress.expected)}. Target dibagi linear sejak ${goal['start_date']} sampai tenggat, memakai hari UTC; bukan prediksi hasil investasi.',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final a in repo.allocations.where(
                        (a) => a['goal_id'] == goal['id'],
                      ))
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${a['user_id'] == repo.source.userId ? 'Alokasi saya' : 'Kontribusi anggota'}: ${hidden ? '••••••' : '${a['amount']} ${goal['currency']}'}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    if (a['user_id'] != repo.source.userId)
                                      Text(
                                        'Snapshot: ${a['backing_checked_at'] ?? 'belum tersedia'}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (a['user_id'] == repo.source.userId)
                                TextButton(
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                  ),
                                  onPressed: () => allocation(
                                    goal['id'] as String,
                                    existing: a,
                                  ),
                                  child: const Text('Ubah / tarik'),
                                ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          FilledButton.tonal(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.accentLight,
                              foregroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                            ),
                            onPressed: () => allocation(goal['id'] as String),
                            child: const Text('Alokasikan dana'),
                          ),
                          if (mine) ...[
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: const BorderSide(color: AppColors.border),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                              ),
                              onPressed: () => edit(goal: goal),
                              child: const Text('Ubah goal'),
                            ),
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: const BorderSide(color: AppColors.border),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                              ),
                              onPressed: () {
                                active.save(
                                  () => repo.update(
                                    goal['id'] as String,
                                    name: goal['name'] as String,
                                    target: goal['target_amount'] as String,
                                    targetDate: goal['target_date'] as String,
                                    status: goal['status'] == 'COMPLETED'
                                        ? 'ACTIVE'
                                        : 'COMPLETED',
                                  ),
                                );
                                setState(() {});
                              },
                              child: Text(
                                goal['status'] == 'COMPLETED'
                                    ? 'Buka kembali'
                                    : 'Tandai selesai',
                              ),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.expense,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                              ),
                              onPressed: () => remove(goal),
                              child: const Text('Arsipkan'),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),

          for (final a in repo.allocations.where(
            (a) =>
                a['user_id'] == repo.source.userId &&
                !repo.goals.any((g) => g['id'] == a['goal_id']) &&
                goalMinor('${a['amount']}') > BigInt.zero,
          ))
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Alokasi saya — goal tidak tersedia',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          state.isBalanceHidden ? '••••••' : '${a['amount']}',
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
        ],
      ),
    );
  }
}
