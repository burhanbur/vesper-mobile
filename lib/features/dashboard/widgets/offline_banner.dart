import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../app/theme/app_colors.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    final failed = state.dataError != null;
    if (!state.isOfflineMode &&
        state.pendingSyncCount == 0 &&
        !state.loading &&
        !failed) {
      return const SizedBox.shrink();
    }
    final title = state.isOfflineMode
        ? 'Mode Offline Aktif'
        : state.loading
        ? 'Memuat data dari server'
        : failed
        ? 'Data server belum berhasil dimuat'
        : 'Ada ${state.pendingSyncCount} Data Menunggu Sync';
    final message = state.isOfflineMode
        ? 'Anda sedang offline. Data transaksi disimpan aman di database lokal dan akan disinkronkan otomatis saat kembali online.'
        : state.loading
        ? 'Menampilkan data lokal sambil mengambil akun dan riwayat transaksi. Riwayat besar memerlukan waktu lebih lama.'
        : failed
        ? 'Pemuatan belum selesai. Data lokal tetap tersedia; Anda bisa mencoba memuat ulang.'
        : 'Tekan tombol untuk mengirim perubahan lokal dan memperbarui data server.';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: state.isOfflineMode
              ? AppColors.warningLight
              : AppColors.infoLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: state.isOfflineMode
                ? AppColors.warning.withValues(alpha: 0.4)
                : AppColors.info.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (state.loading && !state.isOfflineMode)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  semanticsLabel: 'Memuat data server',
                ),
              )
            else
              Icon(
                state.isOfflineMode
                    ? Icons.cloud_off_rounded
                    : Icons.sync_problem_rounded,
                color: state.isOfflineMode ? AppColors.warning : AppColors.info,
                size: 22,
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: state.isOfflineMode
                          ? const Color(0xFF78350F)
                          : const Color(0xFF0369A1),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 11,
                      color: state.isOfflineMode
                          ? const Color(0xFF92400E)
                          : const Color(0xFF075985),
                      height: 1.3,
                    ),
                  ),
                  if (!state.isOfflineMode &&
                      (failed || state.pendingSyncCount > 0)) ...[
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: state.loading
                          ? null
                          : () async {
                              final userId = state.currentUserId;
                              await state.syncPendingNow();
                              if (!context.mounted ||
                                  state.currentUserId != userId) {
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: AppColors.primary,
                                  content: Text(
                                    state.dataError == null
                                        ? 'Data berhasil diperbarui.'
                                        : 'Data belum berhasil dimuat. Coba lagi nanti.',
                                  ),
                                ),
                              );
                            },
                      child: Text(
                        failed
                            ? 'Coba muat ulang'
                            : 'Sinkronkan ${state.pendingSyncCount} Data Sekarang',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
