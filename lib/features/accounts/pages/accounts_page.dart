import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/shell_management_scope.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../household/models/household.dart';
import '../../household/widgets/create_group_sheet.dart';
import '../models/account.dart';
import '../models/account_picker_group.dart';
import '../models/account_picker_section.dart';
import 'account_detail_page.dart';

class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key});

  static void showAccountSettings(BuildContext context, Account account) {
    _AccountsPageState._showAccountDetailModal(context, account);
  }

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  // Filter mode: 'all' = semua akun, 'personal' = akun pribadi, or household.id = grup spesifik
  String _activeFilter = 'all';
  final Set<String> _expandedParents = <String>{};

  static IconData _getAccountIcon(AccountType type) {
    return AccountTypeDefinition.getDefinition(type).icon;
  }

  static Color _getAccountColor(AccountType type) {
    return AccountTypeDefinition.getDefinition(type).color;
  }

  void _showAddAccountModal(BuildContext context) {
    final nameController = TextEditingController();
    final numberController = TextEditingController();
    final balanceController = TextEditingController();
    AccountType selectedType = AccountType.bank;
    bool isShared = false;
    String? selectedParentId;

    final state = AppStateScope.of(context);
    String? selectedAccountTypeId =
        state.accountTypes.firstOrNull?['id'] as String?;
    final validHouseholdIds = state.households.map((h) => h.id).toSet();
    String selectedHouseholdId =
        validHouseholdIds.contains(state.activeHouseholdId)
        ? state.activeHouseholdId
        : (state.households.isNotEmpty ? state.households.first.id : 'hh-1');
    final parentCandidates = state.accounts
        .where((a) => a.parentAccountId == null && a.type == AccountType.bank)
        .toList();

    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tambah Akun / Rekening Baru',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Tipe Akun',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: state.accountTypes.map((def) {
                    final isSelected = selectedAccountTypeId == def['id'];
                    return ChoiceChip(
                      avatar: const Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 16,
                      ),
                      label: Text(def['name'] as String),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (val) {
                        if (val) {
                          setModalState(() {
                            selectedAccountTypeId = def['id'] as String;
                            selectedType = def['category'] == 'INVESTMENT'
                                ? AccountType.investment
                                : AccountType.cash;
                          });
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Nama Akun',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    hintText: 'Contoh: BCA Tabungan atau Kantong Bersama',
                    prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Saldo Awal (Rp)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: balanceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: 'Contoh: 1000000',
                    prefixText: 'Rp ',
                    prefixIcon: Icon(Icons.money_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Nomor Rekening / Keterangan',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: numberController,
                  decoration: const InputDecoration(
                    hintText: 'Contoh: 1234 5678 90',
                    prefixIcon: Icon(Icons.numbers_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                // Nested Pocket Option
                if (selectedType == AccountType.bank &&
                    parentCandidates.isNotEmpty) ...[
                  const Text(
                    'Jadikan Kantong (Child Pocket)?',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: selectedParentId,
                        isExpanded: true,
                        hint: const Text('Bukan Kantong (Akun Utama Terpisah)'),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Bukan Kantong (Akun Utama Terpisah)'),
                          ),
                          ...parentCandidates.map(
                            (p) => DropdownMenuItem<String?>(
                              value: p.id,
                              child: Text(
                                'Di bawah ${p.name} (${p.institution})',
                              ),
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          setModalState(() => selectedParentId = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                // Shared with group toggle
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: isShared,
                  activeThumbColor: AppColors.primary,
                  title: const Text(
                    'Bagikan ke Grup Bersama (Shared)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Pilih grup yang dapat mengakses dan melihat transaksi akun ini.',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                  onChanged: (val) => setModalState(() => isShared = val),
                ),
                if (isShared) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Pilih Grup Tujuan',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: validHouseholdIds.contains(selectedHouseholdId)
                            ? selectedHouseholdId
                            : (state.households.isNotEmpty
                                  ? state.households.first.id
                                  : null),
                        isExpanded: true,
                        items: state.households
                            .map(
                              (h) => DropdownMenuItem<String>(
                                value: h.id,
                                child: Row(
                                  children: [
                                    Text(
                                      h.type.emoji,
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        h.name,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => selectedHouseholdId = val);
                          }
                        },
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final balance =
                        int.tryParse(
                          balanceController.text.replaceAll(
                            RegExp(r'[^0-9]'),
                            '',
                          ),
                        ) ??
                        0;
                    if (name.isEmpty) return;

                    try {
                      state.addAccount(
                        name: name,
                        accountTypeId: selectedAccountTypeId,
                        type: selectedType,
                        initialBalance: balance,
                        accountNumber: numberController.text.trim().isEmpty
                            ? 'Rek. Baru'
                            : numberController.text.trim(),
                        institution: AccountTypeDefinition.getDefinition(
                          selectedType,
                        ).categoryGroup,
                        isShared: isShared,
                        householdId: isShared ? selectedHouseholdId : null,
                        parentAccountId: selectedParentId,
                      );
                    } catch (error) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(error.toString())));
                      return;
                    }

                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: AppColors.primary,
                        content: Text('Akun "$name" berhasil ditambahkan!'),
                      ),
                    );
                  },
                  child: const Text('Simpan Akun'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openAccountDetail(BuildContext context, Account account) {
    final state = AppStateScope.of(context);
    ShellManagementScope.open(
      context,
      AccountDetailPage(
        accountId: account.id,
        onSettings: () => _showAccountDetailModal(
          context,
          state.getAccountById(account.id) ?? account,
        ),
      ),
    );
  }

  static void _showAccountDetailModal(BuildContext context, Account account) {
    final state = AppStateScope.of(context);
    final validHouseholdIds = state.households.map((h) => h.id).toSet();
    bool modalIsShared = account.isShared;
    bool modalIsIncludeTotal = account.isIncludeTotal;
    final children = state.getChildrenForAccount(account.id);
    final hasChildren = children.isNotEmpty;
    final modalDisplayBalance = hasChildren
        ? account.balance + children.fold<int>(0, (sum, c) => sum + c.balance)
        : account.balance;
    String modalSelectedHouseholdId =
        (account.householdId != null &&
            validHouseholdIds.contains(account.householdId))
        ? account.householdId!
        : (validHouseholdIds.contains(state.activeHouseholdId)
              ? state.activeHouseholdId
              : (state.households.isNotEmpty
                    ? state.households.first.id
                    : 'hh-1'));

    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          final color = _getAccountColor(account.type);

          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header with account icon & name
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          _getAccountIcon(account.type),
                          color: color,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              account.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${account.institution.isNotEmpty ? '${account.institution} • ' : ''}${account.accountNumber}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Balance Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Saldo Rekening',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (hasChildren) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Akumulasi dari ${children.length} kantong',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.accentDark,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 4),
                              Text(
                                state.isBalanceHidden
                                    ? '••••••'
                                    : CurrencyFormatter.formatRupiah(
                                        modalDisplayBalance,
                                      ),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              if (hasChildren) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Total akumulasi dari ${children.length} kantong terhubung',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.accentDark,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            '👤 Milik ${account.ownerName}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Include in Total Toggle Card
                  Material(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(
                        color: modalIsIncludeTotal && !hasChildren
                            ? AppColors.accent.withValues(alpha: 0.5)
                            : AppColors.border,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: modalIsIncludeTotal && !hasChildren
                                  ? AppColors.accent.withValues(alpha: 0.12)
                                  : AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              modalIsIncludeTotal && !hasChildren
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                              color: modalIsIncludeTotal && !hasChildren
                                  ? AppColors.accentDark
                                  : AppColors.textMuted,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Sertakan dalam Total Saldo',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  hasChildren
                                      ? 'Akun induk otomatis dikecualikan agar saldo kantong tidak ganda.'
                                      : modalIsIncludeTotal
                                      ? 'Saldo akun ini dihitung dalam ringkasan total saldo.'
                                      : 'Saldo akun ini diabaikan dari ringkasan total saldo.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: hasChildren
                                        ? const Color(0xFFD97706)
                                        : AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          CupertinoSwitch(
                            value: modalIsIncludeTotal && !hasChildren,
                            activeTrackColor: AppColors.primary,
                            onChanged: hasChildren
                                ? null
                                : (val) => setModalState(
                                    () => modalIsIncludeTotal = val,
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Sharing Settings Card
                  Material(
                    color: modalIsShared
                        ? const Color(0xFFF0FDF4)
                        : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(
                        color: modalIsShared
                            ? AppColors.accent.withValues(alpha: 0.5)
                            : AppColors.border,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: modalIsShared,
                            activeThumbColor: AppColors.primary,
                            title: const Text(
                              'Bagikan ke Ruang Grup Bersama',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              modalIsShared
                                  ? 'Rekening ini dapat diakses & dilihat anggota grup terpilih.'
                                  : 'Rekening ini bersifat pribadi dan hanya terlihat oleh Anda.',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                            onChanged: (val) =>
                                setModalState(() => modalIsShared = val),
                          ),
                          if (modalIsShared) ...[
                            const Divider(height: 20),
                            const Text(
                              'Pilih Grup yang Dapat Mengakses',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value:
                                      validHouseholdIds.contains(
                                        modalSelectedHouseholdId,
                                      )
                                      ? modalSelectedHouseholdId
                                      : (state.households.isNotEmpty
                                            ? state.households.first.id
                                            : null),
                                  isExpanded: true,
                                  items: state.households
                                      .map(
                                        (h) => DropdownMenuItem<String>(
                                          value: h.id,
                                          child: Row(
                                            children: [
                                              Text(
                                                h.type.emoji,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  h.name,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setModalState(
                                        () => modalSelectedHouseholdId = val,
                                      );
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Save button
                  ElevatedButton(
                    onPressed: () {
                      if (modalIsIncludeTotal != account.isIncludeTotal &&
                          !hasChildren) {
                        state.updateAccountIncludeTotal(
                          accountId: account.id,
                          isIncludeTotal: modalIsIncludeTotal,
                        );
                      }
                      state.updateAccountSharing(
                        accountId: account.id,
                        isShared: modalIsShared,
                        householdId: modalIsShared
                            ? modalSelectedHouseholdId
                            : null,
                      );

                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: AppColors.primary,
                          content: Text(
                            modalIsShared
                                ? 'Rekening "${account.name}" berhasil dibagikan ke grup!'
                                : 'Rekening "${account.name}" kini disetel sebagai Pribadi.',
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Simpan Pengaturan Rekening',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGroupBadge(Account account, AppState state) {
    if (account.householdId != null) {
      final hh = state.households.cast<Household?>().firstWhere(
        (h) => h?.id == account.householdId,
        orElse: () => null,
      );
      if (hh != null) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.accentLight,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '${hh.type.emoji} ${hh.name}',
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: AppColors.accentDark,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }
    }

    if (account.isShared) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.accentLight,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          '👥 Bersama',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: AppColors.accentDark,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        '👤 Pribadi',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final isHidden = state.isBalanceHidden;
    final allAccounts = state.accounts;

    // Hitung total saldo pribadi vs total saldo grup
    final personalAccounts = allAccounts
        .where((a) => !a.isShared && a.householdId == null)
        .toList();
    final totalPersonalBalance = personalAccounts
        .where((a) => a.isIncludeTotal && a.isCashBankOrWallet)
        .fold(0, (sum, a) => sum + a.balance);

    final totalSharedBalance = allAccounts
        .where((a) => a.isShared && a.isIncludeTotal && a.isCashBankOrWallet)
        .fold(0, (sum, a) => sum + a.balance);

    // Hitung akun yang difilter dan total yang ditampilkan di Hero Card
    final List<Account> filteredAccounts;
    final int heroBalance;
    final String heroTitle;

    if (_activeFilter == 'all') {
      filteredAccounts = allAccounts;
      heroBalance = state.totalLiquidCash;
      heroTitle = 'Total Saldo Kas & Bank';
    } else if (_activeFilter == 'personal') {
      filteredAccounts = personalAccounts;
      heroBalance = totalPersonalBalance;
      heroTitle = 'Total Saldo Akun Pribadi';
    } else {
      final selectedGroup = state.households.firstWhere(
        (h) => h.id == _activeFilter,
        orElse: () => state.household,
      );
      filteredAccounts = allAccounts.where((a) {
        if (a.householdId != null) return a.householdId == _activeFilter;
        return a.isShared && _activeFilter == 'hh-1';
      }).toList();
      heroBalance = filteredAccounts
          .where((a) => a.isIncludeTotal && a.isCashBankOrWallet)
          .fold(0, (sum, a) => sum + a.balance);
      heroTitle = 'Saldo Bersama: ${selectedGroup.name}';
    }

    // Top-level / Root accounts for display
    final rootAccounts = filteredAccounts
        .where((a) => a.parentAccountId == null && a.isVisible)
        .toList();
    final sections = buildAccountPickerSections(
      buildAccountPickerGroups(
        selectableAccounts: rootAccounts,
        accountUniverse: allAccounts,
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Kelola Akun & Rekening'),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.add_circle_outline_rounded,
              color: AppColors.primary,
            ),
            onPressed: () => _showAddAccountModal(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. HERO WEALTH & CASH CARD (Dual-Tier Breakdown)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          heroTitle,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            isHidden
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 20,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () => state.toggleHideBalance(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isHidden
                          ? 'Rp •••••••••'
                          : CurrencyFormatter.formatRupiah(heroBalance),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: AppColors.divider),
                    const SizedBox(height: 10),
                    // Mini distribution summary
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Pribadi: ',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  isHidden
                                      ? '••••••'
                                      : CurrencyFormatter.formatRupiah(
                                          totalPersonalBalance,
                                        ),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 14,
                          color: AppColors.border,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.accent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Grup: ',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  isHidden
                                      ? '••••••'
                                      : CurrencyFormatter.formatRupiah(
                                          totalSharedBalance,
                                        ),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // 2. MODERN HORIZONTAL PILL SELECTOR (Semua, Pribadi, & Semua Grup Pengguna)
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    // Pill: Semua
                    _buildPillChip(
                      id: 'all',
                      label: 'Semua Rekening',
                      count: allAccounts
                          .where((a) => a.parentAccountId == null)
                          .length,
                      icon: Icons.layers_outlined,
                    ),
                    const SizedBox(width: 8),

                    // Pill: Pribadi
                    _buildPillChip(
                      id: 'personal',
                      label: 'Akun Pribadi',
                      count: personalAccounts
                          .where((a) => a.parentAccountId == null)
                          .length,
                      icon: Icons.person_outline_rounded,
                    ),
                    const SizedBox(width: 8),

                    // Pills: Setiap Grup Dinamis yang Diikuti Pengguna
                    for (final h in state.households) ...[
                      _buildGroupPill(h, state),
                      const SizedBox(width: 8),
                    ],

                    // Tombol Buat Grup Baru
                    InkWell(
                      onTap: () => CreateOrJoinGroupSheet.show(context),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_rounded,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Grup Baru',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 3. DAFTAR REKENING HEADER
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _activeFilter == 'all'
                          ? 'Daftar Akun & Kantong'
                          : _activeFilter == 'personal'
                          ? 'Daftar Akun Pribadi'
                          : 'Akun Terhubung: ${state.households.firstWhere((h) => h.id == _activeFilter, orElse: () => state.household).name}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${rootAccounts.length} Rekening',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 4. ACCOUNTS LIST ATAU EMPTY STATE
              if (rootAccounts.isEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 36,
                    horizontal: 20,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          color: AppColors.surfaceVariant,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_outlined,
                          color: AppColors.textMuted,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _activeFilter == 'personal'
                            ? 'Belum Ada Akun Pribadi'
                            : 'Belum Ada Rekening di Grup Ini',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _activeFilter == 'personal'
                            ? 'Semua rekening Anda saat ini telah dibagikan ke grup bersama.'
                            : 'Bagikan rekening pribadi atau buat kantong khusus untuk grup ini agar pengeluaran bersama tercatat rapi.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: Text(
                          _activeFilter == 'personal'
                              ? 'Tambah Akun Pribadi'
                              : 'Tambah Rekening Grup',
                        ),
                        onPressed: () => _showAddAccountModal(context),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                for (
                  var sectionIndex = 0;
                  sectionIndex < sections.length;
                  sectionIndex++
                ) ...[
                  if (sectionIndex == 0 ||
                      sections[sectionIndex - 1].category !=
                          sections[sectionIndex].category)
                    Padding(
                      padding: EdgeInsets.only(
                        top: sectionIndex == 0 ? 0 : 20,
                        bottom: 12,
                      ),
                      child: Text(
                        sections[sectionIndex].category,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    child: Text(
                      sections[sectionIndex].label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: sections[sectionIndex].groups.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final account = sections[sectionIndex]
                          .groups[index]
                          .entries
                          .first
                          .account;
                      final children = state.getChildrenForAccount(account.id);
                      final hasChildren = children.isNotEmpty;
                      final isExpanded = _expandedParents.contains(account.id);
                      final color = _getAccountColor(account.type);
                      final parentDisplayBalance = hasChildren
                          ? account.balance +
                                children.fold<int>(
                                  0,
                                  (sum, c) => sum + c.balance,
                                )
                          : account.balance;

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Parent Account Tile
                            InkWell(
                              onTap: () => _openAccountDetail(context, account),
                              onLongPress: () =>
                                  _showAccountDetailModal(context, account),
                              borderRadius: BorderRadius.circular(20),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(
                                        _getAccountIcon(account.type),
                                        color: color,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  account.name,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w700,
                                                    color:
                                                        AppColors.textPrimary,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              _buildGroupBadge(account, state),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            hasChildren
                                                ? '${children.length} Kantong Terhubung'
                                                : '${account.accountNumber} • Milik ${account.ownerName}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textMuted,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          isHidden
                                              ? '••••••'
                                              : CurrencyFormatter.formatRupiah(
                                                  parentDisplayBalance,
                                                ),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        if (hasChildren)
                                          TextButton(
                                            onPressed: () => setState(() {
                                              if (isExpanded) {
                                                _expandedParents.remove(
                                                  account.id,
                                                );
                                              } else {
                                                _expandedParents.add(
                                                  account.id,
                                                );
                                              }
                                            }),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  isExpanded
                                                      ? 'Tutup'
                                                      : 'Lihat Kantong',
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    color: AppColors.accentDark,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                Icon(
                                                  isExpanded
                                                      ? Icons
                                                            .keyboard_arrow_up_rounded
                                                      : Icons
                                                            .keyboard_arrow_down_rounded,
                                                  size: 16,
                                                  color: AppColors.accentDark,
                                                ),
                                              ],
                                            ),
                                          )
                                        else
                                          const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                'Riwayat Transaksi',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: AppColors.primary,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              Icon(
                                                Icons.chevron_right_rounded,
                                                size: 14,
                                                color: AppColors.primary,
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Nested Pockets (Kantong Anak per PRD 4.3)
                            if (hasChildren && isExpanded) ...[
                              const Divider(
                                height: 1,
                                color: AppColors.divider,
                                indent: 64,
                              ),
                              Container(
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFBFDFB),
                                  borderRadius: BorderRadius.vertical(
                                    bottom: Radius.circular(20),
                                  ),
                                ),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: children.length,
                                  separatorBuilder: (context, idx) =>
                                      const Divider(
                                        height: 1,
                                        indent: 64,
                                        color: AppColors.divider,
                                      ),
                                  itemBuilder: (context, cIdx) {
                                    final child = children[cIdx];
                                    return InkWell(
                                      onTap: () =>
                                          _openAccountDetail(context, child),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                        child: Row(
                                          children: [
                                            const SizedBox(width: 14),
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: const BoxDecoration(
                                                color: AppColors.accent,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    child.name,
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          AppColors.textPrimary,
                                                    ),
                                                  ),
                                                  Text(
                                                    child.accountNumber,
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      color:
                                                          AppColors.textMuted,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Text(
                                              isHidden
                                                  ? '••••••'
                                                  : CurrencyFormatter.formatRupiah(
                                                      child.balance,
                                                    ),
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            const Icon(
                                              Icons.chevron_right_rounded,
                                              size: 16,
                                              color: AppColors.textMuted,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ],

              const SizedBox(height: 20),

              // Button "+ Tambah Akun Baru"
              OutlinedButton.icon(
                onPressed: () => _showAddAccountModal(context),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('Tambah Akun atau Kantong Baru'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPillChip({
    required String id,
    required String label,
    required int count,
    required IconData icon,
  }) {
    final isSelected = _activeFilter == id;
    return GestureDetector(
      onTap: () => setState(() => _activeFilter = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              '$label ($count)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupPill(Household household, AppState state) {
    final isSelected = _activeFilter == household.id;
    final groupAccounts = state.accounts.where((a) {
      if (a.parentAccountId != null) return false;
      if (a.householdId != null) return a.householdId == household.id;
      return a.isShared && household.id == 'hh-1';
    }).length;

    return GestureDetector(
      onTap: () {
        setState(() => _activeFilter = household.id);
        state.switchHousehold(household.id);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(household.type.emoji, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 6),
            Text(
              '${household.name} ($groupAccounts)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
