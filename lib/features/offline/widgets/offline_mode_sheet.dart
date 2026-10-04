import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../app/theme/app_colors.dart';

class OfflineModeSheet {
  static void show(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
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

    return Container(
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

          // Illustration circle matching contoh-2.png
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: AppColors.accentLight.withValues(alpha: 0.7),
              shape: BoxShape.circle,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  top: 24,
                  right: 20,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Container(
                  width: 54,
                  height: 74,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary, width: 2.5),
                  ),
                  child: Center(
                    child: Container(
                      width: 28,
                      height: 2,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                Transform.rotate(
                  angle: -0.7,
                  child: Container(
                    width: 64,
                    height: 3,
                    color: AppColors.expense,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Text matching contoh-2.png
          const Text(
            'Anda sedang offline',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Semua data mutasi akan disimpan aman di perangkat ini (SQLite lokal) dan akan disinkronkan otomatis saat kembali online.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),

          const SizedBox(height: 24),

          // Offline Status details
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
                  'Antrean Sinkronisasi Tertunda:',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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

          const SizedBox(height: 24),

          // Button matching contoh-2.png: "Lihat Data Offline"
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text('Lihat Data Offline'),
          ),

          const SizedBox(height: 10),

          // Toggle online button
          TextButton(
            onPressed: () {
              state.toggleOfflineMode();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: AppColors.primary,
                  content: Text('Kembali ke Mode Online. Menyinkronkan perubahan...'),
                ),
              );
            },
            child: const Text(
              'Beralih ke Online',
              style: TextStyle(color: AppColors.accentDark, fontWeight: FontWeight.w600),
            ),
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
