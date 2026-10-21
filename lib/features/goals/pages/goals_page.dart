import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
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
            title: Text(goal == null ? 'Buat goal' : 'Ubah goal'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    maxLength: 120,
                    decoration: const InputDecoration(labelText: 'Nama goal'),
                  ),
                  TextField(
                    controller: target,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Target nominal (contoh: 1000000.00)',
                    ),
                  ),
                  TextField(
                    controller: currency,
                    enabled: goal == null,
                    maxLength: 3,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Mata uang'),
                  ),
                  TextField(
                    controller: date,
                    decoration: const InputDecoration(
                      labelText: 'Tanggal target UTC (YYYY-MM-DD)',
                    ),
                  ),
                  if (goal == null)
                    DropdownButtonFormField<String>(
                      initialValue: group,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Kepemilikan & visibilitas',
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Pribadi — hanya saya'),
                        ),
                        for (final g
                            in repo.source
                                .rows('groups')
                                .where((g) => repo.member(g['id'] as String)))
                          DropdownMenuItem(
                            value: g['id'] as String,
                            child: Text('Rumah tangga: ${g['name']}'),
                          ),
                      ],
                      onChanged: (v) => update(() => group = v),
                    ),
                  const Text(
                    'Alokasi hanya menyisihkan dana; saldo tetap dapat dibelanjakan. Mata uang dan cakupan tidak berubah setelah dibuat.',
                  ),
                  if (error != null)
                    Text(
                      error!,
                      style: TextStyle(color: Theme.of(ctx).colorScheme.error),
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
            title: const Text('Atur alokasi dana'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (existing == null)
                    DropdownButtonFormField<String>(
                      initialValue: account,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Akun / kantong milik saya',
                      ),
                      items: [
                        for (final a in accounts)
                          DropdownMenuItem(
                            value: a['id'] as String,
                            child: Text('${a['name']}'),
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
                  if (account != null)
                    Text(
                      'Dana belum dialokasikan: ${goalMoney(repo.available(account!))} ${goal?['currency'] ?? ''}',
                    ),
                  TextField(
                    controller: amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Total alokasi dari akun ini',
                    ),
                  ),
                  const Text(
                    'Isi total baru, bukan tambahan. Isi 0 untuk menarik alokasi. Tidak ada uang berpindah atau pengeluaran dibuat.',
                  ),
                  if (error != null)
                    Text(
                      error!,
                      style: TextStyle(color: Theme.of(ctx).colorScheme.error),
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
        title: const Text('Arsipkan goal?'),
        content: const Text(
          'Seluruh alokasi goal ini dilepas setelah sinkronisasi diterima server. Saldo dan transaksi tidak berubah.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
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
        appBar: AppBar(title: const Text('Goal & Target')),
        body: const Center(child: Text('Masuk untuk membuka goal.')),
      );
    }
    final repo = active.repository;
    final pending = repo.source.outbox
        .where((e) => ['goals', 'goal_allocations'].contains(e['entity_type']))
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Goal & Target'),
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
        onPressed: () => edit(),
        icon: const Icon(Icons.add),
        label: const Text('Buat goal'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          const Text(
            'Alokasi bukan pengeluaran dan tidak mengunci kas. Dana yang sama dihitung sekali, alokasi tertua lebih dulu. Progres saya memakai saldo lokal; kontribusi anggota memakai snapshot server terakhir.',
          ),
          if (!repo.complete)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Sinkronkan riwayat awal sebelum menambah alokasi. Goal pribadi dapat dibuat offline.',
              ),
            ),
          if (message != null) Text(message!),
          if (active.error != null)
            Text(
              active.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (state.dataError != null) Text(state.dataError!),
          if (pending.isNotEmpty) ...[
            Text(
              '${pending.length} perubahan goal menunggu sinkronisasi / penyelesaian konflik.',
            ),
            for (final item in pending)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item['status']} — ${item['error'] ?? item['operation']}',
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
              padding: EdgeInsets.all(24),
              child: Text('Belum ada goal. Buat target pertama kamu.'),
            ),
          for (final goal in repo.goals)
            Builder(
              builder: (context) {
                final progress = repo.progress(goal);
                final hidden = state.isBalanceHidden;
                String money(BigInt value) => hidden
                    ? '••••••'
                    : '${goalMoney(value)} ${goal['currency']}';
                final mine = goal['user_id'] == repo.source.userId;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${goal['name']}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${goal['group_id'] == null ? 'Pribadi — hanya saya' : 'Rumah tangga — anggota aktif'} • ${mine ? 'Saya pembuat' : 'Dibuat anggota'}',
                        ),
                        Text(
                          'Target ${goal['target_date']} UTC • ${goal['status'] == 'COMPLETED'
                              ? 'Selesai (penanda pencapaian)'
                              : progress.achieved
                              ? 'Target tercapai'
                              : progress.overdue
                              ? 'Melewati tenggat'
                              : progress.onTrack
                              ? 'Sesuai jalur'
                              : 'Tertinggal'}',
                        ),
                        if (!hidden) ...[
                          LinearProgressIndicator(
                            value: progress.percent / 100,
                          ),
                          Text('${progress.percent}%'),
                        ],
                        Text(
                          'Didukung saldo: ${money(progress.funded)} / ${money(progress.target)}',
                        ),
                        Text('Total alokasi: ${money(progress.pledged)}'),
                        if (progress.shortfall > BigInt.zero)
                          Text(
                            'Kekurangan dukungan saldo: ${money(progress.shortfall)}',
                          ),
                        Text(
                          'Perlu ${money(progress.monthly)} per bulan kalender tersisa (termasuk bulan ini).',
                        ),
                        Text(
                          'Patokan hari ini: ${money(progress.expected)}. Target dibagi linear sejak ${goal['start_date']} sampai tenggat, memakai hari UTC; bukan prediksi hasil investasi.',
                        ),
                        for (final a in repo.allocations.where(
                          (a) => a['goal_id'] == goal['id'],
                        ))
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              '${a['user_id'] == repo.source.userId ? 'Alokasi saya' : 'Kontribusi anggota'}: ${hidden ? '••••••' : '${a['amount']} ${goal['currency']}'}',
                            ),
                            subtitle: a['user_id'] != repo.source.userId
                                ? Text(
                                    'Snapshot: ${a['backing_checked_at'] ?? 'belum tersedia'}',
                                  )
                                : null,
                            trailing: a['user_id'] == repo.source.userId
                                ? TextButton(
                                    onPressed: () => allocation(
                                      goal['id'] as String,
                                      existing: a,
                                    ),
                                    child: const Text('Ubah / tarik'),
                                  )
                                : null,
                          ),
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton(
                              onPressed: () => allocation(goal['id'] as String),
                              child: const Text('Alokasikan dana'),
                            ),
                            if (mine) ...[
                              TextButton(
                                onPressed: () => edit(goal: goal),
                                child: const Text('Ubah goal'),
                              ),
                              TextButton(
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
                                onPressed: () => remove(goal),
                                child: const Text('Arsipkan'),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
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
            ListTile(
              title: const Text('Alokasi saya — goal tidak tersedia'),
              subtitle: Text(
                state.isBalanceHidden ? '••••••' : '${a['amount']}',
              ),
              trailing: TextButton(
                onPressed: () =>
                    allocation(a['goal_id'] as String, existing: a),
                child: const Text('Tarik alokasi'),
              ),
            ),
        ],
      ),
    );
  }
}
