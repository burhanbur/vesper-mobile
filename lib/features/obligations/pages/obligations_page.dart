import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_state.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../app/theme/app_colors.dart';
import '../data/obligations_controller.dart';
import '../data/obligations_repository.dart';
import 'obligation_amount_input.dart';

class _InstallmentDraft {
  String date;
  final TextEditingController amount;
  _InstallmentDraft(this.date, this.amount);
}

class ObligationsPage extends StatefulWidget {
  const ObligationsPage({super.key, this.initialLinkedAccountId});

  final String? initialLinkedAccountId;

  @override
  State<ObligationsPage> createState() => _ObligationsPageState();
}

class _ObligationsPageState extends State<ObligationsPage> {
  ObligationsController? controller;
  String? error;
  bool _initialFormOpened = false;
  int _statusTab = 0; // 0 = Aktif, 1 = Lunas
  String _filter = 'ALL';

  static bool _isSettled(Map<String, dynamic> debt) =>
      obligationMinor('${debt['outstanding']}') <= BigInt.zero;

  static String _obligationActionLabel(dynamic action) {
    switch (action) {
      case 'OPEN':
        return 'Catat pinjaman';
      case 'REPAY':
        return 'Pembayaran pinjaman';
      case 'REVERSE':
        return 'Koreksi pembayaran';
      case 'DELETE':
        return 'Arsipkan / batalkan';
      default:
        return '$action';
    }
  }

  static String _outboxStatusLabel(dynamic status) {
    switch (status) {
      case 'pending':
        return 'Menunggu sinkron';
      case 'failed':
        return 'Perlu ditinjau';
      case 'syncing':
        return 'Menyinkronkan';
      default:
        return '$status';
    }
  }

