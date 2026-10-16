import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/transaction_period.dart';
import '../../../core/widgets/month_selector.dart';
import '../../../database/transaction_query.dart';
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
  final List<TransactionCursor?> _pages = [null];
  int _page = 0;
  String? _scope;
  int? _revision;
  void _resetPages() {
    _pages
      ..clear()
      ..add(null);
    _page = 0;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    if (_scope != state.localDataScope ||
        _revision != state.localDataRevision) {
      _scope = state.localDataScope;
      _revision = state.localDataRevision;
      _resetPages();
    }
    final page = state.transactionPage(
      TransactionQuery(
        start: _period.start,
        end: _period.end,
        after: _pages[_page],
        type: switch (_selectedFilter) {
          'Pengeluaran' => 'EXPENSE',
          'Pemasukan' => 'INCOME',
          'Transfer' => 'TRANSFER',
          _ => null,
        },
        search: _searchQuery,
        actorId: state.currentUserId,
        actorName: state.userName,
      ),
    );
    final filtered = page.items;
    final periodTransactions = state.transactionsInPeriod(
      _period.start,
      _period.end,
    );
    final periodIncome = _period.total(
      periodTransactions,
      TransactionType.income,
    );
    final periodExpense = _period.total(
      periodTransactions,
      TransactionType.expense,
    );
    final isHidden = state.isBalanceHidden;

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
            tooltip: _isSearchVisible ? 'Tutup pencarian' : 'Cari transaksi',
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
                  _resetPages();
                }
              });
            },
          ),
        ],
      ),
      body: CustomScrollView(
        key: ValueKey((
          _scope,
          _revision,
          _page,
          _selectedFilter,
          _searchQuery,
          _period.start,
        )),
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                // Optional Expandable Search Bar
                if (_isSearchVisible)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 4,
                    ),
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Cari transaksi, kategori, atau nama...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                tooltip: 'Hapus pencarian',
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                    _resetPages();
                                  });
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val.trim();
                          _resetPages();
                        });
                      },
                    ),
                  ),

                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
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

                // Month Selector & Monthly Summary Card
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 6,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.border.withValues(alpha: 0.6),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Column(
                      children: [
                        MonthSelector(
                          period: _period,
                          onChanged: (period) => setState(() {
                            _period = period;
                            _resetPages();
                          }),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Divider(
                            height: 16,
                            thickness: 1,
                            color: AppColors.border.withValues(alpha: 0.5),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildPeriodStat(
                                  title: 'Pemasukan',
                                  amount: periodIncome,
                                  icon: Icons.arrow_downward_rounded,
                                  color: AppColors.income,
                                  bgLight: AppColors.incomeLight,
                                  isIncome: true,
                                  isHidden: isHidden,
                                ),
                              ),
                              Container(
                                height: 32,
                                width: 1,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                color: AppColors.border.withValues(alpha: 0.6),
                              ),
                              Expanded(
                                child: _buildPeriodStat(
                                  title: 'Pengeluaran',
                                  amount: periodExpense,
                                  icon: Icons.arrow_upward_rounded,
                                  color: AppColors.expense,
                                  bgLight: AppColors.expenseLight,
                                  isIncome: false,
                                  isHidden: isHidden,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Transaction count & title row
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      const Text(
                        'Daftar Transaksi',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${filtered.length} Transaksi',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 2),
              ],
            ),
          ),

          // Transactions List Grouped by Date
          if (filtered.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 40,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(
                          color: AppColors.surfaceVariant,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.receipt_long_outlined,
                          size: 36,
                          color: AppColors.textMuted.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Belum Ada Transaksi',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Tidak ada transaksi pada filter dan periode ini.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              sliver: SliverList.builder(
                itemCount: rows.length,
                itemBuilder: (context, index) {
                  final row = rows[index];
                  if (row is DateTime) {
                    return Padding(
                      padding: const EdgeInsets.only(
                        top: 14,
                        bottom: 8,
                        left: 2,
                        right: 2,
                      ),
                      child: Row(
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.calendar_today_rounded,
                                    size: 13,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      DateFormatter.formatShort(row),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  final tx = row as TransactionItem;
                  return Container(
                    key: ValueKey(tx.id),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.border.withValues(alpha: 0.6),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: TransactionItemTile(
                      transaction: tx,
                      showDate: false,
                    ),
                  );
                },
              ),
            ),
          SliverToBoxAdapter(
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.border.withValues(alpha: 0.6),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Halaman transaksi sebelumnya',
                        icon: const Icon(Icons.chevron_left_rounded),
                        onPressed: _page == 0
                            ? null
                            : () => setState(() => _page--),
                      ),
                      Expanded(
                        child: Text(
                          'Halaman ${_page + 1} · ${filtered.length} ditampilkan',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Halaman transaksi berikutnya',
                        icon: const Icon(Icons.chevron_right_rounded),
                        onPressed: page.next == null
                            ? null
                            : () => setState(() {
                                if (_pages.length > _page + 1) {
                                  _pages.removeRange(_page + 1, _pages.length);
                                }
                                _pages.add(page.next);
                                _page++;
                              }),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodStat({
    required String title,
    required int amount,
    required IconData icon,
    required Color color,
    required Color bgLight,
    required bool isIncome,
    required bool isHidden,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: bgLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isHidden
                    ? '••••••'
                    : CurrencyFormatter.formatRupiah(
                        amount,
                        withSign: true,
                        isIncome: isIncome,
                        isExpense: !isIncome,
                      ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return ChoiceChip(
      showCheckmark: false,
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: isSelected
            ? AppColors.primary
            : AppColors.border.withValues(alpha: 0.7),
        width: 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      labelStyle: TextStyle(
        fontSize: 12.5,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
        color: isSelected ? Colors.white : AppColors.textSecondary,
      ),
      onSelected: (val) {
        if (val) {
          setState(() {
            _selectedFilter = label;
            _resetPages();
          });
        }
      },
    );
  }
}
