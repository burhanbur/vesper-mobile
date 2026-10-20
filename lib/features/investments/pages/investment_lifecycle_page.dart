import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
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
            title: Text(
              instrument == null
                  ? 'Tambah instrumen IDR'
                  : 'Harga ${instrument['code']}',
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (instrument == null) ...[
                    TextField(
                      controller: code,
                      decoration: const InputDecoration(labelText: 'Kode'),
                    ),
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Nama'),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: type,
                      items:
                          [
                                'STOCK',
                                'MUTUAL_FUND',
                                'CRYPTO',
                                'BOND',
                                'GOLD',
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
                    const Text(
                      'Harga manual global untuk instrumen ini. Tanggal yang sama mengganti harga sebelumnya. Disimpan lokal sebelum dikirim.',
                    ),
                    TextField(
                      controller: date,
                      decoration: const InputDecoration(
                        labelText: 'Tanggal UTC (YYYY-MM-DD)',
                      ),
                    ),
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
      appBar: AppBar(title: const Text('Kelola investasi')),
      body: active == null
          ? const Center(child: Text('Silakan masuk kembali.'))
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
                    ),
                    Wrap(
                      spacing: 8,
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
                    if (active.error != null) Text(active.error!),
                    if (readError != null) Text(readError),
                    if (overview != null) ...[
                      const Text(
                        'Ringkasan lintas akun',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Modal beli kumulatif (termasuk fee): ${money(overview.contributed)}',
                      ),
                      Text('Hasil jual bersih: ${money(overview.proceeds)}'),
                      Text(
                        'Laba/rugi jual terealisasi: ${money(overview.realized)}',
                      ),
                      Text(
                        'Fee beli / pajak terpisah: ${money(overview.buyFees)}',
                      ),
                      Text('Dividen bersih: ${money(overview.dividends)}'),
                      Text(
                        'Nilai pasar holding: ${money(overview.marketValue)}',
                      ),
                      Text(
                        'Laba/rugi belum terealisasi: ${money(overview.unrealized)}',
                      ),
                      if (overview.missingPrices > 0)
                        Text(
                          '${overview.missingPrices} posisi belum memiliki harga; total valuasi tidak tersedia.',
                        ),
                      const Text(
                        'Biaya rata-rata tidak termasuk fee beli. Laba jual mengurangi fee jual. Dividen bukan kontribusi modal.',
                      ),
                    ],
                    const Divider(),
                    const Text(
                      'Instrumen & harga manual',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Cache katalog: ${source.state['investment_catalog_fetched_at'] ?? 'belum pernah dimuat'}',
                    ),
                    const Text(
                      'Harga bertanggal, bukan real-time. Harga lama/cache offline mungkin usang; periksa tanggal sebelum memakai valuasi.',
                    ),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Cari kode / nama instrumen',
                      ),
                      onChanged: (v) =>
                          setState(() => search = v.toLowerCase()),
                    ),
                    for (final item in repo.instruments.where(
                      (r) => '${r['code']} ${r['name']}'.toLowerCase().contains(
                        search,
                      ),
                    ))
                      ListTile(
                        title: Text('${item['code']} • ${item['name']}'),
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
                      ),
                    if (source.pendingInvestmentCatalog.isNotEmpty) ...[
                      const Text(
                        'Antrean katalog • otomatis dicoba ulang saat sinkronisasi',
                      ),
                      for (final item in source.pendingInvestmentCatalog)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${item['payload']['code'] ?? item['payload']['price_date']}: ${item['error'] ?? 'Menunggu pengiriman'}',
                            ),
                            if (item['error'] != null)
                              TextButton(
                                onPressed: source.isSyncing
                                    ? null
                                    : () async {
                                        final discard = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text(
                                              'Hentikan pengiriman katalog?',
                                            ),
                                            content: const Text(
                                              'Antrean dan nilai lokal terkait akan dihapus. Ini tidak membatalkan perubahan yang mungkin sudah diterima server. Muat ulang katalog untuk memeriksa hasilnya.',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, false),
                                                child: const Text('Kembali'),
                                              ),
                                              FilledButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, true),
                                                child: const Text('Hentikan'),
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
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      failure.toString(),
                                                    ),
                                                  ),
                                                );
                                          }
                                        }
                                      },
                                child: const Text('Hentikan pengiriman lokal'),
                              ),
                          ],
                        ),
                      TextButton(
                        onPressed: () async {
                          try {
                            await AppStateScope.of(context)
                                .checkInvestmentRecovery();
                          } catch (_) {
                            /* Queue retains the delivery error. */
                          }
                          if (mounted) setState(() {});
                        },
                        child: const Text('Sinkronkan ulang'),
                      ),
                    ],
                    const Divider(),
                    const Text(
                      'Riwayat investasi',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    DropdownButtonFormField<String>(
                      key: ValueKey(accountId),
                      initialValue: accountId ?? '',
                      decoration: const InputDecoration(
                        labelText: 'Filter akun',
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
                    if (history.isEmpty && readError == null)
                      const Text('Belum ada transaksi investasi.'),
                    for (final row in history)
                      Card(
                        child: ListTile(
                          title: Text(
                            '${row['type']} • ${source.row('instruments', '${row['instrument_id']}')?['code'] ?? row['instrument_id']}',
                          ),
                          subtitle: Text(
                            '${source.row('accounts', '${row['account_id']}')?['name']} • ${row['transacted_at']}\n'
                            '${hidden ? '••••••' : row['quantity']} unit × ${money(row['price_per_unit'] as String?)}\n'
                            'Fee/pajak: ${money(row['fee'] as String?)} • ${row['version'] == '0' ? 'Lokal/pending' : 'Tersinkron'}\n${row['description'] ?? ''}',
                          ),
                        ),
                      ),
                    const Text(
                      'Transaksi diterima bersifat tetap. Untuk kesalahan transaksi, periksa riwayat dan hubungi pengelola; jangan mencatat ulang transaksi dengan status belum pasti. Pemulihan perintah tersedia pada formulir transaksi.',
                    ),
                  ],
                );
              },
            ),
    );
  }
}
