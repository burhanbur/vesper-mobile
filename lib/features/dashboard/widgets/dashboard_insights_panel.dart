import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../models/dashboard_insights.dart';

class DashboardInsightsPanel extends StatelessWidget {
  final DashboardInsights insights;
  final bool hidden;
  final VoidCallback onBills, onSpending, onBudgets;
  const DashboardInsightsPanel({
    super.key,
    required this.insights,
    required this.hidden,
    required this.onBills,
    required this.onSpending,
    required this.onBudgets,
  });

  String _money(BigInt value) =>
      hidden ? '••••••' : CurrencyFormatter.formatMinorRupiah(value);

  @override
  Widget build(BuildContext context) {
    final bills = insights.bills;
    final spending = insights.spending;
    final budgets = insights.budgets;
    final budget = budgets?.firstOrNull;
    final percent = spending?.changePercent;
    final change = percent == null
        ? null
        : '${percent.abs() ~/ BigInt.from(100)},${(percent.abs() % BigInt.from(100)).toString().padLeft(2, '0')}%';
    final comparison = spending == null
        ? ''
        : '1–${spending.comparedDays} ${DateFormatter.formatMonthShort(spending.currentStart.month)} vs '
              '1–${spending.comparedDays} ${DateFormatter.formatMonthShort(spending.previousStart.month)}';
    final billsUnavailable = bills == null || bills.needsReview;

    return Padding(
      key: const ValueKey('dashboard_insights'),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sekilas',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 10),
          Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _InsightRow(
                  id: 'bills',
                  icon: Icons.event_note_outlined,
                  title: 'Tagihan 7 hari ke depan',
                  value: billsUnavailable
                      ? 'Periksa jadwal tagihan'
                      : bills.count == 0
                      ? 'Tidak ada tagihan terjadwal'
                      : '${bills.count} tagihan · ${_money(bills.total)}',
                  detail: bills == null
                      ? 'Jadwal belum selesai dimuat'
                      : bills.needsReview
                      ? 'Ada data pembayaran yang perlu diperiksa'
                      : bills.count == 0
                      ? 'Termasuk hari ini · sesuai jadwal tercatat'
                      : '${bills.nextTitle ?? 'Lihat jadwal'}${bills.estimatedCount > 0 ? ' · termasuk ${bills.estimatedCount} perkiraan' : ''}',
                  onTap: onBills,
                ),
                const Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: AppColors.borderSubtle,
                ),
                _InsightRow(
                  id: 'spending',
                  icon: Icons.receipt_long_outlined,
                  title: 'Laju pengeluaran',
                  value: spending == null
                      ? 'Belum dapat dibandingkan'
                      : hidden
                      ? '••••••'
                      : !spending.hasPreviousEntries
                      ? 'Belum ada pembanding'
                      : percent == null
                      ? 'Pembanding bulan lalu Rp 0'
                      : spending.current == spending.previous
                      ? 'Sama dengan bulan lalu'
                      : percent == BigInt.zero
                      ? 'Selisih kurang dari 0,01%'
                      : '$change ${percent.isNegative ? 'lebih rendah' : 'lebih tinggi'}',
                  detail: spending == null
                      ? 'Histori transaksi belum selesai dimuat'
                      : '$comparison${spending.hasPreviousEntries ? '' : '\nBelum ada pengeluaran pada rentang bulan lalu'}',
                  onTap: onSpending,
                ),
                const Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: AppColors.borderSubtle,
                ),
                _InsightRow(
                  id: 'budgets',
                  icon: Icons.donut_large_outlined,
                  title: 'Budget perlu perhatian',
                  value: budgets == null
                      ? 'Belum dapat dihitung'
                      : budget == null
                      ? 'Belum ada budget mencapai 80%'
                      : '${budget.name} · ${hidden ? '••••••' : '${budget.percent}% terpakai'}',
                  detail: budgets == null
                      ? 'Histori transaksi belum selesai dimuat'
                      : budget == null
                      ? 'Lihat atau atur budget bulanan'
                      : '${budget.remaining.isNegative ? 'Lewat' : 'Sisa'} ${_money(budget.remaining.abs())}'
                            '${budget.isEstimated ? ' · perkiraan' : ''}'
                            '${budgets.length > 1 ? ' · +${budgets.length - 1} kategori' : ''}',
                  onTap: onBudgets,
                  attention: !hidden && budget != null,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 2),
            child: Text(
              insights.provisional
                  ? 'Data lokal · ada perubahan belum tersinkron'
                  : 'Berdasarkan catatan pribadi · IDR',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  final String id, title, value, detail;
  final IconData icon;
  final VoidCallback onTap;
  final bool attention;
  const _InsightRow({
    required this.id,
    required this.title,
    required this.value,
    required this.detail,
    required this.icon,
    required this.onTap,
    this.attention = false,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    key: ValueKey('dashboard_insight_$id'),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.accentDark),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: attention
                        ? AppColors.warning
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    ),
  );
}
