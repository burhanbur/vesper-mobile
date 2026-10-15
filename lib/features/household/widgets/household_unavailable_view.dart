import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_state.dart';
import '../../../app/theme/app_colors.dart';
import '../models/household.dart';
import 'create_group_sheet.dart';
import 'create_group_category_sheet.dart';
import 'group_category_mapping_sheet.dart';
import 'group_account_sharing_sheet.dart';
import 'group_switcher_sheet.dart';
import 'collaboration_panel.dart';

/// Category snapshots and online privacy-scoped collaboration reads.
class HouseholdUnavailableView extends StatefulWidget {
  const HouseholdUnavailableView({super.key});

  @override
  State<HouseholdUnavailableView> createState() =>
      _HouseholdUnavailableViewState();
}

class _HouseholdUnavailableViewState extends State<HouseholdUnavailableView> {
  AppState? _state;
  String? _groupKey;

  void _changeMonth(AppState state, int delta) {
    final parts = state.householdReportPeriod.split('-');
    final date = DateTime.utc(int.parse(parts[0]), int.parse(parts[1]) + delta);
    if (date.year < 1000 || date.year > 9999) return;
    state.loadHouseholdCategoryReport(
      period:
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}',
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppStateScope.of(context);
    final key = '${state.repository?.userId}:${state.activeHouseholdId}';
    if (!identical(state, _state) || key != _groupKey) {
      _state = state;
      _groupKey = key;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && identical(_state, state) && key == _groupKey) {
          state.loadHouseholdCategoryReport();
        }
      });
    }
  }

  Widget _buildFeatureTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final group = state.activeHousehold;
    final hasGroup = state.households.isNotEmpty;
    final membersLoaded =
        state.repository?.entities.containsKey('members:${group.id}') == true;
    final categoriesLoaded =
        state.repository?.entities.containsKey(
          'group_categories:${group.id}',
        ) ==
        true;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: hasGroup
            ? InkWell(
                onTap: () => GroupSwitcherSheet.show(context),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        group.type.emoji,
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          group.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (state.households.length > 1) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                      ],
                    ],
                  ),
                ),
              )
            : const Text(
                'Grup Finansial',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
        actions: [
          if (hasGroup && state.households.length > 1)
            IconButton(
              tooltip: 'Ganti Grup',
              onPressed: () => GroupSwitcherSheet.show(context),
              icon: const Icon(Icons.swap_horiz_rounded),
            ),
          IconButton(
            tooltip: 'Buat / Gabung Grup',
            onPressed: () => CreateOrJoinGroupSheet.show(context),
            icon: const Icon(Icons.group_add_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          if (!hasGroup) ...[
            // Hero Onboarding Card
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryDark, AppColors.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.22),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.diversity_3_rounded,
                          size: 14,
                          color: AppColors.accent,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Kolaborasi Finansial',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Kelola Keuangan Bersama Lebih Terbuka & Rapi',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Belum ada grup tersimpan di perangkat. Muat ulang saat terhubung untuk memeriksa keanggotaan.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => CreateOrJoinGroupSheet.show(
                        context,
                        initialTabIndex: 0,
                      ),
                      icon: const Icon(
                        Icons.add_circle_outline_rounded,
                        size: 18,
                      ),
                      label: const Text(
                        'Buat Grup Baru',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primaryDark,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => CreateOrJoinGroupSheet.show(
                        context,
                        initialTabIndex: 1,
                      ),
                      icon: const Icon(Icons.vpn_key_outlined, size: 18),
                      label: const Text(
                        'Gabung via Kode Undangan',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Server check card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.accentLight.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.sync_rounded,
                      color: state.loading
                          ? AppColors.accentDark
                          : AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sudah tergabung di grup?',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Tarik status keanggotaan terbaru dari server.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: state.loading || state.isOfflineMode
                        ? null
                        : state.refresh,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      backgroundColor: AppColors.surfaceVariant,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: state.loading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Muat ulang data grup',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // Features list
            const Text(
              'Keuntungan Ruang Finansial Grup',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            _buildFeatureTile(
              icon: Icons.pie_chart_rounded,
              iconColor: AppColors.primary,
              iconBgColor: AppColors.primaryLight.withValues(alpha: 0.12),
              title: 'Catat Pengeluaran Bersama',
              description: 'Bagi beban biaya rumah tangga, kosan, atau liburan secara transparan.',
            ),
            const SizedBox(height: 10),
            _buildFeatureTile(
              icon: Icons.account_balance_wallet_rounded,
              iconColor: AppColors.accentDark,
              iconBgColor: AppColors.accentLight.withValues(alpha: 0.35),
              title: 'Kas & Rekening Terintegrasi',
              description: 'Tautkan rekening kas yang ingin dibagikan tanpa khawatir saldo pribadi tercampur.',
            ),
            const SizedBox(height: 10),
            _buildFeatureTile(
              icon: Icons.shield_outlined,
              iconColor: AppColors.gold,
              iconBgColor: AppColors.gold.withValues(alpha: 0.15),
              title: 'Privasi Terjamin 100%',
              description: 'Hanya transaksi kategori yang dibagikan yang terlihat oleh anggota grup.',
            ),
          ] else ...[
            // Group Header & Invite Code Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.accentLight.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          group.type.emoji,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              group.name,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              group.type.displayName,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (state.households.length > 1)
                        IconButton(
                          tooltip: 'Ganti Grup',
                          icon: const Icon(
                            Icons.swap_horiz_rounded,
                            color: AppColors.primary,
                          ),
                          onPressed: () => GroupSwitcherSheet.show(context),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Invite Code & Group ID block
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.vpn_key_rounded,
                                  size: 15,
                                  color: AppColors.primary,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Kode Undangan Grup',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            TextButton.icon(
                              onPressed: group.inviteCode.isEmpty
                                  ? null
                                  : () async {
                                      try {
                                        await Clipboard.setData(
                                          ClipboardData(text: group.inviteCode),
                                        );
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Kode undangan disalin.',
                                                ),
                                              ),
                                            );
                                      } catch (_) {
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Kode tidak dapat disalin. Silakan salin secara manual.',
                                                ),
                                              ),
                                            );
                                      }
                                    },
                              icon: const Icon(Icons.copy, size: 13),
                              label: const Text(
                                'Salin kode',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                foregroundColor: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        SelectableText(
                          group.inviteCode.isEmpty
                              ? 'Kode belum tersedia di perangkat.'
                              : group.inviteCode,
                          key: const ValueKey('household_invite_code'),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                            color: AppColors.primaryDark,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'ID Grup',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        SelectableText(
                          group.id,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Bagikan ID grup dan kode undangan. Menambahkan anggota langsung belum didukung.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Members Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.people_alt_outlined,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          membersLoaded
                              ? '${group.members.length} anggota tersimpan'
                              : 'Daftar anggota belum tersedia di perangkat.',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (group.members.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    for (final member in group.members)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: AppColors.accentLight,
                            child: Text(
                              member.avatarInitials,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          title: Text(
                            member.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            member.roleName,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: member.role == MemberRole.admin
                                  ? AppColors.primaryLight.withValues(
                                      alpha: 0.12,
                                    )
                                  : AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              member.roleName,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: member.role == MemberRole.admin
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Financial Notice Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.sageMuted.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Status Integrasi Kas Grup',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(
                      'Saldo Kas Bersama',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: Text(
                      'Muat panel kolaborasi online di bawah. Data yang belum dimuat bukan saldo nol.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const Divider(height: 10),
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(
                      'Kontribusi & Riwayat Transaksi Grup',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: Text(
                      'Panel kolaborasi menampilkan transaksi berkategori terpetakan pada akun dibagikan; transaksi pribadi tidak otomatis dibagikan.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const Divider(height: 10),
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(
                      'Pencatatan & Pengelolaan Grup',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: Text(
                      'Keluar, hapus anggota dan alihkan pemilik tersedia online di panel kolaborasi. Perubahan informasi grup belum tersedia.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            const CollaborationPanel(),
            // Shared Accounts Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.accentLight.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.share_outlined,
                          color: AppColors.primary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pembagian Akun',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Pilih akun kas atau bank yang dibagikan.',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: state.isOfflineMode
                          ? null
                          : () => showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              builder: (_) => AppStateScope(
                                state: state,
                                child: GroupAccountSharingSheet(
                                  groupId: group.id,
                                ),
                              ),
                            ),
                      icon: const Icon(Icons.share_outlined, size: 14),
                      label: const Text(
                        'Kelola pembagian akun (online)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        backgroundColor: AppColors.surfaceVariant,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Category Report Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Laporan Kategori Grup — Bulan UTC',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Agregat server untuk akun yang dibagikan dalam grup ini; bukan transaksi pribadi perangkat.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Bulan UTC sebelumnya',
                          onPressed: () => _changeMonth(state, -1),
                          icon: const Icon(
                            Icons.chevron_left,
                            color: AppColors.primary,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        Expanded(
                          child: Text(
                            '${state.householdReportPeriod} (UTC)',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Bulan UTC berikutnya',
                          onPressed: () => _changeMonth(state, 1),
                          icon: const Icon(
                            Icons.chevron_right,
                            color: AppColors.primary,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                  if (state.householdReportLoading) ...[
                    const SizedBox(height: 8),
                    const LinearProgressIndicator(),
                  ],
                  const SizedBox(height: 12),
                  if (state.householdCategoryReport case final report?) ...[
                    Text(
                      'Cache lokal • Diambil: ${report.fetchedAt.toUtc().toIso8601String()} (UTC)',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (report.categories.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Laporan server tidak memiliki kategori untuk periode ini.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    for (final category in report.categories)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: category.type == 'INCOME'
                                  ? AppColors.incomeLight
                                  : AppColors.expenseLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              category.type == 'INCOME'
                                  ? Icons.arrow_downward_rounded
                                  : Icons.arrow_upward_rounded,
                              color: category.type == 'INCOME'
                                  ? AppColors.income
                                  : AppColors.expense,
                              size: 16,
                            ),
                          ),
                          title: Text(
                            category.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            category.type == 'INCOME'
                                ? 'Pemasukan'
                                : 'Pengeluaran',
                            style: TextStyle(
                              fontSize: 11,
                              color: category.type == 'INCOME'
                                  ? AppColors.income
                                  : AppColors.expense,
                            ),
                          ),
                          trailing: Text(
                            state.isBalanceHidden
                                ? 'Rp •••••'
                                : 'Rp ${category.type == 'INCOME' ? category.income : category.expense}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: category.type == 'INCOME'
                                  ? AppColors.income
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                  ] else ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        'Agregat belum tersedia untuk bulan ini; bukan nominal nol.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                  if (state.householdReportError != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Laporan gagal dimuat: ${state.householdReportError}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.expense,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed:
                          state.householdReportLoading || state.isOfflineMode
                          ? null
                          : () => state.loadHouseholdCategoryReport(),
                      icon: const Icon(Icons.refresh_rounded, size: 14),
                      label: const Text('Muat ulang laporan kategori'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Group Categories Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Kategori Grup',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (state.canManageGroupCategories)
                        TextButton.icon(
                          onPressed: state.isOfflineMode
                              ? null
                              : () => showModalBottomSheet<void>(
                                  context: context,
                                  isScrollControlled: true,
                                  builder: (_) => AppStateScope(
                                    state: state,
                                    child: const CreateGroupCategorySheet(),
                                  ),
                                ),
                          icon: const Icon(Icons.add, size: 14),
                          label: const Text(
                            'Tambah kategori grup (online)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (!categoriesLoaded)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        'Daftar kategori belum tersedia di perangkat.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  else if (state.groupCategories.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        'Tidak ada kategori pada data grup tersimpan.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  else ...[
                    for (final category in state.groupCategories)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: category.type == 'INCOME'
                                  ? AppColors.incomeLight
                                  : AppColors.expenseLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              category.type == 'INCOME'
                                  ? Icons.category_outlined
                                  : Icons.sell_outlined,
                              color: category.type == 'INCOME'
                                  ? AppColors.income
                                  : AppColors.expense,
                              size: 16,
                            ),
                          ),
                          title: Text(
                            category.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: const Text(
                            'Ketuk untuk pemetaan kategori pribadi (online). Nominal ada pada laporan bulan UTC di atas.',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          onTap: state.isOfflineMode
                              ? null
                              : () => showModalBottomSheet<void>(
                                  context: context,
                                  isScrollControlled: true,
                                  builder: (_) => AppStateScope(
                                    state: state,
                                    child: GroupCategoryMappingSheet(
                                      groupId: group.id,
                                      categoryId: category.id,
                                      categoryName: category.name,
                                      categoryType: category.type,
                                    ),
                                  ),
                                ),
                          trailing: state.canManageGroupCategories
                              ? IconButton(
                                  tooltip:
                                      'Edit kategori grup ${category.name}',
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 16,
                                  ),
                                  onPressed: state.isOfflineMode
                                      ? null
                                      : () => showModalBottomSheet<void>(
                                          context: context,
                                          isScrollControlled: true,
                                          builder: (_) => AppStateScope(
                                            state: state,
                                            child: CreateGroupCategorySheet(
                                              categoryId: category.id,
                                              groupId: group.id,
                                              initialName: category.name,
                                              initialType: category.type,
                                            ),
                                          ),
                                        ),
                                )
                              : null,
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],

          // Offline & Error Status Footers
          if (state.isOfflineMode) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.wifi_off_rounded,
                    color: AppColors.warning,
                    size: 18,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Mode offline: menampilkan data grup tersimpan.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (state.dataError != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.expenseLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.expense.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.expense,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      state.dataError!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.expense,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (hasGroup) ...[
            const SizedBox(height: 16),
            Center(
              child: TextButton.icon(
                onPressed: state.loading || state.isOfflineMode
                    ? null
                    : state.refresh,
                icon: state.loading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Muat ulang data grup'),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              ),
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
