import 'package:flutter/material.dart';

/// Stable names are persisted locally per user, never sent to the sync API.
enum DashboardBalanceView {
  netWorth(
    'Total Kekayaan Bersih',
    'Kas + investasi − utang',
    Icons.account_balance_rounded,
  ),
  cash('Total Kas', 'Tunai, bank, dan dompet digital', Icons.payments_outlined),
  investments(
    'Total Investasi',
    'Nilai portofolio investasi',
    Icons.trending_up_rounded,
  ),
  debt(
    'Total Utang',
    'Kartu kredit, paylater, dan pinjaman',
    Icons.credit_card_outlined,
  );

  const DashboardBalanceView(this.label, this.description, this.icon);

  final String label;
  final String description;
  final IconData icon;
}
