import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../app/theme/app_colors.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    if (!state.isOfflineMode && state.pendingSyncCount == 0) {
      return const SizedBox.shrink();
    }

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
                    state.isOfflineMode
                        ? 'Mode Offline Aktif'
                        : 'Ada ${state.pendingSyncCount} Data Menunggu Sync',
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
                    state.isOfflineMode
                        ? 'Anda sedang offline. Data transaksi disimpan aman di database lokal dan akan disinkronkan otomatis saat kembali online.'
                        : 'Koneksi kembali normal. Tekan tombol untuk mengirim perubahan lokal ke server.',
                    style: TextStyle(
                      fontSize: 11,
                      color: state.isOfflineMode
                          ? const Color(0xFF92400E)
                          : const Color(0xFF075985),
                      height: 1.3,
                    ),
                  ),
                  if (state.pendingSyncCount > 0) ...[
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () {
                        state.syncPendingNow();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: AppColors.primary,
                            content: Text(
                              'Berhasil menyinkronkan data ke server!',
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Sinkronkan ${state.pendingSyncCount} Data Sekarang',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
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
