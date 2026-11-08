import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../sync/data/finance_repository.dart';
import '../data/investment_lifecycle_controller.dart';
import '../data/investment_lifecycle_repository.dart';
import '../models/investment.dart';
import '../widgets/offline_investment_trade_form.dart';

class InvestmentLifecyclePage extends StatefulWidget {
  const InvestmentLifecyclePage({super.key});
  @override
  State<InvestmentLifecyclePage> createState() =>
      _InvestmentLifecyclePageState();
}

class _InvestmentLifecyclePageState extends State<InvestmentLifecyclePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _selectedTab = 0;
  InvestmentLifecycleController? controller;
  String search = '';
  String? accountId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging &&
          _selectedTab != _tabController.index) {
        setState(() {
          _selectedTab = _tabController.index;
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppStateScope.of(context);
    final source = state.repository;
    final user = state.currentUserId;
    if (accountId != null &&
        (source == null || !source.canTradeAccount(accountId!, 'INVESTMENT'))) {
      accountId = null;
    }
    if (source == null || user.isEmpty || source.userId != user) {
      controller?.dispose();
      controller = null;
    } else if (!identical(controller?.repository.source, source)) {
      controller?.dispose();
      controller = InvestmentLifecycleController(
        InvestmentLifecycleRepository(source),
        () =>
            mounted &&
            identical(state.repository, source) &&
            state.currentUserId == user,
        state.requestAutomaticSync,
      );
      unawaited(controller!.refresh());
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    controller?.dispose();
    super.dispose();
  }

  Future<void> edit({Map<String, dynamic>? instrument}) async {
    final active = controller!;
    final code = TextEditingController();
    final name = TextEditingController();
    final date = TextEditingController(
      text: DateTime.now().toUtc().toIso8601String().substring(0, 10),
    );
    final price = TextEditingController();
    String type = 'STOCK';
    String? error;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => Material(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 14,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            instrument == null
                                ? 'Tambah instrumen IDR'
                                : 'Harga ${instrument['code']}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (instrument == null) ...[
                      TextField(
                        controller: code,
                        decoration: InputDecoration(
                          labelText: 'Kode',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: name,
                        decoration: InputDecoration(
                          labelText: 'Nama',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: type,
                        decoration: InputDecoration(
                          labelText: 'Tipe',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                        items: [
                          'STOCK',
                          'MUTUAL_FUND',
                          'BOND',
                          'CRYPTO',
                          'COMMODITY',
                          'OTHER',
                        ]
                            .map(
                              (t) => DropdownMenuItem(value: t, child: Text(t)),
                            )
                            .toList(),
                        onChanged: (t) => type = t!,
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Harga manual global untuk instrumen ini. Tanggal yang sama mengganti harga sebelumnya. Disimpan lokal sebelum dikirim.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                      TextField(
                        controller: date,
                        decoration: InputDecoration(
                          labelText: 'Tanggal harga (YYYY-MM-DD)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: price,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Harga IDR (maks. 8 desimal)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          error!,
                          style: TextStyle(
                            color: Theme.of(ctx).colorScheme.error,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,
                              side: const BorderSide(color: AppColors.border),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Batal'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () {
                              try {
                                if (instrument == null) {
                                  active.saveInstrument(
                                    code.text,
                                    name.text,
                                    type,
                                  );
                                } else {
                                  active.savePrice(
                                    instrument['id'] as String,
                                    date.text,
                                    price.text,
                                  );
                                }
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Tersimpan lokal • menunggu sinkronisasi',
                                    ),
                                  ),
                                );
                              } catch (failure) {
                                setDialogState(
                                  () => error = failure.toString(),
                                );
                              }
                            },
                            child: const Text('Simpan lokal'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    } finally {
      // Dialog route animations can still reference fields until the next frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        code.dispose();
        name.dispose();
        date.dispose();
        price.dispose();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = controller;
    final hidden = AppStateScope.of(context).isBalanceHidden;
    String money(String? value) => hidden
        ? '••••••'
        : value == null
        ? 'Belum tersedia'
        : 'IDR $value';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Kelola investasi',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: active == null
          ? const Center(
              child: Text(
                'Silakan masuk kembali.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          : ListenableBuilder(
              listenable: active,
              builder: (context, _) {
                final repo = active.repository;
                final source = repo.source;
                InvestmentOverview? overview;
                List<Map<String, dynamic>> history = [];
                String? readError;
                try {
                  overview = repo.overview();
                  history = repo.history(accountId).reversed.toList();
                } catch (failure) {
                  readError = failure.toString();
                }
                return Column(
                  children: [
                    _buildTabBar(),
                    Expanded(
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        children: [
                          _buildTopActionCard(active),
                          if (active.loading)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: LinearProgressIndicator(
                                color: AppColors.primary,
                                backgroundColor: AppColors.surfaceVariant,
                              ),
                            ),
                          if (active.error != null)
                            _buildErrorBanner(active.error!),
                          if (readError != null)
                            _buildErrorBanner(readError),
                          if ((_selectedTab == 0 || _selectedTab == 1) &&
                              overview != null) ...[
                            const SizedBox(height: 12),
                            _buildOverviewSection(overview, money),
                          ],
                          if (_selectedTab == 0 || _selectedTab == 2) ...[
                            const SizedBox(height: 16),
                            _buildInstrumentsSection(
                              repo,
                              source,
                              money,
                              active,
                            ),
                          ],
                          if (_selectedTab == 0 || _selectedTab == 3) ...[
                            const SizedBox(height: 16),
                            _buildHistorySection(
                              history,
                              source,
                              money,
                              hidden,
                              readError,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 6, 14, 8),
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.25),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        onTap: (index) {
          setState(() => _selectedTab = index);
        },
        tabs: const [
          Tab(text: 'Semua'),
          Tab(text: 'Ringkasan'),
          Tab(text: 'Instrumen'),
          Tab(text: 'Riwayat'),
        ],
      ),
    );
  }

  Widget _buildTopActionCard(InvestmentLifecycleController active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.incomeLight,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 11,
                      color: AppColors.income,
                    ),
                    SizedBox(width: 3),
                    Text(
                      'IDR • Aktif',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.income,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Kas settlement terpisah dari holding',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const OfflineInvestmentTradeForm(
                    initialType: InvestmentTradeType.buy,
                  ),
                ),
                icon: const Icon(Icons.swap_horiz_rounded, size: 14),
                label: const Text(
                  'Beli / Jual / Dividen',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => edit(),
                icon: const Icon(Icons.add_rounded, size: 14),
                label: const Text(
                  'Tambah instrumen',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: active.loading ? null : active.refresh,
                icon: const Icon(Icons.cloud_sync_outlined, size: 14),
                label: const Text(
                  'Cari data server',
                  style: TextStyle(fontSize: 11),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.expenseLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.expense.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 16,
            color: AppColors.expense,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, color: AppColors.expense),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewSection(
    InvestmentOverview overview,
    String Function(String?) money,
  ) {
    final unrealizedPositive =
        overview.unrealized != null && !overview.unrealized!.startsWith('-');
    final realizedPositive = !overview.realized.startsWith('-');

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.pie_chart_outline_rounded,
                size: 15,
                color: AppColors.primary,
              ),
              const SizedBox(width: 5),
              const Text(
                'Ringkasan Portofolio',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              if (overview.unrealized != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: unrealizedPositive
                        ? AppColors.incomeLight
                        : AppColors.expenseLight,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    'Laba belum terealisasi: ${money(overview.unrealized)}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: unrealizedPositive
                          ? AppColors.income
                          : AppColors.expense,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Nilai pasar: ${money(overview.marketValue)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                'Dividen bersih: ${money(overview.dividends)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.income,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Modal beli: ${money(overview.contributed)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Text(
                'Laba jual: ${money(overview.realized)}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: realizedPositive
                      ? AppColors.income
                      : AppColors.expense,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Hasil jual: ${money(overview.proceeds)}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              Text(
                'Fee beli: ${money(overview.buyFees)}',
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInstrumentsSection(
    InvestmentLifecycleRepository repo,
    FinanceRepository source,
    String Function(String?) money,
    InvestmentLifecycleController active,
  ) {
    final filtered = repo.instruments.where(
      (r) => '${r['code']} ${r['name']}'.toLowerCase().contains(search),
    ).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.candlestick_chart_rounded,
              size: 15,
              color: AppColors.primary,
            ),
            const SizedBox(width: 5),
            const Text(
              'Instrumen & Kuotasi',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            Text(
              '${filtered.length} instrumen',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 36,
          child: TextField(
            decoration: InputDecoration(
              labelText: 'Cari kode / nama instrumen',
              prefixIcon: const Icon(Icons.search_rounded, size: 16),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 0,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
            onChanged: (v) => setState(() => search = v.toLowerCase()),
          ),
        ),
        const SizedBox(height: 6),
        for (final item in filtered)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: AppColors.border),
            ),
            color: Colors.white,
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              title: Text(
                '${item['code']} • ${item['name']}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              subtitle: Text(
                '${item['type']} • ${item['pending_catalog'] == true ? 'Menunggu sinkronisasi' : 'IDR'}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              trailing: TextButton(
                onPressed: () => edit(instrument: item),
                child: const Text('Harga'),
              ),
            ),
          ),
        if (source.rows('instrument_prices').isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.price_check_rounded,
                      size: 15,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Harga Terakhir Disimpan',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                for (final quote in source.rows('instrument_prices'))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.5),
                    child: Text(
                      '${source.row('instruments', '${quote['instrument_id']}')?['code'] ?? quote['instrument_id']}: ${money(quote['close_price'] as String?)} • ${DateFormatter.calendarDate(quote['price_date'])}${quote['pending_catalog'] == true ? ' • lokal/pending' : ''}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (source.pendingInvestmentCatalog.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warningLight.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.hourglass_top_rounded,
                      size: 16,
                      color: AppColors.warning,
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Antrean katalog • otomatis dicoba ulang saat sinkronisasi',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                for (final item in source.pendingInvestmentCatalog)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item['payload']['code'] ?? item['payload']['price_date']}: ${item['error'] ?? 'Menunggu pengiriman'}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      if (item['error'] != null)
                        TextButton(
                          onPressed: source.isSyncing
                              ? null
                              : () async {
                                  final discard = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text(
                                        'Hentikan pengiriman katalog?',
                                      ),
                                      content: const Text(
                                        'Antrean dan nilai lokal terkait akan dihapus. Ini tidak membatalkan perubahan yang mungkin sudah diterima server. Muat ulang katalog untuk memeriksa hasilnya.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text('Kembali'),
                                        ),
                                        FilledButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: const Text('Hentikan'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (discard == true && mounted) {
                                    try {
                                      active.discardCatalog(
                                        item['id'] as String,
                                      );
                                    } catch (failure) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  failure.toString(),
                                                ),
                                              ),
                                            );
                                      }
                                    }
                                  }
                                },
                          child: const Text('Hentikan pengiriman lokal'),
                        ),
                    ],
                  ),
                TextButton.icon(
                  onPressed: () async {
                    try {
                      await AppStateScope.of(context)
                          .checkInvestmentRecovery();
                    } catch (_) {
                      /* Queue retains the delivery error. */
                    }
                    if (mounted) setState(() {});
                  },
                  icon: const Icon(Icons.sync_rounded, size: 16),
                  label: const Text('Sinkronkan ulang'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHistorySection(
    List<Map<String, dynamic>> history,
    FinanceRepository source,
    String Function(String?) money,
    bool hidden,
    String? readError,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(
              Icons.history_rounded,
              size: 16,
              color: AppColors.primary,
            ),
            SizedBox(width: 6),
            Text(
              'Riwayat investasi',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: ValueKey(accountId),
          initialValue: accountId ?? '',
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Filter akun',
            prefixIcon: const Icon(
              Icons.account_balance_outlined,
              size: 18,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
          items: [
            const DropdownMenuItem(
              value: '',
              child: Text('Semua akun'),
            ),
            for (final account in source.rows('accounts').where(
              (r) => source.canTradeAccount(
                '${r['id']}',
                'INVESTMENT',
              ),
            ))
              DropdownMenuItem(
                value: account['id'] as String,
                child: Text('${account['name']}'),
              ),
          ],
          onChanged: (v) => setState(() => accountId = v == '' ? null : v),
        ),
        const SizedBox(height: 8),
        if (history.isEmpty && readError == null)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 36,
                  color: AppColors.textMuted.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Belum ada transaksi investasi.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        for (final row in history)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppColors.border),
            ),
            color: Colors.white,
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: row['type'] == 'BUY'
                      ? AppColors.incomeLight
                      : row['type'] == 'SELL'
                          ? AppColors.expenseLight
                          : AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  row['type'] == 'BUY'
                      ? Icons.add_circle_outline_rounded
                      : row['type'] == 'SELL'
                          ? Icons.remove_circle_outline_rounded
                          : Icons.account_balance_wallet_outlined,
                  size: 20,
                  color: row['type'] == 'BUY'
                      ? AppColors.income
                      : row['type'] == 'SELL'
                          ? AppColors.expense
                          : AppColors.primary,
                ),
              ),
              title: Text(
                '${row['type']} • ${source.row('instruments', '${row['instrument_id']}')?['code'] ?? row['instrument_id']}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '${source.row('accounts', '${row['account_id']}')?['name']} • ${DateFormatter.timestamp(row['transacted_at'], timeZone: AppStateScope.of(context).timeZone)}\n'
                '${hidden ? '••••••' : row['quantity']} unit × ${money(row['price_per_unit'] as String?)}\n'
                'Fee/pajak: ${money(row['fee'] as String?)} • ${row['version'] == '0' ? 'Lokal/pending' : 'Tersinkron'}\n${row['description'] ?? ''}',
              ),
            ),
          ),
        const SizedBox(height: 8),
        const Text(
          'Transaksi diterima bersifat tetap. Untuk kesalahan transaksi, periksa riwayat dan hubungi pengelola; jangan mencatat ulang transaksi dengan status belum pasti. Pemulihan perintah tersedia pada formulir transaksi.',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textMuted,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}
