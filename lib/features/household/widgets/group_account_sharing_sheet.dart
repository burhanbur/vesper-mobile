import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import 'group_list_status.dart';

class GroupAccountSharingSheet extends StatefulWidget {
  final String groupId;
  const GroupAccountSharingSheet({super.key, required this.groupId});
  @override
  State<GroupAccountSharingSheet> createState() =>
      _GroupAccountSharingSheetState();
}

class _GroupAccountSharingSheetState extends State<GroupAccountSharingSheet> {
  String? _selected, _error;
  bool _busy = false;
  AppState? _state;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppStateScope.of(context);
    if (identical(_state, state)) return;
    _state = state;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && identical(_state, state)) {
        state.loadGroupList(widget.groupId);
      }
    });
  }

  Future<void> _submit(bool remove) async {
    if (_busy || _selected == null) return;
    final accountId = _selected!;
    final state = AppStateScope.of(context);
    final repo = state.repository;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          remove ? 'Hentikan pembagian akun?' : 'Bagikan akun ke grup?',
        ),
        content: Text(
          remove
              ? 'Akun ini tidak lagi berkontribusi ke laporan grup. Riwayat pribadi tidak dihapus.'
              : 'Transaksi akun ini dapat berkontribusi ke laporan grup melalui pemetaan kategori, termasuk riwayat sebelumnya. Anggota grup dapat melihat agregat tersebut. Saldo dan transaksi pribadi tidak diubah.',
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
        _busy ||
        !identical(state.repository, repo) ||
        widget.groupId != state.activeHouseholdId) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await state.shareGroupAccount(
        groupId: widget.groupId,
        accountId: accountId,
        remove: remove,
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final repo = state.repository;
    final allUserAccounts = (repo?.rows('accounts') ?? <Map<String, dynamic>>[])
        .where(
          (row) => row['user_id'] == repo?.userId && row['deleted_at'] == null,
        )
        .toList();

    // Accounts that have at least one child pointing to them are parents
    final parentAccountIds = <String>{};
    for (final a in allUserAccounts) {
      final parentId = a['parent_account_id']?.toString();
      if (parentId != null && parentId.isNotEmpty) {
        parentAccountIds.add(parentId);
      }
    }

    // Map parent ID to parent Name
    final parentNamesById = <String, String>{};
    for (final a in allUserAccounts) {
      final id = a['id']?.toString();
      final name = a['name']?.toString();
      if (id != null && name != null) {
        parentNamesById[id] = name;
      }
    }

    String getAccountDisplayName(Map<String, dynamic> row) {
      final rawName = row['name']?.toString() ?? 'Akun';
      final parentId = row['parent_account_id']?.toString();
      if (parentId != null && parentId.isNotEmpty) {
        final parentName = parentNamesById[parentId];
        if (parentName != null && parentName.isNotEmpty) {
          if (rawName.startsWith('$parentName - ')) {
            return rawName;
          }
          return '$parentName - $rawName';
        }
      }
      return rawName;
    }

    Map<String, dynamic>? findAccountById(String? id) {
      if (id == null) return null;
      for (final a in allUserAccounts) {
        if (a['id'] == id) return a;
      }
      return null;
    }

    // Only standalone (single) accounts and child accounts (exclude parents)
    final accounts = allUserAccounts
        .where((row) => !parentAccountIds.contains(row['id']?.toString()))
        .toList();
    final validSelection = accounts.any((row) => row['id'] == _selected);
    final rows = state.groupListRows(widget.groupId);
    final shared = rows.any((row) => row['account_id'] == _selected);
    final available =
        !_busy &&
        !state.isOfflineMode &&
        widget.groupId == state.activeHouseholdId &&
        state.groupListFresh(widget.groupId) &&
        !state.groupListLoading(widget.groupId);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Pinned Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.accentLight.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.share_outlined,
                          size: 18,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pembagian Akun Grup (online)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Pilih akun kas/bank yang dibagikan ke laporan grup',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        color: AppColors.textMuted,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),

            // Scrollable Middle List
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                children: [
                  GroupListStatus(state: state, groupId: widget.groupId),
                  if (rows.isNotEmpty) ...[
                    const Text(
                      'Akun yang Dibagikan',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (final row in rows) ...[
                      () {
                        final localAcc = findAccountById(
                          row['account_id']?.toString(),
                        );
                        final sharedName = localAcc != null
                            ? getAccountDisplayName(localAcc)
                            : (row['name']?.toString() ?? 'Akun');
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.income.withValues(alpha: 0.35),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.income.withValues(alpha: 0.05),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.incomeLight,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.cloud_done_rounded,
                                  size: 18,
                                  color: AppColors.income,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Dibagikan oleh Anda: $sharedName',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Aktif dalam agregat laporan grup',
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
                        );
                      }(),
                    ],
                    const SizedBox(height: 6),
                  ],
                  if (state.groupListFresh(widget.groupId) && rows.isEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.border.withValues(alpha: 0.5),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                            color: AppColors.textMuted,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Belum ada akun Anda yang dibagikan.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Text(
                    'Pilih Akun Pribadi',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (accounts.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          'Tidak ada akun pribadi yang tersedia.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    )
                  else ...[
                    for (final acc in accounts.where(
                      (row) => row['id'] != null && row['name'] != null,
                    )) ...[
                      () {
                        final accId = acc['id'].toString();
                        final accName = getAccountDisplayName(acc);
                        final isSelected = _selected == accId;
                        final isShared = rows.any(
                          (r) => r['account_id'] == accId,
                        );
                        final balanceVal = acc['balance'];
                        final currencyVal =
                            acc['currency']?.toString() ?? 'IDR';

                        return InkWell(
                          onTap: _busy
                              ? null
                              : () => setState(() {
                                  _selected = accId;
                                  _error = null;
                                }),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.surfaceVariant
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : isShared
                                    ? AppColors.income.withValues(alpha: 0.45)
                                    : AppColors.border.withValues(alpha: 0.7),
                                width: isSelected ? 1.8 : 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isSelected
                                      ? AppColors.primary.withValues(
                                          alpha: 0.08,
                                        )
                                      : Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primary.withValues(
                                            alpha: 0.12,
                                          )
                                        : isShared
                                        ? AppColors.incomeLight
                                        : AppColors.surfaceVariant,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.account_balance_wallet_rounded,
                                    size: 18,
                                    color: isSelected
                                        ? AppColors.primary
                                        : isShared
                                        ? AppColors.income
                                        : AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              accName,
                                              style: TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: isSelected
                                                    ? FontWeight.w700
                                                    : FontWeight.w600,
                                                color: AppColors.textPrimary,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (isShared) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppColors.incomeLight,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: const Text(
                                                'DIBAGIKAN',
                                                style: TextStyle(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: AppColors.income,
                                                  letterSpacing: 0.4,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        state.isBalanceHidden
                                            ? '••••••'
                                            : CurrencyFormatter.formatCurrency(
                                                balanceVal,
                                                currency: currencyVal,
                                              ),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  isSelected
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_unchecked_rounded,
                                  size: 20,
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.border,
                                ),
                              ],
                            ),
                          ),
                        );
                      }(),
                    ],
                    Container(
                      margin: const EdgeInsets.only(top: 2, bottom: 8),
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: validSelection ? _selected : null,
                        decoration: InputDecoration(
                          labelText: 'Akun pribadi',
                          prefixIcon: const Icon(
                            Icons.account_balance_rounded,
                            size: 18,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                        items: accounts
                            .where(
                              (row) => row['id'] != null && row['name'] != null,
                            )
                            .map(
                              (row) => DropdownMenuItem(
                                value: row['id'].toString(),
                                child: Text(
                                  getAccountDisplayName(row),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: _busy
                            ? null
                            : (value) => setState(() => _selected = value),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Pinned Bottom Action Footer
            Container(
              padding: EdgeInsets.fromLTRB(
                20,
                10,
                20,
                12 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(
                    color: AppColors.border.withValues(alpha: 0.6),
                    width: 1,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_selected != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: shared
                            ? AppColors.incomeLight.withValues(alpha: 0.5)
                            : AppColors.surfaceVariant.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: shared
                              ? AppColors.income.withValues(alpha: 0.3)
                              : AppColors.border.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            shared
                                ? Icons.check_circle_outline
                                : Icons.info_outline,
                            size: 14,
                            color: shared
                                ? AppColors.income
                                : AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              shared
                                  ? 'Akun terpilih tercatat dibagikan oleh Anda.'
                                  : 'Akun terpilih tidak tercatat pada daftar ini.',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: shared
                                    ? AppColors.income
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.expenseLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.expense,
                        ),
                      ),
                    ),
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: available && validSelection && !shared
                          ? () => _submit(false)
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        _busy ? 'Memproses…' : 'Bagikan akun',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: available && validSelection && shared
                        ? () => _submit(true)
                        : null,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.expense,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                    ),
                    child: const Text('Hentikan pembagian akun terpilih'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