  static String _eventOperationLabel(dynamic operation) {
    switch (operation) {
      case 'REPAY':
        return 'PEMBAYARAN';
      case 'OPEN':
        return 'PEMBUKAAN';
      case 'REVERSE':
        return 'KOREKSI';
      case 'DELETE':
        return 'ARSIP';
      default:
        return '$operation';
    }
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

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
    if (!_initialFormOpened &&
        controller != null &&
        widget.initialLinkedAccountId != null) {
      _initialFormOpened = true;
      final active = controller;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && identical(controller, active)) {
          form(linkedAccountId: widget.initialLinkedAccountId);
        }
      });
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime _addMonthsClamped(DateTime anchor, int monthOffset) {
    final zeroMonth = (anchor.month - 1) + monthOffset;
    final year = anchor.year + (zeroMonth ~/ 12);
    final month = (zeroMonth % 12) + 1;
    final lastDay = DateTime.utc(year, month + 1, 0).day;
    final day = anchor.day > lastDay ? lastDay : anchor.day;
    return DateTime.utc(year, month, day);
  }

  Future<void> form({
    Map<String, dynamic>? debt,
    String? linkedAccountId,
  }) async {
    final active = controller!;
    final repo = active.repository;
    final linkedAccount = repo.cashAccounts
        .where((account) => account['id'] == linkedAccountId)
        .firstOrNull;
    if (linkedAccountId != null &&
        (linkedAccount == null ||
            repo.source.isMappedObligationAccount(linkedAccountId))) {
      setState(
        () => error = 'Akun tidak tersedia atau sudah terhubung ke pinjaman.',
      );
      return;
    }
    final balance = linkedAccount == null
        ? BigInt.zero
        : obligationMinor('${linkedAccount['balance']}', signed: true);
    final counterparty = TextEditingController();
    final principal = TextEditingController();
    final interest = TextEditingController(text: '0');
    final fee = TextEditingController(text: '0');
    final due = TextEditingController();
    final tenor = TextEditingController(text: '3');
    final installments = <_InstallmentDraft>[];
    final extraControllers = <TextEditingController>[];
    final nowLocal = DateTime.now();
    var firstInstallmentDate = _addMonthsClamped(
      DateTime.utc(nowLocal.year, nowLocal.month, nowLocal.day),
      1,
    );
    bool showInstallments = false;
    String kind = linkedAccount != null && !balance.isNegative
        ? 'RECEIVABLE'
        : 'PAYABLE';
    String? cashId, interestCategory, feeCategory, saveError;
    String? mappedId = linkedAccountId;
    if (linkedAccount != null) {
      principal.text = ObligationAmountInput.fromDecimal(
        obligationMoney(balance.abs()),
      );
    }
    bool existing = linkedAccount != null;
    bool showCosts = false;
    bool savedOnce = false;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
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
                for (final account
                    in (label == 'Akun lama (opsional)'
                        ? repo.cashAccounts.where(
                            (a) => !repo.source.isMappedObligationAccount(
                              a['id'] as String,
                            ),
                          )
                        : repo.fundingAccounts))
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
              inputFormatters: const [ObligationAmountInput()],
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: label,
                helperText: label == 'Jumlah pembayaran'
                    ? 'Bagian pinjaman yang dikembalikan. Isi bunga dan biaya terpisah.'
                    : null,
                prefixText: 'Rp ',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
            return Material(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 14,
                    bottom: MediaQuery.of(ctx).viewInsets.bottom + 12,
                  ),
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 44,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: AppColors.border,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                debt == null
                                    ? 'Catat utang / piutang'
                                    : 'Catat pembayaran',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Flexible(
                          child: SingleChildScrollView(
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
                            child: Text('Saya berutang'),
                          ),
                          DropdownMenuItem(
                            value: 'RECEIVABLE',
                            child: Text('Orang berutang ke saya'),
                          ),
                        ],
                        onChanged: (v) => update(() => kind = v!),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: counterparty,
                        decoration: InputDecoration(
                          labelText: kind == 'PAYABLE'
                              ? 'Saya berutang kepada'
                              : 'Yang berutang ke saya',
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
                      amount(principal, 'Jumlah pinjaman'),
                      const SizedBox(height: 10),
                      TextField(
                        controller: due,
                        readOnly: true,
                        onTap: () async {
                          final current = DateTime.tryParse(due.text) ??
                              DateTime.now().add(const Duration(days: 30));
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: current,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                            helpText: 'PILIH TANGGAL JATUH TEMPO',
                          );
                          if (picked != null) {
                            update(() {
                              due.text =
                                  '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                            });
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'Jatuh tempo (YYYY-MM-DD, opsional)',
                          hintText: 'Pilih tanggal jatuh tempo',
                          helperText: due.text.isNotEmpty
                              ? DateFormatter.calendarDate(due.text)
                              : null,
                          prefixIcon: const Icon(
                            Icons.event_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          suffixIcon: due.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear_rounded,
                                    size: 18,
                                    color: AppColors.textSecondary,
                                  ),
                                  tooltip: 'Hapus tanggal jatuh tempo',
                                  onPressed: () => update(() => due.clear()),
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
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Material(
                        color: AppColors.background,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            InkWell(
                              onTap: () => update(
                                () => showInstallments = !showInstallments,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_month_rounded,
                                      size: 18,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'Jadwal cicilan (opsional)',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    if (installments.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        margin: const EdgeInsets.only(right: 6),
                                        decoration: BoxDecoration(
                                          color: AppColors.accentLight,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Text(
                                          '${installments.length}x',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                    Icon(
                                      showInstallments
                                          ? Icons.expand_less_rounded
                                          : Icons.expand_more_rounded,
                                      size: 20,
                                      color: AppColors.textSecondary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (showInstallments)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  0,
                                  12,
                                  12,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const Divider(height: 1),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        SizedBox(
                                          width: 84,
                                          child: TextField(
                                            controller: tenor,
                                            keyboardType: TextInputType.number,
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly,
                                            ],
                                            decoration: InputDecoration(
                                              labelText: 'Tenor',
                                              suffixText: 'bln',
                                              isDense: true,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 10,
                                                  ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 10,
                                                  ),
                                              side: const BorderSide(
                                                color: AppColors.border,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                            onPressed: () async {
                                              final picked =
                                                  await showDatePicker(
                                                    context: ctx,
                                                    initialDate:
                                                        firstInstallmentDate,
                                                    firstDate: DateTime(2000),
                                                    lastDate: DateTime(2100),
                                                    helpText:
                                                        'MULAI CICILAN PERTAMA',
                                                  );
                                              if (picked != null) {
                                                update(() {
                                                  firstInstallmentDate =
                                                      DateTime.utc(
                                                        picked.year,
                                                        picked.month,
                                                        picked.day,
                                                      );
                                                });
                                              }
                                            },
                                            icon: const Icon(
                                              Icons.event_rounded,
                                              size: 15,
                                              color: AppColors.primary,
                                            ),
                                            label: Text(
                                              DateFormatter.calendarDate(
                                                _isoDate(firstInstallmentDate),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        FilledButton(
                                          style: FilledButton.styleFrom(
                                            backgroundColor: AppColors.primary,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 10,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                          onPressed: () {
                                            final count =
                                                int.tryParse(
                                                  tenor.text.trim(),
                                                ) ??
                                                0;
                                            final dec =
                                                ObligationAmountInput.toDecimal(
                                                  principal.text,
                                                );
                                            final majorStr = dec
                                                .split('.')
                                                .first;
                                            final totalRupiah =
                                                BigInt.tryParse(majorStr) ??
                                                BigInt.zero;
                                            if (count < 1 ||
                                                count > 360 ||
                                                totalRupiah <= BigInt.zero) {
                                              update(() {
                                                saveError =
                                                    'Isi jumlah pinjaman dan tenor (1–360 bulan) terlebih dahulu.';
                                              });
                                              return;
                                            }
                                            if (totalRupiah <
                                                BigInt.from(count)) {
                                              update(() {
                                                saveError =
                                                    'Jumlah pinjaman terlalu kecil untuk dibagi $count cicilan.';
                                              });
                                              return;
                                            }
                                            update(() {
                                              for (final old in installments) {
                                                extraControllers.add(
                                                  old.amount,
                                                );
                                              }
                                              installments.clear();
                                              final countBig = BigInt.from(
                                                count,
                                              );
                                              final base =
                                                  totalRupiah ~/ countBig;
                                              final remainder =
                                                  totalRupiah % countBig;
                                              for (var i = 0; i < count; i++) {
                                                final part = i == count - 1
                                                    ? base + remainder
                                                    : base;
                                                final date = _isoDate(
                                                  _addMonthsClamped(
                                                    firstInstallmentDate,
                                                    i,
                                                  ),
                                                );
                                                final ctrl =
                                                    TextEditingController(
                                                      text:
                                                          ObligationAmountInput
                                                              .fromDecimal(
                                                                '$part.00',
                                                              ),
                                                    );
                                                installments.add(
                                                  _InstallmentDraft(date, ctrl),
                                                );
                                              }
                                              due.text = installments.last.date;
                                              saveError = null;
                                            });
                                          },
                                          child: const Text(
                                            'Bagi rata',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (installments.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      for (
                                        var i = 0;
                                        i < installments.length;
                                        i++
                                      )
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 6,
                                          ),
                                          child: Row(
                                            children: [
                                              SizedBox(
                                                width: 24,
                                                child: Text(
                                                  '#${i + 1}',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.textMuted,
                                                  ),
                                                ),
                                              ),
                                              InkWell(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                onTap: () async {
                                                  final current =
                                                      DateTime.tryParse(
                                                        installments[i].date,
                                                      ) ??
                                                      firstInstallmentDate;
                                                  final picked =
                                                      await showDatePicker(
                                                        context: ctx,
                                                        initialDate: current,
                                                        firstDate: DateTime(
                                                          2000,
                                                        ),
                                                        lastDate: DateTime(
                                                          2100,
                                                        ),
                                                        helpText:
                                                            'TANGGAL CICILAN #${i + 1}',
                                                      );
                                                  if (picked != null) {
                                                    update(() {
                                                      installments[i].date =
                                                          _isoDate(picked);
                                                      if (i ==
                                                          installments.length -
                                                              1) {
                                                        due.text =
                                                            installments[i]
                                                                .date;
                                                      }
                                                    });
                                                  }
                                                },
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 8,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    border: Border.all(
                                                      color: AppColors.border,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    DateFormatter.calendarDate(
                                                      installments[i].date,
                                                    ),
                                                    style: const TextStyle(
                                                      fontSize: 11.5,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          AppColors.textPrimary,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: TextField(
                                                  controller:
                                                      installments[i].amount,
                                                  inputFormatters: const [
                                                    ObligationAmountInput(),
                                                  ],
                                                  keyboardType:
                                                      const TextInputType.numberWithOptions(
                                                        decimal: true,
                                                      ),
                                                  onChanged: (_) =>
                                                      update(() {}),
                                                  decoration: InputDecoration(
                                                    prefixText: 'Rp ',
                                                    isDense: true,
                                                    filled: true,
                                                    fillColor: Colors.white,
                                                    contentPadding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 9,
                                                        ),
                                                    border: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              IconButton(
                                                tooltip: 'Hapus cicilan',
                                                visualDensity:
                                                    VisualDensity.compact,
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(
                                                      minWidth: 28,
                                                      minHeight: 28,
                                                    ),
                                                icon: const Icon(
                                                  Icons.close_rounded,
                                                  size: 16,
                                                  color: AppColors.textMuted,
                                                ),
                                                onPressed: () => update(() {
                                                  final removed = installments
                                                      .removeAt(i);
                                                  extraControllers.add(
                                                    removed.amount,
                                                  );
                                                  if (installments.isNotEmpty) {
                                                    due.text =
                                                        installments.last.date;
                                                  }
                                                }),
                                              ),
                                            ],
                                          ),
                                        ),
                                      Builder(
                                        builder: (_) {
                                          var scheduled = BigInt.zero;
                                          for (final row in installments) {
                                            final dec =
                                                ObligationAmountInput.toDecimal(
                                                  row.amount.text,
                                                );
                                            scheduled +=
                                                BigInt.tryParse(
                                                  dec.split('.').first,
                                                ) ??
                                                BigInt.zero;
                                          }
                                          final target =
                                              BigInt.tryParse(
                                                ObligationAmountInput.toDecimal(
                                                  principal.text,
                                                ).split('.').first,
                                              ) ??
                                              BigInt.zero;
                                          final matched =
                                              target > BigInt.zero &&
                                              scheduled == target;
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              top: 4,
                                            ),
                                            child: Text(
                                              'Total cicilan: ${CurrencyFormatter.formatMinorRupiah(scheduled * BigInt.from(100))}'
                                              '${target > BigInt.zero ? ' / ${CurrencyFormatter.formatMinorRupiah(target * BigInt.from(100))}' : ''}',
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w700,
                                                color: matched
                                                    ? AppColors.income
                                                    : AppColors.warning,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                    const SizedBox(height: 6),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: TextButton.icon(
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          minimumSize: Size.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        onPressed: () => update(() {
                                          final nextDate = installments.isEmpty
                                              ? firstInstallmentDate
                                              : _addMonthsClamped(
                                                  DateTime.tryParse(
                                                        installments.last.date,
                                                      ) ??
                                                      firstInstallmentDate,
                                                  1,
                                                );
                                          final iso = _isoDate(nextDate);
                                          installments.add(
                                            _InstallmentDraft(
                                              iso,
                                              TextEditingController(),
                                            ),
                                          );
                                          due.text = iso;
                                        }),
                                        icon: const Icon(
                                          Icons.add_rounded,
                                          size: 16,
                                        ),
                                        label: const Text(
                                          'Tambah cicilan manual',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (linkedAccount != null)
                        Text(
                          'Menghubungkan akun ${linkedAccount['name']}. Tidak membuat arus kas baru. Saldo positif adalah piutang; saldo negatif adalah utang. Isi nama orang yang terkait, bukan nama akun.',
                          style: const TextStyle(fontSize: 12),
                        ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Pinjaman lama (uang sudah berpindah sebelumnya)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        value: existing,
                        onChanged: linkedAccount != null
                            ? null
                            : (v) => update(() {
                                existing = v;
                                cashId = null;
                                mappedId = null;
                              }),
                      ),
                      if (existing) ...[
                        const Text(
                          'Hanya mencatat sisa pinjaman, saldo rekening tidak berubah. Jika pernah dibuat sebagai akun, pilih akun lama di bawah agar tidak dihitung dua kali.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (linkedAccount == null)
                          accounts(
                            'Akun lama (opsional)',
                            mappedId,
                            (v) => mappedId = v,
                          ),
                      ] else ...[
                        Text(
                          kind == 'PAYABLE'
                              ? 'Uang pinjaman masuk ke rekening ini.'
                              : 'Uang yang dipinjamkan keluar dari rekening ini.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        accounts(
                          kind == 'PAYABLE'
                              ? 'Uang masuk ke'
                              : 'Uang keluar dari',
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
                        debt['kind'] == 'PAYABLE'
                            ? 'Bayar dari rekening'
                            : 'Terima di rekening',
                        cashId,
                        (v) => cashId = v,
                      ),
                      const SizedBox(height: 10),
                      amount(principal, 'Jumlah pembayaran'),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Ada bunga atau biaya tambahan'),
                        value: showCosts,
                        onChanged: (value) => update(() {
                          showCosts = value;
                          if (!value) {
                            interest.text = '0';
                            fee.text = '0';
                            interestCategory = null;
                            feeCategory = null;
                          }
                        }),
                      ),
                      if (showCosts) ...[
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
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Kembali'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        if (savedOnce) return;
                        final saved = active.save(
                          () {
                            if (debt == null) {
                              if (!existing && cashId == null) {
                                throw StateError(
                                  'Pilih akun kas pendanaan.',
                                );
                              }
                              final hasSchedule =
                                  showInstallments && installments.isNotEmpty;
                              final installmentsText = hasSchedule
                                  ? installments
                                        .map(
                                          (r) =>
                                              '${r.date}=${ObligationAmountInput.toDecimal(r.amount.text)}',
                                        )
                                        .join('\n')
                                  : '';
                              repo.open(
                                kind: kind,
                                counterparty: counterparty.text,
                                principal:
                                    ObligationAmountInput.toDecimal(
                                      principal.text,
                                    ),
                                dueDate: due.text.isEmpty && hasSchedule
                                    ? installments.last.date
                                    : due.text,
                                installments: installmentsText,
                                cashAccountId: existing ? null : cashId,
                                linkedAccountId: mappedId,
                              );
                            } else {
                              if (cashId == null) {
                                throw StateError(
                                  'Pilih akun kas pembayaran.',
                                );
                              }
                              repo.repay(
                                debt['id'] as String,
                                cashAccountId: cashId!,
                                principal:
                                    ObligationAmountInput.toDecimal(
                                      principal.text,
                                    ),
                                interest:
                                    ObligationAmountInput.toDecimal(
                                      interest.text,
                                    ),
                                fee: ObligationAmountInput.toDecimal(
                                  fee.text,
                                ),
                                interestCategoryId: interestCategory,
                                feeCategoryId: feeCategory,
                              );
                            }
                          },
                          amounts: [
                            ObligationAmountInput.toDecimal(
                              principal.text,
                            ),
                            if (debt == null && showInstallments)
                              for (final row in installments)
                                ObligationAmountInput.toDecimal(
                                  row.amount.text,
                                ),
                            if (debt != null) ...[
                              ObligationAmountInput.toDecimal(
                                interest.text,
                              ),
                              ObligationAmountInput.toDecimal(fee.text),
                            ],
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
                      child: const Text('Simpan'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
          tenor,
          ...extraControllers,
          ...installments.map((row) => row.amount),
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
    String moneyMinor(BigInt minor) => state.isBalanceHidden
        ? '••••••'
        : CurrencyFormatter.formatMinorRupiah(minor);
    String money(dynamic value) => moneyMinor(obligationMinor('$value'));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Utang & Piutang',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: state.isBalanceHidden
                ? 'Tampilkan saldo'
                : 'Sembunyikan saldo',
            icon: Icon(
              state.isBalanceHidden
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: AppColors.textPrimary,
            ),
            onPressed: () => setState(() => state.toggleHideBalance()),
          ),
          IconButton(
            tooltip: 'Tambah utang / piutang',
            icon: const Icon(Icons.add_rounded, color: AppColors.textPrimary),
            onPressed: active == null ? null : () => form(),
          ),
          IconButton(
            tooltip: 'Sinkronkan',
            icon: const Icon(Icons.sync_rounded, color: AppColors.textPrimary),
            onPressed: (active == null || active.repository.source.isSyncing)
                ? null
                : () async {
                    try {
                      await state.syncPendingNow();
                    } catch (failure) {
                      if (mounted) {
                        setState(() => error = failure.toString());
                      }
                    }
                    if (mounted) setState(() {});
                  },
          ),
          const SizedBox(width: 8),
        ],
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
                final receivableMinor = obligationMinor(
                  '${totals['receivable']}',
                );
                final payableMinor = obligationMinor('${totals['payable']}');
                final netMinor = receivableMinor - payableMinor;
                final isNetPositive = netMinor >= BigInt.zero;

                final activeRecords =
                    repo.records.where((d) => !_isSettled(d)).toList();
                final settledRecords =
                    repo.records.where(_isSettled).toList();
                final tabRecords =
                    _statusTab == 0 ? activeRecords : settledRecords;

                final displayedDebts = tabRecords.where((debt) {
                  if (_filter == 'RECEIVABLE') {
                    return debt['kind'] == 'RECEIVABLE';
                  }
                  if (_filter == 'PAYABLE') return debt['kind'] == 'PAYABLE';
                  return true;
                }).toList();

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    // 1. Unified Hero Card with Net Position & Utang/Piutang stats
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            AppColors.primaryGradientStart,
                            AppColors.primaryGradientEnd,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.18),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.account_balance_rounded,
                                    size: 15,
                                    color: Colors.white70,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Posisi Bersih',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.85,
                                      ),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  isNetPositive ? 'Surplus' : 'Defisit',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            state.isBalanceHidden
                                ? '••••••'
                                : (netMinor == BigInt.zero
                                      ? 'Rp 0'
                                      : '${isNetPositive ? '+' : '-'}${CurrencyFormatter.formatMinorRupiah(netMinor.abs())}'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.arrow_downward_rounded,
                                            size: 13,
                                            color: Color(0xFF34D399),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Piutang',
                                            style: TextStyle(
                                              color: Colors.white.withValues(
                                                alpha: 0.8,
                                              ),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Sisa piutang: ${money(totals['receivable'])}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.arrow_upward_rounded,
                                            size: 13,
                                            color: Color(0xFFF87171),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Utang',
                                            style: TextStyle(
                                              color: Colors.white.withValues(
                                                alpha: 0.8,
                                              ),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Sisa utang: ${money(totals['payable'])}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (!source.hasCompleteObligationHistory) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 8),
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

                    // 2. Status Segmented Tab Bar (Aktif vs Lunas)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          for (final tab in [
                            (0, 'Aktif (${activeRecords.length})'),
                            (1, 'Lunas (${settledRecords.length})'),
                          ])
                            Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _statusTab = tab.$1),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 9,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _statusTab == tab.$1
                                        ? AppColors.primary
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    tab.$2,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: _statusTab == tab.$1
                                          ? Colors.white
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 3. Kind Filter Bar
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _filterChip(
                          label: 'Semua (${tabRecords.length})',
                          selected: _filter == 'ALL',
                          onTap: () => setState(() => _filter = 'ALL'),
                        ),
                        _filterChip(
                          label:
                              'Piutang (${tabRecords.where((d) => d['kind'] == 'RECEIVABLE').length})',
                          selected: _filter == 'RECEIVABLE',
                          onTap: () => setState(() => _filter = 'RECEIVABLE'),
                        ),
                        _filterChip(
                          label:
                              'Utang (${tabRecords.where((d) => d['kind'] == 'PAYABLE').length})',
                          selected: _filter == 'PAYABLE',
                          onTap: () => setState(() => _filter = 'PAYABLE'),
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
                                '${_obligationActionLabel(queued['payload']['action'])} • ${_outboxStatusLabel(queued['status'])}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (queued['cancellation_requested'] == true)
                                const Padding(
                                  padding: EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Memeriksa pembatalan ke server; saldo sementara hingga sinkronisasi selesai.',
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
                                      'Coba ulang',
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => confirm(
                                      'Perintah hanya dibatalkan jika belum diproses server. Jika sudah diproses, data akan diselaraskan saat sinkron.',
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
                    if (displayedDebts.isEmpty)
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
                              child: Icon(
                                _statusTab == 0
                                    ? Icons.handshake_outlined
                                    : Icons.check_circle_outline_rounded,
                                size: 36,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _statusTab == 0
                                  ? 'Belum ada pinjaman aktif.'
                                  : 'Belum ada pinjaman yang lunas.',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _statusTab == 0
                                  ? 'Catat utang atau piutang di sini. Kartu kredit dikelola di menu Akun.'
                                  : 'Pinjaman yang sudah dilunasi akan tampil di sini.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    for (final debt in displayedDebts)
                      Card(
                        key: ValueKey('debt_${debt['id']}'),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        color: Colors.white,
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ExpansionTile(
                          shape: const Border(),
                          collapsedShape: const Border(),
                          leading: Container(
                            width: 38,
                            height: 38,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: debt['kind'] == 'PAYABLE'
                                  ? AppColors.expenseLight
                                  : AppColors.incomeLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              debt['kind'] == 'PAYABLE'
                                  ? Icons.arrow_upward_rounded
                                  : Icons.arrow_downward_rounded,
                              size: 20,
                              color: debt['kind'] == 'PAYABLE'
                                  ? AppColors.expense
                                  : AppColors.income,
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${debt['kind'] == 'PAYABLE' ? 'Utang' : 'Piutang'} • ${debt['counterparty']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (_isSettled(debt))
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.incomeLight,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'LUNAS',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.income,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Text(
                            _isSettled(debt)
                                ? 'Lunas • pokok ${money(debt['principal'])}'
                                : 'Sisa ${money(debt['outstanding'])} • jatuh tempo ${debt['due_date'] != null ? DateFormatter.calendarDate(debt['due_date']) : 'belum ditentukan'}',
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
                                  const Divider(
                                    height: 1,
                                    color: AppColors.border,
                                  ),
                                  const SizedBox(height: 12),

                                  // Financial Overview Card
                                  Builder(
                                    builder: (_) {
                                      final principalMinor = obligationMinor(
                                        '${debt['principal']}',
                                      );
                                      final outstandingMinor = obligationMinor(
                                        '${debt['outstanding']}',
                                      );
                                      final paidMinor =
                                          principalMinor > outstandingMinor
                                          ? principalMinor - outstandingMinor
                                          : BigInt.zero;
                                      final progress =
                                          principalMinor > BigInt.zero
                                          ? ((paidMinor * BigInt.from(10000)) ~/
                                                        principalMinor)
                                                    .toInt()
                                                    .clamp(0, 10000) /
                                                10000.0
                                          : 1.0;
                                      final percentStr =
                                          principalMinor > BigInt.zero
                                          ? ((paidMinor * BigInt.from(100)) ~/
                                                    principalMinor)
                                                .toInt()
                                                .clamp(0, 100)
                                                .toString()
                                          : '100';

                                      return Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceVariant
                                              .withValues(alpha: 0.5),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: AppColors.border.withValues(
                                              alpha: 0.7,
                                            ),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      debt['kind'] == 'PAYABLE'
                                                          ? 'POKOK PINJAMAN'
                                                          : 'POKOK PIUTANG',
                                                      style: const TextStyle(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        letterSpacing: 0.5,
                                                        color:
                                                            AppColors.textMuted,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      money(debt['principal']),
                                                      style: const TextStyle(
                                                        fontSize: 13.5,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: AppColors
                                                            .textPrimary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.end,
                                                  children: [
                                                    Text(
                                                      debt['kind'] == 'PAYABLE'
                                                          ? 'SISA UTANG'
                                                          : 'SISA PIUTANG',
                                                      style: const TextStyle(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        letterSpacing: 0.5,
                                                        color:
                                                            AppColors.textMuted,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      money(
                                                        debt['outstanding'],
                                                      ),
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color:
                                                            debt['kind'] ==
                                                                'PAYABLE'
                                                            ? AppColors.expense
                                                            : AppColors.income,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            if (principalMinor >
                                                BigInt.zero) ...[
                                              const SizedBox(height: 8),
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(3),
                                                child: LinearProgressIndicator(
                                                  value: progress,
                                                  minHeight: 5,
                                                  backgroundColor:
                                                      AppColors.border,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                        Color
                                                      >(
                                                        debt['kind'] ==
                                                                'PAYABLE'
                                                            ? AppColors.expense
                                                            : AppColors.income,
                                                      ),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    debt['kind'] == 'PAYABLE'
                                                        ? 'Terbayar: ${moneyMinor(paidMinor)}'
                                                        : 'Diterima: ${moneyMinor(paidMinor)}',
                                                    style: const TextStyle(
                                                      fontSize: 10.5,
                                                      color: AppColors
                                                          .textSecondary,
                                                    ),
                                                  ),
                                                  Text(
                                                    '$percentStr%',
                                                    style: const TextStyle(
                                                      fontSize: 10.5,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: AppColors
                                                          .textSecondary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 12),

                                  // Action Buttons
                                  Row(
                                    children: [
                                      if (!_isSettled(debt)) ...[
                                        Expanded(
                                          child: FilledButton.icon(
                                            style: FilledButton.styleFrom(
                                              backgroundColor:
                                                  AppColors.primary,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 10,
                                                  ),
                                            ),
                                            onPressed: () => form(debt: debt),
                                            icon: const Icon(
                                              Icons.payments_rounded,
                                              size: 16,
                                            ),
                                            label: Text(
                                              debt['kind'] == 'PAYABLE'
                                                  ? 'Bayar / cicil'
                                                  : 'Terima pembayaran',
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor:
                                                AppColors.textSecondary,
                                            side: const BorderSide(
                                              color: AppColors.border,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 10,
                                            ),
                                          ),
                                          onPressed: () => confirm(
                                            _isSettled(debt)
                                                ? 'Arsipkan pinjaman lunas ini dari daftar utama? Riwayat pembayaran tetap tersimpan.'
                                                : 'Pinjaman tanpa pembayaran aktif dapat dibatalkan sekaligus mengembalikan saldo awal. Lanjutkan?',
                                            () => repo.delete(
                                              debt['id'] as String,
                                            ),
                                          ),
                                          icon: const Icon(
                                            Icons.archive_outlined,
                                            size: 16,
                                          ),
                                          label: Text(
                                            _isSettled(debt)
                                                ? 'Arsipkan'
                                                : 'Arsipkan / batalkan',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Linked Account Notice
                                  if (debt['linked_account_id'] != null) ...[
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppColors.infoLight,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.sync_alt_rounded,
                                            size: 14,
                                            color: AppColors.info,
                                          ),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Menggantikan akun lama dalam net worth; pelunasan pokok juga memperbarui akun tersebut.',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: AppColors.info,
                                                height: 1.3,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],

                                  // Installment Schedule
                                  if (repo
                                      .schedule(debt['id'] as String)
                                      .isNotEmpty) ...[
                                    const SizedBox(height: 14),
                                    const Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_month_rounded,
                                          size: 15,
                                          color: AppColors.primary,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'Jadwal Cicilan Pokok',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12.5,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    for (final row in repo.schedule(
                                      debt['id'] as String,
                                    ))
                                      Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 6,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceVariant
                                              .withValues(alpha: 0.4),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: AppColors.border.withValues(
                                              alpha: 0.6,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.event_outlined,
                                              size: 14,
                                              color: AppColors.textMuted,
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                DateFormatter.calendarDate(
                                                  row['due_date'],
                                                ),
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: AppColors.border,
                                                ),
                                              ),
                                              child: Text(
                                                'Sisa pokok ${money(row['remaining'])}',
                                                style: const TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w600,
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 4,
                                      ),
                                      child: Text(
                                        'Pembayaran pokok dialokasikan berurutan; bunga/biaya dicatat terpisah saat bayar.',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textMuted,
                                          height: 1.3,
                                        ),
                                      ),
                                    ),
                                  ],

                                  // Payment & Correction History
                                  const SizedBox(height: 14),
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.history_rounded,
                                        size: 15,
                                        color: AppColors.primary,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Riwayat pembayaran & koreksi',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12.5,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  if (repo.events(debt['id'] as String).isEmpty)
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                        horizontal: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceVariant
                                            .withValues(alpha: 0.3),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: AppColors.border.withValues(
                                            alpha: 0.5,
                                          ),
                                        ),
                                      ),
                                      child: const Center(
                                        child: Text(
                                          'Belum ada pembayaran atau penyesuaian untuk pinjaman ini.',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: AppColors.textMuted,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                    ),
                                  for (final event in repo.events(
                                    debt['id'] as String,
                                  ))
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: event['reversed_at'] != null
                                              ? AppColors.border
                                              : AppColors.primary.withValues(
                                                  alpha: 0.2,
                                                ),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.02,
                                            ),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 7,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      event['reversed_at'] !=
                                                          null
                                                      ? AppColors.expenseLight
                                                      : (event['operation'] ==
                                                                'REPAY'
                                                            ? AppColors
                                                                  .incomeLight
                                                            : AppColors
                                                                  .surfaceVariant),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  event['reversed_at'] != null
                                                      ? 'DIBALIKKAN'
                                                      : _eventOperationLabel(
                                                          event['operation'],
                                                        ),
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color:
                                                        event['reversed_at'] !=
                                                            null
                                                        ? AppColors.expense
                                                        : (event['operation'] ==
                                                                  'REPAY'
                                                              ? AppColors.income
                                                              : AppColors
                                                                    .textPrimary),
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                DateFormatter.timestamp(
                                                  event['transacted_at'],
                                                  timeZone: AppStateScope.of(
                                                    context,
                                                  ).timeZone,
                                                ),
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.textMuted,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    const Text(
                                                      'POKOK',
                                                      style: TextStyle(
                                                        fontSize: 9,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color:
                                                            AppColors.textMuted,
                                                      ),
                                                    ),
                                                    Text(
                                                      money(event['principal']),
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: AppColors
                                                            .textPrimary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    const Text(
                                                      'BUNGA',
                                                      style: TextStyle(
                                                        fontSize: 9,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color:
                                                            AppColors.textMuted,
                                                      ),
                                                    ),
                                                    Text(
                                                      money(event['interest']),
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: AppColors
                                                            .textSecondary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    const Text(
                                                      'BIAYA',
                                                      style: TextStyle(
                                                        fontSize: 9,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color:
                                                            AppColors.textMuted,
                                                      ),
                                                    ),
                                                    Text(
                                                      money(event['fee']),
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: AppColors
                                                            .textSecondary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              if (event['operation'] ==
                                                      'REPAY' &&
                                                  event['reversed_at'] == null)
                                                OutlinedButton.icon(
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor:
                                                        AppColors.expense,
                                                    side: const BorderSide(
                                                      color: AppColors
                                                          .expenseLight,
                                                    ),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 4,
                                                        ),
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                    ),
                                                  ),
                                                  onPressed: () => confirm(
                                                    'Batalkan pembayaran ini? Saldo dan sisa pokok akan dikembalikan, sementara riwayat koreksi tetap tercatat.',
                                                    () => repo.reverse(
                                                      debt['id'] as String,
                                                      event['id'] as String,
                                                    ),
                                                  ),
                                                  icon: const Icon(
                                                    Icons.undo_rounded,
                                                    size: 13,
                                                  ),
                                                  label: const Text(
                                                    'Koreksi',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
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
