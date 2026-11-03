import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/shell_management_scope.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../database/transaction_query.dart';
import '../../obligations/data/obligations_repository.dart';
import '../../obligations/pages/obligations_page.dart';
import '../../transactions/models/transaction.dart';
import '../../transactions/widgets/add_transaction_modal.dart';
import '../../transactions/widgets/transaction_item_tile.dart';
import '../models/account.dart';
import '../widgets/balance_adjustment_dialog.dart';

enum AccountDateFilterMode {
  all('Semua'),
  month('Bulan'),
  year('Tahun'),
  date('Tanggal');

  final String label;
  const AccountDateFilterMode(this.label);
}

/// Account ledger displayed within the shell's management navigator.
class AccountDetailPage extends StatefulWidget {
  final String accountId;
  final VoidCallback onSettings;

  const AccountDetailPage({
    super.key,
    required this.accountId,
    required this.onSettings,
  });

  @override
  State<AccountDetailPage> createState() => _AccountDetailPageState();
}

class _AccountDetailPageState extends State<AccountDetailPage> {
  bool _started = false;
  final _pages = <TransactionCursor?>[null];
  int _page = 0;
  Object? _scope;
  int? _revision;

  AccountDateFilterMode _filterMode = AccountDateFilterMode.all;
  DateTime? _selectedMonth;
  int? _selectedYear;
  DateTime? _selectedDate;
  DateTimeRange? _selectedDateRange;

