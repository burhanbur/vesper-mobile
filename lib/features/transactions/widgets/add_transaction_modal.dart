import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../accounts/widgets/account_picker_sheet.dart';
import '../../categories/models/category.dart';
import '../models/transaction.dart';

class AddTransactionModal extends StatefulWidget {
  final TransactionType initialType;
  final String? initialAccountId;
  final TransactionItem? transactionToEdit;

  const AddTransactionModal({
    super.key,
    this.initialType = TransactionType.expense,
    this.initialAccountId,
    this.transactionToEdit,
  });

  static Future<void> show(
    BuildContext context, {
    TransactionType initialType = TransactionType.expense,
    String? initialAccountId,
    TransactionItem? transactionToEdit,
  }) {
    final cached = transactionToEdit == null
        ? null
        : AppStateScope.of(context).repository
              ?.row('transactions', transactionToEdit.id);
    if (cached != null &&
        cached.containsKey('category_id') &&
        cached['category_id'] == null &&
        transactionToEdit?.type != TransactionType.transfer &&
        transactionToEdit?.transferId == null) {
      return showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Transaksi turunan tidak dapat diubah'),
          content: const SingleChildScrollView(
            child: Text(
              'Transaksi kas ini dikelola oleh modul asalnya dan tidak dapat diubah atau dihapus secara langsung.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Mengerti'),
            ),
          ],
        ),
      );
    }
    if (transactionToEdit?.type == TransactionType.transfer ||
        transactionToEdit?.transferId != null) {
      return showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Transfer tidak dapat diubah'),
          content: const Text(
            'Transfer yang sudah dicatat tidak dapat diubah atau dihapus. Tidak ada transaksi yang dibuat.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Mengerti'),
            ),
          ],
        ),
      );
    }
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddTransactionModal(
        initialType: initialType,
        initialAccountId: initialAccountId,
        transactionToEdit: transactionToEdit,
      ),
    );
  }

  @override
  State<AddTransactionModal> createState() => _AddTransactionModalState();
}

class _AddTransactionModalState extends State<AddTransactionModal> {
  late TransactionType _selectedType;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  String? _selectedAccountId;
  String? _selectedToAccountId;
  String _selectedCategory = 'Makanan & Minuman';
  DateTime _selectedDate = DateTime.now();

  bool get _isEditing => widget.transactionToEdit != null;

  // Utang / Piutang Shortcut toggle per PRD 4.5
  bool _isDebtShortcut = false;
  bool _isDebtPayable = true; // true: Gw ngutang, false: Gw ngutangin
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final toEdit = widget.transactionToEdit;
    if (toEdit != null) {
      _selectedType = toEdit.type;
      _selectedAccountId = toEdit.accountId;
      _selectedToAccountId = toEdit.toAccountId;
      _selectedCategory = toEdit.categoryName;
      _selectedDate = toEdit.date;
      _noteController.text = toEdit.note ?? '';
      _amountController.text = CurrencyFormatter.formatRupiah(toEdit.amount);
    } else {
      _selectedType = widget.initialType;
      _selectedAccountId = widget.initialAccountId;
      if (_selectedType == TransactionType.income) {
        _selectedCategory = 'Gaji';
      } else if (_selectedType == TransactionType.transfer) {
        _selectedCategory = 'Transfer Antar Akun';
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onAmountChanged(String val) {
    final parsed = CurrencyFormatter.parseRupiah(val);
    if (parsed == 0) {
      _amountController.value = const TextEditingValue(text: '');
      return;
    }
    final formatted = CurrencyFormatter.formatRupiah(parsed);
    _amountController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  Future<void> _submit() async {
    if (_isSaving) return;

    final state = AppStateScope.of(context);
    final availableIds = state.selectableAccounts.map((a) => a.id).toSet();
    if (!availableIds.contains(_selectedAccountId) ||
        (_selectedType == TransactionType.transfer &&
            !availableIds.contains(_selectedToAccountId))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih akun yang tersedia.')),
      );
      return;
    }

    final amount = CurrencyFormatter.parseRupiah(_amountController.text);
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.expense,
          content: Text('Nominal harus lebih dari Rp 0'),
        ),
      );
      return;
    }

