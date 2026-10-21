import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../app/theme/app_colors.dart';
import '../../goals/data/goals_repository.dart';
import '../../obligations/pages/obligations_page.dart';
import '../data/bills_repository.dart';
import '../data/bills_controller.dart';

class BillsPage extends StatefulWidget {
  const BillsPage({super.key});
  @override
  State<BillsPage> createState() => _BillsPageState();
}

class _BillsPageState extends State<BillsPage> {
  BillsController? controller;
  bool older = false;
  String view = 'OPEN', message = '';
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppStateScope.of(context),
        source = state.repository,
        user = state.currentUserId;
    if (source == null || user.isEmpty || source.userId != user) {
      controller?.dispose();
      controller = null;
      message = '';
    } else if (!identical(controller?.repository.source, source)) {
      controller?.dispose();
      message = '';
      controller = BillsController(
        BillsRepository(source),
        () =>
            mounted &&
            identical(state.repository, source) &&
            state.currentUserId == user,
        state.billsSaved,
      );
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  Future<void> schedule({Map<String, dynamic>? bill}) async {
    final active = controller!, repo = active.repository;
    final title = TextEditingController(text: bill?['title'] as String?);
    final amount = TextEditingController(text: bill?['amount'] as String?);
    final anchor = TextEditingController(
      text: bill?['anchor_date'] as String? ?? goalDay(DateTime.now()),
    );
    final end = TextEditingController(text: bill?['end_date'] as String?);
    final days = TextEditingController(text: '${bill?['reminder_days'] ?? 3}');
    String type = '${bill?['transaction_type'] ?? 'EXPENSE'}',
        frequency = '${bill?['frequency'] ?? 'MONTHLY'}',
        amountType = '${bill?['amount_type'] ?? 'FIXED'}';
    String? account = bill?['account_id'] as String?,
        category = bill?['category_id'] as String?,
        debt = bill?['obligation_id'] as String?,
        error;
    int offset = bill?['utc_offset_minutes'] as int? ?? 420;
    bool enabled = bill?['reminder_enabled'] as bool? ?? true,
        isActive = bill?['active'] as bool? ?? true,
        saved = false;
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
              bill == null ? 'Buat jadwal' : 'Ubah pengingat / arsip',
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
                    controller: title,
                    maxLength: 120,
                    decoration: InputDecoration(
                      labelText: 'Judul',
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
                  if (bill == null) ...[
                    DropdownButtonFormField<String>(
                      initialValue: debt,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Cicilan pinjaman (opsional)',
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
                            'Transaksi rutin biasa',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        for (final d in repo.debts)
                          DropdownMenuItem(
                            value: d['id'] as String,
                            child: Text(
                              '${d['counterparty']}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) => update(() {
                        debt = v;
                        category = null;
                        if (v != null) {
                          final d = repo.debts.firstWhere(
                                (d) => d['id'] == v,
                              ),
                              first = (d['installments'] as List).first;
                          frequency = 'INSTALLMENTS';
                          type = d['kind'] == 'PAYABLE'
                              ? 'EXPENSE'
                              : 'INCOME';
                          amountType = 'FIXED';
                          amount.text = '${first['principal']}';
                          anchor.text = '${first['due_date']}';
                        } else {
                          frequency = 'MONTHLY';
                        }
                      }),
                    ),
                    const SizedBox(height: 10),
                    if (debt == null) ...[
                      DropdownButtonFormField<String>(
                        key: ValueKey('type:$type'),
                        initialValue: type,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Jenis transaksi',
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
                        items: const [
                          DropdownMenuItem(
                            value: 'EXPENSE',
                            child: Text('Pengeluaran'),
                          ),
                          DropdownMenuItem(
                            value: 'INCOME',
                            child: Text('Pemasukan'),
                          ),
                        ],
                        onChanged: (v) => update(() {
                          type = v!;
                          category = null;
                        }),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: amountType,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Nominal',
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
                        items: const [
                          DropdownMenuItem(
                            value: 'FIXED',
                            child: Text('Tetap'),
                          ),
                          DropdownMenuItem(
                            value: 'ESTIMATED',
                            child: Text(
                              'Perkiraan — isi aktual saat bayar',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        onChanged: (v) => update(() => amountType = v!),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: amount,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Nominal IDR bulat',
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
                      DropdownButtonFormField<String>(
                        key: ValueKey('frequency:$frequency'),
                        initialValue: frequency,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Pengulangan',
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
                          for (final f in [
                            'ONCE',
                            'WEEKLY',
                            'MONTHLY',
                            'YEARLY',
                          ])
                            DropdownMenuItem(value: f, child: Text(f)),
                        ],
                        onChanged: (v) => update(() => frequency = v!),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: anchor,
                        decoration: InputDecoration(
                          labelText: 'Tanggal awal (YYYY-MM-DD)',
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
                      TextField(
                        controller: end,
                        decoration: InputDecoration(
                          labelText: 'Tanggal akhir opsional (YYYY-MM-DD)',
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
                    ] else
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Tanggal dan pokok disalin dari cicilan pinjaman aktif. Catat pembayaran di Utang & Piutang, lalu tautkan buktinya; tidak dibuat pengeluaran baru.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    DropdownButtonFormField<String>(
                      initialValue: account,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Akun kas IDR milik saya',
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
                        for (final a in repo.accounts)
                          DropdownMenuItem(
                            value: a['id'] as String,
                            child: Text(
                              '${a['name']}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) => update(() => account = v),
                    ),
                    if (debt == null) ...[
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        key: ValueKey('category:$type:$category'),
                        initialValue: category,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Kategori',
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
                          for (final c in repo.categories(type))
                            DropdownMenuItem(
                              value: c['id'] as String,
                              child: Text(
                                '${c['name']}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (v) => update(() => category = v),
                      ),
                    ],
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      initialValue: offset,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Zona waktu tetap (tanpa DST)',
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
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('UTC')),
                        DropdownMenuItem(
                          value: 420,
                          child: Text('WIB (UTC+07)'),
                        ),
                        DropdownMenuItem(
                          value: 480,
                          child: Text('WITA (UTC+08)'),
                        ),
                        DropdownMenuItem(
                          value: 540,
                          child: Text('WIT (UTC+09)'),
                        ),
                      ],
                      onChanged: (v) => update(() => offset = v!),
                    ),
                  ] else
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Syarat finansial/tanggal tidak berubah. Untuk perubahan nominal, akun atau pengulangan, arsipkan seri ini dan buat seri baru. Riwayat lama tetap disimpan.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Jadwal aktif',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    value: isActive,
                    onChanged: (v) => update(() => isActive = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Pengingat dalam aplikasi',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    value: enabled,
                    onChanged: (v) => update(() => enabled = v),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: days,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Ingatkan sebelum jatuh tempo (0–30 hari)',
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
                    'Pengingat tampil saat aplikasi dibuka/disinkronkan. Tidak meminta izin notifikasi sistem, tidak dikirim saat aplikasi tertutup, dan tidak membuat transaksi otomatis. Bulanan/tahunan memakai tanggal asal yang dijepit pada akhir bulan.',
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
                        final data = <String, dynamic>{
                          'title': title.text,
                          'reminder_enabled': enabled,
                          'reminder_days': int.tryParse(days.text) ?? -1,
                        };
                        if (bill != null) {
                          data['active'] = isActive;
                        } else {
                          data.addAll({
                            'transaction_type': type,
                            'amount_type': amountType,
                            'amount': amount.text.trim(),
                            'account_id': account ?? '',
                            'category_id': category,
                            'obligation_id': debt,
                            'frequency': frequency,
                            'anchor_date': anchor.text.trim(),
                            'end_date': end.text.trim().isEmpty
                                ? null
                                : end.text.trim(),
                            'utc_offset_minutes': offset,
                          });
                        }
                        final ok = active.save(
                          () => repo.saveSchedule(
                            data,
                            id: bill?['id'] as String?,
                          ),
                        );
                        if (ok) {
                          saved = true;
                          Navigator.pop(ctx);
                        } else {
                          update(() => error = active.error);
                        }
                      },
                child: const Text('Simpan jadwal'),
              ),
            ],
          ),
        ),
      );
      await Navigator.of(context).push(route);
      await route.completed;
    } finally {
      title.dispose();
      amount.dispose();
      anchor.dispose();
      end.dispose();
      days.dispose();
    }
    if (mounted && identical(controller, active)) {
      setState(() {
        if (saved) {
          message =
              'Jadwal tersimpan lokal. Pembayaran tetap memerlukan konfirmasi.';
        }
      });
    }
  }

  Future<void> action(BillDueItem item, String action) async {
    final active = controller!, repo = active.repository;
    final actual = TextEditingController(text: item.amount),
        note = TextEditingController();
    String? recordId, error;
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
              action == 'PAY'
                  ? 'Konfirmasi pencatatan pembayaran'
                  : action == 'SKIP'
                  ? 'Lewati kejadian ini'
                  : action == 'REOPEN'
                  ? 'Buka kembali kejadian'
                  : 'Tautkan pembayaran yang sudah dicatat',
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
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${item.bill['title']} • ${item.date} • ${item.amount} IDR',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (action == 'PAY') ...[
                    TextField(
                      controller: actual,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Nominal aktual IDR bulat',
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
                    const Text(
                      'Membuat satu transaksi baru saat ini dan mengubah saldo kas. Jika sudah dicatat sebelumnya, batalkan lalu pilih Tautkan transaksi; jangan bayar dua kali.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                  if (action.startsWith('LINK_')) ...[
                    DropdownButtonFormField<String>(
                      initialValue: recordId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Bukti pembayaran yang sesuai',
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
                        for (final r in repo.linkable(item))
                          DropdownMenuItem(
                            value: r['id'] as String,
                            child: Text(
                              '${r['transacted_at']} • ${r['principal'] ?? r['amount']} IDR',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) => update(() => recordId = v),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Hanya menautkan bukti. Tidak mengurangi kas atau membuat transaksi lagi. Pembayaran cicilan besar dapat dibagi ke beberapa kejadian selama total pokoknya cukup.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                  if (action == 'REOPEN')
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        'Tidak mengubah uang. Pembayaran yang masih valid tidak dapat dibuka kembali. Koreksi dahulu melalui transaksi/Utang & Piutang bila perlu.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: note,
                    maxLength: 500,
                    decoration: InputDecoration(
                      labelText: action == 'SKIP'
                          ? 'Alasan wajib'
                          : 'Catatan opsional',
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
                          () => repo.command(
                            item,
                            action,
                            amount: actual.text.trim(),
                            recordId: recordId,
                            note: note.text,
                          ),
                        );
                        if (ok) {
                          saved = true;
                          Navigator.pop(ctx);
                        } else {
                          update(() => error = active.error);
                        }
                      },
                child: const Text('Konfirmasi'),
              ),
            ],
          ),
        ),
      );
      await Navigator.of(context).push(route);
      await route.completed;
    } finally {
      actual.dispose();
      note.dispose();
    }
    if (mounted && identical(controller, active)) {
      setState(() {
        if (saved) {
          message =
              'Kejadian tersimpan lokal; tunggu rekonsiliasi sebelum mengubah pembayaran lagi.';
        }
      });
    }
  }

