import 'package:flutter/material.dart';

/// Stable names are persisted locally per user, never sent to the sync API.
enum DashboardBalanceView {
  netWorth(
    'Estimasi tercatat lokal',
    'Parsial; bukan net worth lengkap',
    Icons.account_balance_rounded,
  ),
  cash('Kas', 'Tunai, bank & e-wallet', Icons.payments_outlined),
  investments('Investasi', 'Nilai portofolio', Icons.trending_up_rounded),
  debt('Utang', 'Kredit, paylater & pinjaman', Icons.credit_card_outlined);

  const DashboardBalanceView(this.label, this.description, this.icon);

  final String label;
  final String description;
  final IconData icon;
}
