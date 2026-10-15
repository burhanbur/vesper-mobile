import 'package:flutter/material.dart';

import '../../../app/app_state.dart';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Status hanya milik Anda, bukan seluruh anggota grup.'),
        if (loading) const LinearProgressIndicator(),
        if (!fresh)
          Text(
            cached
                ? 'Menampilkan cache terakhir. Status mungkin berubah; bukan konfirmasi status terkini.'
                : 'Status belum tersedia. Daftar kosong bukan bukti tidak ada pembagian atau pemetaan.',
          ),
        if (state.isOfflineMode)
          const Text('Offline: perubahan membutuhkan koneksi.'),
        if (error != null) Text(error),
        TextButton(
          onPressed:
              loading ||
                  state.isOfflineMode ||
                  groupId != state.activeHouseholdId
              ? null
              : () => state.loadGroupList(groupId, mappings: mappings),
          child: const Text('Muat ulang status'),
        ),
      ],
    );
  }
}
