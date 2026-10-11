import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../models/account.dart';
import '../models/account_picker_group.dart';
import '../models/account_picker_section.dart';

/// A reusable bottom sheet modal for picking an account.
/// Features clean grouping, pocket nesting indication, institution badges,
/// search filter, and active balance display.
class AccountPickerSheet extends StatefulWidget {
  final String title;
  final String? selectedAccountId;
  final List<Account>? accounts;
  final bool showBalance;
  final List<Account>? accountUniverse;
  final bool? isBalanceHidden;

  const AccountPickerSheet({
    super.key,
    this.title = 'Pilih Rekening / Kantong',
    this.selectedAccountId,
    this.accounts,
    this.showBalance = true,
    this.accountUniverse,
    this.isBalanceHidden,
  });

  static Future<Account?> show(
    BuildContext context, {
    String title = 'Pilih Rekening / Kantong',
    String? selectedAccountId,
    List<Account>? accounts,
    bool showBalance = true,
  }) {
    final state = AppStateScope.of(context);
    final universe = List<Account>.unmodifiable(state.accounts);
    final selectable = List<Account>.unmodifiable(
      accounts ?? state.selectableAccounts,
    );
    final hidden = state.isBalanceHidden;
    FocusManager.instance.primaryFocus?.unfocus();
    return showModalBottomSheet<Account>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AccountPickerSheet(
        title: title,
        selectedAccountId: selectedAccountId,
        accounts: selectable,
        showBalance: showBalance,
        accountUniverse: universe,
        isBalanceHidden: hidden,
      ),
    );
  }

  @override
  State<AccountPickerSheet> createState() => _AccountPickerSheetState();
}