  void _resetPagination() {
    _page = 0;
    _pages
      ..clear()
      ..add(null);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Render cached history first. Use the existing full sync/list refresh so an
    // account-filtered snapshot cannot replace other accounts' cached history.
    final state = AppStateScope.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(state.refresh());
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final account = state.getAccountById(widget.accountId);
    final parentId = account?.parentAccountId;
    final parent = parentId != null && parentId != account?.id
        ? state.getAccountById(parentId)
        : null;
    final title = account == null
        ? 'Detail Akun'
        : parent == null
        ? account.name
        : '${parent.name} - ${account.name}';
    if (_scope != state.localDataScope ||
        _revision != state.localDataRevision) {
      _scope = state.localDataScope;
      _revision = state.localDataRevision;
      _resetPagination();
    }

    final nowLocal = state.timeZone.at(DateTime.now());
    DateTime? queryStart;
    DateTime? queryEnd;

    switch (_filterMode) {
      case AccountDateFilterMode.all:
        queryStart = null;
        queryEnd = null;
        break;
      case AccountDateFilterMode.month:
        final month =
            _selectedMonth ?? DateTime.utc(nowLocal.year, nowLocal.month);
        queryStart = state.timeZone.fromCalendar(
          DateTime.utc(month.year, month.month, 1),
        );
        queryEnd = state.timeZone.fromCalendar(
          DateTime.utc(month.year, month.month + 1, 1),
        );
        break;
      case AccountDateFilterMode.year:
        final year = _selectedYear ?? nowLocal.year;
        queryStart = state.timeZone.fromCalendar(DateTime.utc(year, 1, 1));
        queryEnd = state.timeZone.fromCalendar(DateTime.utc(year + 1, 1, 1));
        break;
      case AccountDateFilterMode.date:
        if (_selectedDateRange != null) {
          final start = _selectedDateRange!.start;
          final end = _selectedDateRange!.end;
          queryStart = state.timeZone.fromCalendar(
            DateTime.utc(start.year, start.month, start.day),
          );
          queryEnd = state.timeZone.fromCalendar(
            DateTime.utc(end.year, end.month, end.day + 1),
          );
        } else {
          final date =
              _selectedDate ??
              DateTime.utc(nowLocal.year, nowLocal.month, nowLocal.day);
          queryStart = state.timeZone.fromCalendar(
            DateTime.utc(date.year, date.month, date.day),
          );
          queryEnd = state.timeZone.fromCalendar(
            DateTime.utc(date.year, date.month, date.day + 1),
          );
        }
        break;
    }

    final history = state.transactionPage(
      TransactionQuery(
        accountId: widget.accountId,
        start: queryStart,
        end: queryEnd,
        after: _pages[_page],
      ),
    );
    final transactions = history.items;
    final rows = <Object>[];
    DateTime? previousDay;
    for (final tx in transactions) {
      final local = state.timeZone.at(tx.date);
      final day = DateTime.utc(local.year, local.month, local.day);
      if (day != previousDay) {
        rows.add(day);
        previousDay = day;
      }
      rows.add(tx);
    }

    final children = account != null
        ? state.getChildrenForAccount(account.id)
        : const <Account>[];
    final hasChildren = children.isNotEmpty;
    final source = state.repository;
    final mapped = source?.isMappedObligationAccount(widget.accountId) ?? false;
    final legacyLoan =
        account != null &&
        RegExp(
          r'hutang|utang|piutang|loan|debt|paylater|kredit',
          caseSensitive: false,
        ).hasMatch('${account.name} ${account.institution}');
    final canRegister =
        source != null &&
        legacyLoan &&
        ObligationsRepository(source).cashAccounts.any(
          (row) =>
              row['id'] == widget.accountId &&
              obligationMinor('${row['balance']}', signed: true) != BigInt.zero,
        );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (account != null)
            IconButton(
              tooltip: 'Pengaturan & Sharing',
              icon: const Icon(Icons.settings_outlined),
              onPressed: widget.onSettings,
            ),
        ],
      ),
      body: account == null
          ? const Center(child: Text('Akun tidak ditemukan.'))
          : RefreshIndicator(
              onRefresh: state.refresh,
              child: ListView(
                key: ValueKey((
                  _scope,
                  _revision,
                  _page,
                  widget.accountId,
                  _filterMode,
                  _selectedMonth,
                  _selectedYear,
                  _selectedDate,
                  _selectedDateRange,
                )),
                padding: const EdgeInsets.only(bottom: 24),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _buildBalanceCard(
                    context,
                    state,
                    account,
                    hasChildren,
                    children,
                    mapped,
                    canRegister,
                  ),
                  _buildIncludeTotalCard(
                    context,
                    state,
                    account,
                    hasChildren,
                    mapped,
                  ),
                  _buildHistoryHeader(state),
                  _buildFilterCard(context, state, nowLocal),
                  if (transactions.isEmpty)
                    _buildEmptyState()
                  else ...[
                    for (final row in rows)
                      if (row is DateTime)
                        _buildDayHeader(row)
                      else if (row is TransactionItem)
                        _buildTransactionRow(row, account.id),
                  ],
                  _buildPaginationCard(transactions.length, history.next),
                ],
              ),
            ),
    );
  }

  Widget _buildBalanceCard(
    BuildContext context,
    AppState state,
    Account account,
    bool hasChildren,
    List<Account> children,
    bool mapped,
    bool canRegister,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.7),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Saldo Rekening',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              if (account.institution.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    account.institution,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            state.isBalanceHidden
                ? '••••••'
                : CurrencyFormatter.formatRupiah(account.balance),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          if (hasChildren) ...[
            const SizedBox(height: 6),
            Text(
              'Total akumulasi dari ${children.length} kantong terhubung: ${state.isBalanceHidden ? '••••••' : CurrencyFormatter.formatRupiah(account.balance + children.fold<int>(0, (sum, c) => sum + c.balance))}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.accentDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (mapped || canRegister) ...[
            const SizedBox(height: 12),
            Text(
              mapped
                  ? 'Saldo ini terhubung ke Utang & Piutang. Catat pelunasan di sana agar sisa pinjaman dan kas tetap sesuai.'
                  : 'Punya pinjaman berjalan? Catat pihak dan sisa pokok dengan menghubungkan saldo akun ini, tanpa membuat uang keluar/masuk lagi.',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            TextButton.icon(
              icon: const Icon(Icons.handshake_outlined, size: 16),
              label: Text(
                mapped
                    ? 'Kelola Utang & Piutang'
                    : 'Hubungkan ke Utang & Piutang',
              ),
              onPressed: () => ShellManagementScope.open(
                context,
                ObligationsPage(
                  initialLinkedAccountId: mapped ? null : account.id,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: mapped
                    ? null
                    : () {
                        if (account.ownerUserId != state.currentUserId ||
                            state.currentUserId.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Hanya pemilik akun dapat menyesuaikan saldo.',
                              ),
                            ),
                          );
                          return;
                        }
                        showDialog<void>(
                          context: context,
                          builder: (_) => BalanceAdjustmentDialog(
                            state: state,
                            accountId: account.id,
                          ),
                        );
                      },
                child: const Text('Ubah Saldo'),
              ),
              OutlinedButton(
                onPressed:
                    !mapped &&
                        state.selectableAccounts.any(
                          (candidate) => candidate.id == account.id,
                        )
                    ? () => AddTransactionModal.show(
                        context,
                        initialType: TransactionType.transfer,
                        initialAccountId: account.id,
                      )
                    : null,
                child: const Text('Transfer Saldo'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIncludeTotalCard(
    BuildContext context,
    AppState state,
    Account account,
    bool hasChildren,
    bool mapped,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: account.isIncludeTotal && !hasChildren
              ? AppColors.accent.withValues(alpha: 0.3)
              : AppColors.border.withValues(alpha: 0.7),
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
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: account.isIncludeTotal && !hasChildren
                  ? AppColors.accent.withValues(alpha: 0.12)
                  : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              account.isIncludeTotal && !hasChildren
                  ? Icons.visibility_rounded
                  : Icons.visibility_off_rounded,
              color: account.isIncludeTotal && !hasChildren
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
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasChildren
                      ? 'Akun induk otomatis dikecualikan agar saldo kantong tidak ganda.'
                      : account.isIncludeTotal
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
            key: const ValueKey('account_include_total_switch'),
            value: account.isIncludeTotal && !hasChildren,
            activeTrackColor: AppColors.primary,
            onChanged:
                (account.ownerUserId != state.currentUserId &&
                        state.currentUserId.isNotEmpty) ||
                    hasChildren ||
                    mapped
                ? null
                : (val) async {
                    try {
                      await state.updateAccountIncludeTotal(
                        accountId: account.id,
                        isIncludeTotal: val,
                      );
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Gagal memperbarui: $e')),
                        );
                      }
                    }
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryHeader(AppState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Riwayat Transaksi',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Terbaru terlebih dahulu • Akun ini saja',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          if (state.loading) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
          ],
          if (state.isOfflineMode || state.dataError != null)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Menampilkan data lokal. Tarik untuk mencoba sinkronisasi kembali.',
                style: TextStyle(fontSize: 12, color: AppColors.warning),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterCard(
    BuildContext context,
    AppState state,
    DateTime nowLocal,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.7),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: AccountDateFilterMode.values.map((mode) {
              final isSelected = _filterMode == mode;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Material(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.surfaceVariant.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        if (_filterMode == mode) return;
                        setState(() {
                          _filterMode = mode;
                          _resetPagination();
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Center(
                          child: Text(
                            mode.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (_filterMode != AccountDateFilterMode.all) ...[
            const SizedBox(height: 10),
            Divider(height: 1, color: AppColors.divider.withValues(alpha: 0.7)),
            const SizedBox(height: 8),
            _buildSubFilterControls(context, state, nowLocal),
          ],
        ],
      ),
    );
  }

  Widget _buildSubFilterControls(
    BuildContext context,
    AppState state,
    DateTime nowLocal,
  ) {
    switch (_filterMode) {
      case AccountDateFilterMode.month:
        return _buildMonthControls(context, nowLocal);
      case AccountDateFilterMode.year:
        return _buildYearControls(context, nowLocal);
      case AccountDateFilterMode.date:
        return _buildDateControls(context, nowLocal);
      case AccountDateFilterMode.all:
        return const SizedBox.shrink();
    }
  }

  Widget _buildMonthControls(BuildContext context, DateTime nowLocal) {
    final currentMonth =
        _selectedMonth ?? DateTime.utc(nowLocal.year, nowLocal.month);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Bulan sebelumnya',
          icon: const Icon(Icons.chevron_left_rounded, size: 22),
          onPressed: () {
            setState(() {
              _selectedMonth = DateTime.utc(
                currentMonth.year,
                currentMonth.month - 1,
              );
              _resetPagination();
            });
          },
        ),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime(currentMonth.year, currentMonth.month, 1),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
              initialDatePickerMode: DatePickerMode.year,
              helpText: 'PILIH BULAN & TAHUN',
              builder: (context, child) => Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: Theme.of(context).colorScheme.copyWith(
                    primary: AppColors.primary,
                    onPrimary: Colors.white,
                  ),
                ),
                child: child!,
              ),
            );
            if (picked != null) {
              setState(() {
                _selectedMonth = DateTime.utc(picked.year, picked.month);
                _resetPagination();
              });
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.calendar_month_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  DateFormatter.formatMonthYear(currentMonth),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_drop_down,
                  size: 18,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Bulan berikutnya',
          icon: const Icon(Icons.chevron_right_rounded, size: 22),
          onPressed: () {
            setState(() {
              _selectedMonth = DateTime.utc(
                currentMonth.year,
                currentMonth.month + 1,
              );
              _resetPagination();
            });
          },
        ),
      ],
    );
  }

  Widget _buildYearControls(BuildContext context, DateTime nowLocal) {
    final currentYear = _selectedYear ?? nowLocal.year;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Tahun sebelumnya',
          icon: const Icon(Icons.chevron_left_rounded, size: 22),
          onPressed: () {
            setState(() {
              _selectedYear = currentYear - 1;
              _resetPagination();
            });
          },
        ),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime(currentYear, 1, 1),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
              initialDatePickerMode: DatePickerMode.year,
              helpText: 'PILIH TAHUN',
              builder: (context, child) => Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: Theme.of(context).colorScheme.copyWith(
                    primary: AppColors.primary,
                    onPrimary: Colors.white,
                  ),
                ),
                child: child!,
              ),
            );
            if (picked != null) {
              setState(() {
                _selectedYear = picked.year;
                _resetPagination();
              });
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  '$currentYear',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_drop_down,
                  size: 18,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Tahun berikutnya',
          icon: const Icon(Icons.chevron_right_rounded, size: 22),
          onPressed: () {
            setState(() {
              _selectedYear = currentYear + 1;
              _resetPagination();
            });
          },
        ),
      ],
    );
  }

  Widget _buildDateControls(BuildContext context, DateTime nowLocal) {
    final hasRange = _selectedDateRange != null;
    final currentDate =
        _selectedDate ??
        DateTime.utc(nowLocal.year, nowLocal.month, nowLocal.day);

    return Row(
      children: [
        if (!hasRange)
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Hari sebelumnya',
            icon: const Icon(Icons.chevron_left_rounded, size: 22),
            onPressed: () {
              setState(() {
                _selectedDate = DateTime.utc(
                  currentDate.year,
                  currentDate.month,
                  currentDate.day - 1,
                );
                _resetPagination();
              });
            },
          ),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () async {
              if (hasRange) {
                final picked = await showDateRangePicker(
                  context: context,
                  initialDateRange: _selectedDateRange,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                  builder: (context, child) => Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: Theme.of(context).colorScheme.copyWith(
                        primary: AppColors.primary,
                        onPrimary: Colors.white,
                      ),
                    ),
                    child: child!,
                  ),
                );
                if (picked != null) {
                  setState(() {
                    _selectedDateRange = picked;
                    _resetPagination();
                  });
                }
              } else {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime(
                    currentDate.year,
                    currentDate.month,
                    currentDate.day,
                  ),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                  helpText: 'PILIH TANGGAL',
                  builder: (context, child) => Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: Theme.of(context).colorScheme.copyWith(
                        primary: AppColors.primary,
                        onPrimary: Colors.white,
                      ),
                    ),
                    child: child!,
                  ),
                );
                if (picked != null) {
                  setState(() {
                    _selectedDate = DateTime.utc(
                      picked.year,
                      picked.month,
                      picked.day,
                    );
                    _resetPagination();
                  });
                }
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.event_note_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hasRange
                          ? '${DateFormatter.formatShort(_selectedDateRange!.start)} - ${DateFormatter.formatShort(_selectedDateRange!.end)}'
                          : DateFormatter.formatShort(currentDate),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!hasRange)
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Hari berikutnya',
            icon: const Icon(Icons.chevron_right_rounded, size: 22),
            onPressed: () {
              setState(() {
                _selectedDate = DateTime.utc(
                  currentDate.year,
                  currentDate.month,
                  currentDate.day + 1,
                );
                _resetPagination();
              });
            },
          ),
        const SizedBox(width: 4),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: hasRange ? 'Ganti ke satu tanggal' : 'Pilih rentang tanggal',
          icon: Icon(
            hasRange ? Icons.close_rounded : Icons.date_range_rounded,
            size: 20,
            color: hasRange ? AppColors.accentDark : AppColors.primary,
          ),
          onPressed: () async {
            if (hasRange) {
              setState(() {
                _selectedDateRange = null;
                _resetPagination();
              });
            } else {
              final picked = await showDateRangePicker(
                context: context,
                initialDateRange: DateTimeRange(
                  start: DateTime(currentDate.year, currentDate.month, 1),
                  end: DateTime(
                    currentDate.year,
                    currentDate.month,
                    currentDate.day,
                  ),
                ),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
                builder: (context, child) => Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: Theme.of(context).colorScheme.copyWith(
                      primary: AppColors.primary,
                      onPrimary: Colors.white,
                    ),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) {
                setState(() {
                  _selectedDateRange = picked;
                  _resetPagination();
                });
              }
            }
          },
        ),
      ],
    );
  }

  Widget _buildDayHeader(DateTime day) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6, left: 16, right: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.border.withValues(alpha: 0.8),
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 13,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  DateFormatter.formatShort(day),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionRow(TransactionItem item, String accountId) {
    return Container(
      key: ValueKey(item.id),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
        key: ValueKey(item.id),
        transaction: item,
        currentAccountId: accountId,
        showDate: false,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: AppColors.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              size: 26,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Belum ada transaksi pada akun ini.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          if (_filterMode != AccountDateFilterMode.all) ...[
            const SizedBox(height: 4),
            const Text(
              'Tidak ada transaksi pada filter periode ini.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _filterMode = AccountDateFilterMode.all;
                  _resetPagination();
                });
              },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Tampilkan Semua'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaginationCard(int count, TransactionCursor? nextCursor) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Halaman transaksi sebelumnya',
              onPressed: _page == 0 ? null : () => setState(() => _page--),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Text(
                'Halaman ${_page + 1} · $count ditampilkan',
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
              onPressed: nextCursor == null
                  ? null
                  : () => setState(() {
                      if (_pages.length == _page + 1) {
                        _pages.add(nextCursor);
                      }
                      _page++;
                    }),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
