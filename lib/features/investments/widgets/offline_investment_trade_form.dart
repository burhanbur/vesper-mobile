import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../models/investment.dart';
import '../models/investment_settlement.dart';

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
    final repo = state.repository!;
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
      decoration: InputDecoration(labelText: label),
      items: rows
          .map(
            (r) => DropdownMenuItem<String>(
              value: r['id'] as String,
              child: Text('${r['name'] ?? r['code'] ?? r['id']}'),
            ),
          )
          .toList(),
      onChanged: (v) => setState(() => change(v)),
    );
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Catat Transaksi Investasi',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Text(
                'BUY/SELL disimpan lokal. Dividen belum didukung. Selesaikan sinkronisasi awal sebelum mencatat.',
              ),
              SegmentedButton<InvestmentTradeType>(
                segments: const [
                  ButtonSegment(
                    value: InvestmentTradeType.buy,
                    label: Text('BELI'),
                  ),
                  ButtonSegment(
                    value: InvestmentTradeType.sell,
                    label: Text('JUAL'),
                  ),
                ],
                selected: {type},
                onSelectionChanged: (v) => setState(() => type = v.single),
              ),
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
              picker(
                'Instrumen',
                instruments,
                instrumentId,
                (v) => instrumentId = v,
              ),
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
              for (final field in [
                (quantity, 'Jumlah unit (maks. 8 desimal)'),
                (price, 'Harga per unit (Rp)'),
                (fee, 'Biaya (Rp)'),
              ])
                TextField(
                  controller: field.$1,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: field.$2,
                    helperText: 'Gunakan titik sebagai pemisah desimal',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              TextField(
                controller: note,
                maxLength: 5000,
                decoration: const InputDecoration(labelText: 'Catatan'),
                onChanged: (_) => setState(() {}),
              ),
              Text('Nilai kas: ${total == null ? '—' : 'Rp $total'}'),
              if (position != null) Text(position),
              for (final item in repo.outbox.where(
                (e) => e['entity_type'] == 'investment_transactions',
              ))
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Command ${item['entity_id']}: ${item['status']}${item['error'] == null ? '' : ' — ${item['error']}'}',
                    ),
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
                  ],
                ),
              if (blocked != null) Text(blocked),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              FilledButton(
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
                child: const Text('Simpan lokal'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
