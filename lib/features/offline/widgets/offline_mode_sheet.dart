import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../app/theme/app_colors.dart';

class OfflineModeSheet {
  static void show(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _OfflineModeContent(),
    );
  }
}

class _OfflineModeContent extends StatelessWidget {
  const _OfflineModeContent();

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final isOffline = state.isOfflineMode;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: isOffline
                    ? AppColors.warningLight
                    : AppColors.accentLight.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isOffline
                    ? Icons.cloud_off_rounded
                    : Icons.cloud_done_rounded,
                size: 40,
                color: isOffline ? AppColors.warning : AppColors.primary,
              ),
            ),

            const SizedBox(height: 18),

            Text(
              isOffline ? 'Anda sedang offline' : 'Mode Online Aktif',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isOffline
                  ? 'Semua perubahan tersimpan aman di perangkat ini dan akan disinkronkan otomatis saat kembali online.'
                  : 'Perubahan yang Anda catat otomatis disinkronkan dengan server saat koneksi tersedia.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),

            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Antrean Sinkronisasi Tertunda',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: state.pendingSyncCount > 0
                          ? AppColors.warningLight
                          : AppColors.incomeLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${state.pendingSyncCount} Item',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: state.pendingSyncCount > 0
                            ? AppColors.warning
                            : AppColors.income,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            if (isOffline) ...[
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Lihat Data Offline'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  state.toggleOfflineMode();
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppColors.primary,
                      content: Text(
                        'Kembali ke Mode Online. Menyinkronkan perubahan...',
                      ),
                    ),
                  );
                },
                child: const Text(
                  'Beralih ke Online',
                  style: TextStyle(
                    color: AppColors.accentDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ] else ...[
              ElevatedButton(
                onPressed: state.loading
                    ? null
                    : () async {
                        await state.syncPendingNow();
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: state.dataError == null
                                  ? AppColors.primary
                                  : AppColors.warning,
                              content: Text(state.syncFeedbackMessage),
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  state.loading ? 'Menyinkronkan…' : 'Sinkronkan Sekarang',
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  state.toggleOfflineMode();
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      duration: Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppColors.warning,
                      content: Text(
                        'Mode Offline aktif: perubahan tersimpan di perangkat ini.',
                      ),
                    ),
                  );
                },
                child: const Text(
                  'Beralih ke Mode Offline',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}
