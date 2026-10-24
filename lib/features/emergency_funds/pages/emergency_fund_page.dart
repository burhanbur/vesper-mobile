import 'package:flutter/material.dart';

import '../../../app/app_state.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../app/theme/app_colors.dart';
import '../../goals/data/goals_repository.dart';
import '../data/emergency_fund_controller.dart';
import '../data/emergency_fund_repository.dart';

class EmergencyFundPage extends StatefulWidget {
  const EmergencyFundPage({super.key});
  @override
  State<EmergencyFundPage> createState() => _EmergencyFundPageState();
}

class _EmergencyFundPageState extends State<EmergencyFundPage> {
  EmergencyFundController? controller;
  String? message;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppStateScope.of(context);
    final source = state.repository;
    final user = state.currentUserId;
    if (source == null || user.isEmpty || source.userId != user) {
      controller?.dispose();
      controller = null;
      message = null;
    } else if (!identical(controller?.repository.source, source)) {
      controller?.dispose();
      message = null;
      controller = EmergencyFundController(
        EmergencyFundRepository(source),
        () =>
            mounted &&
            identical(state.repository, source) &&
            user == state.currentUserId,
        state.emergencyPlanSaved,
      );
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  Future<void> configure() async {
    final active = controller!;
    final repo = active.repository;
    final plan = repo.plan;
    var mode = '${plan?['baseline_mode'] ?? 'MANUAL'}';
    var history = plan?['history_months'] as int? ?? 3;
    String? goalId = plan?['goal_id'] as String?;
    if (!repo.privateGoals.any((g) => g['id'] == goalId)) goalId = null;
    final accountIds = (plan?['account_ids'] as List? ?? const [])
        .cast<String>()
        .where((id) => repo.accounts.any((a) => a['id'] == id))
        .toSet();
    final categoryIds = (plan?['category_ids'] as List? ?? const [])
        .cast<String>()
        .where((id) => repo.categories.any((c) => c['id'] == id))
        .toSet();
    final manual = TextEditingController(
      text: plan?['manual_baseline'] as String? ?? '',
    );
    final months = TextEditingController(
      text: '${plan?['coverage_months'] ?? 6}',
    );
    String? error;
    bool saved = false;
    try {
      final route = DialogRoute<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, update) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            actionsOverflowButtonSpacing: 8,
            backgroundColor: Colors.white,
            title: const Text(
              'Atur dana darurat',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppColors.textPrimary,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Rencana pribadi dalam IDR. Pilih dana yang memang dapat dipakai saat darurat. Pengaturan ini tidak memindahkan uang.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: mode,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Baseline pengeluaran wajib',
                      labelStyle: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'MANUAL',
                        child: Text(
                          'Manual — nominal per bulan',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'HISTORY',
                        child: Text(
                          'Estimasi dari histori',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    onChanged: (v) => update(() => mode = v!),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: manual,
                    enabled: mode == 'MANUAL',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Pengeluaran wajib per bulan (IDR)',
                      labelStyle: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: months,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Target cakupan (1–60 bulan)',
                      labelStyle: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    initialValue: history,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Jendela histori',
                      labelStyle: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    items: [
                      for (final n in [3, 6, 12])
                        DropdownMenuItem(
                          value: n,
                          child: Text(
                            '$n bulan kalender penuh',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => update(() => history = v!),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Kategori pengeluaran wajib',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Dipakai dalam mode histori. Pilih kebutuhan wajib seperti makan, hunian, kesehatan dan utilitas. Bulan tanpa transaksi ikut dihitung nol.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final c in repo.categories)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${c['name']}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      value: categoryIds.contains(c['id']),
                      onChanged: (v) => update(() {
                        if (v == true) {
                          categoryIds.add(c['id'] as String);
                        } else {
                          categoryIds.remove(c['id']);
                        }
                      }),
                    ),
                  if (repo.categories.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        'Belum ada kategori pengeluaran milik sendiri. Baseline manual tetap tersedia.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),
                  const Text(
                    'Akun/kantong likuid yang dihitung',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Hanya kas IDR milik sendiri tanpa subakun/pemetaan utang. Investasi dan akun anggota lain tidak termasuk. Alokasi goal lain dikurangkan.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final a in repo.accounts)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${a['name']}${a['is_visible'] == false ? ' (tersembunyi)' : ''}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      value: accountIds.contains(a['id']),
                      onChanged: (v) => update(() {
                        if (v == true) {
                          accountIds.add(a['id'] as String);
                        } else {
                          accountIds.remove(a['id']);
                        }
                      }),
                    ),
                  if (repo.accounts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        'Belum ada akun kas/kantong IDR yang memenuhi syarat.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: goalId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Goal pribadi dana darurat (opsional)',
                      labelStyle: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text(
                          'Hanya kas yang belum dialokasikan',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      for (final g in repo.privateGoals)
                        DropdownMenuItem(
                          value: g['id'] as String,
                          child: Text(
                            '${g['name']}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => update(() => goalId = v),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Alokasi goal terpilih yang didukung saldo ikut dihitung, hanya dari akun yang dicentang. Target goal tidak diubah. Pilihan lama yang tidak memenuhi syarat tidak ikut saat disimpan.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(ctx).colorScheme.error,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: saved
                    ? null
                    : () {
                        final ok = active.save(
                          () => repo.save(
                            mode: mode,
                            manualBaseline: manual.text,
                            coverageMonths:
                                int.tryParse(months.text.trim()) ?? 0,
                            historyMonths: history,
                            accountIds: accountIds.toList()..sort(),
                            categoryIds: categoryIds.toList()..sort(),
                            goalId: goalId,
                          ),
                        );
                        if (ok) {
                          saved = true;
                          Navigator.pop(ctx);
                        } else {
                          update(() => error = active.error);
                        }
                      },
                child: const Text('Simpan lokal'),
              ),
            ],
          ),
        ),
      );
      await Navigator.of(context).push(route);
      await route.completed;
    } finally {
      manual.dispose();
      months.dispose();
    }
    if (mounted && identical(controller, active)) {
      setState(() {
        if (saved) {
          message = 'Rencana tersimpan lokal; sinkronisasi mengikuti koneksi.';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final active = controller;
    if (active == null || !active.isCurrent()) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Dana Darurat'),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: const Center(
          child: Text(
            'Masuk untuk membuka rencana dana darurat.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    final repo = active.repository;
    final plan = repo.plan;
    EmergencyAssessment? result;
    String? assessmentError;
    if (plan != null) {
      try {
        result = repo.assess(plan, timeZone: state.timeZone);
      } catch (_) {
        assessmentError = 'Data perhitungan belum valid. Tinjau pengaturan dan sinkronkan ulang.';
      }
    }
    final hidden = state.isBalanceHidden;
    String money(BigInt? value) => value == null
        ? 'Belum tersedia'
        : hidden
        ? '••••••'
        : '${goalMoney(value)} IDR';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Dana Darurat'),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        actions: [
          IconButton(
            tooltip: 'Sinkronkan rencana',
            onPressed: state.loading
                ? null
                : () async {
                    await state.refresh();
                    if (mounted) setState(() {});
                  },
            icon: const Icon(Icons.sync),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header Intro Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.accentLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Cakupan kebutuhan wajib',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Perencanaan pribadi. Kas belum dialokasikan ditambah dana dari goal darurat terpilih; dana yang sama dihitung sekali. Hasil memakai data lokal dan bukan jaminan likuiditas bank.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                if (!repo.complete)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Sinkronkan untuk memuat rencana dari perangkat lain. Pengaturan baru tetap dapat disimpan offline.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.warning,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  onPressed: configure,
                  icon: const Icon(Icons.tune, size: 18),
                  label: Text(
                    plan == null ? 'Atur dana darurat' : 'Ubah pengaturan',
                  ),
                ),
              ],
            ),
          ),

          if (plan == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Belum ada rencana. Masukkan pengeluaran wajib per bulan dan pilih dana likuid.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
          if (assessmentError != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                assessmentError,
                style: const TextStyle(color: AppColors.expense),
              ),
            ),

          if (result case final r?) ...[
            const SizedBox(height: 16),
            // Assessment Hero Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      plan!['baseline_mode'] == 'MANUAL'
                          ? 'Baseline manual — diisi sendiri'
                          : 'Baseline estimasi — histori lokal',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Cakupan saat ini: ${r.coverageHundredths == null
                        ? 'Belum tersedia'
                        : hidden
                        ? '••••••'
                        : '${r.coverageHundredths! ~/ BigInt.from(100)}.${(r.coverageHundredths! % BigInt.from(100)).toString().padLeft(2, '0')} bulan'}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pengeluaran wajib per bulan: ${money(r.baseline)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Target ${plan['coverage_months']} bulan: ${money(r.target)}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Dana likuid yang memenuhi syarat: ${money(r.liquid)}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Kekurangan target: ${money(r.remaining)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: (r.remaining != null && r.remaining! > BigInt.zero)
                          ? AppColors.expense
                          : AppColors.income,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Cakupan ditampilkan dengan dua desimal dibulatkan ke bawah. Baseline nol/tidak diketahui tidak dianggap cukup atau tak terbatas.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      height: 1.35,
                    ),
                  ),
                  if (plan['baseline_mode'] == 'HISTORY') ...[
                    const Divider(height: 20),
                    Text(
                      'Periode: ${DateFormatter.formatShort(state.timeZone.at(r.historyStart))} sampai ${DateFormatter.formatShort(state.timeZone.at(r.historyEnd.subtract(const Duration(microseconds: 1))))} (${r.historyMonths} bulan penuh).',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Rata-rata total pengeluaran kategori wajib dibagi semua bulan dalam jendela, dibulatkan ke atas ke sen. Bulan berjalan, transfer dan pembelian investasi tanpa kategori tidak dihitung.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Kategori: ${repo.categories.where((c) => (plan['category_ids'] as List).contains(c['id'])).map((c) => c['name']).join(', ')}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),
            // Breakdown card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Rincian dana yang dihitung',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final a in r.accounts)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                a.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                money(a.total),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Kas bebas alokasi: ${money(a.free)}\nAlokasi goal darurat yang didukung saldo: ${money(a.earmarked)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              height: 1.3,
                            ),
                          ),
                          const Divider(height: 14),
                        ],
                      ),
                    ),
                  const Text(
                    'Investasi/akun nonkas, mata uang selain IDR, akun pihak lain, akun induk dan akun terikat utang dikecualikan. Akun tersembunyi hanya ikut jika dipilih. Alokasi goal lain, termasuk goal selesai yang belum ditarik, tidak ikut.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      height: 1.35,
                    ),
                  ),
                  for (final warning in r.warnings)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 15,
                            color: AppColors.warning,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              warning,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.warning,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],

          if (message != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                message!,
                style: const TextStyle(
                  color: AppColors.income,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          if (active.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                active.error!,
                style: const TextStyle(color: AppColors.expense),
              ),
            ),
          if (state.dataError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                state.dataError!,
                style: const TextStyle(color: AppColors.expense),
              ),
            ),

          for (final item in repo.queue)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rencana: ${item['status']} — ${item['error'] ?? 'menunggu sinkronisasi'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (['conflict', 'rejected'].contains(item['status']))
                    Wrap(
                      children: [
                        TextButton(
                          onPressed: () {
                            active.save(
                              () => repo.recover(item['id'] as String),
                            );
                            setState(() {});
                          },
                          child: const Text(
                            'Coba ulang dengan validasi server',
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            active.save(
                              () => repo.recover(
                                item['id'] as String,
                                discard: true,
                              ),
                            );
                            setState(() {});
                          },
                          child: const Text(
                            'Gunakan server / batalkan perubahan lokal',
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
