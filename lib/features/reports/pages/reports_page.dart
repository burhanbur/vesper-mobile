import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../core/utils/currency_formatter.dart';
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
  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final now = DateTime.now();
    final totals = <String, int>{};
    for (final tx in state.transactions) {
      final date = tx.date.toLocal();
      if (date.year != now.year || date.month != now.month) continue;
      final type = _selectedTab == 2 ? TransactionType.income : TransactionType.expense;
      if (tx.type == type) totals.update(tx.categoryName, (v) => v + tx.amount, ifAbsent: () => tx.amount);
    }
    final sorted = totals.entries.toList()..sort((a,b) => b.value.compareTo(a.value));
    String money(int amount) => state.isBalanceHidden ? 'Rp •••••' : CurrencyFormatter.formatRupiah(amount);
    return Scaffold(
      appBar: AppBar(title: const Text('Insights & Laporan'), actions: [IconButton(
        tooltip: 'Rencana Budget', icon: const Icon(Icons.pie_chart_outline_rounded),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const BudgetPage())),
      )]),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Row(children: [for (final (index, label) in ['Ringkasan', 'Pengeluaran', 'Pemasukan'].indexed)
          Expanded(child: TextButton(key: ValueKey('reports_tab_$index'),
            onPressed: () => setState(() => _selectedTab = index), child: Text(label)))]),
        Text('${now.year}-${now.month.toString().padLeft(2, '0')}', textAlign: TextAlign.center),
        if (_selectedTab == 0) ...[
          ListTile(title: const Text('Surplus / Neraca Bulan Ini'), trailing: Text(money(state.monthNetSavings))),
          ListTile(title: const Text('Pemasukan'), trailing: Text(money(state.monthIncome))),
          ListTile(title: const Text('Pengeluaran'), trailing: Text(money(state.monthExpense))),
        ] else ListTile(title: Text(_selectedTab == 1 ? 'Total Pengeluaran Bulan Ini' : 'Total Pemasukan Bulan Ini'),
          trailing: Text(money(_selectedTab == 1 ? state.monthExpense : state.monthIncome))),
        const SizedBox(height: 16),
        Text(_selectedTab == 2 ? 'Rincian Sumber Pemasukan' : 'Rincian Kategori Pengeluaran'),
        if (sorted.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('Belum ada transaksi pada periode ini.')),
        for (final entry in sorted) ListTile(title: Text(entry.key.isEmpty ? 'Tanpa kategori' : entry.key), trailing: Text(money(entry.value))),
        if (state.dataError != null) Text(state.dataError!),
        TextButton(onPressed: state.loading ? null : state.refresh, child: const Text('Muat ulang')),
      ]),
    );
  }
}
