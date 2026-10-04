import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../models/transaction.dart';

class AddTransactionModal extends StatefulWidget {
  final TransactionType initialType;

  const AddTransactionModal({
    super.key,
    this.initialType = TransactionType.expense,
  });

  static Future<void> show(
    BuildContext context, {
    TransactionType initialType = TransactionType.expense,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddTransactionModal(initialType: initialType),
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

  // Utang / Piutang Shortcut toggle per PRD 4.5
  bool _isDebtShortcut = false;
  bool _isDebtPayable = true; // true: Gw ngutang, false: Gw ngutangin

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
    if (_selectedType == TransactionType.income) {
      _selectedCategory = 'Gaji';
    } else if (_selectedType == TransactionType.transfer) {
      _selectedCategory = 'Transfer Antar Akun';
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

  void _submit() {
    final state = AppStateScope.of(context);
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

    if (_isDebtShortcut) {
      // Shortcut "Catat Utang / Piutang" per PRD 4.5:
      // "Gw ngutang" -> transfer(from=Kas/Dompet, to=Hutang / Kas Masuk)
      state.addTransaction(
        type: TransactionType.transfer,
        amount: amount,
        accountId: accountId,
        toAccountId: _selectedToAccountId ?? state.selectableAccounts.last.id,
        categoryName: _isDebtPayable ? 'Catat Utang (Kewajiban)' : 'Catat Piutang',
        note: _noteController.text.trim().isNotEmpty
            ? _noteController.text.trim()
            : (_isDebtPayable ? 'Pinjaman / Utang' : 'Piutang ke pihak lain'),
        date: _selectedDate,
        isDebt: _isDebtPayable,
        isReceivable: !_isDebtPayable,
      );
    } else if (_selectedType == TransactionType.transfer) {
      final toAccountId = _selectedToAccountId ??
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
          state.isOfflineMode
              ? 'Transaksi tersimpan lokal ke SQLite (antre sinkronisasi saat online)'
              : 'Transaksi berhasil disimpan!',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final selectableAccounts = state.selectableAccounts;

    _selectedAccountId ??= selectableAccounts.isNotEmpty ? selectableAccounts.first.id : null;
    if (_selectedType == TransactionType.transfer && _selectedToAccountId == null) {
      _selectedToAccountId = selectableAccounts.length > 1 ? selectableAccounts[1].id : null;
    }

    // PRD 4.4 Rule: Categories switch according to selected account's owner!
    final isIncome = _selectedType == TransactionType.income;
    final currentCategories = state.getCategoriesForAccount(
      _selectedAccountId ?? selectableAccounts.first.id,
      isIncome: isIncome,
    );

    if (!currentCategories.contains(_selectedCategory) && currentCategories.isNotEmpty) {
      _selectedCategory = currentCategories.first;
    }

    final selectedAcc = state.getAccountById(_selectedAccountId ?? '');
    final isOtherMemberAccount = selectedAcc != null && selectedAcc.ownerUserId != state.currentUserId;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
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
                const Text(
                  'Tambah Transaksi',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Segmented Type Selector (Pengeluaran, Pemasukan, Transfer)
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
            ),

            // Shortcut Catat Utang / Piutang per PRD 4.5
            if (_selectedType == TransactionType.transfer) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.accentLight.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.handshake_outlined, size: 16, color: AppColors.accentDark),
                        const SizedBox(width: 8),
                        Text(
                          _isDebtShortcut ? 'Mode Catat Utang / Piutang' : 'Shortcut Utang / Piutang',
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
                      onChanged: (val) => setState(() => _isDebtShortcut = val),
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
                        label: const Center(child: Text('Gw Ngutang (Kewajiban)')),
                        selected: _isDebtPayable,
                        selectedColor: AppColors.warning,
                        labelStyle: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _isDebtPayable ? Colors.white : AppColors.textPrimary,
                        ),
                        onSelected: (val) {
                          if (val) setState(() => _isDebtPayable = true);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Gw Ngutangin (Piutang)')),
                        selected: !_isDebtPayable,
                        selectedColor: AppColors.income,
                        labelStyle: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: !_isDebtPayable ? Colors.white : AppColors.textPrimary,
                        ),
                        onSelected: (val) {
                          if (val) setState(() => _isDebtPayable = false);
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
            Text(
              _selectedType == TransactionType.transfer ? 'Dari Akun Asal' : 'Pilih Akun',
              style: const TextStyle(
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
                  value: _selectedAccountId,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  items: selectableAccounts.map((acc) {
                    final isPocket = acc.parentAccountId != null;
                    return DropdownMenuItem<String>(
                      value: acc.id,
                      child: Text(
                        '${isPocket ? "  ↳ " : ""}${acc.name} (${CurrencyFormatter.formatCompact(acc.balance)})',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isPocket ? FontWeight.w600 : FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedAccountId = val;
                    });
                  },
                ),
              ),
            ),

            // If Transfer: Ke Akun Tujuan
            if (_selectedType == TransactionType.transfer) ...[
              const SizedBox(height: 14),
              const Text(
                'Ke Akun Tujuan',
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
                    value: _selectedToAccountId,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    items: selectableAccounts.map((acc) {
                      final isPocket = acc.parentAccountId != null;
                      return DropdownMenuItem<String>(
                        value: acc.id,
                        child: Text(
                          '${isPocket ? "  ↳ " : ""}${acc.name} (${CurrencyFormatter.formatCompact(acc.balance)})',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isPocket ? FontWeight.w600 : FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedToAccountId = val;
                      });
                    },
                  ),
                ),
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
                children: currentCategories.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                    onSelected: (val) {
                      if (val) {
                        setState(() {
                          _selectedCategory = cat;
                        });
                      }
                    },
                  );
                }).toList(),
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
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
                                DateFormatter.formatShort(_selectedDate),
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
                prefixIcon: Icon(Icons.edit_note_rounded, color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Simpan Transaksi',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
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
