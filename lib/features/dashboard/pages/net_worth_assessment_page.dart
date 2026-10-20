import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../app/theme/app_colors.dart';
import '../models/net_worth_assessment.dart';

/// Owner-scoped read assessment, never a replacement for unsynced local balances.
class NetWorthAssessmentPage extends StatefulWidget {
  const NetWorthAssessmentPage({super.key});

  @override
  State<NetWorthAssessmentPage> createState() => _NetWorthAssessmentPageState();
}

class _NetWorthAssessmentPageState extends State<NetWorthAssessmentPage> {
  NetWorthAssessment? _data;
  String? _error;
  bool _loading = false;
  DateTime? _date;
  Object? _session;
  int _request = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = AppStateScope.of(context).netWorthSessionKey;
    if (_session != session) {
      _session = session;
      ++_request;
      _data = null;
      _error = null;
      _loading = false;
      _date = null;
    }
  }

  Future<void> _load() async {
    final state = AppStateScope.of(context);
    final session = state.netWorthSessionKey;
    final request = ++_request;
    bool active() =>
        mounted && request == _request && session == state.netWorthSessionKey;
    setState(() {
      _loading = true;
      _data = null;
      _error = null;
    });
    try {
      final data = await state.fetchNetWorthAssessment(_date);
      if (active()) setState(() => _data = data);
    } catch (_) {
      if (active()) {
        setState(
          () => _error =
              'Penilaian belum tersedia. Periksa koneksi lalu coba lagi.',
        );
      }
    } finally {
      if (active()) setState(() => _loading = false);
    }
  }

  static String _formatMissingComponent(String raw) {
    switch (raw) {
      case 'attribution_unavailable':
        return 'Atribusi kontribusi & pasar';
      case 'obligations_unavailable':
        return 'Data pinjaman';
      case 'holdings_unavailable':
        return 'Valuasi investasi';
      default:
        return raw.replaceAll('_', ' ');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final data = _data;
    String money(String key) => state.isBalanceHidden
        ? '••••••'
        : data?.amounts[key] == null
        ? 'Belum tersedia'
        : 'IDR ${data!.amounts[key]}';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Penilaian kekayaan pribadi',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          // Top Info Banner
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
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Data server milik Anda saja, bukan total household. Perubahan lokal yang belum tersinkron belum tercakup.',
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
          const SizedBox(height: 12),

          // Date Selector Button
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              backgroundColor: Colors.white,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _loading
                ? null
                : () async {
                    final session = state.netWorthSessionKey;
                    final now = DateTime.now().toUtc();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate:
                          _date ?? DateTime(now.year, now.month, now.day),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(now.year, now.month, now.day),
                    );
                    if (picked != null &&
                        mounted &&
                        session == state.netWorthSessionKey) {
                      setState(() {
                        _date = DateTime.utc(
                          picked.year,
                          picked.month,
                          picked.day,
                        );
                        _data = null;
                        _error = null;
                      });
                    }
                  },
            icon: const Icon(Icons.calendar_today_rounded, size: 16),
            label: Text(
              _date == null
                  ? 'Tanggal: hari ini (UTC)'
                  : 'Tanggal UTC: ${_date!.toIso8601String().substring(0, 10)}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          if (_date != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: TextButton.icon(
                onPressed: _loading
                    ? null
                    : () => setState(() {
                        _date = null;
                        _data = null;
                        _error = null;
                      }),
                icon: const Icon(Icons.replay_rounded, size: 14),
                label: const Text('Kembali ke hari ini (UTC)'),
              ),
            ),
          const SizedBox(height: 8),

          // Load Button
          FilledButton.icon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text(
              'Muat penilaian',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),

          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),

          if (_error != null)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.expenseLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.expense, fontSize: 12),
              ),
            ),

          if (data != null) ...[
            if (data.unavailable)
              Container(
                margin: const EdgeInsets.only(top: 14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.history_toggle_off_rounded,
                          size: 20,
                          color: AppColors.warning,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Riwayat Belum Tersedia',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Waktu respons: ${data.observedAt} (bukan bukti historis)',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Histori belum tersedia: bukti saldo historis belum memadai. Tidak ada titik grafik yang direkayasa.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              // Hero Net Worth / Subtotal Card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.border),
                ),
                color: Colors.white,
                margin: const EdgeInsets.only(top: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
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
                                size: 16,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                data.complete
                                    ? 'Net Worth Tercatat'
                                    : 'Subtotal Teridentifikasi',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
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
                              color: data.complete
                                  ? AppColors.incomeLight
                                  : AppColors.warningLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              data.complete ? 'Lengkap' : 'Parsial',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: data.complete
                                    ? AppColors.income
                                    : AppColors.warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        data.complete
                            ? 'Net worth tercatat: ${money('net_worth')}'
                            : 'Subtotal diketahui: ${money('known_net_worth')}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      if (data.complete) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Subtotal diketahui: ${money('known_net_worth')}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      if (data.amounts['obligation_liabilities'] != null ||
                          data.amounts['receivables_value'] != null) ...[
                        const Divider(height: 20),
                        Row(
                          children: [
                            if (data.amounts['obligation_liabilities'] != null)
                              Expanded(
                                child: Text(
                                  'Sisa utang: ${money('obligation_liabilities')}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.expense,
                                  ),
                                ),
                              ),
                            if (data.amounts['receivables_value'] != null)
                              Expanded(
                                child: Text(
                                  'Sisa piutang: ${money('receivables_value')}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.income,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Rincian Komponen Aset & Kewajiban Card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.border),
                ),
                color: Colors.white,
                margin: const EdgeInsets.only(top: 10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.pie_chart_outline_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Rincian Posisi',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      Text(
                        'Aset diketahui: ${money('known_assets')}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Kewajiban saldo negatif: ${money('known_balance_liabilities')}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Kas: ${money('cash_balance')}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Kas akun investasi: ${money('investment_cash_balance')}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Nilai holdings: ${money('holdings_value')}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        data.complete
                            ? 'Harga manual bertanggal tetap digunakan; periksa penanda harga usang.'
                            : 'Subtotal bukan net worth lengkap. Harga lama tetap masuk subtotal; posisi tanpa harga tidak dinilai nol.',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColors.textMuted,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Informasi Audit & Observasi Card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: AppColors.border),
                ),
                color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                margin: const EdgeInsets.only(top: 10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tanggal penilaian: ${data.snapshotDate}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        data.unavailable
                            ? 'Waktu respons: ${data.observedAt} (bukan bukti historis)'
                            : 'Waktu observasi (UTC): ${data.observedAt}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                      if (!data.unavailable) ...[
                        const SizedBox(height: 2),
                        Text(
                          data.isHistoricalObservation
                              ? 'Observasi historis pertama yang tersimpan; bukan saldo akhir hari.'
                              : 'Observasi saldo tercatat saat ini; bukan saldo akhir hari.',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                      const SizedBox(height: 2),
                      Text(
                        'Komponen belum tersedia: ${data.missingComponents.isEmpty ? 'Tidak ada' : data.missingComponents.map(_formatMissingComponent).join(', ')}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Akun dikecualikan: ${data.excludedAccountCount}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data.complete
                            ? 'Mencakup aset dan kewajiban yang tercatat. Data yang belum dicatat dan atribusi kontribusi versus perubahan pasar tidak tercakup.'
                            : 'Observasi ini masih parsial. Periksa komponen belum tersedia; observasi lama tidak ditulis ulang setelah penambahan utang/piutang.',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColors.textMuted,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Holdings List
              if (data.holdings.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Daftar Kepemilikan (Holdings)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                for (final row in data.holdings)
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    color: Colors.white,
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      title: Text(
                        row.instrumentId,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'Harga: ${row.priceDate ?? 'belum tersedia'} · ${row.stale == true ? 'USANG' : row.unavailableReason ?? 'tersedia'} · ${row.priceSource ?? 'sumber belum tersedia'}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: Text(
                        state.isBalanceHidden
                            ? '••••'
                            : row.marketValue ?? 'Tidak dinilai',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
              ],
            ],
          ],
        ],
      ),
    );
  }
}
