import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/shell_management_scope.dart';
import '../../../core/utils/date_formatter.dart';
import '../../accounts/pages/accounts_page.dart';
import '../../categories/pages/categories_page.dart';
import '../../household/pages/household_page.dart';
import '../../investments/pages/portfolio_page.dart';
import '../../obligations/pages/obligations_page.dart';
import '../../notifications/widgets/notifications_sheet.dart';
import '../../offline/widgets/offline_mode_sheet.dart';
import '../../reports/pages/budget_page.dart';
import '../../reports/pages/reports_page.dart';
import '../../reports/pages/financial_export_page.dart';
import '../../goals/pages/goals_page.dart';
import '../../emergency_funds/pages/emergency_fund_page.dart';
import '../../bills/pages/bills_page.dart';
import '../../financial_health/pages/financial_health_page.dart';
import '../../asset_allocation/pages/asset_allocation_page.dart';
import '../../cash_flow/pages/cash_flow_page.dart';
import '../../sync/widgets/sync_conflict_modal.dart';
import '../data/devices_repository.dart';
import 'devices_page.dart';
import 'security_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  void _showSyncQueueModal(BuildContext context, AppState state) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Antrean Sinkronisasi (Sync Queue)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Menampilkan mutasi lokal yang disimpan di SQLite dan menunggu sinkronisasi ke server Express & PostgreSQL saat online.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            if (state.syncQueue.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Tidak ada mutasi yang tertunda.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: state.syncQueue.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = state.syncQueue[index];
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        item.isSynced
                            ? Icons.check_circle_rounded
                            : Icons.pending_rounded,
                        color: item.isSynced
                            ? AppColors.income
                            : AppColors.warning,
                        size: 20,
                      ),
                      title: Text(
                        item.description,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        DateFormatter.formatRelativeOrDate(item.timestamp),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: item.isSynced
                              ? AppColors.incomeLight
                              : AppColors.warningLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.isSynced ? 'Synced' : 'Pending',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: item.isSynced
                                ? AppColors.income
                                : AppColors.warning,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: state.pendingSyncCount > 0
                  ? () {
                      state.syncPendingNow();
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: AppColors.primary,
                          content: Text(
                            'Semua mutasi berhasil disinkronkan ke server!',
                          ),
                        ),
                      );
                    }
                  : null,
              child: const Text('Sinkronkan Semua Sekarang'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Lainnya & Pengaturan')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Profile Card (contoh-1.png & contoh-2.png)
              Container(
                padding: const EdgeInsets.all(18),
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
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.primary,
                      child: Text(
                        state.userName.isNotEmpty
                            ? state.userName
                                  .split(' ')
                                  .where((e) => e.isNotEmpty)
                                  .map((e) => e[0])
                                  .take(2)
                                  .join()
                            : 'U',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.userName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            state.userEmail,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accentLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${state.household.type.emoji} ${state.household.name}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.accentDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.edit_outlined,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Menu Items (Directly matching contoh-1.png & contoh-2.png)
              const Text(
                'Fitur Keuangan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),

              Material(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: AppColors.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.trending_up_rounded,
                        color: AppColors.primary,
                      ),
                      title: const Text(
                        'Aset & Portofolio Investasi',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        'Saham, kripto, reksa dana, & emas',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (context) => const PortfolioPage(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: const Icon(Icons.handshake_outlined),
                      title: const Text('Utang & Piutang'),
                      subtitle: const Text(
                        'Pokok, cicilan, bunga dan pelunasan',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => const ObligationsPage(),
                        ),
                      ),
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: const Icon(Icons.flag_outlined),
                      title: const Text('Goal & Target'),
                      subtitle: const Text('Target pribadi dan rumah tangga'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(builder: (_) => const GoalsPage()),
                      ),
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: const Icon(Icons.health_and_safety_outlined),
                      title: const Text('Dana Darurat'),
                      subtitle: const Text(
                        'Kebutuhan wajib dan cakupan dana likuid',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => const EmergencyFundPage(),
                        ),
                      ),
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: const Icon(Icons.event_repeat_outlined),
                      title: const Text('Tagihan & Jadwal'),
                      subtitle: const Text(
                        'Jatuh tempo, pengingat dan pembayaran',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(builder: (_) => const BillsPage()),
                      ),
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: const Icon(Icons.monitor_heart_outlined),
                      title: const Text('Indikator Keuangan'),
                      subtitle: const Text(
                        'Tabungan, likuiditas dan beban utang',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => const FinancialHealthPage(),
                        ),
                      ),
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: const Icon(Icons.pie_chart_outline),
                      title: const Text('Alokasi Aset'),
                      subtitle: const Text('Komposisi, target dan konsentrasi'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => const AssetAllocationPage(),
                        ),
                      ),
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: const Icon(Icons.timeline_outlined),
                      title: const Text('Proyeksi Arus Kas'),
                      subtitle: const Text(
                        'Komitmen mendatang dan potensi kekurangan kas',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(builder: (_) => const CashFlowPage()),
                      ),
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: const Icon(Icons.file_download_outlined),
                      title: const Text('Ekspor & Rekonsiliasi'),
                      subtitle: const Text(
                        'CSV transaksi dan pencocokan saldo',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => const FinancialExportPage(),
                        ),
                      ),
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: const Icon(
                        Icons.bar_chart_rounded,
                        color: AppColors.primary,
                      ),
                      title: const Text(
                        'Laporan & Analisis',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        'Grafik pemasukan vs pengeluaran & breakdown kategori',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (context) => const ReportsPage(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: const Icon(
                        Icons.pie_chart_outline_rounded,
                        color: AppColors.primary,
                      ),
                      title: const Text(
                        'Budget & Perencanaan',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        'Pantau batas pengeluaran kategori',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (context) => const BudgetPage(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: const Icon(
                        Icons.account_balance_rounded,
                        color: AppColors.primary,
                      ),
                      title: const Text(
                        'Kelola Akun & Kantong (Pockets)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        'Rekening bank, kas dompet, nested kantong',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        ShellManagementScope.open(
                          context,
                          const AccountsPage(),
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: const Icon(
                        Icons.category_rounded,
                        color: AppColors.primary,
                      ),
                      title: const Text(
                        'Kelola Kategori Transaksi',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${state.categories.length} kategori pemasukan & pengeluaran',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        ShellManagementScope.open(
                          context,
                          const CategoriesPage(),
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: const Icon(
                        Icons.groups_rounded,
                        color: AppColors.primary,
                      ),
                      title: const Text(
                        'Grup Finansial & Kolaborasi',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${state.households.length} grup aktif: ${state.household.type.emoji} ${state.household.name}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (context) => const HouseholdPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Offline-First & Sync Control Center
              const Text(
                'Offline-First & Sinkronisasi',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),

              Material(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: AppColors.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    SwitchListTile(
                      value: state.isOfflineMode,
                      activeThumbColor: AppColors.warning,
                      title: const Text(
                        'Simulasi Mode Offline',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        'Simulasikan transaksi tanpa koneksi (data tersimpan di database lokal SQLite Drift).',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      onChanged: (val) {
                        state.toggleOfflineMode();
                        if (state.isOfflineMode) {
                          OfflineModeSheet.show(context);
                        }
                      },
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: Icon(
                        Icons.cloud_sync_rounded,
                        color: state.pendingSyncCount > 0
                            ? AppColors.warning
                            : AppColors.primary,
                      ),
                      title: const Text(
                        'Status Antrean Sync',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${state.pendingSyncCount} mutasi menunggu sinkronisasi',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _showSyncQueueModal(context, state),
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: Icon(
                        Icons.sync_problem_rounded,
                        color: state.conflictCount > 0
                            ? AppColors.warning
                            : AppColors.primary,
                      ),
                      title: const Text(
                        'Resolusi Konflik Data',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        'Penyelesaian konflik versi server vs lokal',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (state.conflictCount > 0) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.warningLight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${state.conflictCount} Konflik',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.warning,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                      onTap: () => SyncConflictModal.show(context),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Pengaturan Akun & Keamanan
              const Text(
                'Pengaturan Akun & Keamanan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),

              Material(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: AppColors.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.security_rounded,
                        color: AppColors.primary,
                      ),
                      title: const Text(
                        'Keamanan & Sesi',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        'Ingat saya & logout perangkat ini',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (context) => SecurityPage(
                            auth: state.auth,
                            onLogout: state.logout,
                          ),
                        ),
                      ),
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: const Icon(
                        Icons.devices_rounded,
                        color: AppColors.primary,
                      ),
                      title: const Text(
                        'Device Terdaftar',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        'Lihat perangkat terdaftar untuk sinkronisasi',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (context) => DevicesPage(
                            repository: DevicesRepository(
                              client: state.auth.client,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: const Icon(
                        Icons.notifications_none_rounded,
                        color: AppColors.primary,
                      ),
                      title: const Text(
                        'Notifikasi & Peringatan',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        'Notifikasi transaksi bersama & pengingat budget',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => NotificationsSheet.show(context),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Panduan & Onboarding Aplikasi
              const Text(
                'Panduan & Informasi Aplikasi',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),

              Material(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: AppColors.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.auto_stories_rounded,
                        color: AppColors.primary,
                      ),
                      title: const Text(
                        'Lihat Panduan Onboarding',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        'Fitur multi-grup, offline-first & manajemen kekayaan',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => state.showOnboarding(),
                    ),
                    ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: const Text('Lisensi sumber terbuka'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => showLicensePage(
                        context: context,
                        applicationName: 'Vesper',
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Logout (PRD 5.10: revoke refresh token + clear secure storage + clear investment cache)
              Material(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: AppColors.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  leading: const Icon(
                    Icons.logout_rounded,
                    color: AppColors.expense,
                  ),
                  title: const Text(
                    'Logout',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.expense,
                    ),
                  ),
                  subtitle: const Text(
                    'Hapus sesi lokal & coba cabut sesi server perangkat ini',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  onTap: () {
                    showDialog<void>(
                      context: context,
                      builder: (dialogCtx) => AlertDialog(
                        title: const Text('Logout?'),
                        content: const Text(
                          'Sesi akan berakhir. Data lokal tetap tersimpan di perangkat ini. Anda perlu login ulang untuk sync.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(dialogCtx).pop(),
                            child: const Text('Batal'),
                          ),
                          TextButton(
                            onPressed: () async {
                              Navigator.of(dialogCtx).pop();
                              final messenger = ScaffoldMessenger.of(context);
                              var failed = false;
                              try {
                                await state.logout();
                              } catch (_) {
                                failed = true;
                              }
                              messenger.showSnackBar(
                                SnackBar(
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: AppColors.primary,
                                  content: Text(
                                    failed
                                        ? 'Sesi lokal dihapus. Pencabutan sesi server tidak dapat dikonfirmasi.'
                                        : 'Anda telah logout. Silakan login kembali.',
                                  ),
                                ),
                              );
                            },
                            child: const Text(
                              'Logout',
                              style: TextStyle(
                                color: AppColors.expense,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
