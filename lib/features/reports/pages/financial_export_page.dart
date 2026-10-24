import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_state.dart';
import '../../../core/utils/app_time_zone.dart';
import '../../../app/theme/app_colors.dart';
import '../data/csv_file.dart';
import '../data/financial_export_controller.dart';
import '../data/financial_export_repository.dart';

class FinancialExportPage extends StatefulWidget {
  const FinancialExportPage({super.key});
  @override
  State<FinancialExportPage> createState() => _FinancialExportPageState();
}

class _FinancialExportPageState extends State<FinancialExportPage> {
  FinancialExportController? controller;
  String? accountId, reconciliationId, error, message;
  String currency = 'IDR';
  late DateTime start, end;
  AppTimeZone? rangeZone;
  String? rangeZoneRules;
  final statement = TextEditingController();
  final reference = TextEditingController();
  FinancialExport? result;
  BalanceReconciliation? comparison;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now().toUtc();
    start = DateTime.utc(now.year, now.month, 1);
    end = DateTime.utc(now.year, now.month, now.day);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppStateScope.of(context);
    if (rangeZone == null) {
      end = state.timeZone.calendarDate(DateTime.now());
      start = DateTime.utc(end.year, end.month, 1);
    }
    final rules = state.timeZone == AppTimeZone.device
        ? '${DateTime.now().timeZoneName}:${DateTime.now().timeZoneOffset.inMinutes}'
        : state.timeZone.name;
    if (rangeZone != state.timeZone || rangeZoneRules != rules) {
      rangeZone = state.timeZone;
      rangeZoneRules = rules;
      result = null;
      message = null;
    }
    final source = state.repository;
    if (source == null || source.userId != state.currentUserId) {
      controller?.dispose();
      controller = null;
      result = null;
      comparison = null;
    } else if (!identical(controller?.repository.source, source)) {
      controller?.dispose();
      controller = FinancialExportController(
        state,
        FinancialExportRepository(source),
      );
      accountId = null;
      reconciliationId = null;
      result = null;
      comparison = null;
      statement.clear();
      reference.clear();
      error = null;
      message = null;
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    statement.dispose();
    reference.dispose();
    super.dispose();
  }

  String date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  void perform(VoidCallback action) {
    try {
      controller!.requireCurrent();
      action();
      setState(() => error = null);
    } catch (failure) {
      setState(() => error = failure.toString());
    }
  }

