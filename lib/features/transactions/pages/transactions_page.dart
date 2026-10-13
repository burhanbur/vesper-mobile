import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../models/transaction.dart';
import '../widgets/transaction_item_tile.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  String _selectedFilter = 'Semua'; // Semua, Pemasukan, Pengeluaran, Transfer
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearchVisible = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final allTransactions = state.transactions;

    // Filter by type
    final filtered = allTransactions.where((tx) {
      if (_selectedFilter == 'Pengeluaran' &&
          tx.type != TransactionType.expense) {
        return false;
      }
      if (_selectedFilter == 'Pemasukan' && tx.type != TransactionType.income) {
        return false;
      }
      if (_selectedFilter == 'Transfer' &&
          tx.type != TransactionType.transfer) {
        return false;
      }

      // Filter by search query
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchNote = (tx.note ?? '').toLowerCase().contains(q);
        final matchCategory = tx.categoryName.toLowerCase().contains(q);
        final matchActor = tx.createdByName.toLowerCase().contains(q);
        return matchNote || matchCategory || matchActor;
      }

      return true;
    }).toList();

    // Group transactions by date string (e.g. "26 Sep", "25 Sep", "24 Sep")
    final Map<String, List<TransactionItem>> groupedByDate = {};
    for (final tx in filtered) {
      final dateKey = DateFormatter.formatShort(tx.date);
      groupedByDate.putIfAbsent(dateKey, () => []).add(tx);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Transaksi'),
        actions: [
          IconButton(
            icon: Icon(
              _isSearchVisible
                  ? Icons.search_off_rounded
                  : Icons.search_rounded,
              color: AppColors.primary,
            ),
            onPressed: () {
              setState(() {
                _isSearchVisible = !_isSearchVisible;
                if (!_isSearchVisible) {
                  _searchController.clear();
                  _searchQuery = '';
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Optional Expandable Search Bar
          if (_isSearchVisible)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Cari transaksi, kategori, atau nama...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (val) {
                  setState(() => _searchQuery = val.trim());
                },
              ),
            ),

          // Filter Chips matching contoh-1.png & contoh-2.png
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip('Semua'),
                const SizedBox(width: 8),
                _buildFilterChip('Pemasukan'),
                const SizedBox(width: 8),
                _buildFilterChip('Pengeluaran'),
                const SizedBox(width: 8),
                _buildFilterChip('Transfer'),
              ],
            ),
          ),

          // Month Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormatter.formatMonthYear(DateTime.now()),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${filtered.length} Transaksi',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // Transactions List Grouped by Date (contoh-1.png & contoh-2.png)
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 56,
                          color: AppColors.textMuted.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Tidak ada transaksi yang sesuai.',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 6,
                    ),
                    itemCount: groupedByDate.keys.length,
                    itemBuilder: (context, groupIdx) {
                      final dateKey = groupedByDate.keys.elementAt(groupIdx);
                      final items = groupedByDate[dateKey]!;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Date Section Header (e.g. 26 Sep, 25 Sep)
                          Padding(
                            padding: const EdgeInsets.only(
                              top: 14,
                              bottom: 6,
                              left: 4,
                            ),
                            child: Text(
                              dateKey,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),

                          // Card container holding date items
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: items.length,
                              separatorBuilder: (context, idx) => const Divider(
                                height: 1,
                                color: AppColors.divider,
                                indent: 72,
                              ),
                              itemBuilder: (context, idx) {
                                return TransactionItemTile(
                                  transaction: items[idx],
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return ChoiceChip(
      label: Text(label),
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
            _selectedFilter = label;
          });
        }
      },
    );
  }
}
