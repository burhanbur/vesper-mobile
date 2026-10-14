import 'package:flutter/material.dart';

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
        icon: const Icon(Icons.chevron_left),
      ),
      Expanded(
        child: Text(
          DateFormatter.formatMonthYear(period.start),
          textAlign: TextAlign.center,
        ),
      ),
      IconButton(
        tooltip: 'Bulan berikutnya',
        onPressed: () => onChanged(period.shift(1)),
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  );
}