    final accountId = _selectedAccountId ?? state.selectableAccounts.first.id;
    if (_selectedType == TransactionType.transfer) {
      final toAccountId =
          _selectedToAccountId ??
          (state.selectableAccounts.length > 1
              ? state.selectableAccounts[1].id
              : state.selectableAccounts.first.id);

      if (accountId == toAccountId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.expense,
            content: Text('Akun asal dan akun tujuan transfer harus berbeda!'),
          ),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      _saveTransaction(amount: amount, accountId: accountId);
    } on ApiFailure catch (error) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.expense,
            content: Text('Gagal menyimpan transaksi: $e'),
          ),
        );
      }
    }
  }

  void _saveTransaction({required int amount, required String accountId}) {
    final state = AppStateScope.of(context);

    if (_isEditing) {
      state.updateTransaction(
        id: widget.transactionToEdit!.id,
        type: _selectedType,
        amount: amount,
        accountId: accountId,
        categoryName: _selectedCategory,
        note: _noteController.text.trim(),
        date: _selectedDate,
      );
    } else if (_isDebtShortcut) {
      // Shortcut "Catat Utang / Piutang" per PRD 4.5:
      // "Gw ngutang" -> transfer(from=Kas/Dompet, to=Hutang / Kas Masuk)
      state.addTransaction(
        type: TransactionType.transfer,
        amount: amount,
        accountId: accountId,
        toAccountId: _selectedToAccountId ?? state.selectableAccounts.last.id,
        categoryName: _isDebtPayable
            ? 'Catat Utang (Kewajiban)'
            : 'Catat Piutang',
        note: _noteController.text.trim().isNotEmpty
            ? _noteController.text.trim()
            : (_isDebtPayable ? 'Pinjaman / Utang' : 'Piutang ke pihak lain'),
        date: _selectedDate,
        isDebt: _isDebtPayable,
        isReceivable: !_isDebtPayable,
      );
    } else if (_selectedType == TransactionType.transfer) {
      final toAccountId =
          _selectedToAccountId ??
          (state.selectableAccounts.length > 1
              ? state.selectableAccounts[1].id
              : state.selectableAccounts.first.id);

      state.addTransaction(
        type: TransactionType.transfer,
        amount: amount,
        accountId: accountId,
        toAccountId: toAccountId,
        categoryName: 'Transfer Antar Akun',
        note: _noteController.text.trim().isNotEmpty
            ? _noteController.text.trim()
            : 'Transfer antar akun',
        date: _selectedDate,
      );
    } else {
      state.addTransaction(
        type: _selectedType,
        amount: amount,
        accountId: accountId,
        categoryName: _selectedCategory,
        note: _noteController.text.trim(),
        date: _selectedDate,
      );
    }

    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primary,
        content: Text(
          _isEditing
              ? 'Perubahan transaksi berhasil disimpan!'
              : (state.isOfflineMode
                    ? 'Transaksi tersimpan lokal ke SQLite (antre sinkronisasi saat online)'
                    : 'Transaksi berhasil disimpan!'),
        ),
      ),
    );
  }

  void _showQuickAddCategoryDialog(
    BuildContext context,
    AppState state,
    bool isIncome,
  ) {
    final textController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(
          isIncome
              ? 'Tambah Kategori Pemasukan'
              : 'Tambah Kategori Pengeluaran',
        ),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Nama kategori baru...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = textController.text.trim();
              if (name.isNotEmpty) {
                state.addCategory(
                  name: name,
                  type: isIncome ? CategoryType.income : CategoryType.expense,
                  icon: isIncome
                      ? Icons.account_balance_wallet_rounded
                      : Icons.shopping_bag_rounded,
                  color: isIncome ? AppColors.income : AppColors.expense,
                );
                setState(() => _selectedCategory = name);
                Navigator.of(dialogCtx).pop();
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final selectableAccounts = state.selectableAccounts;

    _selectedAccountId ??= selectableAccounts.isNotEmpty
        ? selectableAccounts.first.id
        : null;
    if (_selectedType == TransactionType.transfer &&
        _selectedToAccountId == null) {
      _selectedToAccountId = selectableAccounts
          .where((account) => account.id != _selectedAccountId)
          .firstOrNull
          ?.id;
    }

    // PRD 4.4 Rule: Categories switch according to selected account's owner!
    final isIncome = _selectedType == TransactionType.income;
    final currentCategories = state.getCategoriesForAccount(
      _selectedAccountId ?? '',
      isIncome: isIncome,
    );

    if (!currentCategories.contains(_selectedCategory) &&
        currentCategories.isNotEmpty) {
      _selectedCategory = currentCategories.first;
    }

    final selectedAcc = state.getAccountById(_selectedAccountId ?? '');
    final isOtherMemberAccount =
        selectedAcc != null && selectedAcc.ownerUserId != state.currentUserId;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      margin: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top drag handle
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

                    // Header & Close Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _isEditing ? 'Ubah Transaksi' : 'Tambah Transaksi',
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
                          onPressed: _isSaving
                              ? null
                              : () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Segmented Type Selector (Pengeluaran, Pemasukan, Transfer)
                    // If editing, we allow switching between expense and income, but not transfer
                    if (!_isEditing)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildTypeButton(
                                type: TransactionType.expense,
                                label: 'Pengeluaran',
                                activeColor: AppColors.expense,
                              ),
                            ),
                            Expanded(
                              child: _buildTypeButton(
                                type: TransactionType.income,
                                label: 'Pemasukan',
                                activeColor: AppColors.income,
                              ),
                            ),
                            Expanded(
                              child: _buildTypeButton(
                                type: TransactionType.transfer,
                                label: 'Transfer',
                                activeColor: AppColors.transfer,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildTypeButton(
                                type: TransactionType.expense,
                                label: 'Pengeluaran',
                                activeColor: AppColors.expense,
                              ),
                            ),
                            Expanded(
                              child: _buildTypeButton(
                                type: TransactionType.income,
                                label: 'Pemasukan',
                                activeColor: AppColors.income,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Shortcut Catat Utang / Piutang per PRD 4.5
                    if (_selectedType == TransactionType.transfer) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accentLight.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.handshake_outlined,
                                  size: 16,
                                  color: AppColors.accentDark,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _isDebtShortcut
                                      ? 'Mode Catat Utang / Piutang'
                                      : 'Shortcut Utang / Piutang',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.accentDark,
                                  ),
                                ),
                              ],
                            ),
                            Switch(
                              value: _isDebtShortcut,
                              activeThumbColor: AppColors.primary,
                              onChanged: (val) =>
                                  setState(() => _isDebtShortcut = val),
                            ),
                          ],
                        ),
                      ),
                      if (_isDebtShortcut) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ChoiceChip(
                                label: const Center(
                                  child: Text('Gw Ngutang (Kewajiban)'),
                                ),
                                selected: _isDebtPayable,
                                selectedColor: AppColors.warning,
                                labelStyle: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _isDebtPayable
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                ),
                                onSelected: (val) {
                                  if (val) {
                                    setState(() => _isDebtPayable = true);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ChoiceChip(
                                label: const Center(
                                  child: Text('Gw Ngutangin (Piutang)'),
                                ),
                                selected: !_isDebtPayable,
                                selectedColor: AppColors.income,
                                labelStyle: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: !_isDebtPayable
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                ),
                                onSelected: (val) {
                                  if (val) {
                                    setState(() => _isDebtPayable = false);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],

                    const SizedBox(height: 18),

                    // Nominal Input
                    const Text(
                      'Nominal',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Rp 0',
                        prefixIcon: Icon(
                          Icons.payments_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      onChanged: _onAmountChanged,
                    ),
                    const SizedBox(height: 16),

                    // Akun Selector (Supporting pockets)
                    AccountSelectorTile(
                      label: _selectedType == TransactionType.transfer
                          ? 'Dari Akun Asal'
                          : 'Pilih Akun',
                      account: selectedAcc,
                      onTap: () async {
                        final picked = await AccountPickerSheet.show(
                          context,
                          title: _selectedType == TransactionType.transfer
                              ? 'Pilih Akun Asal'
                              : 'Pilih Akun',
                          selectedAccountId: _selectedAccountId,
                          accounts: selectableAccounts,
                        );
                        if (mounted && picked != null) {
                          setState(() {
                            _selectedAccountId = picked.id;
                          });
                        }
                      },
                    ),

                    // If Transfer: Ke Akun Tujuan
                    if (_selectedType == TransactionType.transfer) ...[
                      const SizedBox(height: 14),
                      Builder(
                        builder: (context) {
                          final selectedToAcc = state.getAccountById(
                            _selectedToAccountId ?? '',
                          );
                          return AccountSelectorTile(
                            label: 'Ke Akun Tujuan',
                            account: selectedToAcc,
                            onTap: () async {
                              final picked = await AccountPickerSheet.show(
                                context,
                                title: 'Pilih Akun Tujuan',
                                selectedAccountId: _selectedToAccountId,
                                accounts: selectableAccounts
                                    .where((a) => a.id != _selectedAccountId)
                                    .toList(),
                              );
                              if (mounted && picked != null) {
                                setState(() {
                                  _selectedToAccountId = picked.id;
                                });
                              }
                            },
                          );
                        },
                      ),
                    ],

                    // Categories (PRD 4.4: Show owner name if account owned by another member!)
                    if (_selectedType != TransactionType.transfer) ...[
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Kategori',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          if (isOtherMemberAccount)
                            Text(
                              '(Kategori milik ${selectedAcc.ownerName})',
                              style: const TextStyle(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: AppColors.accentDark,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ...currentCategories.map((cat) {
                            final isSelected = _selectedCategory == cat;
                            final categoryObj = state.getCategoryByName(cat);
                            return ChoiceChip(
                              avatar: categoryObj != null
                                  ? Icon(
                                      categoryObj.icon,
                                      size: 15,
                                      color: isSelected
                                          ? Colors.white
                                          : categoryObj.color,
                                    )
                                  : null,
                              label: Text(cat),
                              selected: isSelected,
                              selectedColor: AppColors.primary,
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textPrimary,
                              ),
                              onSelected: (val) {
                                if (val) {
                                  setState(() {
                                    _selectedCategory = cat;
                                  });
                                }
                              },
                            );
                          }),
                          ActionChip(
                            avatar: const Icon(
                              Icons.add_rounded,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            label: const Text('Tambah Kategori'),
                            labelStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                            side: const BorderSide(color: AppColors.border),
                            backgroundColor: AppColors.surfaceVariant,
                            onPressed: () => _showQuickAddCategoryDialog(
                              context,
                              state,
                              isIncome,
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Tanggal
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Tanggal',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _selectedDate,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2030),
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      _selectedDate = picked;
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceVariant,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_today_rounded,
                                        size: 16,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        DateFormatter.formatShort(
                                          _selectedDate,
                                        ),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
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
                    const SizedBox(height: 14),

                    // Catatan
                    const Text(
                      'Catatan (opsional)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _noteController,
                      decoration: const InputDecoration(
                        hintText: 'Contoh: Nasi Padang, Belanja Mingguan',
                        prefixIcon: Icon(
                          Icons.edit_note_rounded,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: ElevatedButton(
                key: const ValueKey('transaction_save_button'),
                onPressed: _isSaving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSaving
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Menyimpan...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        _isEditing ? 'Simpan Perubahan' : 'Simpan Transaksi',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeButton({
    required TransactionType type,
    required String label,
    required Color activeColor,
  }) {
    final isSelected = _selectedType == type;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedType = type;
          if (type == TransactionType.income) {
            _selectedCategory = 'Gaji';
          } else if (type == TransactionType.expense) {
            _selectedCategory = 'Makanan & Minuman';
          } else {
            _selectedCategory = 'Transfer Antar Akun';
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? activeColor : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