  Future<void> cancelCommand(Map item) async {
    final active = controller!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        actionsOverflowButtonSpacing: 8,
        backgroundColor: Colors.white,
        title: const Text(
          'Ajukan pembatalan perintah?',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        content: const Text(
          'Server membatalkan hanya jika perintah belum pernah diterapkan. Pembayaran yang sudah masuk tidak dibalik; keadaan server akan dipulihkan ke perangkat.',
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
            child: const Text('Ajukan pembatalan'),
          ),
        ],
      ),
    );
    if (mounted && identical(controller, active) && ok == true) {
      active.save(
        () => active.repository.source.retryBillCommand(
          item['id'] as String,
          cancel: true,
        ),
      );
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context), active = controller;
    if (active == null || !active.isCurrent()) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Tagihan & Jadwal'),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: const Center(
          child: Text(
            'Masuk untuk membuka tagihan.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    final repo = active.repository;
    List<BillDueItem> entries = [];
    String? loadError;
    try {
      entries = repo.occurrences(older: older);
    } catch (e) {
      loadError = e.toString();
    }
    if (view == 'HISTORY') {
      entries = [
        for (final r in repo.records)
          if (repo.schedules.any((b) => b['id'] == r['bill_id']))
            BillDueItem(
              repo.schedules.firstWhere((b) => b['id'] == r['bill_id']),
              '${r['due_date']}',
              '${r['id']}',
              repo.status(
                r,
                repo.schedules.firstWhere((b) => b['id'] == r['bill_id']),
              ),
              '${r['amount']}',
              false,
              r,
            ),
      ];
      entries.sort((a, b) => b.date.compareTo(a.date));
    } else {
      entries = entries
          .where((o) => !['PAID', 'SKIPPED'].contains(o.status))
          .toList();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Tagihan & Jadwal'),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        actions: [
          IconButton(
            tooltip: 'Sinkronkan',
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
        onPressed: () => schedule(),
        label: const Text('Buat jadwal'),
        icon: const Icon(Icons.add),
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
                  Icons.event_repeat_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Pengingat dalam aplikasi, bukan pembayaran otomatis. Transaksi dicatat hanya setelah konfirmasi. Waktu jatuh tempo mengikuti zona tetap tiap jadwal; lewat tanggal berarti tertunggak.',
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
                  'Sinkronkan riwayat awal sebelum mencatat kejadian. Jadwal baru dapat disimpan offline.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.warning,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          if (message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                message,
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

          const SizedBox(height: 14),
          // Filter & View Controller
          Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: view,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Tampilan jadwal',
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
                    items: const [
                      DropdownMenuItem(
                        value: 'OPEN',
                        child: Text('Mendatang & lewat tempo'),
                      ),
                      DropdownMenuItem(
                        value: 'HISTORY',
                        child: Text('Riwayat pembayaran / dilewati'),
                      ),
                    ],
                    onChanged: (v) => setState(() => view = v!),
                  ),
                  if (view == 'OPEN') ...[
                    const SizedBox(height: 6),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Sertakan tunggakan lama sejak awal',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: const Text(
                        'Default: 12 bulan terakhir dan 60 hari mendatang. Jadwal sekali bayar selalu ditampilkan sampai selesai.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                      value: older,
                      onChanged: (v) => setState(() => older = v),
                    ),
                  ],
                ],
              ),
            ),
          ),

          if (loadError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                loadError,
                style: const TextStyle(color: AppColors.expense),
              ),
            ),

          for (final item in repo.queue)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item['entity_type']}: ${item['status']} — ${item['error'] ?? 'menunggu sinkronisasi'}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  if (item['entity_type'] == 'bill_schedules' &&
                      ['rejected', 'conflict'].contains(item['status']))
                    Wrap(
                      children: [
                        for (final discard in [false, true])
                          TextButton(
                            onPressed: () {
                              active.save(
                                () => repo.recoverSchedule(
                                  item['id'] as String,
                                  discard: discard,
                                ),
                              );
                              setState(() {});
                            },
                            child: Text(
                              discard
                                  ? 'Gunakan keadaan server'
                                  : 'Coba ulang jadwal',
                            ),
                          ),
                      ],
                    ),
                  if (item['entity_type'] == 'bill_commands' &&
                      [
                        'pending',
                        'conflict',
                        'rejected',
                      ].contains(item['status']))
                    Wrap(
                      children: [
                        TextButton(
                          onPressed: () {
                            active.save(
                              () => repo.source.retryBillCommand(
                                item['id'] as String,
                              ),
                            );
                            setState(() {});
                          },
                          child: const Text('Coba ulang'),
                        ),
                        if (item['server_data'] is Map)
                          TextButton(
                            onPressed: () {
                              active.save(
                                () => repo.source.retryBillCommand(
                                  item['id'] as String,
                                  useServer: true,
                                ),
                              );
                              setState(() {});
                            },
                            child: const Text('Gunakan keadaan server'),
                          ),
                        TextButton(
                          onPressed: () => cancelCommand(item),
                          child: const Text('Ajukan pembatalan'),
                        ),
                      ],
                    ),
                ],
              ),
            ),

          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'Tidak ada kejadian pada tampilan ini.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),

          const SizedBox(height: 12),
          for (final o in entries)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.015),
                    blurRadius: 6,
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
                          '${o.bill['title']}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (o.status == 'PAID')
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.income,
                          size: 20,
                        )
                      else if (o.overdue && o.status == 'PENDING')
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: AppColors.expense,
                          size: 20,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${o.date} • UTC${(o.bill['utc_offset_minutes'] as int) == 0 ? '' : '+${(o.bill['utc_offset_minutes'] as int) ~/ 60}'} • ${o.status}${o.overdue && o.status == 'PENDING' ? ' — lewat tempo' : ''}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    state.isBalanceHidden
                        ? '••••••'
                        : '${o.amount} IDR • ${o.bill['amount_type'] == 'FIXED' ? 'tetap' : 'perkiraan'}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  if (o.record?['note'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${o.record!['note']}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  if (!['PAID', 'SKIPPED'].contains(o.status) &&
                      o.bill['active'] == true) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (o.bill['obligation_id'] == null &&
                            o.status != 'NEEDS_REVIEW')
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
                            onPressed: () => action(o, 'PAY'),
                            child: const Text('Catat pembayaran'),
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
                          onPressed: () => action(
                            o,
                            o.bill['obligation_id'] == null
                                ? 'LINK_TRANSACTION'
                                : 'LINK_OBLIGATION',
                          ),
                          child: Text(
                            o.bill['obligation_id'] == null
                                ? 'Tautkan transaksi'
                                : 'Tautkan pembayaran pinjaman',
                          ),
                        ),
                        if (o.bill['obligation_id'] != null)
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
                            onPressed: () => Navigator.of(context).push<void>(
                              MaterialPageRoute(
                                builder: (_) => const ObligationsPage(),
                              ),
                            ),
                            child: const Text('Buka Utang & Piutang'),
                          ),
                        if (o.status == 'PENDING')
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.textMuted,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                            ),
                            onPressed: () => action(o, 'SKIP'),
                            child: const Text('Lewati'),
                          ),
                      ],
                    ),
                  ],
                  if (['SKIPPED', 'NEEDS_REVIEW'].contains(o.status)) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => action(o, 'REOPEN'),
                      child: const Text('Buka kembali kejadian'),
                    ),
                  ],
                ],
              ),
            ),

          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 6),
          const Text(
            'Seri jadwal',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          for (final bill in repo.schedules)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${bill['title']}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${bill['frequency']} • ${bill['active'] == true ? 'aktif' : 'diarsipkan'} • pengingat ${bill['reminder_enabled'] == true ? '${bill['reminder_days']} hari sebelum' : 'mati'}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => schedule(bill: bill),
                    child: const Text('Ubah / arsip'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
