import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/network/api_client.dart';
import '../data/collaboration_repository.dart';

/// No durable cross-member cache: revocation is checked on every online refresh.
class CollaborationPanel extends StatefulWidget {
  const CollaborationPanel({super.key});
  @override
  State<CollaborationPanel> createState() => _CollaborationPanelState();
}

class _CollaborationPanelState extends State<CollaborationPanel>
    with WidgetsBindingObserver {
  String? _scope;
  int _token = 0, _contributionPage = 1, _feedPage = 1, _memberPage = 1;
  bool _owner = false;
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _data;
  List<Map<String, dynamic>> _members = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (state != AppLifecycleState.resumed) {
      setState(() {
        ++_token;
        _data = null;
        _members = [];
        _owner = false;
        _loading = false;
        _error = null;
      });
    } else {
      final app = AppStateScope.of(context);
      if (app.repository != null &&
          !app.isOfflineMode &&
          app.activeHouseholdId.isNotEmpty) {
        _load();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppStateScope.of(context);
    final scope =
        '${state.repository?.userId}:${state.activeHouseholdId}:${state.householdReportPeriod}:${state.isOfflineMode}';
    if (_scope != scope) {
      _scope = scope;
      _token++;
      _data = null;
      _members = [];
      _error = null;
      _loading = false;
      _owner = false;
      _contributionPage = _feedPage = _memberPage = 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scope == scope) _load();
      });
    }
  }

  Future<void> _load() async {
    final state = AppStateScope.of(context);
    final repo = state.repository;
    final group = state.activeHouseholdId;
    final period = state.householdReportPeriod;
    final contributionPage = _contributionPage;
    final feedPage = _feedPage;
    final memberPage = _memberPage;
    final token = ++_token;
    setState(() {
      _loading = true;
      _error = null;
      _data = null;
      _members = [];
      _owner = false;
    });
    try {
      if (repo == null || state.isOfflineMode) {
        throw StateError('Koneksi online diperlukan.');
      }
      final service = CollaborationRepository(repo.client);
      final data = await service.read(group, period, contributionPage);
      if (!mounted || token != _token) return;
      final feedData = feedPage == contributionPage
          ? data
          : await service.read(group, period, feedPage);
      if (!mounted || token != _token) return;
      final members = await service.members(group, memberPage);
      if (!mounted || token != _token) return;
      final role = await service.actorRole(group, repo.userId);
      if (!mounted || token != _token) return;
      if (role == null) {
        throw const ApiFailure(
          'Keanggotaan tidak dapat diverifikasi. Muat ulang grup.',
          statusCode: 403,
        );
      }
      setState(() {
        _data = {...data, 'feed': feedData['feed']};
        _members = members;
        _owner = role == 'OWNER';
      });
    } catch (error) {
      if (mounted && token == _token) {
        setState(() {
          _error = '$error';
        });
      }
    } finally {
      if (mounted && token == _token) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _manage(String user, String action) async {
    final state = AppStateScope.of(context);
    final repo = state.repository;
    final group = state.activeHouseholdId;
    final scope = _scope;
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
        _loading ||
        repo == null ||
        scope != _scope ||
        state.isOfflineMode ||
        !identical(repo, state.repository)) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await CollaborationRepository(repo.client).manage(group, user, action);
      if (!mounted || scope != _scope) return;
      // Remove privileged presentation immediately; the containing group list is refreshed separately.
      setState(() {
        _data = null;
        _members = [];
      });
      await state.refresh();
      if (!mounted || scope != _scope || !identical(repo, state.repository)) {
        return;
      }
      await _load();
    } catch (error) {
      if (mounted && scope == _scope) {
        setState(() {
          _error = '$error';
          _loading = false;
          _data = null;
          _members = [];
          _owner = false;
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
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
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
                onPressed: _loading || page == 1
                    ? null
                    : () {
                        select(page - 1);
                        _load();
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
                onPressed: _loading || count < 20
                    ? null
                    : () {
                        select(page + 1);
                        _load();
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

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final owner = _owner;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.accentLight.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.people_alt_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Kolaborasi grup',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
              const Spacer(),
              if (_loading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, size: 15, color: AppColors.primary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Online saja • Saldo akun CASH yang dibagikan, per mata uang. Kontribusi = pemasukan/pengeluaran berkategori terpetakan pada bulan acuan server terpilih, bukan utang atau setoran anggota. Transfer dan investasi tidak dihitung.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _loading || state.isOfflineMode ? null : _load,
              icon: const Icon(Icons.refresh_rounded, size: 14),
              label: const Text(
                'Muat ulang kolaborasi',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                foregroundColor: AppColors.primary,
              ),
            ),
          ),
          if (_loading)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: const LinearProgressIndicator(
                minHeight: 3,
                color: AppColors.primary,
                backgroundColor: AppColors.accentLight,
              ),
            ),
          if (_error != null)
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.expenseLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.expense.withValues(alpha: 0.25),
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
                      _error!,
                      style: const TextStyle(
                        color: AppColors.expense,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (_data != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.accentLight.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 15,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Saldo kas bersama',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if ((_data!['balances'] as List).isEmpty)
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
                      Icons.info_outline_rounded,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Tidak ada saldo kas dibagikan.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            for (final row in _data!['balances'] as List)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.accentLight.withValues(alpha: 0.4),
                      AppColors.surfaceVariant.withValues(alpha: 0.6),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.wallet_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Kas (${row['currency']})',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${row['currency']} ${row['balance']}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            const Divider(height: 20),
            const SizedBox(height: 4),
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
            if ((_data!['contributions'] as List).isEmpty)
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
              for (final row in _data!['contributions'] as List)
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
              (_data!['contributions'] as List).length,
              (page) => _contributionPage = page,
            ),
            const SizedBox(height: 10),
            const Divider(height: 20),
            const SizedBox(height: 4),
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
              ],
            ),
            const SizedBox(height: 8),
            if ((_data!['feed'] as List).isEmpty)
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
              for (final row in _data!['feed'] as List)
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
                                timeZone: AppStateScope.of(context).timeZone,
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
              (_data!['feed'] as List).length,
              (page) => _feedPage = page,
            ),
            const SizedBox(height: 10),
            const Divider(height: 20),
            const SizedBox(height: 4),
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
              ],
            ),
            const SizedBox(height: 8),
            for (final member in _members)
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
                          ? ((member['name'] as String?) ?? '')[0].toUpperCase()
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
                              !_loading &&
                              !state.isOfflineMode &&
                              (owner ||
                                  member['user_id'] ==
                                      state.repository?.userId),
                          onSelected: (action) {
                            final targetUserId =
                                (member['user_id'] as String?) ?? '';
                            if (targetUserId.isNotEmpty) {
                              _manage(targetUserId, action);
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
              _members.length,
              (page) => _memberPage = page,
            ),
          ],
        ],
      ),
    );
  }
}
