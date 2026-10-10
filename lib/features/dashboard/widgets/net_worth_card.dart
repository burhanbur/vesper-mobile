import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';

class NetWorthCard extends StatelessWidget {
  const NetWorthCard({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final isHidden = state.isBalanceHidden;

    final growth = state.monthGrowthPercentage;
    final isPositive = growth > 0.0001;
    final isNegative = growth < -0.0001;

    final Color badgeColor;
    final Color badgeBg;
    final Color badgeBorder;
    final IconData badgeIcon;
    final String badgeText;
    final Color sparklineColor;

    if (isPositive) {
      badgeColor = AppColors.accent;
      badgeBg = AppColors.accent.withValues(alpha: 0.18);
      badgeBorder = AppColors.accent.withValues(alpha: 0.32);
      badgeIcon = Icons.arrow_upward_rounded;
      badgeText = '+${growth.toStringAsFixed(1)}% bulan ini';
      sparklineColor = AppColors.accent;
    } else if (isNegative) {
      badgeColor = const Color(0xFFFF8A80);
      badgeBg = AppColors.expense.withValues(alpha: 0.2);
      badgeBorder = const Color(0xFFFF8A80).withValues(alpha: 0.32);
      badgeIcon = Icons.arrow_downward_rounded;
      badgeText = '${growth.toStringAsFixed(1)}% bulan ini';
      sparklineColor = const Color(0xFFFF8A80);
    } else {
      badgeColor = AppColors.sageMuted;
      badgeBg = Colors.white.withValues(alpha: 0.08);
      badgeBorder = Colors.white.withValues(alpha: 0.14);
      badgeIcon = Icons.remove_rounded;
      badgeText = '0.0% bulan ini';
      sparklineColor = AppColors.sageMuted.withValues(alpha: 0.5);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [
              AppColors.primaryGradientStart,
              AppColors.primaryGradientEnd,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Decorative background circles
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.04),
                ),
              ),
            ),
            Positioned(
              left: -20,
              bottom: -20,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withValues(alpha: 0.06),
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Label & Eye toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Total Kekayaan',
                            style: TextStyle(
                              color: AppColors.sageMuted,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: state.toggleHideBalance,
                            child: Icon(
                              isHidden
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: AppColors.sageMuted,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                      // Growth Badge (dinamis berdasarkan persentase bulan ini)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: badgeBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              badgeIcon,
                              size: 12,
                              color: badgeColor,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              badgeText,
                              style: TextStyle(
                                color: badgeColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Total Amount in Rupiah + Sparkline wave
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        isHidden
                            ? 'Rp •••••••••'
                            : CurrencyFormatter.formatRupiah(state.totalNetWorth),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      // Mini Sparkline curve
                      SizedBox(
                        width: 72,
                        height: 28,
                        child: CustomPaint(
                          painter: _SparklinePainter(
                            points: state.monthNetWorthTrend,
                            lineColor: sparklineColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Divider inside card
                  Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                  const SizedBox(height: 14),

                  // Bottom stats: Pemasukan & Pengeluaran
                  Row(
                    children: [
                      // Pemasukan
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.18),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.arrow_downward_rounded,
                                color: AppColors.accent,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Pemasukan',
                                    style: TextStyle(
                                      color: AppColors.sageMuted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isHidden
                                        ? '••••••'
                                        : CurrencyFormatter.formatRupiah(
                                            state.monthIncome,
                                            withSign: true,
                                            isIncome: true,
                                          ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Vertical Divider
                      Container(
                        width: 1,
                        height: 30,
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                      const SizedBox(width: 14),

                      // Pengeluaran
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: AppColors.expense.withValues(
                                  alpha: 0.22,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.arrow_upward_rounded,
                                color: Color(0xFFFF8A80),
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Pengeluaran',
                                    style: TextStyle(
                                      color: AppColors.sageMuted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isHidden
                                        ? '••••••'
                                        : CurrencyFormatter.formatRupiah(
                                            state.monthExpense,
                                            withSign: true,
                                            isExpense: true,
                                          ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
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
          ],
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> points;
  final Color lineColor;

  const _SparklinePainter({
    required this.points,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final minVal = points.reduce((a, b) => a < b ? a : b);
    final maxVal = points.reduce((a, b) => a > b ? a : b);

    // If perfectly flat or single point, draw subtle horizontal line through center
    if (minVal == maxVal || points.length == 1) {
      canvas.drawLine(
        Offset(0, size.height * 0.5),
        Offset(size.width, size.height * 0.5),
        paint,
      );
      return;
    }

    final path = Path();
    const padding = 3.0;
    final usableHeight = size.height - (padding * 2);

    for (var i = 0; i < points.length; i++) {
      final x = (i / (points.length - 1)) * size.width;
      final normalized = (points[i] - minVal) / (maxVal - minVal);
      final y = padding + usableHeight - (normalized * usableHeight);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        final prevX = ((i - 1) / (points.length - 1)) * size.width;
        final prevNorm = (points[i - 1] - minVal) / (maxVal - minVal);
        final prevY = padding + usableHeight - (prevNorm * usableHeight);
        final midX = (prevX + x) / 2;
        path.cubicTo(midX, prevY, midX, y, x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.lineColor != lineColor || oldDelegate.points != points;
}
