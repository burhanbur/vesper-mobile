import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../app/theme/app_colors.dart';
import '../models/investment.dart';
import '../models/investment_settlement.dart';
import 'investment_recovery_sheet.dart';

class OfflineInvestmentTradeForm extends StatefulWidget {
  final InvestmentTradeType initialType;
  const OfflineInvestmentTradeForm({super.key, required this.initialType});

  @override
  State<OfflineInvestmentTradeForm> createState() =>
      _OfflineInvestmentTradeFormState();
}

class _OfflineInvestmentTradeFormState
    extends State<OfflineInvestmentTradeForm> {
  final quantity = TextEditingController();
  final price = TextEditingController();
  final fee = TextEditingController(text: '0');
  final note = TextEditingController();
  String? accountId, cashId, instrumentId, error;
  late InvestmentTradeType type = widget.initialType == InvestmentTradeType.sell
      ? InvestmentTradeType.sell
      : InvestmentTradeType.buy;

  @override
  void dispose() {
    for (final controller in [quantity, price, fee, note]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final repo = state.repository;
    if (repo == null) {
      return const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Silakan masuk kembali untuk membuka transaksi investasi.',
          ),
        ),
      );
    }
    final accounts = repo.rows('accounts');
    final instruments = repo
        .rows('instruments')
        .where((r) => r['deleted_at'] == null && r['currency'] == 'IDR')
        .toList();
    String? total;
    try {
      total = InvestmentSettlement.calculate(
        type: type.name.toUpperCase(),
        quantity: quantity.text,
        pricePerUnit: price.text,
        fee: fee.text,
      ).amount;
    } on FormatException {
      total = null;
    }
    String? blocked;
    if (!repo.hasCompleteInvestmentHistory) {
      blocked = 'Selesaikan sinkronisasi awal sebelum mencatat investasi.';
    } else if (repo.hasUnresolvedInvestmentTrade) {
      blocked = 'Perintah investasi sebelumnya masih menunggu rekonsiliasi.';
    } else if (repo.isSyncing) {
      blocked = 'Tunggu hingga sinkronisasi selesai.';
    } else if (accountId == null || cashId == null || instrumentId == null) {
      blocked = 'Pilih portofolio, instrumen, dan akun kas aktif.';
    } else {
      try {
        repo.previewInvestmentTrade(
          accountId: accountId!,
          cashAccountId: cashId!,
          instrumentId: instrumentId!,
          type: type.name.toUpperCase(),
          quantity: quantity.text,
          pricePerUnit: price.text,
          fee: fee.text,
          description: note.text,
          at: DateTime.fromMillisecondsSinceEpoch(
            DateTime.now().millisecondsSinceEpoch,
            isUtc: true,
          ),
        );
      } catch (failure) {
        blocked = failure.toString();
      }
    }
    String? position;
    if (accountId != null && instrumentId != null) {
      try {
        final current = repo
            .investmentHistory(accountId!)
            .position(instrumentId!);
        position =
            'Posisi lokal: ${current.quantity} unit; biaya rata-rata ${current.average}';
      } catch (_) {
        position = 'Posisi lokal belum dapat diverifikasi.';
      }
    }
    Widget picker(
      String label,
      List<Map<String, dynamic>> rows,
      String? value,
      void Function(String?) change,
    ) => DropdownButtonFormField<String>(
      key: ValueKey('$label:$value:${rows.map((r) => r['id']).join(',')}'),
      initialValue: rows.any((r) => r['id'] == value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(
          label == 'Portofolio'
              ? Icons.pie_chart_outline_rounded
              : label == 'Instrumen'
              ? Icons.show_chart_rounded
              : Icons.account_balance_wallet_outlined,
          size: 20,
          color: AppColors.primary,
        ),
        filled: true,
        fillColor: AppColors.surfaceVariant.withValues(alpha: 0.35),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
      items: rows
          .map(
            (r) => DropdownMenuItem<String>(
              value: r['id'] as String,
              child: Text(
                '${r['name'] ?? r['code'] ?? r['id']}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: (v) => setState(() => change(v)),
    );

    final isBuy = type == InvestmentTradeType.buy;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top drag indicator
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.candlestick_chart_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Catat Transaksi Investasi',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Offline-first • Simpan lokal & sinkron otomatis',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Info note banner
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'BUY/SELL disimpan lokal. Dividen belum didukung. Selesaikan sinkronisasi awal sebelum mencatat.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Segmented Button (BELI / JUAL) with no checkmark squishing text
              SegmentedButton<InvestmentTradeType>(
                showSelectedIcon: false,
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return isBuy
                          ? const Color(0xFF0D9488)
                          : const Color(0xFFE11D48);
                    }
                    return Colors.transparent;
                  }),
                  foregroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return Colors.white;
                    }
                    return AppColors.textSecondary;
                  }),
                  shape: WidgetStateProperty.all(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                segments: const [
                  ButtonSegment(
                    value: InvestmentTradeType.buy,
                    label: Text(
                      'BELI',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  ButtonSegment(
                    value: InvestmentTradeType.sell,
                    label: Text(
                      'JUAL',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
                selected: {type},
                onSelectionChanged: (v) => setState(() => type = v.single),
              ),
              const SizedBox(height: 14),

              // Dropdown Pickers (Order preserved for tests: Portofolio, Instrumen, Akun kas)
              picker(
                'Portofolio',
                accounts
                    .where(
                      (r) =>
                          repo.canTradeAccount(r['id'] as String, 'INVESTMENT'),
                    )
                    .toList(),
                accountId,
                (v) => accountId = v,
              ),
              const SizedBox(height: 10),
              picker(
                'Instrumen',
                instruments,
                instrumentId,
                (v) => instrumentId = v,
              ),
              const SizedBox(height: 10),
              picker(
                'Akun kas',
                accounts
                    .where(
                      (r) => repo.canTradeAccount(r['id'] as String, 'CASH'),
                    )
                    .toList(),
                cashId,
                (v) => cashId = v,
              ),
              const SizedBox(height: 14),

              // Input Fields (Order preserved: 0=quantity, 1=price, 2=fee)
              TextField(
                controller: quantity,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Jumlah unit (maks. 8 desimal)',
                  prefixIcon: const Icon(
                    Icons.tag_rounded,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  hintText: 'Contoh: 10 atau 0.05432100',
                  filled: true,
                  fillColor: AppColors.surfaceVariant.withValues(alpha: 0.35),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: price,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Harga per unit (Rp)',
                  prefixText: 'Rp ',
                  prefixIcon: const Icon(
                    Icons.price_change_outlined,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  hintText: 'Contoh: 50000',
                  filled: true,
                  fillColor: AppColors.surfaceVariant.withValues(alpha: 0.35),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: fee,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Biaya (Rp)',
                  prefixText: 'Rp ',
                  prefixIcon: const Icon(
                    Icons.receipt_long_outlined,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  hintText: 'Contoh: 2500',
                  filled: true,
                  fillColor: AppColors.surfaceVariant.withValues(alpha: 0.35),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: note,
                maxLength: 5000,
                decoration: InputDecoration(
                  labelText: 'Catatan',
                  prefixIcon: const Icon(
                    Icons.edit_note_rounded,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  hintText: 'Tulis keterangan atau strategi (opsional)',
                  filled: true,
                  fillColor: AppColors.surfaceVariant.withValues(alpha: 0.35),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 6),

              // Settlement Summary Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isBuy
                      ? const Color(0xFFF0FDF4)
                      : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isBuy
                        ? AppColors.primary.withValues(alpha: 0.25)
                        : const Color(0xFFFCA5A5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isBuy
                              ? 'Estimasi Kas Terpotong'
                              : 'Estimasi Kas Diterima',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isBuy
                                ? AppColors.incomeLight
                                : AppColors.expenseLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isBuy ? 'Pengeluaran Kas' : 'Penerimaan Kas',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isBuy
                                  ? AppColors.income
                                  : AppColors.expense,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Nilai kas: ${total == null ? '—' : 'Rp $total'}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (position != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.insights_rounded,
                              size: 14,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                position,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Command recovery & retry options
              for (final item in repo.outbox.where(
                (e) => e['entity_type'] == 'investment_transactions',
              ))
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Command ${item['entity_id']}: ${item['status']}${item['error'] == null ? '' : ' — ${item['error']}'}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (['rejected', 'conflict'].contains(item['status']))
                        OutlinedButton(
                          onPressed: repo.isSyncing
                              ? null
                              : () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text(
                                        'Coba ulang perintah asli?',
                                      ),
                                      content: const Text(
                                        'ID dan isi transaksi tidak berubah. Tidak ada transaksi baru atau pembatalan saldo. Jika penyebab penolakan belum diperbaiki di server, perintah dapat ditolak kembali.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Batal'),
                                        ),
                                        FilledButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text('Coba ulang'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (!mounted ||
                                      !context.mounted ||
                                      confirmed != true ||
                                      !identical(repo, state.repository) ||
                                      !identical(
                                        state,
                                        AppStateScope.of(context),
                                      )) {
                                    return;
                                  }
                                  try {
                                    state.retryInvestmentTrade(
                                      item['id'] as String,
                                    );
                                    setState(() => error = null);
                                  } catch (failure) {
                                    setState(() => error = failure.toString());
                                  }
                                },
                          child: const Text('Coba ulang command asli'),
                        ),
                      const SizedBox(height: 6),
                      OutlinedButton.icon(
                        onPressed: () {
                          try {
                            final reference = repo.investmentRecoveryReference(
                              item['id'] as String,
                            );
                            showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              builder: (_) =>
                                  InvestmentRecoverySheet(reference: reference),
                            );
                          } catch (failure) {
                            setState(() => error = failure.toString());
                          }
                        },
                        icon: const Icon(Icons.support_agent, size: 18),
                        label: const Text('Info pemulihan'),
                      ),
                    ],
                  ),
                ),

              // Blocked banner
              if (blocked != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFD97706),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          blocked,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Error banner
              if (error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Text(
                    error!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),

              // Submit button
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: blocked != null || total == null
                      ? null
                      : () {
                          try {
                            state.recordInvestmentTrade(
                              accountId: accountId!,
                              instrumentId: instrumentId!,
                              cashAccountId: cashId!,
                              tradeType: type,
                              quantity: quantity.text,
                              pricePerUnit: price.text,
                              fee: fee.text,
                              note: note.text,
                            );
                            Navigator.of(context).pop();
                          } catch (e) {
                            setState(() => error = e.toString());
                          }
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: isBuy
                        ? const Color(0xFF0D9488)
                        : const Color(0xFFE11D48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Simpan lokal',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
