import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../app/theme/app_colors.dart';
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
      backgroundColor: AppColors.background,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.auto_graph_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Skenario kas, bukan transaksi',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Saldo aktual sebagai pembuka; komitmen dan asumsi berikutnya hanya proyeksi. Pembayaran yang sudah dicatat perlu ditautkan di Tagihan & Jadwal agar tidak dianggap belum dibayar.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: configure,
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    label: const Text('Ubah asumsi proyeksi'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Horizon ${config['days']} hari; zona ${DateFormatter.fixedZone(config['utc_offset_minutes'] as int)}. Termasuk hari pertama dan terakhir yang ditampilkan.',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Perkiraan: ${config['include_estimates'] == true ? 'termasuk' : 'dikecualikan'}; tunggakan: ${config['include_overdue'] == true ? 'dibawa ke awal' : 'dikecualikan'}; piutang: ${config['include_receivables'] == true ? 'diasumsikan masuk' : 'dikecualikan'}; alokasi goal: ${config['reserve_goals'] == true ? 'disisihkan' : 'tidak disisihkan'}.',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Tanggal tagihan dipetakan dari pukul 00:00 zona jadwal ke zona proyeksi. Tanggal cicilan tanpa tagihan dianggap berada di zona proyeksi. Alokasi goal dibekukan pada nilai pembuka, bukan rencana setoran mendatang.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.expense.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.expense.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                error,
                style: const TextStyle(color: AppColors.expense, fontSize: 12),
              ),
            ),
          ],
          if (state.dataError != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                state.dataError!,
                style: const TextStyle(color: AppColors.warning, fontSize: 12),
              ),
            ),
          ],
          if (result case final r?) ...[
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Periode ${r.start} sampai ${r.end}; dihitung ${DateFormatter.formatFull(r.assessedAt, timeZone: state.timeZone)}.',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: r.closing < BigInt.zero
                          ? AppColors.expense.withValues(alpha: 0.08)
                          : AppColors.income.withValues(alpha: 0.08),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(15),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Proyeksi penutup: ${money(r.closing)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: r.closing < BigInt.zero
                                ? AppColors.expense
                                : AppColors.income,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Minimum konservatif: ${money(r.minimum)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Saldo aktual gabungan: ${money(r.actual)}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Alokasi goal terdanai: ${money(r.reserved)}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Kas tersedia pembuka: ${money(r.available)}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: r.firstShortfall == null
                                ? AppColors.income.withValues(alpha: 0.06)
                                : AppColors.warningLight.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: r.firstShortfall == null
                                  ? AppColors.income.withValues(alpha: 0.2)
                                  : AppColors.warning.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                r.firstShortfall == null
                                    ? Icons.check_circle_outline_rounded
                                    : Icons.warning_amber_rounded,
                                size: 16,
                                color: r.firstShortfall == null
                                    ? AppColors.income
                                    : AppColors.warning,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  r.firstShortfall == null
                                      ? 'Tidak ada kekurangan gabungan pada komitmen yang dimodelkan.'
                                      : 'Potensi kekurangan gabungan pertama: ${r.firstShortfall!.date} • ${money(r.firstShortfall!.low)}',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: r.firstShortfall == null
                                        ? AppColors.income
                                        : AppColors.warning,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${r.paidExcluded} kejadian/pokok lunas dan ${r.skippedExcluded} kejadian dilewati tidak ditambahkan kembali.',
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 18,
                  color: AppColors.primary,
                ),
                SizedBox(width: 8),
                Text(
                  'Per akun — tanpa transfer otomatis',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final a in r.accounts)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Aktual: ${money(a.actual)}; tersedia: ${money(a.available)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Penutup: ${money(a.days.last.closing)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      a.firstShortfall == null
                          ? 'Tidak ada kekurangan pada skenario akun ini.'
                          : 'Potensi kekurangan ${a.firstShortfall!.date}: ${money(a.firstShortfall!.low)}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: a.firstShortfall == null
                            ? AppColors.textMuted
                            : AppColors.warning,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Card(
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppColors.border),
              ),
              child: ExpansionTile(
                title: const Text(
                  'Timeline harian gabungan',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                children: [
                  for (final d in r.days)
                    ListTile(
                      title: Text(
                        d.date,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'Pembuka ${money(d.opening)}\nMasuk ${money(d.inflow)} • keluar ${money(d.outflow)}\nMinimum ${money(d.low)} • penutup ${money(d.closing)}',
                        style: const TextStyle(fontSize: 11.5),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Card(
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppColors.border),
              ),
              child: ExpansionTile(
                title: Text(
                  'Komitmen & asumsi (${r.entries.length})',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                children: [
                  if (r.entries.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Belum ada komitmen dalam horizon ini; pengeluaran yang tidak dijadwalkan belum dimodelkan.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  for (final e in r.entries)
                    ListTile(
                      title: Text(
                        '${e.title} • ${e.income ? 'masuk' : 'keluar'} ${money(e.amount)}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${e.date} • jatuh tempo ${e.dueDate}\n${e.source}${e.assumption ? ' • ASUMSI' : ''}${e.overdue ? ' • TUNGGAKAN' : ''}\nAkun: ${r.accounts.firstWhere((a) => a.id == e.accountId).name}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),
            if (r.warnings.isNotEmpty) ...[
              const SizedBox(height: 18),
              const Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: AppColors.warning,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Batas dan kelengkapan data',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              for (final warning in r.warnings)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    warning,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ],
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => open(const BillsPage()),
            icon: const Icon(Icons.calendar_month_rounded, size: 18),
            label: const Text('Buka Tagihan & Jadwal'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => open(const ObligationsPage()),
            icon: const Icon(Icons.handshake_outlined, size: 18),
            label: const Text('Buka Utang & Piutang'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
