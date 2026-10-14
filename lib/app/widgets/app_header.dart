import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../features/notifications/widgets/notifications_sheet.dart';
import '../../features/offline/widgets/offline_mode_sheet.dart';
import '../app_state.dart';
import '../theme/app_colors.dart';

class AppHeader extends StatelessWidget {
  final VoidCallback? onHouseholdTap;

  const AppHeader({super.key, this.onHouseholdTap});

  String _getInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'U';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return trimmed.substring(0, math.min(2, trimmed.length)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final initials = _getInitials(state.userName);
    final greetingName = state.userName.isNotEmpty
        ? state.userName.split(' ').first
        : 'Pengguna';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: SizedBox(
        width: double.infinity,
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            // Left: Avatar + Greeting + Household Selector
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Avatar with Gradient & Subtle Ring
                GestureDetector(
                  onTap: onHouseholdTap,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.primaryLight, AppColors.primary],
                      ),
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.18),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        initials,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Greeting & Household Dropdown
                Flexible(
                  child: InkWell(
                    onTap: onHouseholdTap,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Halo, $greetingName',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  state.household.name,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 3),
                              const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 18,
                                color: AppColors.textSecondary,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Right: Online/Offline Badge + Notification Bell
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Offline / Online Indicator Badge
                Material(
                  color: Colors.transparent,
                  child: InkWell(
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
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: state.isOfflineMode
                            ? AppColors.warningLight
                            : AppColors.accentLight.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: state.isOfflineMode
                              ? AppColors.warning.withValues(alpha: 0.35)
                              : AppColors.accent.withValues(alpha: 0.25),
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
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      (state.isOfflineMode
                                              ? AppColors.warning
                                              : AppColors.accentDark)
                                          .withValues(alpha: 0.4),
                                  blurRadius: 4,
                                  spreadRadius: 0.5,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            state.isOfflineMode ? 'Offline' : 'Online',
                            style: TextStyle(
                              fontSize: 11,
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
                ),

                const SizedBox(width: 8),

                // Notification Bell (with unread badge)
                IconButton(
                  tooltip: 'Notifikasi',
                  onPressed: () => NotificationsSheet.show(context),
                  icon: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.border.withValues(alpha: 0.8),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(
                          Icons.notifications_none_rounded,
                          color: AppColors.textPrimary,
                          size: 20,
                        ),
                        if (state.unreadNotificationCount > 0)
                          Positioned(
                            right: 9,
                            top: 8,
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: AppColors.expense,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
