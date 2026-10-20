import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
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
      appBar: AppBar(title: const Text('Penilaian kekayaan pribadi')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Data server milik Anda saja, bukan total household. Perubahan lokal yang belum tersinkron belum tercakup.',
          ),
          const SizedBox(height: 12),
          OutlinedButton(
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
            child: Text(
              _date == null
                  ? 'Tanggal: hari ini (UTC)'
                  : 'Tanggal UTC: ${_date!.toIso8601String().substring(0, 10)}',
            ),
          ),
          if (_date != null)
            TextButton(
              onPressed: _loading
                  ? null
                  : () => setState(() {
                      _date = null;
                      _data = null;
                      _error = null;
                    }),
              child: const Text('Kembali ke hari ini (UTC)'),
            ),
          FilledButton(
            onPressed: _loading ? null : _load,
            child: const Text('Muat penilaian'),
          ),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (_error != null) Text(_error!),
          if (data != null) ...[
            Text('Tanggal penilaian: ${data.snapshotDate}'),
            Text(
              data.unavailable
                  ? 'Waktu respons: ${data.observedAt} (bukan bukti historis)'
                  : 'Waktu observasi (UTC): ${data.observedAt}',
            ),
            if (!data.unavailable)
              Text(
                data.isHistoricalObservation
                    ? 'Observasi historis pertama yang tersimpan; bukan saldo akhir hari.'
                    : 'Observasi saldo tercatat saat ini; bukan saldo akhir hari.',
              ),
            Text(
              'Komponen belum tersedia: ${data.missingComponents.join(', ')}',
            ),
            Text('Akun dikecualikan: ${data.excludedAccountCount}'),
            const Text(
              'Utang dan piutang lengkap belum tersedia hingga WM06. Subtotal aset dikurangi kewajiban saldo negatif tetap parsial. Atribusi kontribusi versus perubahan pasar belum tersedia.',
            ),
            if (data.unavailable)
              const Text(
                'Histori belum tersedia: bukti saldo historis belum memadai. Tidak ada titik grafik yang direkayasa.',
              )
            else ...[
              Text('Subtotal diketahui: ${money('known_net_worth')}'),
              Text('Aset diketahui: ${money('known_assets')}'),
              Text(
                'Kewajiban saldo negatif: ${money('known_balance_liabilities')}',
              ),
              Text('Kas: ${money('cash_balance')}'),
              Text('Kas akun investasi: ${money('investment_cash_balance')}'),
              Text('Nilai holdings: ${money('holdings_value')}'),
              const Text(
                'Subtotal bukan net worth lengkap. Harga lama tetap masuk subtotal; posisi tanpa harga tidak dinilai nol.',
              ),
              for (final row in data.holdings)
                ListTile(
                  title: Text(row.instrumentId),
                  subtitle: Text(
                    'Harga: ${row.priceDate ?? 'belum tersedia'} · ${row.stale == true ? 'USANG' : row.unavailableReason ?? 'tersedia'} · ${row.priceSource ?? 'sumber belum tersedia'}',
                  ),
                  trailing: Text(
                    state.isBalanceHidden
                        ? '••••'
                        : row.marketValue ?? 'Tidak dinilai',
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }
}