  Future<void> pickDate(bool first) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: first ? start : end,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (first) {
        start = DateTime.utc(picked.year, picked.month, picked.day);
      } else {
        end = DateTime.utc(picked.year, picked.month, picked.day);
      }
      result = null;
      message = null;
    });
  }

  Future<void> saveCsv() async {
    final active = controller;
    final export = result;
    if (active == null || export == null || saving) return;
    setState(() {
      saving = true;
      error = null;
      message = null;
    });
    try {
      active.requireCurrent();
      final path = await saveFinancialCsv(
        'vesper-${date(start)}-${date(end)}-$currency-${DateTime.now().millisecondsSinceEpoch}.csv',
        export.csv,
      );
      if (mounted && active.isCurrent) {
        setState(
          () => message = path == null
              ? 'Penyimpanan dibatalkan.'
              : 'CSV disimpan: $path',
        );
      }
    } catch (failure) {
      if (mounted && active.isCurrent) {
        setState(() => error = failure.toString());
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> confirm() async {
    final active = controller!;
    final preview = comparison;
    if (preview == null || preview.difference == BigInt.zero) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: const Text(
          'Catat penyesuaian saldo?',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Saldo tercatat: ${financialDecimal(preview.recorded)} IDR\n'
          'Saldo rekening koran: ${financialDecimal(preview.statement)} IDR\n'
          'Selisih: ${financialDecimal(preview.difference)} IDR\n\n'
          'Referensi: ${preview.reference}\n\n'
          'Selisih dicatat sebagai transaksi pemasukan/pengeluaran baru hari ini '
          'dan memengaruhi laporan. Riwayat lama tetap ada. '
          'Pastikan tidak ada transaksi bank yang belum dicatat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Catat penyesuaian'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted || !identical(controller, active)) return;
    final saved = active.confirm(preview);
    if (!mounted) return;
    setState(() {
      error = active.error;
      if (saved) {
        comparison = null;
        result = null;
        message = 'Penyesuaian tersimpan lokal dan masuk antrean sinkronisasi.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final active = controller;
    if (active == null || !active.isCurrent) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text(
            'Ekspor & Rekonsiliasi',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        body: const Center(
          child: Text(
            'Masuk dan tunggu data lokal tersedia.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    final repo = active.repository;
    final currencies = {
      'IDR',
      ...repo.accounts.map((a) => '${a['currency']}'),
    }.toList()..sort();
    final accounts = repo.accounts
        .where((a) => a['currency'] == currency)
        .toList();
    final selectedAccount = accounts.any((a) => a['id'] == accountId)
        ? accountId
        : null;
    final cash = repo.reconciliationAccounts;
    final selectedCash = cash.any((a) => a['id'] == reconciliationId)
        ? reconciliationId
        : null;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Ekspor & Rekonsiliasi',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          // Section 1: Ekspor CSV Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.border),
            ),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.table_chart_rounded,
                        size: 20,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Ekspor transaksi CSV',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 15,
                          color: AppColors.textMuted,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Hanya akun aktif milik sendiri, termasuk akun tersembunyi dan '
                            'transaksi lokal yang belum tersinkron. Data pribadi anggota rumah tangga lain '
                            'tidak disertakan. Periode mengikuti zona waktu pilihan di Pengaturan; timestamp CSV memakai format UTC untuk pertukaran data. '
                            'Berkas berisi data keuangan pribadi.',
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
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: saving ? null : () => pickDate(true),
                          icon: const Icon(
                            Icons.calendar_today_rounded,
                            size: 15,
                          ),
                          label: Text(
                            'Dari ${date(start)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: saving ? null : () => pickDate(false),
                          icon: const Icon(
                            Icons.calendar_today_rounded,
                            size: 15,
                          ),
                          label: Text(
                            'Sampai ${date(end)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey('currency:$currency'),
                    initialValue: currency,
                    decoration: InputDecoration(
                      labelText: 'Mata uang',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: [
                      for (final code in currencies)
                        DropdownMenuItem(value: code, child: Text(code)),
                    ],
                    onChanged: saving
                        ? null
                        : (v) => setState(() {
                            currency = v!;
                            accountId = null;
                            result = null;
                            message = null;
                          }),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey('export-account:$selectedAccount:$currency'),
                    initialValue: selectedAccount,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Akun ekspor',
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
                        child: Text('Semua akun milik sendiri'),
                      ),
                      for (final a in accounts)
                        DropdownMenuItem(
                          value: a['id'] as String,
                          child: Text('${a['name']}'),
                        ),
                    ],
                    onChanged: saving
                        ? null
                        : (v) => setState(() {
                            accountId = v;
                            result = null;
                            message = null;
                          }),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: saving
                        ? null
                        : () => perform(() {
                            if (end.isBefore(start)) {
                              throw StateError(
                                'Tanggal akhir harus setelah tanggal awal.',
                              );
                            }
                            result = repo.exportCalendar(
                              startDate: start,
                              endDate: end,
                              timeZone: state.timeZone,
                              currency: currency,
                              accountId: selectedAccount,
                            );
                            message = null;
                          }),
                    icon: const Icon(Icons.table_view_outlined, size: 18),
                    label: const Text('Siapkan CSV'),
                  ),
                  if (result case final export?) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${export.count} baris • ${export.currency}\n'
                            'Kredit ledger: ${financialDecimal(export.credits)}\n'
                            'Debit ledger: ${financialDecimal(export.debits)}\n'
                            'Perubahan bersih: ${financialDecimal(export.credits - export.debits)}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Total ini mencakup transfer dan penyelesaian investasi/utang; '
                            'bukan total pemasukan atau pengeluaran. Saldo awal tidak termasuk.',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: saving ? null : saveCsv,
                                icon: const Icon(
                                  Icons.download_outlined,
                                  size: 16,
                                ),
                                label: Text(
                                  saving ? 'Menyimpan…' : 'Simpan CSV',
                                ),
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: saving
                                    ? null
                                    : () async {
                                        active.requireCurrent();
                                        await Clipboard.setData(
                                          ClipboardData(text: export.csv),
                                        );
                                        if (mounted && active.isCurrent) {
                                          setState(
                                            () => message =
                                                'CSV disalin ke clipboard.',
                                          );
                                        }
                                      },
                                icon: const Icon(Icons.copy_rounded, size: 16),
                                label: const Text('Salin CSV'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Section 2: Rekonsiliasi Saldo Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.border),
            ),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.balance_rounded,
                        size: 20,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Rekonsiliasi saldo saat ini',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 15,
                          color: AppColors.textMuted,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Bandingkan saldo lokal saat ini dengan saldo rekening koran saat ini. '
                            'Ini bukan rekonstruksi saldo masa lalu. Hanya akun kas IDR milik sendiri tanpa '
                            'subakun dan tanpa pemetaan utang. Penyesuaian mendukung Rupiah bulat.',
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
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    key: ValueKey('cash:$selectedCash'),
                    initialValue: selectedCash,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Akun rekonsiliasi',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: [
                      for (final a in cash)
                        DropdownMenuItem(
                          value: a['id'] as String,
                          child: Text('${a['name']} (${a['balance']} IDR)'),
                        ),
                    ],
                    onChanged: (v) => setState(() {
                      reconciliationId = v;
                      comparison = null;
                      message = null;
                    }),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: statement,
                    decoration: InputDecoration(
                      labelText:
                          'Saldo rekening koran (contoh: 150000 atau -50000)',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: true,
                    ),
                    onChanged: (_) => setState(() => comparison = null),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reference,
                    maxLength: 500,
                    decoration: InputDecoration(
                      labelText: 'Referensi rekening koran / alasan',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (_) => setState(() => comparison = null),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => perform(() {
                      comparison = repo.compare(
                        selectedCash ?? '',
                        statement.text,
                        reference.text,
                      );
                      message = null;
                    }),
                    icon: const Icon(Icons.compare_arrows_rounded, size: 18),
                    label: const Text('Bandingkan saldo'),
                  ),
                  if (comparison case final preview?) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Tercatat: ${financialDecimal(preview.recorded)} IDR\n'
                            'Rekening koran: ${financialDecimal(preview.statement)} IDR\n'
                            'Selisih: ${financialDecimal(preview.difference)} IDR',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (preview.difference == BigInt.zero)
                            const Text(
                              'Saldo cocok. Tidak ada penyesuaian.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.income,
                              ),
                            )
                          else
                            FilledButton(
                              style: FilledButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: confirm,
                              child: const Text('Tinjau penyesuaian'),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (error != null)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.expenseLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                error!,
                style: const TextStyle(color: AppColors.expense, fontSize: 12),
              ),
            ),
          if (message != null)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.incomeLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                message!,
                style: const TextStyle(color: AppColors.income, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}