class _AccountPickerSheetState extends State<AccountPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state =
        widget.accountUniverse == null ||
            widget.accounts == null ||
            widget.isBalanceHidden == null
        ? AppStateScope.of(context)
        : null;
    final allSelectable = widget.accounts ?? state!.selectableAccounts;
    final universe = widget.accountUniverse ?? state!.accounts;
    final hidden = widget.isBalanceHidden ?? state!.isBalanceHidden;
    final groups = buildAccountPickerGroups(
      selectableAccounts: allSelectable,
      accountUniverse: universe,
      query: _searchQuery,
    );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight:
              (MediaQuery.sizeOf(context).height * 0.85 -
                      MediaQuery.viewInsetsOf(context).bottom)
                  .clamp(0.0, double.infinity),
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Search Bar (if more than 5 accounts)
              if (allSelectable.length > 5) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Cari rekening atau kantong...',
                      hintStyle: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      isDense: true,
                      filled: true,
                      fillColor: AppColors.surfaceVariant,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) =>
                        setState(() => _searchQuery = val.trim()),
                  ),
                ),
              ],

              const Divider(height: 1, color: AppColors.border),

              // Account Groups
              Flexible(
                child: groups.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Column(
                            children: const [
                              Icon(
                                Icons.search_off_rounded,
                                size: 40,
                                color: AppColors.textMuted,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Tidak ada akun yang cocok',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        children: [
                          for (final category in ['Cash', 'Investasi'])
                            if (buildAccountPickerSections(groups).any(
                              (section) => section.category == category,
                            )) ...[
                              Padding(
                                padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
                                child: Text(
                                  category,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              for (final section in buildAccountPickerSections(
                                groups,
                              ))
                                if (section.category == category) ...[
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      4,
                                      0,
                                      4,
                                      10,
                                    ),
                                    child: Text(
                                      section.label,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ),
                                  for (final group in section.groups)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 14,
                                      ),
                                      child: _AccountGroupCard(
                                        group: group,
                                        selectedAccountId:
                                            widget.selectedAccountId,
                                        showBalance: widget.showBalance,
                                        isBalanceHidden: hidden,
                                        onSelect: (acc) =>
                                            Navigator.of(context).pop(acc),
                                      ),
                                    ),
                                ],
                            ],
                        ],
                      ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountGroupCard extends StatelessWidget {
  final AccountPickerGroup group;
  final String? selectedAccountId;
  final bool showBalance;
  final bool isBalanceHidden;
  final ValueChanged<Account> onSelect;

  const _AccountGroupCard({
    required this.group,
    required this.selectedAccountId,
    required this.showBalance,
    required this.isBalanceHidden,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final parent = group.parent;
    final isParentAccount = parent != null;
    final parentType = parent != null
        ? parent.type
        : group.entries.first.account.type;
    final typeDef = AccountTypeDefinition.getDefinition(parentType);

    // If it's a standalone account with no parent/pockets, render a clean card
    if (!isParentAccount && group.entries.length == 1) {
      final entry = group.entries.first;
      final account = entry.account;
      final isSelected = account.id == selectedAccountId;
      final accTypeDef = AccountTypeDefinition.getDefinition(account.type);

      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onSelect(account),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.06)
                  : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
                width: isSelected ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                _buildAccountIconBadge(accTypeDef, isPocket: false),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              account.name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _buildTypeBadge(accTypeDef.label, accTypeDef.color),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _buildAccountMetadata(account),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (showBalance) ...[
                        const SizedBox(height: 4),
                        Text(
                          isBalanceHidden
                              ? '••••••'
                              : CurrencyFormatter.formatRupiah(account.balance),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _buildTrailingAction(isSelected, account.isShared),
              ],
            ),
          ),
        ),
      );
    }

    // Multiple pockets or grouped under a parent account (e.g. Bank Jago / Bareksa / etc.)
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Parent / Container Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: typeDef.color.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(19),
              ),
            ),
            child: Row(
              children: [
                _buildAccountIconBadge(
                  typeDef,
                  isPocket: false,
                  size: 30,
                  iconSize: 16,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        parent != null ? parent.name : 'Grup Akun',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (parent != null &&
                          (parent.institution.isNotEmpty ||
                              parent.ownerName.isNotEmpty))
                        Text(
                          [
                            parent.institution,
                            parent.ownerName,
                          ].where((s) => s.isNotEmpty).join(' • '),
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                _buildTypeBadge(typeDef.label, typeDef.color),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    '${group.entries.length} Kantong',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // Pockets list
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: group.entries.length,
            separatorBuilder: (_, _) => Padding(
              padding: const EdgeInsets.only(left: 48, right: 14),
              child: Divider(
                height: 1,
                color: AppColors.border.withValues(alpha: 0.5),
              ),
            ),
            itemBuilder: (context, index) {
              final entry = group.entries[index];
              final account = entry.account;
              final isSelected = account.id == selectedAccountId;
              final isLast = index == group.entries.length - 1;

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onSelect(account),
                  borderRadius: isLast
                      ? const BorderRadius.vertical(bottom: Radius.circular(19))
                      : BorderRadius.zero,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.08)
                        : Colors.transparent,
                    child: Row(
                      children: [
                        // Tree connector icon
                        Container(
                          width: 28,
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.subdirectory_arrow_right_rounded,
                            size: 18,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Pocket details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      account.name,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w600,
                                        color: isSelected
                                            ? AppColors.primary
                                            : AppColors.textPrimary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (entry.hasUnavailableParent) ...[
                                    const SizedBox(width: 6),
                                    const Text(
                                      '(Induk tidak tersedia)',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppColors.warning,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (showBalance) ...[
                                const SizedBox(height: 3),
                                Text(
                                  isBalanceHidden
                                      ? '••••••'
                                      : CurrencyFormatter.formatRupiah(
                                          account.balance,
                                        ),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Right action
                        _buildTrailingAction(isSelected, account.isShared),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAccountIconBadge(
    AccountTypeDefinition def, {
    required bool isPocket,
    double size = 38,
    double iconSize = 20,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: def.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(
        isPocket ? Icons.subdirectory_arrow_right_rounded : def.icon,
        color: def.color,
        size: iconSize,
      ),
    );
  }

  Widget _buildTypeBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  String _buildAccountMetadata(Account account) {
    return [
      if (account.institution.isNotEmpty) account.institution,
      if (account.ownerName.isNotEmpty) account.ownerName,
    ].join(' • ');
  }

  Widget _buildTrailingAction(bool isSelected, bool isShared) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (isSelected)
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.primary,
            size: 20,
          )
        else if (isShared)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.accentLight.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'Bersama',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: AppColors.accentDark,
              ),
            ),
          ),
      ],
    );
  }
}

/// A modern clickable selector tile that displays the currently selected account
/// and triggers the AccountPickerSheet when tapped.
class AccountSelectorTile extends StatelessWidget {
  final String label;
  final Account? account;
  final VoidCallback onTap;
  final bool isError;

  const AccountSelectorTile({
    super.key,
    required this.label,
    required this.account,
    required this.onTap,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final typeDef = account != null
        ? AccountTypeDefinition.getDefinition(account!.type)
        : null;
    final isPocket = account?.isPocket ?? false;
    final state = AppStateScope.of(context);
    final entry = account == null
        ? null
        : resolveAccountPickerEntry(account!, state.accounts);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isError
                    ? AppColors.expense
                    : AppColors.border.withValues(alpha: 0.6),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                if (account != null && typeDef != null) ...[
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: typeDef.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isPocket
                          ? Icons.subdirectory_arrow_right_rounded
                          : typeDef.icon,
                      color: typeDef.color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                account!.name,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: typeDef.color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                typeDef.label,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: typeDef.color,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (entry?.breadcrumb.isNotEmpty == true)
                              entry!.breadcrumb,
                            if (account!.institution.isNotEmpty)
                              account!.institution,
                            if (account!.ownerName.isNotEmpty)
                              account!.ownerName,
                          ].join(' • '),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          state.isBalanceHidden
                              ? '••••••'
                              : CurrencyFormatter.formatRupiah(
                                  account!.balance,
                                ),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: AppColors.textMuted,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Pilih Rekening',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textSecondary,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
