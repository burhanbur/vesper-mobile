import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/transaction_period.dart';
import '../../../core/widgets/month_selector.dart';
import '../../transactions/models/transaction.dart';
import 'budget_page.dart';

/// Reports are derived from the same durable transaction snapshot as the ledger.
class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  int _selectedTab = 0;
  TransactionPeriod _period = TransactionPeriod(DateTime.now());
  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final transactions = _period.filter(state.transactions);
    final income = _period.total(transactions, TransactionType.income);
    final expense = _period.total(transactions, TransactionType.expense);
    final totals = <String, int>{};
    for (final tx in transactions) {
      final type = _selectedTab == 2
          ? TransactionType.income
          : TransactionType.expense;
      if (tx.type == type) {
        totals.update(
          tx.categoryName,
          (v) => v + tx.amount,
          ifAbsent: () => tx.amount,
        );
      }
    }
    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    String money(int amount) => state.isBalanceHidden
        ? 'Rp •••••'
        : CurrencyFormatter.formatRupiah(amount);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights & Laporan'),
        actions: [
          IconButton(
            tooltip: 'Rencana Budget',
            icon: const Icon(Icons.pie_chart_outline_rounded),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const BudgetPage())),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              for (final (index, label) in [
                'Ringkasan',
                'Pengeluaran',
                'Pemasukan',
              ].indexed)
                Expanded(
                  child: TextButton(
                    key: ValueKey('reports_tab_$index'),
                    onPressed: () => setState(() => _selectedTab = index),
                    child: Text(label),
                  ),
                ),
            ],
          ),
          MonthSelector(
            period: _period,
            onChanged: (period) => setState(() => _period = period),
          ),
          const Text(
            'Berdasarkan transaksi yang tersimpan di perangkat.',
            textAlign: TextAlign.center,
          ),
          if (_selectedTab == 0) ...[
            ListTile(
              title: const Text('Surplus / Neraca Periode'),
              trailing: Text(money(income - expense)),
            ),
            ListTile(
              title: const Text('Pemasukan'),
              trailing: Text(money(income)),
            ),
            ListTile(
              title: const Text('Pengeluaran'),
              trailing: Text(money(expense)),
            ),
          ] else
            ListTile(
              title: Text(
                _selectedTab == 1
                    ? 'Total Pengeluaran Periode'
                    : 'Total Pemasukan Periode',
              ),
              trailing: Text(money(_selectedTab == 1 ? expense : income)),
            ),
          const SizedBox(height: 16),
          Text(
            _selectedTab == 2
                ? 'Rincian Sumber Pemasukan'
                : 'Rincian Kategori Pengeluaran',
          ),
          if (sorted.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Belum ada transaksi pada periode ini.'),
            ),
          for (final entry in sorted)
            ListTile(
              title: Text(entry.key.isEmpty ? 'Tanpa kategori' : entry.key),
              trailing: Text(money(entry.value)),
            ),
          if (state.dataError != null) Text(state.dataError!),
          TextButton(
            onPressed: state.loading ? null : state.refresh,
            child: const Text('Muat ulang'),
          ),
        ],
      ),
    );
  }
}
