import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/transaction_period.dart';
import '../../../core/widgets/month_selector.dart';
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
  TransactionPeriod _period = TransactionPeriod(DateTime.now());

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final allTransactions = _period.filter(state.transactions);

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

    filtered.sort((a, b) => b.date.compareTo(a.date));
    // Each header and transaction is a separate lazy row, not a nested list.
    final rows = <Object>[];
    DateTime? previousDay;
    for (final tx in filtered) {
      final local = tx.date.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      if (day != previousDay) rows.add(day);
      rows.add(tx);
      previousDay = day;
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

          MonthSelector(
            period: _period,
            onChanged: (period) => setState(() => _period = period),
          ),
          // Month Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Transaksi lokal pada periode ini',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
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
                    itemCount: rows.length,
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      if (row is DateTime) {
                        return Padding(
                          padding: const EdgeInsets.only(
                            top: 14,
                            bottom: 6,
                            left: 4,
                          ),
                          child: Text(
                            DateFormatter.formatShort(row),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        );
                      }
                      final tx = row as TransactionItem;
                      return Material(
                        key: ValueKey(tx.id),
                        color: Colors.white,
                        child: TransactionItemTile(transaction: tx),
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
