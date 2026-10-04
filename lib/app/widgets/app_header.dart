import 'package:flutter/material.dart';

import '../../features/notifications/widgets/notifications_sheet.dart';
import '../../features/offline/widgets/offline_mode_sheet.dart';
import '../app_state.dart';
import '../theme/app_colors.dart';

class AppHeader extends StatelessWidget {
  final VoidCallback? onHouseholdTap;

  const AppHeader({super.key, this.onHouseholdTap});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Avatar + Greeting + Household Selector (contoh-1.png)
          Row(
            children: [
              // Avatar Circle
              GestureDetector(
                onTap: onHouseholdTap,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      'BM',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Greeting & Household Dropdown
              InkWell(
                onTap: onHouseholdTap,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Halo, Burhan',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            state.household.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Right: Online/Offline Badge + Notification Bell
          Row(
            children: [
              // Offline / Online Indicator Badge
              GestureDetector(
                onTap: () {
                  if (state.isOfflineMode) {
                    OfflineModeSheet.show(context);
                  } else {
                    state.toggleOfflineMode();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        duration: Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: AppColors.warning,
                        content: Text(
                          'Mode Offline aktif: transaksi disimpan ke SQLite lokal.',
                        ),
                      ),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: state.isOfflineMode
                        ? AppColors.warningLight
                        : AppColors.accentLight,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: state.isOfflineMode
                          ? AppColors.warning.withValues(alpha: 0.3)
                          : AppColors.accent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: state.isOfflineMode
                              ? AppColors.warning
                              : AppColors.accentDark,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        state.isOfflineMode ? 'Offline' : 'Online',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: state.isOfflineMode
                              ? AppColors.warning
                              : AppColors.accentDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Notification Bell (with unread badge)
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.notifications_outlined,
                      color: AppColors.textPrimary,
                      size: 24,
                    ),
                    onPressed: () => NotificationsSheet.show(context),
                  ),
                  if (state.unreadNotificationCount > 0)
                    Positioned(
                      right: 10,
                      top: 10,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.expense,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
