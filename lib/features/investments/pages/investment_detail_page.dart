import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../models/investment.dart';
import '../widgets/investment_trade_modal.dart';
import '../widgets/update_price_modal.dart';

class InvestmentDetailPage extends StatefulWidget {
  final String assetId;

  const InvestmentDetailPage({super.key, required this.assetId});

  @override
  State<InvestmentDetailPage> createState() => _InvestmentDetailPageState();
}

class _InvestmentDetailPageState extends State<InvestmentDetailPage> {
  String _selectedTimeframe = '1M'; // 1D, 1W, 1M, 3M, 1Y, ALL

  IconData _getAssetIcon(InvestmentAssetType type) {
    switch (type) {
      case InvestmentAssetType.crypto:
        return Icons.currency_bitcoin_rounded;
      case InvestmentAssetType.mutualFund:
        return Icons.show_chart_rounded;
      case InvestmentAssetType.gold:
        return Icons.workspace_premium_rounded;
      case InvestmentAssetType.stock:
        return Icons.candlestick_chart_rounded;
      case InvestmentAssetType.bond:
        return Icons.account_balance_rounded;
    }
  }

  Color _getAssetColor(InvestmentAssetType type) {
    switch (type) {
      case InvestmentAssetType.crypto:
        return const Color(0xFFF7931A);
      case InvestmentAssetType.mutualFund:
        return AppColors.accentDark;
      case InvestmentAssetType.gold:
        return const Color(0xFFD97706);
      case InvestmentAssetType.stock:
        return AppColors.primary;
      case InvestmentAssetType.bond:
        return AppColors.transfer;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final isHidden = state.isBalanceHidden;

    final asset = state.investments.firstWhere(
      (inv) => inv.id == widget.assetId,
      orElse: () => state.investments.first,
    );

    final color = _getAssetColor(asset.type);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(asset.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_calendar_rounded, color: AppColors.primary),
            tooltip: 'Update Harga Hari Ini',
            onPressed: () => UpdatePriceModal.show(context, asset),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Asset Header (Matching contoh-1.png & contoh-2.png)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(_getAssetIcon(asset.type), color: color, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                asset.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${asset.symbol} • ${asset.quantityDisplay}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: asset.isProfitable ? AppColors.incomeLight : AppColors.expenseLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                asset.isProfitable
                                    ? Icons.arrow_upward_rounded
                                    : Icons.arrow_downward_rounded,
                                size: 14,
                                color: asset.isProfitable ? AppColors.income : AppColors.expense,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${asset.isProfitable ? '+' : ''}${asset.returnPercentage.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: asset.isProfitable ? AppColors.income : AppColors.expense,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    const Divider(height: 1, color: AppColors.divider),
                    const SizedBox(height: 14),

                    // Nilai Saat Ini
                    const Text(
                      'Nilai Saat Ini',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isHidden ? 'Rp •••••••••' : CurrencyFormatter.formatRupiah(asset.totalCurrentValue),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Nilai Beli vs Keuntungan
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Nilai Beli (Modal)',
                                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isHidden
                                    ? '••••••'
                                    : CurrencyFormatter.formatRupiah(asset.totalInvestedValue),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(width: 1, height: 28, color: AppColors.divider),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Floating P/L (Untung/Rugi)',
                                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isHidden
                                    ? '••••••'
                                    : CurrencyFormatter.formatRupiah(
                                        asset.unrealizedGainLoss,
                                        withSign: true,
                                      ),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: asset.isProfitable ? AppColors.income : AppColors.expense,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Interactive Chart Container (Matching contoh-1.png & contoh-2.png)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    // Smooth simulated sparkline chart curve
                    SizedBox(
                      height: 140,
                      child: CustomPaint(
                        size: const Size(double.infinity, 140),
                        painter: _TrendChartPainter(isProfitable: asset.isProfitable),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Timeframe pills: 1D, 1W, 1M, 3M, 1Y, ALL
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: ['1D', '1W', '1M', '3M', '1Y', 'ALL'].map((tf) {
                        final isSel = _selectedTimeframe == tf;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedTimeframe = tf),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSel ? AppColors.primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              tf,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isSel ? Colors.white : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Riwayat Transaksi Investasi (Beli, Jual, Dividen - PRD 5.8)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Riwayat Transaksi',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '${asset.transactions.length} Transaksi',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (asset.transactions.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Center(
                    child: Text(
                      'Belum ada riwayat transaksi.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: asset.transactions.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final tx = asset.transactions[index];
                    final isBuy = tx.type == InvestmentTradeType.buy;
                    final isSell = tx.type == InvestmentTradeType.sell;

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isBuy
                                  ? AppColors.incomeLight
                                  : isSell
                                      ? AppColors.expenseLight
                                      : AppColors.investmentLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isBuy
                                  ? Icons.add_circle_outline_rounded
                                  : isSell
                                      ? Icons.remove_circle_outline_rounded
                                      : Icons.attach_money_rounded,
                              color: isBuy
                                  ? AppColors.income
                                  : isSell
                                      ? AppColors.expense
                                      : AppColors.investment,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tx.type.name.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${DateFormatter.formatDate(state.timeZone.at(tx.transactedAt))} • ${tx.quantity} ${asset.symbol}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                isHidden
                                    ? '••••••'
                                    : '${isBuy ? '+' : '-'}${CurrencyFormatter.formatRupiah(tx.totalAmount)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isBuy ? AppColors.income : AppColors.expense,
                                ),
                              ),
                              if (tx.realizedPl != null)
                                Text(
                                  'P/L: ${CurrencyFormatter.formatRupiah(tx.realizedPl!, withSign: true)}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: tx.realizedPl! >= 0
                                        ? AppColors.income
                                        : AppColors.expense,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),

              const SizedBox(height: 24),

              // Quick Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => UpdatePriceModal.show(context, asset),
                      icon: const Icon(Icons.update_rounded, size: 18),
                      label: const Text('Update Harga'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => InvestmentTradeModal.show(
                        context,
                        preselectedAsset: asset,
                      ),
                      icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                      label: const Text('Beli / Jual'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrendChartPainter extends CustomPainter {
  final bool isProfitable;

  _TrendChartPainter({required this.isProfitable});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isProfitable ? AppColors.income : AppColors.expense
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          (isProfitable ? AppColors.income : AppColors.expense).withValues(alpha: 0.25),
          Colors.white.withValues(alpha: 0.0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height * 0.75);
    path.cubicTo(
      size.width * 0.25,
      size.height * 0.85,
      size.width * 0.35,
      size.height * 0.45,
      size.width * 0.55,
      size.height * 0.50,
    );
    path.cubicTo(
      size.width * 0.75,
      size.height * 0.55,
      size.width * 0.85,
      size.height * 0.15,
      size.width,
      size.height * 0.10,
    );

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
