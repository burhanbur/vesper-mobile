import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../accounts/widgets/account_picker_sheet.dart';
import '../models/investment.dart';

class InvestmentTradeModal {
  static void show(
    BuildContext context, {
    InvestmentAsset? preselectedAsset,
    InvestmentTradeType initialTradeType = InvestmentTradeType.buy,
  }) {
    final state = AppStateScope.of(context);
    final isOffline = state.isOfflineMode;

    if (isOffline) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.wifi_off_rounded, color: AppColors.warning),
              SizedBox(width: 8),
              Text('Koneksi Diperlukan', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: const Text(
            'Pencatatan transaksi investasi (Beli, Jual, Dividen) bersifat online-required untuk memastikan akurasi urutan transaksi & perhitungan average cost price.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Mengerti'),
            ),
          ],
        ),
      );
      return;
    }

    InvestmentTradeType selectedType = initialTradeType;
    InvestmentAsset selectedAsset = preselectedAsset ?? state.investments.first;
    final qtyController = TextEditingController();
    final priceController = TextEditingController(
      text: selectedAsset.currentPrice.toInt().toString(),
    );
    final feeController = TextEditingController(text: '0');
    final noteController = TextEditingController();
    String? selectedCashAccountId = state.selectableAccounts.isNotEmpty
        ? state.selectableAccounts.first.id
        : null;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          final qty = double.tryParse(qtyController.text) ?? 0.0;
          final price =
              double.tryParse(
                priceController.text.replaceAll(RegExp(r'[^0-9.]'), ''),
              ) ??
              0.0;
          final fee =
              int.tryParse(
                feeController.text.replaceAll(RegExp(r'[^0-9]'), ''),
              ) ??
              0;
          final totalEst = (qty * price).round() + fee;

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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Catat Transaksi Investasi',
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

                  const SizedBox(height: 12),

                  // Trade Type Selector: Beli, Jual, Dividen
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('BELI')),
                          selected: selectedType == InvestmentTradeType.buy,
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: selectedType == InvestmentTradeType.buy
                                ? Colors.white
                                : AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setModalState(
                                () => selectedType = InvestmentTradeType.buy,
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('JUAL')),
                          selected: selectedType == InvestmentTradeType.sell,
                          selectedColor: AppColors.expense,
                          labelStyle: TextStyle(
                            color: selectedType == InvestmentTradeType.sell
                                ? Colors.white
                                : AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setModalState(
                                () => selectedType = InvestmentTradeType.sell,
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('DIVIDEN')),
                          selected:
                              selectedType == InvestmentTradeType.dividend,
                          selectedColor: AppColors.income,
                          labelStyle: TextStyle(
                            color: selectedType == InvestmentTradeType.dividend
                                ? Colors.white
                                : AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setModalState(
                                () =>
                                    selectedType = InvestmentTradeType.dividend,
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Asset Dropdown
                  const Text(
                    'Pilih Instrumen',
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
                      child: DropdownButton<InvestmentAsset>(
                        value: selectedAsset,
                        isExpanded: true,
                        items: state.investments
                            .map(
                              (inv) => DropdownMenuItem(
                                value: inv,
                                child: Text('${inv.name} (${inv.symbol})'),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() {
                              selectedAsset = val;
                              priceController.text = val.currentPrice
                                  .toInt()
                                  .toString();
                            });
                          }
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Quantity & Price per unit
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Jumlah Unit / Lembar',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: qtyController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                hintText: 'Contoh: 10',
                              ),
                              onChanged: (_) => setModalState(() {}),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Harga per Unit (Rp)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: priceController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                hintText: 'Harga...',
                              ),
                              onChanged: (_) => setModalState(() {}),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Linked Cash Account (PRD 5.8)
                  AccountSelectorTile(
                    label: selectedType == InvestmentTradeType.buy
                        ? 'Akun Kas Sumber Dana (Uang Keluar)'
                        : 'Akun Kas Tujuan Dana (Uang Masuk)',
                    account: selectedCashAccountId != null
                        ? state.getAccountById(selectedCashAccountId!)
                        : null,
                    onTap: () async {
                      final picked = await AccountPickerSheet.show(
                        context,
                        title: selectedType == InvestmentTradeType.buy
                            ? 'Pilih Sumber Dana Kas'
                            : 'Pilih Rekening Tujuan Kas',
                        selectedAccountId: selectedCashAccountId,
                        accounts: state.selectableAccounts,
                      );
                      if (picked != null) {
                        setModalState(() => selectedCashAccountId = picked.id);
                      }
                    },
                  ),

                  const SizedBox(height: 14),

                  // Fee
                  const Text(
                    'Biaya Transaksi / Fee (Rp)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: feeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'Contoh: 10000',
                    ),
                    onChanged: (_) => setModalState(() {}),
                  ),

                  const SizedBox(height: 14),

                  // Summary Box
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Estimasi Nilai:',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          CurrencyFormatter.formatRupiah(totalEst),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: () {
                      if (qty <= 0 || price <= 0) return;

                      state.recordInvestmentTrade(
                        assetId: selectedAsset.id,
                        tradeType: selectedType,
                        quantity: qty,
                        pricePerUnit: price,
                        fee: fee,
                        cashAccountId: selectedCashAccountId,
                        note: noteController.text.trim().isEmpty
                            ? null
                            : noteController.text.trim(),
                      );

                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: AppColors.primary,
                          content: Text(
                            'Transaksi ${selectedType.name.toUpperCase()} ${selectedAsset.name} berhasil dicatat!',
                          ),
                        ),
                      );
                    },
                    child: Text(
                      'Simpan Transaksi ${selectedType.name.toUpperCase()}',
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
}
