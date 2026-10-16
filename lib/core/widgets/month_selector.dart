import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../utils/date_formatter.dart';
import '../utils/transaction_period.dart';

class MonthSelector extends StatelessWidget {
  const MonthSelector({
    super.key,
    required this.period,
    required this.onChanged,
  });

  final TransactionPeriod period;
  final ValueChanged<TransactionPeriod> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        tooltip: 'Bulan sebelumnya',
        onPressed: () => onChanged(period.shift(-1)),
        icon: const Icon(Icons.chevron_left_rounded),
      ),
      Expanded(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.calendar_month_rounded,
              size: 18,
              color: AppColors.primary,
            ),
            const SizedBox(width: 8),
            Text(
              DateFormatter.formatMonthYear(period.start),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
      IconButton(
        tooltip: 'Bulan berikutnya',
        onPressed: () => onChanged(period.shift(1)),
        icon: const Icon(Icons.chevron_right_rounded),
      ),
    ],
  );
}
