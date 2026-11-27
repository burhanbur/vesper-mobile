import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/currency_amount_input.dart';
import '../../../core/widgets/nominal_quick_keys.dart';
import '../../../app/theme/app_colors.dart';
import '../../goals/data/goals_repository.dart';
import '../../obligations/data/obligations_repository.dart';
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
  int _selectedTab = 0; // 0: Tagihan, 1: Seri Jadwal

  static String _frequencyLabel(Object? raw) => switch (raw?.toString()) {
    'ONCE' => 'Sekali bayar',
    'WEEKLY' => 'Mingguan',
    'MONTHLY' => 'Bulanan',
    'YEARLY' => 'Tahunan',
    _ => '${raw ?? '-'}',
  };
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

  Future<bool> confirmAndDeleteSchedule(
    Map<String, dynamic> bill, {
    BuildContext? sheetContext,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Hapus Jadwal Tagihan?'),
        content: Text(
          'Jadwal "${bill['title']}" akan dihapus. Riwayat transaksi yang sudah dicatat sebelumnya tidak akan terhapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.expense,
            ),
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final active = controller!, repo = active.repository;
      final ok = active.save(() => repo.deleteSchedule(bill['id'] as String));
      if (ok) {
        if (sheetContext != null && sheetContext.mounted) {
          Navigator.pop(sheetContext);
        }
        if (mounted) {
          setState(() {
            message = 'Jadwal tagihan berhasil dihapus.';
          });
        }
        return true;
      }
    }
    return false;
  }

  Future<void> schedule({Map<String, dynamic>? bill}) async {
    final active = controller!, repo = active.repository;
    final state = AppStateScope.of(context);
    final title = TextEditingController(text: bill?['title'] as String?);
    final amount = TextEditingController(
      text: CurrencyAmountInput.fromDecimal(bill?['amount'] as String? ?? ''),
    );
    final initialFeeRaw = '${bill?['admin_fee'] ?? ''}'.trim();
    final hasInitialFee =
        initialFeeRaw.isNotEmpty &&
        !RegExp(r'^0+(?:\.0+)?$').hasMatch(initialFeeRaw);
    final adminFee = TextEditingController(
      text: hasInitialFee ? CurrencyAmountInput.fromDecimal(initialFeeRaw) : '',
    );
    final preferredOffset = AppStateScope.of(context).timeZone
        .offsetMinutesAt(DateTime.now());
    final defaultOffset = [0, 420, 480, 540].contains(preferredOffset)
        ? preferredOffset
        : 0;
    final anchor = TextEditingController(
      text:
          bill?['anchor_date'] as String? ??
          goalDay(DateTime.now().toUtc().add(Duration(minutes: defaultOffset))),
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
    int offset = bill?['utc_offset_minutes'] as int? ?? defaultOffset;
    bool enabled = bill?['reminder_enabled'] as bool? ?? true,
        isActive = bill?['active'] as bool? ?? true,
        saved = false;
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
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
                        child: Row(
                          children: [
                            Text(
                              bill == null ? 'Buat jadwal' : 'Ubah pengingat / arsip',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            if (bill != null)
                              IconButton(
                                tooltip: 'Hapus jadwal',
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: AppColors.expense,
                                  size: 22,
                                ),
                                onPressed: () => confirmAndDeleteSchedule(
                                  bill,
                                  sheetContext: ctx,
                                ),
                              ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 20),
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
                                      final d = repo.debts.firstWhere((d) => d['id'] == v),
                                          first = (d['installments'] as List).first;
                                      frequency = 'INSTALLMENTS';
                                      type = d['kind'] == 'PAYABLE' ? 'EXPENSE' : 'INCOME';
                                      amountType = 'FIXED';
                                      amount.text = CurrencyAmountInput.fromDecimal(
                                        '${first['principal']}',
                                      );
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
                                    inputFormatters: const [CurrencyAmountInput()],
                                    keyboardType: const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'Nominal IDR bulat',
                                      prefixText: 'Rp ',
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
                                  NominalQuickKeys(
                                    controller: amount,
                                    mode: NominalFormatMode.currencyAmountInput,
                                    keyPrefix: 'bill_amount',
                                  ),
                                  if (type == 'EXPENSE') ...[
                                    const SizedBox(height: 10),
                                    TextField(
                                      key: const ValueKey(
                                        'bill_admin_fee_input',
                                      ),
                                      controller: adminFee,
                                      inputFormatters: const [
                                        CurrencyAmountInput(),
                                      ],
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      decoration: InputDecoration(
                                        labelText: 'Biaya admin (opsional)',
                                        hintText: '0 (jika gratis)',
                                        prefixText: 'Rp ',
                                        labelStyle: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 13,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 12,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 8,
                                      children: [
                                        for (final preset in [2500, 6500])
                                          ActionChip(
                                            visualDensity:
                                                VisualDensity.compact,
                                            backgroundColor: Colors.white,
                                            side: const BorderSide(
                                              color: AppColors.border,
                                            ),
                                            label: Text(
                                              CurrencyFormatter.formatRupiah(
                                                preset,
                                              ),
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            onPressed: () {
                                              update(() {
                                                final text = CurrencyAmountInput
                                                    .fromDecimal('$preset');
                                                adminFee.value =
                                                    TextEditingValue(
                                                      text: text,
                                                      selection:
                                                          TextSelection.collapsed(
                                                            offset: text.length,
                                                          ),
                                                    );
                                              });
                                            },
                                          ),
                                      ],
                                    ),
                                  ],
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
                                        DropdownMenuItem(
                                          value: f,
                                          child: Text(_frequencyLabel(f)),
                                        ),
                                    ],
                                    onChanged: (v) => update(() => frequency = v!),
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: anchor,
                                    readOnly: true,
                                    onTap: () async {
                                      final current = DateTime.tryParse(anchor.text) ?? DateTime.now();
                                      final picked = await showDatePicker(
                                        context: ctx,
                                        initialDate: current,
                                        firstDate: DateTime(2000),
                                        lastDate: DateTime(2100),
                                        helpText: 'PILIH TANGGAL AWAL',
                                      );
                                      if (picked != null) {
                                        update(() {
                                          anchor.text = goalDay(picked);
                                        });
                                      }
                                    },
                                    decoration: InputDecoration(
                                      labelText: 'Tanggal mulai',
                                      helperText: anchor.text.isNotEmpty
                                          ? DateFormatter.calendarDate(anchor.text)
                                          : null,
                                      prefixIcon: const Icon(
                                        Icons.calendar_today_rounded,
                                        size: 18,
                                        color: AppColors.primary,
                                      ),
                                      suffixIcon: const Icon(
                                        Icons.arrow_drop_down_rounded,
                                        size: 24,
                                        color: AppColors.textSecondary,
                                      ),
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
                                    readOnly: true,
                                    onTap: () async {
                                      final current = DateTime.tryParse(end.text) ??
                                          (DateTime.tryParse(anchor.text) ?? DateTime.now());
                                      final picked = await showDatePicker(
                                        context: ctx,
                                        initialDate: current,
                                        firstDate: DateTime(2000),
                                        lastDate: DateTime(2100),
                                        helpText: 'PILIH TANGGAL AKHIR',
                                      );
                                      if (picked != null) {
                                        update(() {
                                          end.text = goalDay(picked);
                                        });
                                      }
                                    },
                                    decoration: InputDecoration(
                                      labelText: 'Tanggal berakhir (opsional)',
                                      hintText: 'Pilih tanggal selesai',
                                      helperText: end.text.isNotEmpty
                                          ? DateFormatter.calendarDate(end.text)
                                          : null,
                                      prefixIcon: const Icon(
                                        Icons.event_rounded,
                                        size: 18,
                                        color: AppColors.textSecondary,
                                      ),
                                      suffixIcon: end.text.isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(
                                                Icons.clear_rounded,
                                                size: 18,
                                                color: AppColors.textSecondary,
                                              ),
                                              tooltip: 'Hapus tanggal akhir',
                                              onPressed: () => update(() => end.clear()),
                                            )
                                          : const Icon(
                                              Icons.arrow_drop_down_rounded,
                                              size: 24,
                                              color: AppColors.textSecondary,
                                            ),
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
                                          state.accountDisplayNameById(
                                            a['id'] as String,
                                            fallback: '${a['name']}',
                                          ),
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
                                    DropdownMenuItem(value: 0, child: Text('GMT+00:00')),
                                    DropdownMenuItem(value: 420, child: Text('WIB')),
                                    DropdownMenuItem(value: 480, child: Text('WITA')),
                                    DropdownMenuItem(value: 540, child: Text('WIT')),
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
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                value: isActive,
                                onChanged: (v) => update(() => isActive = v),
                              ),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                  'Pengingat dalam aplikasi',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
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
                              if (bill != null) ...[
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.expense,
                                      side: const BorderSide(
                                        color: AppColors.expense,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      size: 18,
                                    ),
                                    label: const Text('Hapus jadwal ini'),
                                    onPressed: () => confirmAndDeleteSchedule(
                                      bill,
                                      sheetContext: ctx,
                                    ),
                                  ),
                                ),
                              ],
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
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(ctx),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
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
                                  padding: const EdgeInsets.symmetric(vertical: 14),
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
                                          if (bill['transaction_type'] ==
                                                  'EXPENSE' &&
                                              bill['obligation_id'] == null) {
                                            data['admin_fee'] = adminFee.text
                                                    .trim()
                                                    .isEmpty
                                                ? '0.00'
                                                : CurrencyAmountInput.toDecimal(
                                                    adminFee.text.trim(),
                                                  );
                                          }
                                        } else {
                                          data.addAll({
                                            'transaction_type': type,
                                            'amount_type': amountType,
                                            'amount': CurrencyAmountInput.toDecimal(
                                              amount.text.trim(),
                                            ),
                                            'admin_fee':
                                                (type == 'EXPENSE' &&
                                                    debt == null &&
                                                    adminFee.text
                                                        .trim()
                                                        .isNotEmpty)
                                                ? CurrencyAmountInput.toDecimal(
                                                    adminFee.text.trim(),
                                                  )
                                                : '0.00',
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
      title.dispose();
      amount.dispose();
      adminFee.dispose();
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
    final state = AppStateScope.of(context);
    final actual = TextEditingController(
      text: CurrencyAmountInput.fromDecimal(item.amount),
    );
    final defaultFeeRaw = '${item.bill['admin_fee'] ?? ''}'.trim();
    final hasDefaultFee =
        defaultFeeRaw.isNotEmpty &&
        !RegExp(r'^0+(?:\.0+)?$').hasMatch(defaultFeeRaw);
    final adminFee = TextEditingController(
      text: hasDefaultFee ? CurrencyAmountInput.fromDecimal(defaultFeeRaw) : '',
    );
    final note = TextEditingController();
    String? recordId, error;
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
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
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
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 20),
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
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceVariant.withValues(
                                    alpha: 0.7,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppColors.accentLight,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.receipt_long_rounded,
                                        size: 18,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${item.bill['title']}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${DateFormatter.calendarDate(item.date)} • ${state.accountDisplayNameById(item.bill['account_id'] as String?, fallback: '-')}',
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              color: AppColors.textSecondary,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          CurrencyFormatter.formatCurrency(
                                            item.amount,
                                          ),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        if (hasDefaultFee &&
                                            item.bill['transaction_type'] ==
                                                'EXPENSE')
                                          Text(
                                            '+ Admin ${CurrencyFormatter.formatCurrency(defaultFeeRaw)}',
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (action == 'PAY') ...[
                                TextField(
                                  controller: actual,
                                  inputFormatters: const [CurrencyAmountInput()],
                                  keyboardType: const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Nominal aktual IDR bulat',
                                    prefixText: 'Rp ',
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
                                NominalQuickKeys(
                                  controller: actual,
                                  mode: NominalFormatMode.currencyAmountInput,
                                  keyPrefix: 'bill_pay_amount',
                                ),
                                if (item.bill['transaction_type'] ==
                                    'EXPENSE') ...[
                                  const SizedBox(height: 10),
                                  TextField(
                                    key: const ValueKey(
                                      'bill_pay_admin_fee_input',
                                    ),
                                    controller: adminFee,
                                    inputFormatters: const [
                                      CurrencyAmountInput(),
                                    ],
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: InputDecoration(
                                      labelText: 'Biaya admin (opsional)',
                                      hintText: '0 (jika gratis)',
                                      prefixText: 'Rp ',
                                      labelStyle: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 13,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 12,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      for (final preset in [2500, 6500])
                                        ActionChip(
                                          visualDensity: VisualDensity.compact,
                                          backgroundColor: Colors.white,
                                          side: const BorderSide(
                                            color: AppColors.border,
                                          ),
                                          label: Text(
                                            CurrencyFormatter.formatRupiah(
                                              preset,
                                            ),
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          onPressed: () {
                                            update(() {
                                              final text = CurrencyAmountInput
                                                  .fromDecimal('$preset');
                                              adminFee.value = TextEditingValue(
                                                text: text,
                                                selection:
                                                    TextSelection.collapsed(
                                                      offset: text.length,
                                                    ),
                                              );
                                            });
                                          },
                                        ),
                                    ],
                                  ),
                                ],
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
                                const Text(
                                  'Pilih bukti pembayaran yang sesuai',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Builder(
                                  builder: (_) {
                                    final candidates = repo.linkable(item)
                                      ..sort(
                                        (a, b) => '${b['transacted_at'] ?? ''}'
                                            .compareTo(
                                              '${a['transacted_at'] ?? ''}',
                                            ),
                                      );
                                    if (candidates.isEmpty) {
                                      return Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceVariant
                                              .withValues(alpha: 0.5),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: AppColors.border,
                                          ),
                                        ),
                                        child: const Row(
                                          children: [
                                            Icon(
                                              Icons.info_outline_rounded,
                                              size: 16,
                                              color: AppColors.textMuted,
                                            ),
                                            SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Belum ada transaksi cocok yang dapat ditautkan untuk akun dan kategori ini.',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }
                                    return Column(
                                      children: [
                                        for (final r in candidates)
                                          Builder(
                                            builder: (_) {
                                              final id = r['id'] as String;
                                              final selected = recordId == id;
                                              final rawDesc =
                                                  '${r['description'] ?? r['note'] ?? ''}'
                                                      .trim();
                                              final titleText =
                                                  rawDesc.isNotEmpty
                                                  ? rawDesc
                                                  : '${item.bill['title']}';
                                              final accId =
                                                  (r['account_id'] ??
                                                          r['cash_account_id'] ??
                                                          item.bill['account_id'])
                                                      as String?;
                                              final accLabel = state
                                                  .accountDisplayNameById(
                                                    accId,
                                                  );
                                              final timeText =
                                                  DateFormatter.timestamp(
                                                    r['transacted_at'],
                                                    timeZone: state.timeZone,
                                                  );
                                              final formattedNominal =
                                                  CurrencyFormatter.formatCurrency(
                                                    r['principal'] ??
                                                        r['amount'],
                                                  );
                                              return Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 8,
                                                ),
                                                child: Material(
                                                  color: selected
                                                      ? AppColors.primary
                                                            .withValues(
                                                              alpha: 0.06,
                                                            )
                                                      : Colors.white,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          14,
                                                        ),
                                                    side: BorderSide(
                                                      color: selected
                                                          ? AppColors.primary
                                                          : AppColors.border,
                                                      width: selected
                                                          ? 1.5
                                                          : 1.0,
                                                    ),
                                                  ),
                                                  clipBehavior: Clip.antiAlias,
                                                  child: InkWell(
                                                    key: ValueKey(
                                                      'link_candidate_$id',
                                                    ),
                                                    onTap: () => update(
                                                      () => recordId = id,
                                                    ),
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 12,
                                                            vertical: 10,
                                                          ),
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                            selected
                                                                ? Icons
                                                                      .radio_button_checked_rounded
                                                                : Icons
                                                                      .radio_button_off_rounded,
                                                            size: 20,
                                                            color: selected
                                                                ? AppColors
                                                                      .primary
                                                                : AppColors
                                                                      .textMuted,
                                                          ),
                                                          const SizedBox(
                                                            width: 10,
                                                          ),
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Text(
                                                                  titleText,
                                                                  maxLines: 1,
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                  style: const TextStyle(
                                                                    fontSize:
                                                                        13,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w700,
                                                                    color: AppColors
                                                                        .textPrimary,
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  height: 2,
                                                                ),
                                                                Text(
                                                                  [
                                                                    timeText,
                                                                    if (accLabel
                                                                        .isNotEmpty)
                                                                      accLabel,
                                                                  ].join(' • '),
                                                                  maxLines: 1,
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                  style: const TextStyle(
                                                                    fontSize:
                                                                        11,
                                                                    color: AppColors
                                                                        .textSecondary,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                          Text(
                                                            formattedNominal,
                                                            style: TextStyle(
                                                              fontSize: 13,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w800,
                                                              color: selected
                                                                  ? AppColors
                                                                        .primary
                                                                  : AppColors
                                                                        .textPrimary,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 6),
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
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(ctx),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
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
                                  padding: const EdgeInsets.symmetric(vertical: 14),
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
                                            amount: CurrencyAmountInput.toDecimal(
                                              actual.text.trim(),
                                            ),
                                            adminFee:
                                                action == 'PAY' &&
                                                    item.bill['transaction_type'] ==
                                                        'EXPENSE' &&
                                                    adminFee.text
                                                        .trim()
                                                        .isNotEmpty
                                                ? CurrencyAmountInput.toDecimal(
                                                    adminFee.text.trim(),
                                                  )
                                                : null,
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
      actual.dispose();
      adminFee.dispose();
      note.dispose();
    }
    if (mounted && identical(controller, active)) {
      setState(() {
        if (saved) {
          message = 'Kejadian tersimpan lokal; tunggu rekonsiliasi sebelum mengubah pembayaran lagi.';
        }
      });
    }
  }

  Future<void> cancelCommand(Map item) async {
    final active = controller!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
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
          backgroundColor: AppColors.background,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: const Text(
            'Tagihan & Jadwal',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: AppColors.textPrimary,
            ),
          ),
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

    final activeSchedulesCount = repo.schedules
        .where((s) => s['active'] == true)
        .length;
    var heroTotalMinor = BigInt.zero;
    var overdueCount = 0;
    for (final item in entries) {
      if (view == 'HISTORY' ||
          (item.status != 'PAID' && item.status != 'SKIPPED')) {
        heroTotalMinor += obligationMinor(item.amount);
        if (view != 'HISTORY' && item.overdue) overdueCount++;
      }
    }

    Widget banner({
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text(
          'Tagihan & Jadwal',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Buat jadwal',
            onPressed: () => schedule(),
            icon: const Icon(Icons.add_rounded),
          ),
          IconButton(
            tooltip: 'Sinkronkan',
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
            // 1. Clean Hero Summary Card
            Container(
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
                  Row(
                    children: [
                      const Icon(
                        Icons.event_repeat_rounded,
                        size: 15,
                        color: AppColors.accentLight,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          view == 'HISTORY'
                              ? 'RIWAYAT TAGIHAN'
                              : 'TAGIHAN TERJADWAL',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      if (overdueCount > 0 && view != 'HISTORY')
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444)
                                .withValues(alpha: 0.26),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFFFCA5A5)
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                size: 12,
                                color: Color(0xFFFCA5A5),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$overdueCount Lewat Tempo',
                                style: const TextStyle(
                                  color: Color(0xFFFCA5A5),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      state.isBalanceHidden
                          ? '••••••'
                          : (heroTotalMinor == BigInt.zero
                                ? 'Rp 0'
                                : CurrencyFormatter.formatMinorRupiah(
                                    heroTotalMinor,
                                  )),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _BillHeroStat(
                            dotColor: const Color(0xFF34D399),
                            label: 'Jadwal Aktif',
                            value: '$activeSchedulesCount Jadwal',
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 26,
                          color: Colors.white.withValues(alpha: 0.18),
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        Expanded(
                          child: _BillHeroStat(
                            dotColor: overdueCount > 0
                                ? const Color(0xFFF87171)
                                : const Color(0xFFA78BFA),
                            label: view == 'HISTORY'
                                ? 'Tercatat'
                                : 'Kejadian Aktif',
                            value: '${entries.length} Tagihan',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 2. Segmented Tab Bar: Tagihan vs Seri Jadwal
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _selectedTab = 0),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedTab == 0
                              ? AppColors.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Center(
                          child: Text(
                            'Tagihan (${entries.length})',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _selectedTab == 0
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _selectedTab = 1),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedTab == 1
                              ? AppColors.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Center(
                          child: Text(
                            'Seri Jadwal (${repo.schedules.length})',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _selectedTab == 1
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Status / Feedback Banners
            if (!repo.complete)
              banner(
                icon: Icons.cloud_sync_rounded,
                text:
                    'Sinkronkan riwayat awal sebelum mencatat kejadian. Jadwal baru tetap dapat disimpan offline.',
                color: AppColors.warning,
                bg: AppColors.warningLight,
              ),
            if (message.isNotEmpty)
              banner(
                icon: Icons.check_circle_rounded,
                text: message,
                color: AppColors.income,
                bg: AppColors.incomeLight,
              ),
            if (active.error != null)
              banner(
                icon: Icons.error_outline_rounded,
                text: active.error!,
                color: AppColors.expense,
                bg: AppColors.expenseLight,
              ),
            if (state.dataError != null)
              banner(
                icon: Icons.cloud_off_rounded,
                text: state.dataError!,
                color: AppColors.expense,
                bg: AppColors.expenseLight,
              ),
            if (loadError != null)
              banner(
                icon: Icons.error_outline_rounded,
                text: loadError,
                color: AppColors.expense,
                bg: AppColors.expenseLight,
              ),

            if (repo.queue.isNotEmpty)
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
                    for (final item in repo.queue)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item['entity_type']}: ${item['status']} — ${item['error'] ?? 'menunggu sinkronisasi'}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.warning,
                            ),
                          ),
                          if (item['entity_type'] == 'bill_schedules' &&
                              ['rejected', 'conflict'].contains(item['status']))
                            Wrap(
                              spacing: 6,
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
                              spacing: 6,
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
                  ],
                ),
              ),

            const SizedBox(height: 14),

            // 3. Tab 0: Tagihan & Riwayat
            if (_selectedTab == 0) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: view,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Tampilan jadwal',
                        isDense: true,
                        prefixIcon: const Icon(
                          Icons.filter_list_rounded,
                          size: 19,
                          color: AppColors.primary,
                        ),
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
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
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
                      const SizedBox(height: 8),
                      FilterChip(
                        selected: older,
                        onSelected: (v) => setState(() => older = v),
                        selectedColor: AppColors.accentLight,
                        backgroundColor: AppColors.background,
                        checkmarkColor: AppColors.primary,
                        side: BorderSide(
                          color: older ? AppColors.primary : AppColors.border,
                        ),
                        label: Text(
                          'Sertakan tunggakan lama',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: older
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: older
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              if (entries.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 32,
                    horizontal: 20,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.accentLight.withValues(alpha: 0.7),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.event_available_rounded,
                          size: 32,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        view == 'HISTORY'
                            ? 'Belum ada riwayat pembayaran.'
                            : 'Tidak ada tagihan aktif saat ini.',
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        view == 'HISTORY'
                            ? 'Tagihan yang sudah dibayar atau dilewati akan muncul di sini.'
                            : 'Tambahkan jadwal tagihan rutin agar tidak terlewat.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (view != 'HISTORY') ...[
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => schedule(),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Buat jadwal'),
                        ),
                      ],
                    ],
                  ),
                ),

              for (final o in entries)
                _buildOccurrenceCard(
                  context: context,
                  state: state,
                  o: o,
                ),
            ],

            // 4. Tab 1: Seri Jadwal
            if (_selectedTab == 1) ...[
              if (repo.schedules.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 32,
                    horizontal: 20,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.event_repeat_rounded,
                        size: 34,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Belum ada seri jadwal tagihan.',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => schedule(),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Buat jadwal'),
                      ),
                    ],
                  ),
                ),

              for (final bill in repo.schedules)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
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
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: bill['active'] == true
                                  ? AppColors.accentLight
                                  : AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              bill['frequency'] == 'ONCE'
                                  ? Icons.event_rounded
                                  : Icons.repeat_rounded,
                              color: bill['active'] == true
                                  ? AppColors.primary
                                  : AppColors.textMuted,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${bill['title']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    _BillTag(
                                      label: _frequencyLabel(bill['frequency']),
                                      bg: AppColors.surfaceVariant,
                                      fg: AppColors.textSecondary,
                                    ),
                                    _BillTag(
                                      label: bill['active'] == true
                                          ? 'Aktif'
                                          : 'Diarsipkan',
                                      bg: bill['active'] == true
                                          ? AppColors.incomeLight
                                          : AppColors.surfaceVariant,
                                      fg: bill['active'] == true
                                          ? AppColors.income
                                          : AppColors.textMuted,
                                    ),
                                    if (bill['reminder_enabled'] == true)
                                      _BillTag(
                                        label: 'H-${bill['reminder_days']}',
                                        bg: AppColors.infoLight,
                                        fg: AppColors.info,
                                      ),
                                    if (bill['admin_fee'] != null &&
                                        !RegExp(
                                          r'^0+(?:\.0+)?$',
                                        ).hasMatch('${bill['admin_fee']}'))
                                      _BillTag(
                                        label:
                                            '+ Admin ${CurrencyFormatter.formatCurrency(bill['admin_fee'])}',
                                        bg: AppColors.surfaceVariant,
                                        fg: AppColors.textSecondary,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            state.isBalanceHidden
                                ? '••••••'
                                : CurrencyFormatter.formatCurrency(
                                    bill['amount'],
                                  ),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
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
                            onPressed: () => schedule(bill: bill),
                            icon: const Icon(Icons.edit_rounded, size: 15),
                            label: const Text(
                              'Ubah / arsip',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            tooltip: 'Hapus jadwal',
                            icon: const Icon(
                              Icons.delete_rounded,
                              color: AppColors.expense,
                              size: 20,
                            ),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => confirmAndDeleteSchedule(bill),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],

            // 5. Collapsible Guide at the bottom (no clutter at the top!)
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
                  'Cara kerja tagihan & jadwal',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                children: [
                  Text(
                    'Pengingat dalam aplikasi, bukan pembayaran otomatis. Transaksi baru dicatat setelah Anda konfirmasi. Waktu jatuh tempo mengikuti zona tetap tiap jadwal; lewat tanggal berarti tertunggak.',
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

  Widget _buildOccurrenceCard({
    required BuildContext context,
    required AppState state,
    required BillDueItem o,
  }) {
    final isPaid = o.status == 'PAID';
    final isOverduePending = o.overdue && o.status == 'PENDING';
    final accentColor = isPaid
        ? AppColors.income
        : isOverduePending
        ? AppColors.expense
        : AppColors.primary;
    final accentBg = isPaid
        ? AppColors.incomeLight
        : isOverduePending
        ? AppColors.expenseLight
        : AppColors.accentLight;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isOverduePending
              ? AppColors.expense.withValues(alpha: 0.35)
              : AppColors.border,
        ),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accentBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isPaid
                      ? Icons.check_circle_rounded
                      : isOverduePending
                      ? Icons.warning_amber_rounded
                      : Icons.receipt_long_rounded,
                  color: accentColor,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${o.bill['title']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15.5,
                        color: AppColors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${DateFormatter.calendarDate(o.date)} • ${DateFormatter.fixedZone(o.bill['utc_offset_minutes'] as int)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        _BillTag(
                          label: isOverduePending ? 'Lewat tempo' : o.status,
                          bg: isPaid
                              ? AppColors.incomeLight
                              : isOverduePending
                              ? AppColors.expenseLight
                              : AppColors.surfaceVariant,
                          fg: isPaid
                              ? AppColors.income
                              : isOverduePending
                              ? AppColors.expense
                              : AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    state.isBalanceHidden
                        ? '••••••'
                        : CurrencyFormatter.formatCurrency(o.amount),
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: isOverduePending
                          ? AppColors.expense
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    o.bill['amount_type'] == 'FIXED' ? 'Tetap' : 'Perkiraan',
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                  if (o.bill['admin_fee'] != null &&
                      !RegExp(
                        r'^0+(?:\.0+)?$',
                      ).hasMatch('${o.bill['admin_fee']}'))
                    Text(
                      state.isBalanceHidden
                          ? '+ Admin •••'
                          : '+ Admin ${CurrencyFormatter.formatCurrency(o.bill['admin_fee'])}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
              IconButton(
                tooltip: 'Kelola jadwal',
                icon: const Icon(
                  Icons.more_vert_rounded,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: () => schedule(bill: o.bill),
              ),
            ],
          ),
          if (o.record?['note'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
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
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (o.bill['obligation_id'] == null &&
                    o.status != 'NEEDS_REVIEW')
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accentLight,
                      foregroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                    ),
                    onPressed: () => action(o, 'PAY'),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text(
                      'Catat pembayaran',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
                      vertical: 7,
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
                    style: const TextStyle(fontSize: 12.5),
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
                        vertical: 7,
                      ),
                    ),
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => const ObligationsPage(),
                      ),
                    ),
                    child: const Text(
                      'Buka Utang & Piutang',
                      style: TextStyle(fontSize: 12.5),
                    ),
                  ),
                if (o.status == 'PENDING')
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textMuted,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 7,
                      ),
                    ),
                    onPressed: () => action(o, 'SKIP'),
                    child: const Text('Lewati', style: TextStyle(fontSize: 12.5)),
                  ),
              ],
            ),
          ],
          if (['SKIPPED', 'NEEDS_REVIEW'].contains(o.status)) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => action(o, 'REOPEN'),
              icon: const Icon(Icons.replay_rounded, size: 15),
              label: const Text('Buka kembali kejadian'),
            ),
          ],
        ],
      ),
    );
  }
}

class _BillHeroStat extends StatelessWidget {
  final Color dotColor;
  final String label;
  final String value;

  const _BillHeroStat({
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
            ),
          ),
        ),
      ],
    );
  }
}

class _BillTag extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;

  const _BillTag({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}
