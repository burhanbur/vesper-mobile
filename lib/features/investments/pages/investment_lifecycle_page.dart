import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../app/theme/app_colors.dart';
import '../data/investment_lifecycle_controller.dart';
import '../data/investment_lifecycle_repository.dart';
import '../models/investment.dart';
import '../widgets/offline_investment_trade_form.dart';

class InvestmentLifecyclePage extends StatefulWidget {
  const InvestmentLifecyclePage({super.key});
  @override
  State<InvestmentLifecyclePage> createState() =>
      _InvestmentLifecyclePageState();
}

class _InvestmentLifecyclePageState extends State<InvestmentLifecyclePage> {
  InvestmentLifecycleController? controller;
  String search = '';
  String? accountId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppStateScope.of(context);
    final source = state.repository;
    final user = state.currentUserId;
    if (accountId != null &&
        (source == null || !source.canTradeAccount(accountId!, 'INVESTMENT'))) {
      accountId = null;
    }
    if (source == null || user.isEmpty || source.userId != user) {
      controller?.dispose();
      controller = null;
    } else if (!identical(controller?.repository.source, source)) {
      controller?.dispose();
      controller = InvestmentLifecycleController(
        InvestmentLifecycleRepository(source),
        () =>
            mounted &&
            identical(state.repository, source) &&
            state.currentUserId == user,
        state.requestAutomaticSync,
      );
      unawaited(controller!.refresh());
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  Future<void> edit({Map<String, dynamic>? instrument}) async {
    final active = controller!;
    final code = TextEditingController();
    final name = TextEditingController();
    final date = TextEditingController(
      text: DateTime.now().toUtc().toIso8601String().substring(0, 10),
    );
    final price = TextEditingController();
    String type = 'STOCK';
    String? error;
    try {
      await showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: Colors.white,
            title: Text(
              instrument == null
                  ? 'Tambah instrumen IDR'
                  : 'Harga ${instrument['code']}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (instrument == null) ...[
                    TextField(
                      controller: code,
                      decoration: const InputDecoration(labelText: 'Kode'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Nama'),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: type,
                      decoration: const InputDecoration(labelText: 'Tipe'),
                      items:
                          [
                                'STOCK',
                                'MUTUAL_FUND',
                                'BOND',
                                'CRYPTO',
                                'COMMODITY',
                                'OTHER',
                              ]
                              .map(
                                (t) =>
                                    DropdownMenuItem(value: t, child: Text(t)),
                              )
                              .toList(),
                      onChanged: (t) => type = t!,
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Harga manual global untuk instrumen ini. Tanggal yang sama mengganti harga sebelumnya. Disimpan lokal sebelum dikirim.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                    TextField(
                      controller: date,
                      decoration: const InputDecoration(
                        labelText: 'Tanggal UTC (YYYY-MM-DD)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: price,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Harga IDR (maks. 8 desimal)',
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
                onPressed: () {
                  try {
                    if (instrument == null) {
                      active.saveInstrument(code.text, name.text, type);
                    } else {
                      active.savePrice(
                        instrument['id'] as String,
                        date.text,
                        price.text,
                      );
                    }
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Tersimpan lokal • menunggu sinkronisasi',
                        ),
                      ),
                    );
                  } catch (failure) {
                    setDialogState(() => error = failure.toString());
                  }
                },
                child: const Text('Simpan lokal'),
              ),
            ],
          ),
        ),
      );
    } finally {
      // Dialog route animations can still reference fields until the next frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        code.dispose();
        name.dispose();
        date.dispose();
        price.dispose();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = controller;
    final hidden = AppStateScope.of(context).isBalanceHidden;
    String money(String? value) => hidden
        ? '••••••'
        : value == null
        ? 'Belum tersedia'
        : 'IDR $value';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Kelola investasi',
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
                InvestmentOverview? overview;
                List<Map<String, dynamic>> history = [];
                String? readError;
                try {
                  overview = repo.overview();
                  history = repo.history(accountId).reversed.toList();
                } catch (failure) {
                  readError = failure.toString();
                }
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Text(
                      'IDR • Akun investasi aktif milik Anda. Ringkasan lokal, termasuk perintah menunggu sinkronisasi. Kas settlement tidak dijumlahkan ke nilai holding.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton(
                          onPressed: () => showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => const OfflineInvestmentTradeForm(
                              initialType: InvestmentTradeType.buy,
                            ),
                          ),
                          child: const Text('Beli / Jual / Dividen'),
                        ),
                        OutlinedButton(
                          onPressed: () => edit(),
                          child: const Text('Tambah instrumen'),
                        ),
                        TextButton(
                          onPressed: active.loading ? null : active.refresh,
                          child: const Text('Cari data server'),
                        ),
                      ],
                    ),
                    if (active.loading) const LinearProgressIndicator(),
                    if (active.error != null)
                      Text(
                        active.error!,
                        style: const TextStyle(color: AppColors.expense),
                      ),
                    if (readError != null)
                      Text(
                        readError,
                        style: const TextStyle(color: AppColors.expense),
                      ),
                    if (overview != null) ...[
                      const SizedBox(height: 12),
                      const Row(
                        children: [
                          Icon(
                            Icons.query_stats_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Ringkasan lintas akun',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Modal beli kumulatif (termasuk fee): ${money(overview.contributed)}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        'Hasil jual bersih: ${money(overview.proceeds)}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        'Laba/rugi jual terealisasi: ${money(overview.realized)}',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: !overview.realized.startsWith('-')
                              ? AppColors.income
                              : AppColors.expense,
                        ),
                      ),
                      Text(
                        'Fee beli / pajak terpisah: ${money(overview.buyFees)}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        'Dividen bersih: ${money(overview.dividends)}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.income,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Nilai pasar holding: ${money(overview.marketValue)}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Laba/rugi belum terealisasi: ${money(overview.unrealized)}',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: overview.unrealized != null &&
                                  !overview.unrealized!.startsWith('-')
                              ? AppColors.income
                              : AppColors.expense,
                        ),
                      ),
                      if (overview.missingPrices > 0)
                        Text(
                          '${overview.missingPrices} posisi belum memiliki harga; total valuasi tidak tersedia.',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.warning,
                          ),
                        ),
                      const SizedBox(height: 2),
                      const Text(
                        'Biaya rata-rata tidak termasuk fee beli. Laba jual mengurangi fee jual. Dividen bukan kontribusi modal.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                    const Divider(height: 20),
                    const Row(
                      children: [
                        Icon(
                          Icons.candlestick_chart_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Instrumen & harga manual',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Cache katalog: ${source.state['investment_catalog_fetched_at'] ?? 'belum pernah dimuat'}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const Text(
                      'Harga bertanggal, bukan real-time. Harga lama/cache offline mungkin usang; periksa tanggal sebelum memakai valuasi.',
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'Cari kode / nama instrumen',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (v) =>
                          setState(() => search = v.toLowerCase()),
                    ),
                    for (final item in repo.instruments.where(
                      (r) =>
                          '${r['code']} ${r['name']}'.toLowerCase().contains(
                            search,
                          ),
                    ))
                      ListTile(
                        title: Text(
                          '${item['code']} • ${item['name']}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${item['type']} • ${item['pending_catalog'] == true ? 'Menunggu sinkronisasi' : 'IDR'}',
                        ),
                        trailing: TextButton(
                          onPressed: () => edit(instrument: item),
                          child: const Text('Harga'),
                        ),
                      ),
                    for (final quote in source.rows('instrument_prices'))
                      Text(
                        '${source.row('instruments', '${quote['instrument_id']}')?['code'] ?? quote['instrument_id']}: ${money(quote['close_price'] as String?)} • ${quote['price_date']} UTC${quote['pending_catalog'] == true ? ' • lokal/pending' : ''}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    if (source.pendingInvestmentCatalog.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.warningLight.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.hourglass_top_rounded,
                                  size: 16,
                                  color: AppColors.warning,
                                ),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Antrean katalog • otomatis dicoba ulang saat sinkronisasi',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      color: AppColors.warning,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            for (final item in source.pendingInvestmentCatalog)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${item['payload']['code'] ?? item['payload']['price_date']}: ${item['error'] ?? 'Menunggu pengiriman'}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  if (item['error'] != null)
                                    TextButton(
                                      onPressed: source.isSyncing
                                          ? null
                                          : () async {
                                              final discard =
                                                  await showDialog<bool>(
                                                    context: context,
                                                    builder: (ctx) =>
                                                        AlertDialog(
                                                          title: const Text(
                                                            'Hentikan pengiriman katalog?',
                                                          ),
                                                          content: const Text(
                                                            'Antrean dan nilai lokal terkait akan dihapus. Ini tidak membatalkan perubahan yang mungkin sudah diterima server. Muat ulang katalog untuk memeriksa hasilnya.',
                                                          ),
                                                          actions: [
                                                            TextButton(
                                                              onPressed: () =>
                                                                  Navigator.pop(
                                                                    ctx,
                                                                    false,
                                                                  ),
                                                              child: const Text(
                                                                'Kembali',
                                                              ),
                                                            ),
                                                            FilledButton(
                                                              onPressed: () =>
                                                                  Navigator.pop(
                                                                    ctx,
                                                                    true,
                                                                  ),
                                                              child: const Text(
                                                                'Hentikan',
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                  );
                                              if (discard == true &&
                                                  context.mounted) {
                                                try {
                                                  active.discardCatalog(
                                                    item['id'] as String,
                                                  );
                                                } catch (failure) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        failure.toString(),
                                                      ),
                                                    ),
                                                  );
                                                }
                                              }
                                            },
                                      child: const Text(
                                        'Hentikan pengiriman lokal',
                                      ),
                                    ),
                                ],
                              ),
                            TextButton.icon(
                              onPressed: () async {
                                try {
                                  await AppStateScope.of(
                                    context,
                                  ).checkInvestmentRecovery();
                                } catch (_) {
                                  /* Queue retains the delivery error. */
                                }
                                if (mounted) setState(() {});
                              },
                              icon: const Icon(Icons.sync_rounded, size: 16),
                              label: const Text('Sinkronkan ulang'),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const Divider(height: 20),
                    const Row(
                      children: [
                        Icon(
                          Icons.history_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Riwayat investasi',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      key: ValueKey(accountId),
                      initialValue: accountId ?? '',
                      decoration: InputDecoration(
                        labelText: 'Filter akun',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('Semua akun'),
                        ),
                        for (final account
                            in source
                                .rows('accounts')
                                .where(
                                  (r) => source.canTradeAccount(
                                    '${r['id']}',
                                    'INVESTMENT',
                                  ),
                                ))
                          DropdownMenuItem(
                            value: account['id'] as String,
                            child: Text('${account['name']}'),
                          ),
                      ],
                      onChanged: (v) =>
                          setState(() => accountId = v == '' ? null : v),
                    ),
                    const SizedBox(height: 8),
                    if (history.isEmpty && readError == null)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        alignment: Alignment.center,
                        child: Column(
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 36,
                              color: AppColors.textMuted.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Belum ada transaksi investasi.',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    for (final row in history)
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        color: Colors.white,
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(
                            '${row['type']} • ${source.row('instruments', '${row['instrument_id']}')?['code'] ?? row['instrument_id']}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${source.row('accounts', '${row['account_id']}')?['name']} • ${row['transacted_at']}\n'
                            '${hidden ? '••••••' : row['quantity']} unit × ${money(row['price_per_unit'] as String?)}\n'
                            'Fee/pajak: ${money(row['fee'] as String?)} • ${row['version'] == '0' ? 'Lokal/pending' : 'Tersinkron'}\n${row['description'] ?? ''}',
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    const Text(
                      'Transaksi diterima bersifat tetap. Untuk kesalahan transaksi, periksa riwayat dan hubungi pengelola; jangan mencatat ulang transaksi dengan status belum pasti. Pemulihan perintah tersedia pada formulir transaksi.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        height: 1.35,
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
