import 'package:flutter/material.dart';

import 'dart:convert';
import 'dart:typed_data';

import '../../../app/app_state.dart';
import '../../../core/utils/app_time_zone.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../app/theme/app_colors.dart';
import '../data/export_file.dart';
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

  Future<void> saveExport({bool backup = false}) async {
    final active = controller;
    final export = result;
    if (active == null || (!backup && export == null) || saving) return;
    setState(() {
      saving = true;
      error = null;
      message = null;
    });
    try {
      active.requireCurrent();
      final bytes = backup
          ? await active.repository.backup(
              timeZone: AppStateScope.of(context).timeZone,
              currency: currency,
            )
          : Uint8List.fromList(utf8.encode(export!.xls));
      active.requireCurrent();
      final name = backup
          ? 'money_android_tmp_backup(${DateTime.now().millisecondsSinceEpoch}).mmbak'
          : '${date(start)}_${date(end)}.xls';
      final path = await saveFinancialFile(
        name,
        bytes,
        backup ? 'application/octet-stream' : 'application/vnd.ms-excel',
      );
      if (mounted && active.isCurrent) {
        setState(
          () => message = path == null
              ? 'Penyimpanan dibatalkan.'
              : 'Berkas disimpan: $path',
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
    final isSurplus = preview.difference > BigInt.zero;
    final diffFormatted =
        CurrencyFormatter.formatMinorRupiah(preview.difference.abs());
    final recordedFormatted =
        CurrencyFormatter.formatMinorRupiah(preview.recorded);
    final statementFormatted =
        CurrencyFormatter.formatMinorRupiah(preview.statement);

    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSurplus
                    ? AppColors.incomeLight
                    : AppColors.expenseLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isSurplus
                    ? Icons.arrow_downward_rounded
                    : Icons.arrow_upward_rounded,
                color: isSurplus ? AppColors.income : AppColors.expense,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Catat penyesuaian saldo?',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _dialogRow('Saldo tercatat', recordedFormatted),
                  const SizedBox(height: 6),
                  _dialogRow('Saldo rekening koran', statementFormatted),
                  const Divider(height: 16),
                  _dialogRow(
                    isSurplus ? 'Selisih pemasukan' : 'Selisih pengeluaran',
                    '${isSurplus ? '+' : '-'}$diffFormatted',
                    isHighlight: true,
                    highlightColor:
                        isSurplus ? AppColors.income : AppColors.expense,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Referensi: ${preview.reference}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Selisih dicatat sebagai transaksi pemasukan/pengeluaran baru hari ini '
              'dan memengaruhi laporan. Riwayat lama tetap ada. '
              'Pastikan tidak ada transaksi bank yang belum dicatat.',
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.textMuted,
                height: 1.35,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
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

  String normalizeStatementAmount(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return '';
    final isNegative = text.startsWith('-');
    final withoutSign = text.replaceFirst('-', '').trim();
    final clean = withoutSign.replaceFirst(RegExp(r'^Rp\s*'), '');

    if (clean.contains(',')) {
      final parts = clean.split(',');
      final whole = parts[0].replaceAll('.', '');
      final fraction = parts.length > 1 ? parts[1] : '';
      final result = fraction.isEmpty ? whole : '$whole.$fraction';
      return isNegative ? '-$result' : result;
    }

    if (clean.contains('.')) {
      if (RegExp(r'^\d{1,3}(?:\.\d{3})+$').hasMatch(clean)) {
        final whole = clean.replaceAll('.', '');
        return isNegative ? '-$whole' : whole;
      }
      final lastDot = clean.lastIndexOf('.');
      final beforeLastDot = clean.substring(0, lastDot);
      final afterLastDot = clean.substring(lastDot + 1);
      if (afterLastDot.length <= 2 && RegExp(r'^\d+$').hasMatch(afterLastDot)) {
        final whole = beforeLastDot.replaceAll('.', '');
        return '${isNegative ? '-' : ''}$whole.$afterLastDot';
      }
      final whole = clean.replaceAll('.', '');
      return isNegative ? '-$whole' : whole;
    }

    return isNegative ? '-$clean' : clean;
  }

  void _onStatementChanged(String val) {
    setState(() => comparison = null);

    final trimmed = val.trim();
    if (trimmed.isEmpty) return;

    if (trimmed.contains(',') ||
        trimmed.contains('e') ||
        trimmed.contains('E')) {
      return;
    }
    if (trimmed.contains('.')) {
      final withoutSign =
          trimmed.replaceFirst('-', '').replaceFirst(RegExp(r'^Rp\s*'), '');
      if (!RegExp(r'^\d{1,3}(?:\.\d{3})+$').hasMatch(withoutSign)) {
        return;
      }
    }

    final isNegative = trimmed.startsWith('-');
    final digits = trimmed.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) {
      if (isNegative && statement.text != '-') {
        statement.value = const TextEditingValue(
          text: '-',
          selection: TextSelection.collapsed(offset: 1),
        );
      }
      return;
    }

    final parsed = BigInt.tryParse(digits);
    if (parsed == null) return;

    final rawDigits = parsed.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < rawDigits.length; i++) {
      if (i > 0 && (rawDigits.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(rawDigits[i]);
    }

    final formatted = (isNegative ? '-' : '') + buffer.toString();
    if (statement.text != formatted) {
      statement.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  static Widget _dialogRow(
    String label,
    String value, {
    bool isHighlight = false,
    Color? highlightColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w500,
            color: isHighlight ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isHighlight ? 14 : 12,
            fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w600,
            color: highlightColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _summaryRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    bool isBold = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 13 : 12,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final active = controller;
    if (active == null || !active.isCurrent) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: const Text(
            'Ekspor & Rekonsiliasi',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: AppColors.textPrimary,
            ),
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
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Ekspor & Rekonsiliasi',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          // Section 1: Ekspor Excel Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.accentLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.table_chart_rounded,
                        size: 20,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Ekspor data',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Hanya akun aktif milik sendiri, termasuk akun tersembunyi dan '
                          'transaksi lokal yang belum tersinkron. Data pribadi anggota rumah tangga lain '
                          'tidak disertakan. Periode mengikuti zona waktu pilihan di Pengaturan; tanggal Excel memakai zona waktu tersebut. '
                          'Berkas berisi data keuangan pribadi.',
                          style: TextStyle(
                            fontSize: 11.5,
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
                          foregroundColor: AppColors.textPrimary,
                          side: const BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: saving ? null : () => pickDate(true),
                        icon: const Icon(
                          Icons.calendar_today_rounded,
                          size: 15,
                          color: AppColors.primary,
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
                          foregroundColor: AppColors.textPrimary,
                          side: const BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: saving ? null : () => pickDate(false),
                        icon: const Icon(
                          Icons.calendar_today_rounded,
                          size: 15,
                          color: AppColors.primary,
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
                    labelStyle: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
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
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
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
                OutlinedButton.icon(
                  onPressed: saving ? null : () => saveExport(backup: true),
                  icon: const Icon(Icons.backup_outlined),
                  label: Text('Simpan backup $currency (.mmbak)'),
                ),
                const Text(
                  'Backup Money Manager menyimpan semua akun dan riwayat dalam mata uang yang dipilih, tanpa batas tanggal. Filter tanggal dan akun hanya untuk Excel. Detail investasi dan pinjaman Vesper tidak dapat dipulihkan di Money Manager.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  key: ValueKey('export-account:$selectedAccount:$currency'),
                  initialValue: selectedAccount,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Akun ekspor',
                    labelStyle: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
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
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
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
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
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
                  label: const Text(
                    'Siapkan Excel',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (result case final export?) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${export.excelRowCount} baris • ${export.currency}\n'
                          'Uang masuk: ${CurrencyFormatter.formatCurrency(financialDecimal(export.credits), currency: export.currency)}\n'
                          'Uang keluar: ${CurrencyFormatter.formatCurrency(financialDecimal(export.debits), currency: export.currency)}\n'
                          'Selisih: ${CurrencyFormatter.formatCurrency(financialDecimal(export.credits - export.debits), currency: export.currency)}',
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
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: saving ? null : () => saveExport(),
                              icon: const Icon(
                                Icons.download_outlined,
                                size: 16,
                              ),
                              label: Text(
                                saving ? 'Menyimpan…' : 'Simpan Excel',
                              ),
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
          const SizedBox(height: 16),

          // Section 2: Rekonsiliasi Saldo Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.accentLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.balance_rounded,
                        size: 20,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rekonsiliasi saldo saat ini',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Cocokkan catatan aplikasi dengan mutasi bank',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
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
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Bandingkan saldo lokal saat ini dengan saldo rekening koran saat ini. '
                          'Ini bukan rekonstruksi saldo masa lalu. Hanya akun kas IDR milik sendiri tanpa '
                          'subakun dan tanpa pemetaan utang. Penyesuaian mendukung Rupiah bulat.',
                          style: TextStyle(
                            fontSize: 11.5,
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
                  hint: const Text(
                    'Pilih rekening kas / bank',
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                  decoration: InputDecoration(
                    labelText: 'Akun rekonsiliasi',
                    labelStyle: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    prefixIcon: const Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
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
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                  items: [
                    for (final a in cash)
                      DropdownMenuItem(
                        value: a['id'] as String,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${a['name']}',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                CurrencyFormatter.formatCurrency(
                                  a['balance'],
                                  currency: '${a['currency'] ?? 'IDR'}',
                                ),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() {
                    reconciliationId = v;
                    comparison = null;
                    message = null;
                  }),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: statement,
                  decoration: InputDecoration(
                    labelText: 'Saldo rekening koran',
                    hintText: '0',
                    prefixText: 'Rp ',
                    prefixStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                    prefixIcon: const Icon(
                      Icons.receipt_long_rounded,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    helperText:
                        'Saldo riil saat ini (mendukung minus jika overdraft)',
                    helperMaxLines: 2,
                    helperStyle: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                    labelStyle: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
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
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                  ),
                  onChanged: _onStatementChanged,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: reference,
                  maxLength: 500,
                  decoration: InputDecoration(
                    labelText: 'Referensi rekening koran / alasan',
                    hintText: 'Contoh: Rekening koran per 10 Nov 2026',
                    prefixIcon: const Icon(
                      Icons.description_outlined,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    helperText: 'Wajib diisi sebagai catatan audit rekonsiliasi',
                    helperStyle: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                    labelStyle: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
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
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                  onChanged: (_) => setState(() => comparison = null),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(
                      color: AppColors.primary,
                      width: 1.2,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => perform(() {
                    comparison = repo.compare(
                      selectedCash ?? '',
                      normalizeStatementAmount(statement.text),
                      reference.text,
                    );
                    message = null;
                  }),
                  icon: const Icon(
                    Icons.compare_arrows_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  label: const Text(
                    'Bandingkan saldo',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                ),
                if (comparison case final preview?) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: preview.difference == BigInt.zero
                          ? AppColors.incomeLight.withValues(alpha: 0.5)
                          : AppColors.surfaceVariant.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: preview.difference == BigInt.zero
                            ? AppColors.income.withValues(alpha: 0.3)
                            : AppColors.border,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: preview.difference == BigInt.zero
                                    ? AppColors.income
                                    : (preview.difference > BigInt.zero
                                          ? AppColors.primary
                                          : AppColors.expense),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                preview.difference == BigInt.zero
                                    ? Icons.check_rounded
                                    : (preview.difference > BigInt.zero
                                          ? Icons.add_rounded
                                          : Icons.remove_rounded),
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                preview.difference == BigInt.zero
                                    ? 'Saldo Cocok & Sesuai'
                                    : (preview.difference > BigInt.zero
                                          ? 'Selisih Lebih (Surplus)'
                                          : 'Selisih Kurang (Defisit)'),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: preview.difference == BigInt.zero
                                      ? AppColors.income
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ),
                            if (preview.difference == BigInt.zero)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.income.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Cocok',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.income,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.border.withValues(alpha: 0.6),
                            ),
                          ),
                          child: Column(
                            children: [
                              _summaryRow(
                                icon: Icons.account_balance_wallet_outlined,
                                label: 'Saldo Tercatat di Aplikasi',
                                value: CurrencyFormatter.formatMinorRupiah(
                                  preview.recorded,
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Divider(height: 1),
                              ),
                              _summaryRow(
                                icon: Icons.receipt_long_outlined,
                                label: 'Saldo Rekening Koran Bank',
                                value: CurrencyFormatter.formatMinorRupiah(
                                  preview.statement,
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Divider(height: 1),
                              ),
                              _summaryRow(
                                icon: Icons.difference_outlined,
                                label: 'Selisih Penyesuaian',
                                value: preview.difference == BigInt.zero
                                    ? 'Rp 0'
                                    : '${preview.difference > BigInt.zero ? '+' : '-'}${CurrencyFormatter.formatMinorRupiah(preview.difference.abs())}',
                                valueColor: preview.difference == BigInt.zero
                                    ? AppColors.income
                                    : (preview.difference > BigInt.zero
                                          ? AppColors.income
                                          : AppColors.expense),
                                isBold: true,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (preview.difference == BigInt.zero)
                          const Text(
                            'Saldo lokal Anda sudah identik dengan rekening koran. Tidak ada transaksi penyesuaian yang perlu dibuat.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                              height: 1.35,
                            ),
                          )
                        else ...[
                          Text(
                            preview.difference > BigInt.zero
                                ? 'Saldo rekening koran lebih tinggi. Menyetujui akan mencatat transaksi pemasukan penyesuaian baru.'
                                : 'Saldo rekening koran lebih rendah. Menyetujui akan mencatat transaksi pengeluaran penyesuaian baru.',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textMuted,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.tune_rounded, size: 18),
                            onPressed: confirm,
                            label: const Text(
                              'Tinjau penyesuaian',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (error != null)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.expenseLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.expense.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 16,
                    color: AppColors.expense,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      error!,
                      style: const TextStyle(
                        color: AppColors.expense,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (message != null)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.incomeLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.income.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 16,
                    color: AppColors.income,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SelectableText(
                      message!,
                      style: const TextStyle(
                        color: AppColors.income,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
