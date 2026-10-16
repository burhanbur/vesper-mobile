import 'package:flutter/material.dart';

/// References are computed by the repository. This sheet cannot mutate trades,
/// send support messages or authorize cancellation.
class InvestmentRecoverySheet extends StatelessWidget {
  final Map<String, String> reference;
  const InvestmentRecoverySheet({super.key, required this.reference});

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Referensi pemulihan investasi',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            'Jika perintah terus ditolak, ajukan pembatalan dari formulir investasi dan hubungi pengelola melalui kanal dukungan yang Anda kenal. Pengelola hanya dapat menyetujui pembatalan transaksi yang belum pernah diproses server. Tidak ada pesan dukungan yang dikirim otomatis.',
          ),
          const SizedBox(height: 12),
          const Text(
            'Data, saldo lokal, dan antrean tetap disimpan. Jangan membuat transaksi pengganti, menghapus data, atau menginstal ulang aplikasi. Coba ulang perintah asli setelah penyebabnya diperbaiki dan dukungan menyarankan retry.',
          ),
          const SizedBox(height: 16),
          SelectableText(
            reference.entries
                .map((entry) => '${entry.key}: ${entry.value}')
                .join('\n'),
          ),
          const SizedBox(height: 12),
          const Text(
            'Referensi ini berisi identitas akun/perintah dan sidik jari isi perintah, tanpa nominal, catatan, kata sandi, atau token. Bagikan hanya kepada dukungan tepercaya.',
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    ),
  );
}
