import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_state.dart';
import '../../../app/theme/app_colors.dart';
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
              decoration: InputDecoration(
                labelText: label,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
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
              decoration: InputDecoration(
                labelText: label,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
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
              decoration: InputDecoration(
                labelText: label,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              backgroundColor: Colors.white,
              title: Text(
                debt == null ? 'Catat utang / piutang' : 'Catat pembayaran',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'IDR • Form mendukung Rupiah bulat. Pokok tidak dihitung sebagai pemasukan/pengeluaran. Pecahan tidak dibulatkan.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          height: 1.3,
                        ),
                      ),
                    ),
                    if (debt == null) ...[
                      DropdownButtonFormField<String>(
                        initialValue: kind,
                        decoration: InputDecoration(
                          labelText: 'Jenis',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
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
                      const SizedBox(height: 10),
                      TextField(
                        controller: counterparty,
                        decoration: InputDecoration(
                          labelText: 'Nama pihak',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      amount(principal, 'Pokok IDR'),
                      const SizedBox(height: 10),
                      TextField(
                        controller: due,
                        decoration: InputDecoration(
                          labelText: 'Jatuh tempo (YYYY-MM-DD, opsional)',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: schedule,
                        minLines: 2,
                        maxLines: 5,
                        decoration: InputDecoration(
                          labelText: 'Jadwal pokok cicilan (opsional)',
                          hintText: '2026-11-20=100.00\n2026-12-20=100.00',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Saldo awal / pinjaman sudah berjalan',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
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
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        accounts(
                          'Akun lama (opsional)',
                          mappedId,
                          (v) => mappedId = v,
                        ),
                      ] else ...[
                        const Text(
                          'Pendanaan baru akan menambah kas untuk utang atau mengurangi kas untuk piutang.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        accounts(
                          'Akun kas pendanaan',
                          cashId,
                          (v) => cashId = v,
                        ),
                      ],
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Pihak: ${debt['counterparty']}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      accounts(
                        'Akun kas pembayaran',
                        cashId,
                        (v) => cashId = v,
                      ),
                      const SizedBox(height: 10),
                      amount(principal, 'Pokok dibayar IDR'),
                      const SizedBox(height: 10),
                      amount(interest, 'Bunga IDR'),
                      const SizedBox(height: 10),
                      amount(fee, 'Biaya IDR'),
                      const SizedBox(height: 10),
                      category(
                        'Kategori bunga',
                        debt['kind'] == 'PAYABLE' ? 'EXPENSE' : 'INCOME',
                        interestCategory,
                        (v) => interestCategory = v,
                      ),
                      const SizedBox(height: 10),
                      category(
                        'Kategori biaya',
                        'EXPENSE',
                        feeCategory,
                        (v) => feeCategory = v,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Bunga dan biaya memakai kategori masing-masing; untuk piutang, bunga diterima dan biaya dipotong dari penerimaan kas.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                    if (saveError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          saveError!,
                          style: TextStyle(
                            color: Theme.of(ctx).colorScheme.error,
                            fontSize: 12,
                          ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: const Text(
          'Konfirmasi perubahan',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Utang & Piutang',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: active == null
          ? const Center(
              child: Text(
                'Silakan masuk kembali.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          : ListenableBuilder(
              listenable: active,
              builder: (context, _) {
                final repo = active.repository;
                final source = repo.source;
                final totals = repo.totals();
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(12),
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
                              'Catatan pribadi milik Anda. Saldo dan riwayat disimpan lokal; perintah tertunda termasuk dalam estimasi. Akun kas yang dibagikan tetap memperlihatkan arus kas kepada anggota yang berhak, tanpa rincian pinjaman.',
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
                    if (!source.hasCompleteObligationHistory) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.warningLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Selesaikan sinkronisasi awal sebelum mencatat pinjaman.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.warning,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),

                    // Summary Cards for Utang & Piutang
                    Row(
                      children: [
                        Expanded(
                          child: Container(
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
                                        color: AppColors.expenseLight,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.arrow_upward_rounded,
                                        size: 14,
                                        color: AppColors.expense,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Utang',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Sisa utang: ${money(totals['payable'])}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
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
                                        color: AppColors.incomeLight,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.arrow_downward_rounded,
                                        size: 14,
                                        color: AppColors.income,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Piutang',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Sisa piutang: ${money(totals['receivable'])}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: () => form(),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Tambah pinjaman'),
                        ),
                        OutlinedButton.icon(
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
                          icon: const Icon(Icons.sync_rounded, size: 16),
                          label: const Text('Sinkronkan'),
                        ),
                      ],
                    ),
                    if (active.error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          active.error!,
                          style: const TextStyle(color: AppColors.expense),
                        ),
                      ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          error!,
                          style: const TextStyle(color: AppColors.expense),
                        ),
                      ),
                    for (final queued in source.outbox.where(
                      (e) => e['entity_type'] == 'obligation_commands',
                    ))
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        color: Colors.white,
                        margin: const EdgeInsets.only(top: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${queued['payload']['action']} • ${queued['status']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (queued['cancellation_requested'] == true)
                                const Padding(
                                  padding: EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Memeriksa pembatalan atomik; saldo tetap sementara sampai hasil server lengkap.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.warning,
                                    ),
                                  ),
                                ),
                              if (queued['error'] != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    '${queued['error']}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.expense,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 6),
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
                    const SizedBox(height: 8),
                    if (repo.records.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 36,
                          horizontal: 16,
                        ),
                        alignment: Alignment.center,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration(
                                color: AppColors.surfaceVariant,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.handshake_outlined,
                                size: 36,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Belum ada pinjaman aktif.',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Catat utang atau piutang dengan menekan tombol Tambah pinjaman.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    for (final debt in repo.records)
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        color: Colors.white,
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ExpansionTile(
                          shape: const Border(),
                          collapsedShape: const Border(),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: debt['kind'] == 'PAYABLE'
                                  ? AppColors.expenseLight
                                  : AppColors.incomeLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              debt['kind'] == 'PAYABLE'
                                  ? Icons.arrow_upward_rounded
                                  : Icons.arrow_downward_rounded,
                              size: 18,
                              color: debt['kind'] == 'PAYABLE'
                                  ? AppColors.expense
                                  : AppColors.income,
                            ),
                          ),
                          title: Text(
                            '${debt['kind'] == 'PAYABLE' ? 'Utang' : 'Piutang'} • ${debt['counterparty']}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            'Sisa ${money(debt['outstanding'])} • jatuh tempo ${debt['due_date'] ?? 'belum ditentukan'}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Divider(),
                                  Text(
                                    'Pokok awal: ${money(debt['principal'])}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (debt['linked_account_id'] != null)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 4),
                                      child: Text(
                                        'Menggantikan akun lama dalam net worth; pelunasan pokok juga memperbarui akun tersebut.',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ),
                                  for (final row in repo.schedule(
                                    debt['id'] as String,
                                  ))
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        '${row['due_date']} • sisa pokok cicilan ${money(row['remaining'])}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 6),
                                    child: Text(
                                      'Jadwal dialokasikan dari pembayaran pokok secara berurutan; bunga/biaya dicatat saat dibayar, tanpa pembayaran otomatis.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
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
                                  const SizedBox(height: 10),
                                  const Text(
                                    'Riwayat pembayaran & koreksi',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  for (final event in repo.events(
                                    debt['id'] as String,
                                  ))
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(
                                        '${event['operation']} • ${event['reversed_at'] == null ? event['transacted_at'] : 'DIBALIKKAN'}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                      subtitle: Text(
                                        'Pokok ${money(event['principal'])} • bunga ${money(event['interest'])} • biaya ${money(event['fee'])}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
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
