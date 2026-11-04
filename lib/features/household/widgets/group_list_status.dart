import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../app/theme/app_colors.dart';

/// Actor-only status, with explicit distinction between verified and cached data.
class GroupListStatus extends StatelessWidget {
  final AppState state;
  final String groupId;
  final bool mappings;
  const GroupListStatus({
    super.key,
    required this.state,
    required this.groupId,
    this.mappings = false,
  });

  @override
  Widget build(BuildContext context) {
    final loading = state.groupListLoading(groupId, mappings: mappings);
    final error = state.groupListError(groupId, mappings: mappings);
    final cached = state.groupListCached(groupId, mappings: mappings);
    final fresh = state.groupListFresh(groupId, mappings: mappings);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: state.isOfflineMode
            ? AppColors.warningLight.withValues(alpha: 0.5)
            : error != null
            ? AppColors.expenseLight.withValues(alpha: 0.5)
            : AppColors.surfaceVariant.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: state.isOfflineMode
              ? AppColors.warning.withValues(alpha: 0.3)
              : error != null
              ? AppColors.expense.withValues(alpha: 0.3)
              : AppColors.border.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                state.isOfflineMode
                    ? Icons.wifi_off_rounded
                    : error != null
                    ? Icons.error_outline_rounded
                    : Icons.shield_outlined,
                size: 15,
                color: state.isOfflineMode
                    ? AppColors.warning
                    : error != null
                    ? AppColors.expense
                    : AppColors.primary,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Status hanya milik Anda, bukan seluruh anggota grup.',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              TextButton(
                onPressed:
                    loading ||
                        state.isOfflineMode ||
                        groupId != state.activeHouseholdId
                    ? null
                    : () => state.loadGroupList(groupId, mappings: mappings),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  foregroundColor: AppColors.primary,
                ),
                child: const Text('Muat ulang status'),
              ),
            ],
          ),
          if (loading) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: const LinearProgressIndicator(minHeight: 2.5),
            ),
          ],
          if (!fresh) ...[
            const SizedBox(height: 4),
            Text(
              cached
                  ? 'Menampilkan cache terakhir. Status mungkin berubah; bukan konfirmasi status terkini.'
                  : 'Status belum tersedia. Daftar kosong bukan bukti tidak ada pembagian atau pemetaan.',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                height: 1.3,
              ),
            ),
          ],
          if (state.isOfflineMode) ...[
            const SizedBox(height: 4),
            const Text(
              'Offline: perubahan membutuhkan koneksi.',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.warning,
              ),
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 4),
            Text(
              error,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.expense,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
