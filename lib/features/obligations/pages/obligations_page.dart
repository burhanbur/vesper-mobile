import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_state.dart';
import '../data/obligations_controller.dart';
import '../data/obligations_repository.dart';

class ObligationsPage extends StatefulWidget {
  const ObligationsPage({super.key});
  @override
  State<ObligationsPage> createState() => _ObligationsPageState();
}

class _ObligationsPageState extends State<ObligationsPage> {
  ObligationsController? controller;
  String? error;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppStateScope.of(context);
    final source = state.repository;
    final user = state.currentUserId;
    if (source == null || user.isEmpty || source.userId != user) {
      controller?.dispose();
      controller = null;
    } else if (!identical(controller?.repository.source, source)) {
      controller?.dispose();
      controller = ObligationsController(
        ObligationsRepository(source),
        () =>
            mounted &&
            identical(source, state.repository) &&
            user == state.currentUserId,
        state.obligationSaved,
      );
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  Future<void> form({Map<String, dynamic>? debt}) async {
    final active = controller!;
    final repo = active.repository;
    final counterparty = TextEditingController();
    final principal = TextEditingController();
    final interest = TextEditingController(text: '0');
    final fee = TextEditingController(text: '0');
    final due = TextEditingController();
    final schedule = TextEditingController();
    String kind = 'PAYABLE';
    String? cashId, mappedId, interestCategory, feeCategory, saveError;
    bool existing = true;
    bool savedOnce = false;
    try {
      await showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, update) {
            Widget accounts(
              String label,
              String? value,
              void Function(String?) change,
            ) => DropdownButtonFormField<String>(
              key: ValueKey('$label:$value'),
              initialValue: value,
              isExpanded: true,
              decoration: InputDecoration(labelText: label),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Tidak dipilih'),
                ),
                for (final account in repo.cashAccounts)
                  DropdownMenuItem(
                    value: account['id'] as String,
                    child: Text('${account['name']}'),
                  ),
              ],
              onChanged: (v) => update(() => change(v)),
            );
            Widget category(
              String label,
              String type,
              String? value,
              void Function(String?) change,
            ) => DropdownButtonFormField<String>(
              key: ValueKey('$label:$type:$value'),
              initialValue: value,
              isExpanded: true,
              decoration: InputDecoration(labelText: label),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Tidak dipilih'),
                ),
                for (final row
                    in repo.source
                        .rows('categories')
                        .where(
                          (r) =>
                              r['user_id'] == repo.source.userId &&
                              r['deleted_at'] == null &&
                              r['type'] == type,
                        ))
                  DropdownMenuItem(
                    value: row['id'] as String,
                    child: Text('${row['name']}'),
                  ),
              ],
              onChanged: (v) => update(() => change(v)),
            );
            Widget amount(TextEditingController c, String label) => TextField(
              controller: c,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(labelText: label),
            );
            return AlertDialog(
              title: Text(
                debt == null ? 'Catat utang / piutang' : 'Catat pembayaran',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'IDR • Form mendukung Rupiah bulat. Pokok tidak dihitung sebagai pemasukan/pengeluaran. Pecahan tidak dibulatkan.',
                    ),
                    if (debt == null) ...[
                      DropdownButtonFormField<String>(
                        initialValue: kind,
                        decoration: const InputDecoration(labelText: 'Jenis'),
                        items: const [
                          DropdownMenuItem(
                            value: 'PAYABLE',
                            child: Text('Utang saya'),
                          ),
                          DropdownMenuItem(
                            value: 'RECEIVABLE',
                            child: Text('Piutang saya'),
                          ),
                        ],
                        onChanged: (v) => update(() => kind = v!),
                      ),
                      TextField(
                        controller: counterparty,
                        decoration: const InputDecoration(
                          labelText: 'Nama pihak',
                        ),
                      ),
                      amount(principal, 'Pokok IDR'),
                      TextField(
                        controller: due,
                        decoration: const InputDecoration(
                          labelText: 'Jatuh tempo (YYYY-MM-DD, opsional)',
                        ),
                      ),
                      TextField(
                        controller: schedule,
                        minLines: 2,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Jadwal pokok cicilan (opsional)',
                          hintText: '2026-11-20=100.00\n2026-12-20=100.00',
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Saldo awal / pinjaman sudah berjalan',
                        ),
                        value: existing,
                        onChanged: (v) => update(() {
                          existing = v;
                          cashId = null;
                          mappedId = null;
                        }),
                      ),
                      if (existing) ...[
                        const Text(
                          'Tanpa arus kas baru. Jika saldo sudah tercatat sebagai akun lama, petakan akun tersebut agar tidak dihitung dua kali. Saldo utang harus negatif, piutang positif, sama dengan pokok.',
                        ),
                        accounts(
                          'Akun lama (opsional)',
                          mappedId,
                          (v) => mappedId = v,
                        ),
                      ] else ...[
                        const Text(
                          'Pendanaan baru akan menambah kas untuk utang atau mengurangi kas untuk piutang.',
                        ),
                        accounts(
                          'Akun kas pendanaan',
                          cashId,
                          (v) => cashId = v,
                        ),
                      ],
                    ] else ...[
                      Text('Pihak: ${debt['counterparty']}'),
                      accounts(
                        'Akun kas pembayaran',
                        cashId,
                        (v) => cashId = v,
                      ),
                      amount(principal, 'Pokok dibayar IDR'),
                      amount(interest, 'Bunga IDR'),
                      amount(fee, 'Biaya IDR'),
                      category(
                        'Kategori bunga',
                        debt['kind'] == 'PAYABLE' ? 'EXPENSE' : 'INCOME',
                        interestCategory,
                        (v) => interestCategory = v,
                      ),
                      category(
                        'Kategori biaya',
                        'EXPENSE',
                        feeCategory,
                        (v) => feeCategory = v,
                      ),
                      const Text(
                        'Bunga dan biaya memakai kategori masing-masing; untuk piutang, bunga diterima dan biaya dipotong dari penerimaan kas.',
                      ),
                    ],
                    if (saveError != null)
                      Text(
                        saveError!,
                        style: TextStyle(
                          color: Theme.of(ctx).colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Kembali'),
                ),
                FilledButton(
                  onPressed: () {
                    if (savedOnce) return;
                    final saved = active.save(
                      () {
                        if (debt == null) {
                          if (!existing && cashId == null) {
                            throw StateError('Pilih akun kas pendanaan.');
                          }
                          repo.open(
                            kind: kind,
                            counterparty: counterparty.text,
                            principal: principal.text,
                            dueDate: due.text,
                            installments: schedule.text,
                            cashAccountId: existing ? null : cashId,
                            linkedAccountId: mappedId,
                          );
                        } else {
                          if (cashId == null) {
                            throw StateError('Pilih akun kas pembayaran.');
                          }
                          repo.repay(
                            debt['id'] as String,
                            cashAccountId: cashId!,
                            principal: principal.text,
                            interest: interest.text,
                            fee: fee.text,
                            interestCategoryId: interestCategory,
                            feeCategoryId: feeCategory,
                          );
                        }
                      },
                      amounts: [
                        principal.text,
                        if (debt != null) ...[interest.text, fee.text],
                      ],
                      accountIds: [
                        if (cashId != null) cashId!,
                        if (mappedId != null) mappedId!,
                      ],
                    );
                    if (saved) {
                      savedOnce = true;
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Tersimpan lokal • menunggu sinkronisasi',
                          ),
                        ),
                      );
                    } else {
                      update(() => saveError = active.error);
                    }
                  },
                  child: const Text('Simpan lokal'),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final field in [
          counterparty,
          principal,
          interest,
          fee,
          due,
          schedule,
        ]) {
          field.dispose();
        }
      });
    }
  }

  Future<void> confirm(String message, void Function() save) async {
    final active = controller!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi perubahan'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Kembali'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Lanjutkan'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) active.save(save);
  }

  @override
  Widget build(BuildContext context) {
    final active = controller;
    final state = AppStateScope.of(context);
    String money(dynamic value) =>
        state.isBalanceHidden ? '••••••' : 'IDR $value';
    return Scaffold(
      appBar: AppBar(title: const Text('Utang & Piutang')),
      body: active == null
          ? const Center(child: Text('Silakan masuk kembali.'))
          : ListenableBuilder(
              listenable: active,
              builder: (context, _) {
                final repo = active.repository;
                final source = repo.source;
                final totals = repo.totals();
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Text(
                      'Catatan pribadi milik Anda. Saldo dan riwayat disimpan lokal; perintah tertunda termasuk dalam estimasi. Akun kas yang dibagikan tetap memperlihatkan arus kas kepada anggota yang berhak, tanpa rincian pinjaman.',
                    ),
                    if (!source.hasCompleteObligationHistory)
                      const Text(
                        'Selesaikan sinkronisasi awal sebelum mencatat pinjaman.',
                      ),
                    Text('Sisa utang: ${money(totals['payable'])}'),
                    Text('Sisa piutang: ${money(totals['receivable'])}'),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton(
                          onPressed: () => form(),
                          child: const Text('Tambah pinjaman'),
                        ),
                        OutlinedButton(
                          onPressed: source.isSyncing
                              ? null
                              : () async {
                                  try {
                                    await state.syncPendingNow();
                                  } catch (failure) {
                                    if (mounted) {
                                      setState(
                                        () => error = failure.toString(),
                                      );
                                    }
                                  }
                                  if (mounted) setState(() {});
                                },
                          child: const Text('Sinkronkan'),
                        ),
                      ],
                    ),
                    if (active.error != null) Text(active.error!),
                    if (error != null) Text(error!),
                    for (final queued in source.outbox.where(
                      (e) => e['entity_type'] == 'obligation_commands',
                    ))
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${queued['payload']['action']} • ${queued['status']}',
                              ),
                              if (queued['cancellation_requested'] == true)
                                const Text(
                                  'Memeriksa pembatalan atomik; saldo tetap sementara sampai hasil server lengkap.',
                                ),
                              if (queued['error'] != null)
                                Text('${queued['error']}'),
                              Wrap(
                                spacing: 8,
                                children: [
                                  TextButton(
                                    onPressed: () => active.save(
                                      () => source.retryObligationCommand(
                                        queued['id'] as String,
                                      ),
                                    ),
                                    child: const Text(
                                      'Coba ulang perintah asli',
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => confirm(
                                      'Server akan menghentikan perintah hanya jika belum diterapkan. Jika sudah diterapkan, hasil asli direkonsiliasi. Saldo lokal tetap sementara sampai verifikasi lengkap.',
                                      () => source.retryObligationCommand(
                                        queued['id'] as String,
                                        cancel: true,
                                      ),
                                    ),
                                    child: const Text(
                                      'Batalkan jika belum diproses',
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      await Clipboard.setData(
                                        ClipboardData(
                                          text: repo.recoveryReference(
                                            queued['id'] as String,
                                          ),
                                        ),
                                      );
                                    },
                                    child: const Text('Salin referensi'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (repo.records.isEmpty)
                      const Text('Belum ada pinjaman aktif.'),
                    for (final debt in repo.records)
                      Card(
                        child: ExpansionTile(
                          title: Text(
                            '${debt['kind'] == 'PAYABLE' ? 'Utang' : 'Piutang'} • ${debt['counterparty']}',
                          ),
                          subtitle: Text(
                            'Sisa ${money(debt['outstanding'])} • jatuh tempo ${debt['due_date'] ?? 'belum ditentukan'}',
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Pokok awal: ${money(debt['principal'])}',
                                  ),
                                  if (debt['linked_account_id'] != null)
                                    const Text(
                                      'Menggantikan akun lama dalam net worth; pelunasan pokok juga memperbarui akun tersebut.',
                                    ),
                                  for (final row in repo.schedule(
                                    debt['id'] as String,
                                  ))
                                    Text(
                                      '${row['due_date']} • sisa pokok cicilan ${money(row['remaining'])}',
                                    ),
                                  const Text(
                                    'Jadwal dialokasikan dari pembayaran pokok secara berurutan; bunga/biaya dicatat saat dibayar, tanpa pembayaran otomatis.',
                                  ),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      FilledButton(
                                        onPressed: () => form(debt: debt),
                                        child: const Text('Bayar / terima'),
                                      ),
                                      TextButton(
                                        onPressed: () => confirm(
                                          'Pinjaman lunas akan diarsipkan. Pinjaman tanpa pembayaran aktif dapat dibatalkan beserta arus kas pembukaannya. Riwayat audit tetap disimpan.',
                                          () =>
                                              repo.delete(debt['id'] as String),
                                        ),
                                        child: const Text(
                                          'Arsipkan / batalkan',
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Text(
                                    'Riwayat pembayaran & koreksi',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  for (final event in repo.events(
                                    debt['id'] as String,
                                  ))
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(
                                        '${event['operation']} • ${event['reversed_at'] == null ? event['transacted_at'] : 'DIBALIKKAN'}',
                                      ),
                                      subtitle: Text(
                                        'Pokok ${money(event['principal'])} • bunga ${money(event['interest'])} • biaya ${money(event['fee'])}',
                                      ),
                                      trailing:
                                          event['operation'] == 'REPAY' &&
                                              event['reversed_at'] == null
                                          ? TextButton(
                                              onPressed: () => confirm(
                                                'Balikkan pembayaran ini? Pokok, bunga, biaya, dan saldo terkait dikembalikan secara atomik; riwayat pembayaran tetap terlihat.',
                                                () => repo.reverse(
                                                  debt['id'] as String,
                                                  event['id'] as String,
                                                ),
                                              ),
                                              child: const Text('Koreksi'),
                                            )
                                          : null,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }
}
