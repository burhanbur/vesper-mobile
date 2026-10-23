import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/app_time_zone.dart';

class TimeZoneSheet {
  const TimeZoneSheet._();

  static Future<void> show(BuildContext context) {
    final state = AppStateScope.of(context);
    final session = state.netWorthSessionKey;
    String? error;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, update) => SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Zona waktu',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Mengatur tanggal transaksi, ringkasan dashboard, dan periode laporan.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final zone in AppTimeZone.values)
                    ListTile(
                      key: ValueKey('time_zone_${zone.name}'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        zone.label,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: zone == AppTimeZone.device
                          ? Text(
                              'Saat ini ${zone.abbreviation(DateTime.now())}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            )
                          : null,
                      trailing: Icon(
                        state.timeZone == zone
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: state.timeZone == zone
                            ? AppColors.primary
                            : AppColors.textMuted,
                      ),
                      selected: state.timeZone == zone,
                      onTap: () {
                        try {
                          if (session != state.netWorthSessionKey) {
                            throw const ApiFailure('Sesi telah berubah.');
                          }
                          state.setTimeZone(zone);
                          Navigator.of(sheetContext).pop();
                        } catch (e) {
                          update(() => error = e.toString());
                        }
                      },
                    ),
                  const Divider(color: AppColors.borderSubtle),
                  const Text(
                    'Periode budget tetap memakai kalender UTC. Tagihan mengikuti zona jadwal masing-masing. Pilihan ini tersimpan untuk akun ini di perangkat ini.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        error!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.expense,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
