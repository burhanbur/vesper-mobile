import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_state.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/date_formatter.dart';
import '../data/collaboration_repository.dart';
import '../models/household.dart';
import 'create_group_sheet.dart';
import 'create_group_category_sheet.dart';
import 'group_category_mapping_sheet.dart';
import 'group_account_sharing_sheet.dart';
import 'group_switcher_sheet.dart';
import 'group_pockets_panel.dart';

/// Bank Jago-inspired tabbed financial group interface.
/// Distinct modular sections for Pocket & Saldo, Aktivitas, Anggota, and Kategori.
class HouseholdUnavailableView extends StatefulWidget {
  const HouseholdUnavailableView({super.key});

  @override
  State<HouseholdUnavailableView> createState() =>
      _HouseholdUnavailableViewState();
}

class _HouseholdUnavailableViewState extends State<HouseholdUnavailableView>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  AppState? _state;
  String? _groupKey;

  // Collaboration online state
  String? _collabScope;
  int _collabToken = 0;
  int _contributionPage = 1;
  int _feedPage = 1;
  int _memberPage = 1;
  bool _collabOwner = false;
  bool _collabLoading = false;
  String? _collabError;
  Map<String, dynamic>? _collabData;
  List<Map<String, dynamic>> _collabMembers = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (!mounted) return;
    if (lifecycleState != AppLifecycleState.resumed) {
      setState(() {
        ++_collabToken;
        _collabData = null;
        _collabMembers = [];
        _collabOwner = false;
        _collabLoading = false;
        _collabError = null;
      });
    } else {
      final app = AppStateScope.of(context);
      if (app.repository != null &&
          !app.isOfflineMode &&
          app.activeHouseholdId.isNotEmpty) {
        _loadCollaboration();
      }
    }
  }

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
    final reportKey = '${state.repository?.userId}:${state.activeHouseholdId}';
    if (!identical(state, _state) || reportKey != _groupKey) {
      _state = state;
      _groupKey = reportKey;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && identical(_state, state) && reportKey == _groupKey) {
          state.loadHouseholdCategoryReport();
        }
      });
    }

    final collabScope =
        '${state.repository?.userId}:${state.activeHouseholdId}:${state.householdReportPeriod}:${state.isOfflineMode}';
    if (_collabScope != collabScope) {
      _collabScope = collabScope;
      _collabToken++;
      _collabData = null;
      _collabMembers = [];
      _collabError = null;
      _collabLoading = false;
      _collabOwner = false;
      _contributionPage = _feedPage = _memberPage = 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _collabScope == collabScope) {
          _loadCollaboration();
        }
      });
    }
  }

  Future<void> _loadCollaboration() async {
    final state = AppStateScope.of(context);
    final repo = state.repository;
    final group = state.activeHouseholdId;
    final period = state.householdReportPeriod;
    final contributionPage = _contributionPage;
    final feedPage = _feedPage;
    final memberPage = _memberPage;
    final token = ++_collabToken;
    setState(() {
      _collabLoading = true;
      _collabError = null;
      _collabData = null;
      _collabMembers = [];
      _collabOwner = false;
    });
    try {
      if (repo == null || state.isOfflineMode) {
        throw StateError('Koneksi online diperlukan.');
      }
      final service = CollaborationRepository(repo.client);
      final data = await service.read(group, period, contributionPage);
      if (!mounted || token != _collabToken) return;
      final feedData = feedPage == contributionPage
          ? data
          : await service.read(group, period, feedPage);
      if (!mounted || token != _collabToken) return;
      final members = await service.members(group, memberPage);
      if (!mounted || token != _collabToken) return;
      final role = await service.actorRole(group, repo.userId);
      if (!mounted || token != _collabToken) return;
      if (role == null) {
        throw const ApiFailure(
          'Keanggotaan tidak dapat diverifikasi. Muat ulang grup.',
          statusCode: 403,
        );
      }
      setState(() {
        _collabData = {...data, 'feed': feedData['feed']};
        _collabMembers = members;
        _collabOwner = role == 'OWNER';
      });
    } catch (error) {
      if (mounted && token == _collabToken) {
        setState(() {
          _collabError = '$error';
        });
      }
    } finally {
      if (mounted && token == _collabToken) {
        setState(() {
          _collabLoading = false;
        });
      }
    }
  }

  Future<void> _manageMember(String user, String action) async {
    final state = AppStateScope.of(context);
    final repo = state.repository;
    final group = state.activeHouseholdId;
    final scope = _collabScope;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          action == 'REMOVE' ? 'Hapus keanggotaan?' : 'Alihkan kepemilikan?',
        ),
        content: Text(
          action == 'REMOVE'
              ? 'Akses grup serta pembagian akun dan pemetaan kategori anggota akan dicabut. Data pribadi tidak dihapus. Bergabung kembali memerlukan undangan.'
              : 'Anda akan menjadi anggota biasa. Pemilik baru dapat mengelola anggota dan kategori grup.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Konfirmasi'),
          ),
        ],
      ),
    );
    if (!mounted ||
        confirmed != true ||
        _collabLoading ||
        repo == null ||
        scope != _collabScope ||
        state.isOfflineMode ||
        !identical(repo, state.repository)) {
      return;
    }
    setState(() {
      _collabLoading = true;
      _collabError = null;
    });
    try {
      await CollaborationRepository(repo.client).manage(group, user, action);
      if (!mounted ||
          scope != _collabScope ||
          !identical(repo, state.repository)) {
        return;
      }
      setState(() {
        _collabData = null;
        _collabMembers = [];
      });
      await state.refresh();
      if (!mounted ||
          scope != _collabScope ||
          !identical(repo, state.repository)) {
        return;
      }
      await _loadCollaboration();
    } catch (error) {
      if (mounted && scope == _collabScope) {
        setState(() {
          _collabError = '$error';
          _collabLoading = false;
          _collabData = null;
          _collabMembers = [];
          _collabOwner = false;
        });
      }
    }
  }

  Widget _pagination(
    String label,
    int page,
    int count,
    ValueChanged<int> select,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              '$label • Halaman $page',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: _collabLoading || page == 1
                    ? null
                    : () {
                        select(page - 1);
                        _loadCollaboration();
                      },
                icon: const Icon(Icons.chevron_left_rounded, size: 16),
                label: Text(
                  '$label sebelumnya',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  foregroundColor: AppColors.primary,
                ),
              ),
              TextButton(
                onPressed: _collabLoading || count < 20
                    ? null
                    : () {
                        select(page + 1);
                        _loadCollaboration();
                      },
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  foregroundColor: AppColors.primary,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$label berikutnya',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.chevron_right_rounded, size: 16),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
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

  Widget _buildHeroPocketCard(
    AppState state,
    Household group,
    bool membersLoaded,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.22),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.diversity_3_rounded,
                      size: 13,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'KANTONG BERSAMA • ${group.type.displayName.toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (state.households.length > 1)
                InkWell(
                  onTap: () => GroupSwitcherSheet.show(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.swap_horiz_rounded,
                          size: 13,
                          color: Colors.white,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Ganti',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
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
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      membersLoaded
                          ? '${group.members.length} anggota tersimpan'
                          : 'Daftar anggota belum tersedia di perangkat.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.82),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.vpn_key_rounded,
                  size: 13,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 6),
                const Text(
                  'Kode:',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: SelectableText(
                    group.inviteCode.isEmpty
                        ? 'Kode belum tersedia di perangkat.'
                        : group.inviteCode,
                    key: const ValueKey('household_invite_code'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: Colors.white,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                InkWell(
                  onTap: group.inviteCode.isEmpty
                      ? null
                      : () async {
                          try {
                            await Clipboard.setData(
                              ClipboardData(text: group.inviteCode),
                            );
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Kode undangan disalin.'),
                              ),
                            );
                          } catch (_) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Kode tidak dapat disalin.'),
                              ),
                            );
                          }
                        },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.copy_rounded, size: 11, color: Colors.white),
                        SizedBox(width: 3),
                        Text(
                          'Salin',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TabBar(
        controller: _tabController,
        padding: const EdgeInsets.all(4),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: EdgeInsets.zero,
        splashBorderRadius: BorderRadius.circular(10),
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textSecondary,
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: 'Saldo'),
          Tab(text: 'Aktivitas'),
          Tab(text: 'Anggota'),
          Tab(text: 'Kategori'),
        ],
      ),
    );
  }

  Widget _buildSharedAccountsCard(
    BuildContext context,
    AppState state,
    Household group,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accentLight.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.share_outlined,
              color: AppColors.primary,
              size: 16,
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
                SizedBox(height: 1),
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
          TextButton.icon(
            onPressed: state.isOfflineMode
                ? null
                : () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => AppStateScope(
                      state: state,
                      child: GroupAccountSharingSheet(groupId: group.id),
                    ),
                  ),
            icon: const Icon(Icons.tune_rounded, size: 14),
            label: const Text(
              'Kelola',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              backgroundColor: AppColors.surfaceVariant,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryReportCard(AppState state) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Laporan Kategori Grup — Bulan',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Bulan sebelumnya',
                  onPressed: () => _changeMonth(state, -1),
                  icon: const Icon(
                    Icons.chevron_left,
                    color: AppColors.primary,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                Expanded(
                  child: Text(
                    state.householdReportPeriod,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Bulan berikutnya',
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
          const SizedBox(height: 10),
          if (state.householdCategoryReport case final report?) ...[
            Text(
              'Cache lokal • Diambil: ${DateFormatter.formatFull(report.fetchedAt, timeZone: state.timeZone)}',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
            const SizedBox(height: 6),
            if (report.categories.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
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
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: category.type == 'INCOME'
                          ? AppColors.incomeLight
                          : AppColors.expenseLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      category.type == 'INCOME'
                          ? Icons.arrow_downward_rounded
                          : Icons.arrow_upward_rounded,
                      color: category.type == 'INCOME'
                          ? AppColors.income
                          : AppColors.expense,
                      size: 14,
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
                    category.type == 'INCOME' ? 'Pemasukan' : 'Pengeluaran',
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
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'Agregat belum tersedia untuk bulan ini; bukan nominal nol.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
          ],
          if (state.householdReportError != null) ...[
            const SizedBox(height: 6),
            Text(
              'Laporan gagal dimuat: ${state.householdReportError}',
              style: const TextStyle(fontSize: 12, color: AppColors.expense),
            ),
          ],
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: state.householdReportLoading || state.isOfflineMode
                  ? null
                  : () => state.loadHouseholdCategoryReport(),
              icon: const Icon(Icons.refresh_rounded, size: 13),
              label: const Text(
                'Muat ulang laporan kategori',
                style: TextStyle(fontSize: 11),
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineAndErrorFooters(AppState state) {
    return Column(
      children: [
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
    );
  }

  Widget _buildPocketTab(
    BuildContext context,
    AppState state,
    Household group,
  ) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        GroupPocketsPanel(
          key: ValueKey((
            state.netWorthSessionKey,
            group.id,
            state.isOfflineMode,
          )),
          app: state,
          groupId: group.id,
        ),
        const SizedBox(height: 10),

        // Shared Accounts Card
        _buildSharedAccountsCard(context, state, group),

        const SizedBox(height: 10),

        // Category Report Card
        _buildCategoryReportCard(state),

        // Offline & Error Status Footers
        _buildOfflineAndErrorFooters(state),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildActivityTab(AppState state) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        // Header card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
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
                      color: AppColors.transferLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.receipt_long_outlined,
                      size: 15,
                      color: AppColors.transfer,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Aktivitas bulanan (tanpa catatan/akun pribadi)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.incomeLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'ONLINE',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppColors.income,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _collabLoading || state.isOfflineMode
                      ? null
                      : _loadCollaboration,
                  icon: const Icon(Icons.refresh_rounded, size: 13),
                  label: const Text(
                    'Muat ulang aktivitas',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    foregroundColor: AppColors.primary,
                  ),
                ),
              ),
              if (_collabLoading)
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: const LinearProgressIndicator(
                    minHeight: 3,
                    color: AppColors.primary,
                    backgroundColor: AppColors.accentLight,
                  ),
                ),
              if (_collabError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _collabError!,
                    style: const TextStyle(
                      color: AppColors.expense,
                      fontSize: 11,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              if (_collabData != null) ...[
                if ((_collabData!['feed'] as List).isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.history_rounded,
                          size: 16,
                          color: AppColors.textMuted,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Belum ada aktivitas transaksi bulan ini.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  for (final row in _collabData!['feed'] as List)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: row['type'] == 'INCOME'
                                  ? AppColors.incomeLight
                                  : AppColors.expenseLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              row['type'] == 'INCOME'
                                  ? Icons.arrow_downward_rounded
                                  : Icons.arrow_upward_rounded,
                              size: 16,
                              color: row['type'] == 'INCOME'
                                  ? AppColors.income
                                  : AppColors.expense,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${row['category']}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  DateFormatter.timestamp(
                                    row['transacted_at'],
                                    timeZone: state.timeZone,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${row['type'] == 'INCOME' ? '+' : '-'} ${row['currency']} ${row['amount']}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: row['type'] == 'INCOME'
                                  ? AppColors.income
                                  : AppColors.expense,
                            ),
                          ),
                        ],
                      ),
                    ),
                _pagination(
                  'Aktivitas',
                  _feedPage,
                  (_collabData!['feed'] as List).length,
                  (page) => _feedPage = page,
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Kontribusi Bulanan card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
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
                      color: AppColors.primaryLight.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.pie_chart_outline_rounded,
                      size: 15,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Kontribusi bulanan (halaman ini)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_collabData != null) ...[
                if ((_collabData!['contributions'] as List).isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.hourglass_empty_rounded,
                          size: 16,
                          color: AppColors.textMuted,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Belum ada kontribusi pada periode ini.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  for (final row in _collabData!['contributions'] as List)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: AppColors.accentLight,
                                child: Text(
                                  ((row['user_id'] as String?) ?? '').isNotEmpty
                                      ? ((row['user_id'] as String?) ?? '')[0]
                                            .toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${row['user_id']}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              Text(
                                '${row['currency']}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.incomeLight,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.arrow_downward_rounded,
                                        size: 13,
                                        color: AppColors.income,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          'Masuk: ${row['income']}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.income,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.expenseLight,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.arrow_upward_rounded,
                                        size: 13,
                                        color: AppColors.expense,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          'Keluar: ${row['expense']}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.expense,
                                          ),
                                          overflow: TextOverflow.ellipsis,
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
                _pagination(
                  'Kontribusi',
                  _contributionPage,
                  (_collabData!['contributions'] as List).length,
                  (page) => _contributionPage = page,
                ),
              ] else if (!_collabLoading && _collabError == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'Kontribusi anggota online belum dimuat.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildMembersTab(AppState state, Household group) {
    final owner = _collabOwner;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        // Anggota list card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
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
                      color: AppColors.gold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.group_outlined,
                      size: 15,
                      color: AppColors.gold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Anggota (halaman ini)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  if (_collabLoading)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _collabLoading || state.isOfflineMode
                      ? null
                      : _loadCollaboration,
                  icon: const Icon(Icons.refresh_rounded, size: 13),
                  label: const Text(
                    'Muat ulang anggota',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    foregroundColor: AppColors.primary,
                  ),
                ),
              ),
              if (_collabLoading)
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: const LinearProgressIndicator(
                    minHeight: 3,
                    color: AppColors.primary,
                    backgroundColor: AppColors.accentLight,
                  ),
                ),
              if (_collabError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _collabError!,
                    style: const TextStyle(
                      color: AppColors.expense,
                      fontSize: 11,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              if (_collabMembers.isEmpty && !_collabLoading)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.people_outline_rounded,
                        size: 16,
                        color: AppColors.textMuted,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Daftar anggota kolaborasi online belum dimuat.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              else
                for (final member in _collabMembers)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 2,
                      ),
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: member['role'] == 'OWNER'
                            ? AppColors.gold.withValues(alpha: 0.2)
                            : AppColors.accentLight,
                        child: Text(
                          ((member['name'] as String?) ?? '').isNotEmpty
                              ? ((member['name'] as String?) ?? '')[0]
                                    .toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: member['role'] == 'OWNER'
                                ? AppColors.gold
                                : AppColors.primary,
                          ),
                        ),
                      ),
                      title: Text(
                        '${member['name'] ?? ''} • ${member['role'] ?? ''}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        member['role'] == 'OWNER'
                            ? 'Pemilik Grup'
                            : 'Anggota Kolaborasi',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      trailing: member['role'] == 'OWNER'
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.gold.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                '👑 OWNER',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.gold,
                                ),
                              ),
                            )
                          : PopupMenuButton<String>(
                              enabled:
                                  !_collabLoading &&
                                  !state.isOfflineMode &&
                                  (owner ||
                                      member['user_id'] ==
                                          state.repository?.userId),
                              onSelected: (action) {
                                final targetUserId =
                                    (member['user_id'] as String?) ?? '';
                                if (targetUserId.isNotEmpty) {
                                  _manageMember(targetUserId, action);
                                }
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'REMOVE',
                                  child: Text('Hapus / keluar'),
                                ),
                                if (owner)
                                  const PopupMenuItem(
                                    value: 'TRANSFER_OWNER',
                                    child: Text('Jadikan pemilik'),
                                  ),
                              ],
                            ),
                    ),
                  ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pemilik harus mengalihkan kepemilikan sebelum keluar. Setiap daftar memiliki halaman sendiri; saldo tetap mencakup seluruh akun kas yang dibagikan.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _pagination(
                'Anggota',
                _memberPage,
                _collabMembers.length,
                (page) => _memberPage = page,
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildCategoriesTab(
    BuildContext context,
    AppState state,
    Household group,
    bool categoriesLoaded,
  ) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        // Shared accounts shortcut
        _buildSharedAccountsCard(context, state, group),

        const SizedBox(height: 10),

        // Group Categories Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
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
                      fontSize: 14,
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
                      icon: const Icon(Icons.add, size: 13),
                      label: const Text(
                        'Tambah',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
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
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      leading: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: category.type == 'INCOME'
                              ? AppColors.incomeLight
                              : AppColors.expenseLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          category.type == 'INCOME'
                              ? Icons.category_outlined
                              : Icons.sell_outlined,
                          color: category.type == 'INCOME'
                              ? AppColors.income
                              : AppColors.expense,
                          size: 14,
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
                        'Ketuk untuk pemetaan kategori pribadi.',
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
                              tooltip: 'Edit kategori grup ${category.name}',
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              visualDensity: VisualDensity.compact,
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

        const SizedBox(height: 24),
      ],
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
      body: !hasGroup
          ? ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // Hero Onboarding Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primaryDark, AppColors.primary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
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
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.diversity_3_rounded,
                              size: 13,
                              color: AppColors.accent,
                            ),
                            SizedBox(width: 5),
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
                      const SizedBox(height: 12),
                      const Text(
                        'Kelola Keuangan Bersama',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Bagi pengeluaran, pantau kas bersama, dan kelola keuangan terbuka.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => CreateOrJoinGroupSheet.show(
                                context,
                                initialTabIndex: 0,
                              ),
                              icon: const Icon(
                                Icons.add_circle_outline_rounded,
                                size: 16,
                              ),
                              label: const Text(
                                'Buat Grup',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppColors.primaryDark,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => CreateOrJoinGroupSheet.show(
                                context,
                                initialTabIndex: 1,
                              ),
                              icon: const Icon(
                                Icons.vpn_key_outlined,
                                size: 16,
                              ),
                              label: const Text(
                                'Gabung Kode',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.45),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Server check card
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.sync_rounded,
                        color: state.loading
                            ? AppColors.accentDark
                            : AppColors.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Sudah tergabung di grup?',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: state.loading || state.isOfflineMode
                            ? null
                            : state.refresh,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: AppColors.surfaceVariant,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: state.loading
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Muat ulang data grup',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                _buildFeatureTile(
                  icon: Icons.pie_chart_rounded,
                  iconColor: AppColors.primary,
                  iconBgColor: AppColors.primaryLight.withValues(alpha: 0.12),
                  title: 'Catat Pengeluaran Bersama',
                  description: 'Bagi beban biaya rumah tangga, kosan, atau liburan secara transparan.',
                ),
                const SizedBox(height: 8),
                _buildFeatureTile(
                  icon: Icons.account_balance_wallet_rounded,
                  iconColor: AppColors.accentDark,
                  iconBgColor: AppColors.accentLight.withValues(alpha: 0.35),
                  title: 'Kas & Rekening Terintegrasi',
                  description: 'Tautkan rekening kas yang ingin dibagikan tanpa khawatir saldo pribadi tercampur.',
                ),
                const SizedBox(height: 8),
                _buildFeatureTile(
                  icon: Icons.shield_outlined,
                  iconColor: AppColors.gold,
                  iconBgColor: AppColors.gold.withValues(alpha: 0.15),
                  title: 'Privasi Terjamin',
                  description: 'Hanya transaksi kategori yang dibagikan yang terlihat oleh anggota grup.',
                ),
              ],
            )
          : Column(
              children: [
                _buildHeroPocketCard(state, group, membersLoaded),
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildPocketTab(context, state, group),
                      _buildActivityTab(state),
                      _buildMembersTab(state, group),
                      _buildCategoriesTab(
                        context,
                        state,
                        group,
                        categoriesLoaded,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
