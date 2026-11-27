import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/transaction_period.dart';
import '../../../core/utils/app_time_zone.dart';
import '../../../core/widgets/month_selector.dart';
import '../../../database/transaction_query.dart';
import '../../accounts/models/account.dart';
import '../../categories/models/category.dart';
import '../models/transaction.dart';
import '../widgets/transaction_item_tile.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  String _selectedFilter = 'Semua'; // Semua, Pemasukan, Pengeluaran, Transfer
  String? _selectedCategoryId;
  String? _selectedAccountId;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearchVisible = false;
  bool _searchAllPeriods = false;
  TransactionPeriod _period = TransactionPeriod(DateTime.now());
  AppTimeZone? _timeZone;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final zone = AppStateScope.of(context).timeZone;
    if (_timeZone == null) {
      _period = TransactionPeriod(zone.at(DateTime.now()), timeZone: zone);
    } else {
      _period = _period.withTimeZone(zone);
    }
    _timeZone = zone;
  }

  final List<TransactionCursor?> _pages = [null];
  int _page = 0;
  String? _scope;
  int? _revision;
  DateTime? _queryStart, _queryEnd;
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

  void _openAccountFilterSheet(
    BuildContext context,
    List<Account> accounts,
    String? activeAccountId,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        top: false,
        child: Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
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
                      'Filter Akun',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const Divider(height: 12, color: AppColors.divider),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                        ),
                        leading: const Icon(
                          Icons.layers_outlined,
                          color: AppColors.primary,
                        ),
                        title: const Text(
                          'Semua Akun',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        trailing: activeAccountId == null
                            ? const Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.primary,
                              )
                            : null,
                        onTap: () {
                          setState(() {
                            _selectedAccountId = null;
                            _resetPages();
                          });
                          Navigator.of(ctx).pop();
                        },
                      ),
                      for (final acc in accounts)
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                          ),
                          leading: const Icon(
                            Icons.account_balance_wallet_outlined,
                            color: AppColors.textSecondary,
                          ),
                          title: Text(
                            AppStateScope.of(context).accountDisplayName(acc),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            acc.institution,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                          trailing: activeAccountId == acc.id
                              ? const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.primary,
                                )
                              : null,
                          onTap: () {
                            setState(() {
                              _selectedAccountId = acc.id;
                              _resetPages();
                            });
                            Navigator.of(ctx).pop();
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    if (_scope != state.localDataScope ||
        _revision != state.localDataRevision ||
        _queryStart != _period.start ||
        _queryEnd != _period.end) {
      _scope = state.localDataScope;
      _revision = state.localDataRevision;
      _queryStart = _period.start;
      _queryEnd = _period.end;
      _resetPages();
    }
    final categoryOptions = switch (_selectedFilter) {
      'Pemasukan' => state.incomeCategories,
      'Pengeluaran' => state.expenseCategories,
      'Transfer' => const <Category>[],
      _ => state.categories,
    };
    final activeCategoryId =
        categoryOptions.any((c) => c.id == _selectedCategoryId)
        ? _selectedCategoryId
        : null;
    final accountOptions = state.accounts;
    final activeAccountId =
        accountOptions.any((a) => a.id == _selectedAccountId)
        ? _selectedAccountId
        : null;
    final activeAccount = activeAccountId == null
        ? null
        : accountOptions.where((a) => a.id == activeAccountId).firstOrNull;
    final page = state.transactionPage(
      TransactionQuery(
        start: _searchAllPeriods ? null : _period.start,
        end: _searchAllPeriods ? null : _period.end,
        accountId: activeAccountId,
        after: _pages[_page],
        type: switch (_selectedFilter) {
          'Pengeluaran' => 'EXPENSE',
          'Pemasukan' => 'INCOME',
          'Transfer' => 'TRANSFER',
          _ => null,
        },
        categoryId: activeCategoryId,
        search: _searchQuery,
        actorId: state.currentUserId,
        actorName: state.userName,
      ),
    );
    final filtered = page.items;
    final summary = state.periodSummary(
      _period.start,
      _period.end,
      accountId: activeAccountId,
    );
    final periodIncome = summary.income;
    final periodExpense = summary.expense;
    final isHidden = state.isBalanceHidden;
    final periodNet = periodIncome - periodExpense;
    final netColor = periodNet < 0
        ? AppColors.expense
        : periodNet > 0
        ? AppColors.income
        : AppColors.textSecondary;

    // Each header and transaction is a separate lazy row, not a nested list.
    final rows = <Object>[];
    DateTime? previousDay;
    for (final tx in filtered) {
      final local = state.timeZone.at(tx.date);
      final day = DateTime.utc(local.year, local.month, local.day);
      if (day != previousDay) rows.add(day);
      rows.add(tx);
      previousDay = day;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Transaksi'),
        actions: [
          if (accountOptions.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: GestureDetector(
                  key: const ValueKey('transaction_account_filter'),
                  onTap: () => _openAccountFilterSheet(
                    context,
                    accountOptions,
                    activeAccountId,
                  ),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: activeAccount != null
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: activeAccount != null
                            ? AppColors.primary
                            : AppColors.border.withValues(alpha: 0.7),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 13,
                          color: activeAccount != null
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            activeAccount?.name ?? 'Semua Akun',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: activeAccount != null
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: activeAccount != null
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 1),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 15,
                          color: activeAccount != null
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
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
                  _searchAllPeriods = false;
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
          activeCategoryId,
          activeAccountId,
          _searchQuery,
          _searchAllPeriods,
          _period.start,
        )),
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                // Optional Expandable Search Bar + Cross-Month Scope Toggle
                if (_isSearchVisible)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 4,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _searchController,
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: 'Cari transaksi, kategori, atau nama...',
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              size: 20,
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    tooltip: 'Hapus pencarian',
                                    icon: const Icon(
                                      Icons.clear_rounded,
                                      size: 18,
                                    ),
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
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildScopePill(
                              label: 'Bulan ini',
                              selected: !_searchAllPeriods,
                              onTap: () => setState(() {
                                _searchAllPeriods = false;
                                _resetPages();
                              }),
                            ),
                            const SizedBox(width: 8),
                            _buildScopePill(
                              label: 'Semua periode',
                              selected: _searchAllPeriods,
                              onTap: () => setState(() {
                                _searchAllPeriods = true;
                                _resetPages();
                              }),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                // Type Filter Chips
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

                // Category Filter Chips
                if (_selectedFilter != 'Transfer' && categoryOptions.isNotEmpty)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(
                      left: 20,
                      right: 20,
                      bottom: 6,
                    ),
                    child: Row(
                      children: [
                        _buildCategoryChip(
                          label: 'Semua Kategori',
                          isSelected: activeCategoryId == null,
                          onSelected: () {
                            setState(() {
                              _selectedCategoryId = null;
                              _resetPages();
                            });
                          },
                        ),
                        for (final cat in categoryOptions) ...[
                          const SizedBox(width: 8),
                          _buildCategoryChip(
                            label: cat.name,
                            icon: cat.icon,
                            isSelected: activeCategoryId == cat.id,
                            onSelected: () {
                              setState(() {
                                _selectedCategoryId = activeCategoryId == cat.id
                                    ? null
                                    : cat.id;
                                _resetPages();
                              });
                            },
                          ),
                        ],
                      ],
                    ),
                  ),

                // Month Selector & Monthly Summary Card (or All-Periods Banner)
                if (_searchAllPeriods)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 6,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.history_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Menampilkan transaksi lintas semua periode',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () => setState(() {
                              _searchAllPeriods = false;
                              _resetPages();
                            }),
                            child: const Text(
                              'Bulan ini',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
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
                        Container(
                          key: const ValueKey('transaction_period_net'),
                          width: double.infinity,
                          margin: const EdgeInsets.fromLTRB(6, 10, 6, 2),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isHidden || periodNet == 0
                                ? AppColors.surfaceVariant
                                : periodNet < 0
                                ? AppColors.expenseLight
                                : AppColors.incomeLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 12,
                            runSpacing: 6,
                            children: [
                              Text(
                                isHidden
                                    ? 'Surplus / Defisit'
                                    : periodNet < 0
                                    ? 'Defisit bulan ini'
                                    : periodNet > 0
                                    ? 'Surplus bulan ini'
                                    : 'Seimbang bulan ini',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                isHidden
                                    ? '••••••'
                                    : CurrencyFormatter.formatRupiah(
                                        periodNet,
                                        withSign: true,
                                      ),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: isHidden
                                      ? AppColors.textSecondary
                                      : netColor,
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

  Widget _buildScopePill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
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
            _selectedCategoryId = null;
            _resetPages();
          });
        }
      },
    );
  }

  Widget _buildCategoryChip({
    required String label,
    IconData? icon,
    required bool isSelected,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      showCheckmark: false,
      avatar: icon != null
          ? Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            )
          : null,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
        color: isSelected ? Colors.white : AppColors.textSecondary,
      ),
      onSelected: (_) => onSelected(),
    );
  }
}
