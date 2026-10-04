import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../models/investment.dart';
import '../widgets/investment_trade_modal.dart';
import '../widgets/update_price_modal.dart';
import 'investment_detail_page.dart';

class InvestmentsPage extends StatefulWidget {
  const InvestmentsPage({super.key});

  @override
  State<InvestmentsPage> createState() => _InvestmentsPageState();
}

class _InvestmentsPageState extends State<InvestmentsPage> {
  int _selectedSegment = 0; // 0: Total, 1: Detail (contoh-1.png & contoh-2.png)

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
    final investments = state.investments;
    final totalInvValue = state.totalInvestmentValue;
    final isHidden = state.isBalanceHidden;
    final isOffline = state.isOfflineMode;

    // Fixed physical asset approximations from design reference (Properti & Kendaraan)
    const int propertyValue = 250000000;
    const int vehicleValue = 20000000;
    final int cashValue = state.totalLiquidCash;
    final int grandTotalAssets = cashValue + totalInvValue + propertyValue + vehicleValue;

    // Need update prompt check per PRD 4.7
    final needsPriceUpdate = investments.where((inv) => !inv.isPriceUpdatedToday).toList();


    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Aset & Kekayaan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppColors.primary),
            onPressed: () => InvestmentTradeModal.show(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Segmented Toggle: Total vs Detail (contoh-1.png & contoh-2.png)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedSegment = 0),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _selectedSegment == 0 ? AppColors.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              'Total',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _selectedSegment == 0 ? Colors.white : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedSegment = 1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _selectedSegment == 1 ? AppColors.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              'Detail',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _selectedSegment == 1 ? Colors.white : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Total Aset Hero Card (contoh-1.png & contoh-2.png)
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Aset',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.incomeLight,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.arrow_upward_rounded, size: 12, color: AppColors.income),
                              SizedBox(width: 3),
                              Text(
                                '+ 6,2% bulan ini',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.income,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isHidden
                              ? 'Rp •••••••••'
                              : CurrencyFormatter.formatRupiah(grandTotalAssets),
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(
                          width: 60,
                          height: 24,
                          child: CustomPaint(
                            painter: _MiniSparklinePainter(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Light Prompt: Update Daily Price per PRD 4.7
              if (needsPriceUpdate.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.accentLight.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.tips_and_updates_outlined, color: AppColors.accentDark, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Harga ${needsPriceUpdate.first.name} belum diperbarui hari ini.',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => UpdatePriceModal.show(context, needsPriceUpdate.first),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text(
                          'Update',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Offline Warning Notice for Investing write operations (PRD 4.7 & 8)
              if (isOffline) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.warningLight.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Mode Offline: Portofolio ditampilkan dari cache lokal. Aksi beli/jual butuh internet.',
                          style: TextStyle(fontSize: 11, color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Rincian Aset (Asset Breakdown in contoh-1.png & contoh-2.png)
              if (_selectedSegment == 0) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Rincian Aset',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Total: ${CurrencyFormatter.formatCompact(grandTotalAssets)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      _buildAssetCategoryRow(
                        name: 'Kas & Rekening Bank',
                        amount: cashValue,
                        percentage: (cashValue / grandTotalAssets) * 100,
                        icon: Icons.account_balance_wallet_rounded,
                        color: AppColors.primary,
                      ),
                      const Divider(height: 24, color: AppColors.divider),
                      _buildAssetCategoryRow(
                        name: 'Investasi Pasar Modal & Kripto',
                        amount: totalInvValue,
                        percentage: (totalInvValue / grandTotalAssets) * 100,
                        icon: Icons.show_chart_rounded,
                        color: AppColors.investment,
                      ),
                      const Divider(height: 24, color: AppColors.divider),
                      _buildAssetCategoryRow(
                        name: 'Properti & Rumah',
                        amount: propertyValue,
                        percentage: (propertyValue / grandTotalAssets) * 100,
                        icon: Icons.home_rounded,
                        color: const Color(0xFFD97706),
                      ),
                      const Divider(height: 24, color: AppColors.divider),
                      _buildAssetCategoryRow(
                        name: 'Kendaraan Bermotor',
                        amount: vehicleValue,
                        percentage: (vehicleValue / grandTotalAssets) * 100,
                        icon: Icons.directions_car_rounded,
                        color: AppColors.transfer,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Daftar Instrumen Investasi (Holdings)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Portofolio Instrumen',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '${investments.length} Aset',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: investments.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final asset = investments[index];
                  final assetColor = _getAssetColor(asset.type);

                  return InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (context) => InvestmentDetailPage(assetId: asset.id),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: assetColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  _getAssetIcon(asset.type),
                                  color: assetColor,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      asset.name,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${asset.symbol} • ${asset.quantityDisplay}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textMuted,
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
                                        : CurrencyFormatter.formatRupiah(asset.totalCurrentValue),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: asset.isProfitable
                                          ? AppColors.incomeLight
                                          : AppColors.expenseLight,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${asset.isProfitable ? '+' : ''}${asset.returnPercentage.toStringAsFixed(1)}%',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: asset.isProfitable
                                            ? AppColors.income
                                            : AppColors.expense,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Modal: ${CurrencyFormatter.formatCompact(asset.totalInvestedValue)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                Text(
                                  'Gain: ${CurrencyFormatter.formatRupiah(asset.unrealizedGainLoss, withSign: true)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: asset.isProfitable
                                        ? AppColors.income
                                        : AppColors.expense,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),

              // Button "+ Catat Transaksi Investasi"
              ElevatedButton.icon(
                onPressed: () => InvestmentTradeModal.show(context),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('Catat Transaksi Investasi Baru'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssetCategoryRow({
    required String name,
    required int amount,
    required double percentage,
    required IconData icon,
    required Color color,
  }) {
    final state = AppStateScope.of(context);
    final isHidden = state.isBalanceHidden;

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isHidden ? '••••••' : CurrencyFormatter.formatRupiah(amount),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Text(
          '${percentage.toStringAsFixed(1)}%',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _MiniSparklinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.income
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(0, size.height * 0.7);
    path.cubicTo(
      size.width * 0.35,
      size.height * 0.9,
      size.width * 0.6,
      size.height * 0.2,
      size.width,
      size.height * 0.15,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
