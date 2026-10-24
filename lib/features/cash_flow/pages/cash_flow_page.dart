import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../core/utils/date_formatter.dart';
import '../../bills/pages/bills_page.dart';
import '../../obligations/pages/obligations_page.dart';
import '../../reports/data/financial_export_repository.dart';
import '../data/cash_flow_repository.dart';
import '../data/cash_flow_controller.dart';

class CashFlowPage extends StatefulWidget {
  const CashFlowPage({super.key});
  @override
  State<CashFlowPage> createState() => _CashFlowPageState();
}

class _CashFlowPageState extends State<CashFlowPage> {
  CashFlowController? controller;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppStateScope.of(context), source = state.repository;
    if (source == null ||
        state.currentUserId.isEmpty ||
        state.currentUserId != source.userId) {
      controller = null;
    } else if (!identical(controller?.repository.source, source)) {
      controller = CashFlowController(
        CashFlowRepository(source),
        () =>
            mounted &&
            identical(state.repository, source) &&
            state.currentUserId == source.userId,
      );
    }
  }

  Future<void> configure() async {
    final active = controller!,
        repo = active.repository,
        config = active.repository.assumptions;
    var count = config['days'] as int,
        offset = config['utc_offset_minutes'] as int;
    var estimates = config['include_estimates'] == true,
        overdue = config['include_overdue'] == true,
        receivables = config['include_receivables'] == true,
        reserves = config['reserve_goals'] == true;
    final ids = (config['account_ids'] as List)
        .cast<String>()
        .where((id) => repo.accounts.any((a) => a['id'] == id))
        .toSet();
    final mappings = Map<String, String>.from(config['debt_accounts'] as Map)
      ..removeWhere(
        (key, value) =>
            !repo.accounts.any((a) => a['id'] == value) ||
            !repo.debts.any((d) => d['id'] == key),
      );
    String? error;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('Asumsi proyeksi'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Disimpan hanya per pengguna/perangkat. Tidak mengubah saldo, jadwal asli, atau memindahkan uang.',
                  ),
                  DropdownButtonFormField<int>(
                    initialValue: count,
                    decoration: const InputDecoration(
                      labelText: 'Horizon termasuk hari ini',
                    ),
                    items: [
                      for (final d in [7, 30, 60, 90])
                        DropdownMenuItem(value: d, child: Text('$d hari')),
                    ],
                    onChanged: (v) => update(() => count = v!),
                  ),
                  DropdownButtonFormField<int>(
                    initialValue: offset,
                    decoration: const InputDecoration(
                      labelText: 'Zona hari proyeksi (tanpa DST)',
                    ),
                    items: [
                      for (final e in {
                        0: 'GMT+00:00',
                        420: 'WIB',
                        480: 'WITA',
                        540: 'WIT',
                      }.entries)
                        DropdownMenuItem(value: e.key, child: Text(e.value)),
                    ],
                    onChanged: (v) => update(() => offset = v!),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Sertakan nominal perkiraan tagihan'),
                    value: estimates,
                    onChanged: (v) => update(() => estimates = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Bawa tunggakan ke hari pertama'),
                    value: overdue,
                    onChanged: (v) => update(() => overdue = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Asumsikan piutang dibayar sesuai jadwal',
                    ),
                    value: receivables,
                    onChanged: (v) => update(() => receivables = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Sisihkan alokasi goal yang terdanai'),
                    value: reserves,
                    onChanged: (v) => update(() => reserves = v),
                  ),
                  const Text('Akun kas IDR untuk skenario ini'),
                  for (final a in repo.accounts)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${a['name']}'),
                      value: ids.contains(a['id']),
                      onChanged: (v) => update(() {
                        if (v == true) {
                          ids.add(a['id'] as String);
                        } else {
                          ids.remove(a['id']);
                        }
                      }),
                    ),
                  const Text(
                    'Akun pembayaran/penerimaan pinjaman tanpa tagihan aktif. Jika sudah ditautkan ke Tagihan & Jadwal, akun pada tagihan dipakai. Pilih akun di luar pilihan skenario bila pembayaran dilakukan dari akun tersebut. Pokok dihitung sekali.',
                  ),
                  for (final debt in repo.debts)
                    DropdownButtonFormField<String>(
                      key: ValueKey(
                        '${debt['id']}:${mappings[debt['id']]}:${ids.join(',')}',
                      ),
                      initialValue: mappings[debt['id']],
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: '${debt['counterparty']} (${debt['kind']})',
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Belum ditetapkan'),
                        ),
                        for (final a in repo.accounts)
                          DropdownMenuItem(
                            value: a['id'] as String,
                            child: Text('${a['name']}'),
                          ),
                      ],
                      onChanged: (v) => update(() {
                        if (v == null) {
                          mappings.remove(debt['id']);
                        } else {
                          mappings['${debt['id']}'] = v;
                        }
                      }),
                    ),
                  if (error != null)
                    Text(
                      error!,
                      style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                final ok = active.save({
                  'days': count,
                  'utc_offset_minutes': offset,
                  'include_estimates': estimates,
                  'include_overdue': overdue,
                  'include_receivables': receivables,
                  'reserve_goals': reserves,
                  'account_ids': ids.toList(),
                  'debt_accounts': mappings,
                });
                if (ok) {
                  Navigator.pop(ctx);
                } else {
                  update(() => error = active.error);
                }
              },
              child: const Text('Simpan asumsi'),
            ),
          ],
        ),
      ),
    );
    if (mounted && identical(controller, active)) setState(() {});
  }

  Future<void> open(Widget page) async {
    await Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => page));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context), active = controller;
    if (active == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Proyeksi Arus Kas')),
        body: const Center(
          child: Text('Masuk untuk membuka proyeksi arus kas.'),
        ),
      );
    }
    CashFlowForecast? result;
    String? error;
    try {
      result = active.repository.forecast();
    } catch (e) {
      error = e.toString();
    }
    String money(BigInt value) =>
        state.isBalanceHidden ? '••••••' : '${financialDecimal(value)} IDR';
    final config = active.repository.assumptions;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Proyeksi Arus Kas'),
        actions: [
          IconButton(
            tooltip: 'Sinkronkan',
            icon: const Icon(Icons.sync),
            onPressed: state.loading
                ? null
                : () async {
                    await state.refresh();
                    if (mounted) setState(() {});
                  },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Skenario kas, bukan transaksi',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
          ),
          const Text(
            'Saldo aktual sebagai pembuka; komitmen dan asumsi berikutnya hanya proyeksi. Pembayaran yang sudah dicatat perlu ditautkan di Tagihan & Jadwal agar tidak dianggap belum dibayar.',
          ),
          FilledButton.icon(
            onPressed: configure,
            icon: const Icon(Icons.tune),
            label: const Text('Ubah asumsi proyeksi'),
          ),
          Text(
            'Horizon ${config['days']} hari; zona ${DateFormatter.fixedZone(config['utc_offset_minutes'] as int)}. Termasuk hari pertama dan terakhir yang ditampilkan.',
          ),
          Text(
            'Perkiraan: ${config['include_estimates'] == true ? 'termasuk' : 'dikecualikan'}; tunggakan: ${config['include_overdue'] == true ? 'dibawa ke awal' : 'dikecualikan'}; piutang: ${config['include_receivables'] == true ? 'diasumsikan masuk' : 'dikecualikan'}; alokasi goal: ${config['reserve_goals'] == true ? 'disisihkan' : 'tidak disisihkan'}.',
          ),
          const Text(
            'Tanggal tagihan dipetakan dari pukul 00:00 zona jadwal ke zona proyeksi. Tanggal cicilan tanpa tagihan dianggap berada di zona proyeksi. Alokasi goal dibekukan pada nilai pembuka, bukan rencana setoran mendatang.',
          ),
          if (error != null)
            Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (state.dataError != null) Text(state.dataError!),
          if (result case final r?) ...[
            Text(
              'Periode ${r.start} sampai ${r.end}; dihitung ${DateFormatter.formatFull(r.assessedAt, timeZone: state.timeZone)}.',
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Saldo aktual gabungan: ${money(r.actual)}'),
                    Text('Alokasi goal terdanai: ${money(r.reserved)}'),
                    Text('Kas tersedia pembuka: ${money(r.available)}'),
                    Text(
                      'Proyeksi penutup: ${money(r.closing)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text('Minimum konservatif: ${money(r.minimum)}'),
                    Text(
                      r.firstShortfall == null
                          ? 'Tidak ada kekurangan gabungan pada komitmen yang dimodelkan.'
                          : 'Potensi kekurangan gabungan pertama: ${r.firstShortfall!.date} • ${money(r.firstShortfall!.low)}',
                    ),
                    Text(
                      '${r.paidExcluded} kejadian/pokok lunas dan ${r.skippedExcluded} kejadian dilewati tidak ditambahkan kembali.',
                    ),
                  ],
                ),
              ),
            ),
            const Text(
              'Per akun — tanpa transfer otomatis',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            for (final a in r.accounts)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Aktual: ${money(a.actual)}; tersedia: ${money(a.available)}',
                      ),
                      Text('Penutup: ${money(a.days.last.closing)}'),
                      Text(
                        a.firstShortfall == null
                            ? 'Tidak ada kekurangan pada skenario akun ini.'
                            : 'Potensi kekurangan ${a.firstShortfall!.date}: ${money(a.firstShortfall!.low)}',
                      ),
                    ],
                  ),
                ),
              ),
            ExpansionTile(
              title: const Text('Timeline harian gabungan'),
              children: [
                for (final d in r.days)
                  ListTile(
                    title: Text(d.date),
                    subtitle: Text(
                      'Pembuka ${money(d.opening)}\nMasuk ${money(d.inflow)} • keluar ${money(d.outflow)}\nMinimum ${money(d.low)} • penutup ${money(d.closing)}',
                    ),
                  ),
              ],
            ),
            ExpansionTile(
              title: Text('Komitmen & asumsi (${r.entries.length})'),
              children: [
                if (r.entries.isEmpty)
                  const Text(
                    'Belum ada komitmen dalam horizon ini; pengeluaran yang tidak dijadwalkan belum dimodelkan.',
                  ),
                for (final e in r.entries)
                  ListTile(
                    title: Text(
                      '${e.title} • ${e.income ? 'masuk' : 'keluar'} ${money(e.amount)}',
                    ),
                    subtitle: Text(
                      '${e.date} • jatuh tempo ${e.dueDate}\n${e.source}${e.assumption ? ' • ASUMSI' : ''}${e.overdue ? ' • TUNGGAKAN' : ''}\nAkun: ${r.accounts.firstWhere((a) => a.id == e.accountId).name}',
                    ),
                  ),
              ],
            ),
            const Text(
              'Batas dan kelengkapan data',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            for (final warning in r.warnings)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(warning),
              ),
          ],
          TextButton(
            onPressed: () => open(const BillsPage()),
            child: const Text('Buka Tagihan & Jadwal'),
          ),
          TextButton(
            onPressed: () => open(const ObligationsPage()),
            child: const Text('Buka Utang & Piutang'),
          ),
        ],
      ),
    );
  }
}
