import '../../../core/network/api_client.dart';
import '../../../core/utils/app_time_zone.dart';
import '../../../database/transaction_query.dart';
import '../../goals/data/goals_repository.dart';
import '../../sync/data/finance_repository.dart';

class EmergencyAccountFunds {
  final String id, name;
  final BigInt free, earmarked;
  BigInt get total => free + earmarked;
  const EmergencyAccountFunds(this.id, this.name, this.free, this.earmarked);
}

class EmergencyAssessment {
  final BigInt? baseline, liquid, target, remaining, coverageHundredths;
  final List<EmergencyAccountFunds> accounts;
  final List<String> warnings;
  final DateTime historyStart, historyEnd;
  final int monthsWithExpenses, historyMonths;
  const EmergencyAssessment({
    required this.baseline,
    required this.liquid,
    required this.target,
    required this.remaining,
    required this.coverageHundredths,
    required this.accounts,
    required this.warnings,
    required this.historyStart,
    required this.historyEnd,
    required this.monthsWithExpenses,
    required this.historyMonths,
  });
}

class EmergencyFundRepository {
  final FinanceRepository source;
  late final GoalsRepository goals;
  EmergencyFundRepository(this.source) {
    goals = GoalsRepository(source);
    if (source.state['emergency_plan_coverage'] == null) {
      source.atomic(() {
        source.state['emergency_plan_coverage'] = {
          'schema': 1,
          'user_id': source.userId,
          'complete': false,
        };
        if (!source.isSyncing) source.state['cursor'] = '0';
      });
    }
  }
  Map<String, dynamic>? get plan => source
      .rows('emergency_plans')
      .where((p) => p['user_id'] == source.userId && p['deleted_at'] == null)
      .firstOrNull;
  List<Map<String, dynamic>> get accounts =>
      goals.cashAccounts.where((a) => a['currency'] == 'IDR').toList();
  List<Map<String, dynamic>> get categories => source
      .rows('categories')
      .where(
        (c) =>
            c['user_id'] == source.userId &&
            c['type'] == 'EXPENSE' &&
            c['deleted_at'] == null,
      )
      .toList();
  List<Map<String, dynamic>> get privateGoals => goals.goals
      .where(
        (g) =>
            g['user_id'] == source.userId &&
            g['group_id'] == null &&
            g['currency'] == 'IDR',
      )
      .toList();
  List<Map> get queue => source.outbox
      .where((e) => e['entity_type'] == 'emergency_plans')
      .cast<Map>()
      .toList();
  bool get complete =>
      source.state['emergency_plan_coverage'] is Map &&
      source.state['emergency_plan_coverage']['complete'] == true;

  void save({
    required String mode,
    required String manualBaseline,
    required int coverageMonths,
    required int historyMonths,
    required List<String> accountIds,
    required List<String> categoryIds,
    String? goalId,
  }) {
    if (source.isSyncing) {
      throw const ApiFailure('Tunggu sinkronisasi selesai.');
    }
    if (!['MANUAL', 'HISTORY'].contains(mode) ||
        coverageMonths < 1 ||
        coverageMonths > 60 ||
        ![3, 6, 12].contains(historyMonths) ||
        accountIds.length > 100 ||
        categoryIds.length > 200 ||
        accountIds.toSet().length != accountIds.length ||
        categoryIds.toSet().length != categoryIds.length) {
      throw const ApiFailure(
        'Periksa mode baseline, bulan cakupan dan pilihan.',
      );
    }
    final manual = mode == 'MANUAL' ? goalMinor(manualBaseline.trim()) : null;
    if (manual != null &&
        (manual <= BigInt.zero ||
            manual * BigInt.from(coverageMonths) >
                goalMinor('999999999999999999.99'))) {
      throw const ApiFailure(
        'Baseline harus positif dan target dalam batas nominal.',
      );
    }
    if (!accountIds.every((id) => accounts.any((a) => a['id'] == id)) ||
        !categoryIds.every((id) => categories.any((c) => c['id'] == id)) ||
        (goalId != null && !privateGoals.any((g) => g['id'] == goalId))) {
      throw const ApiFailure(
        'Pilih akun, kategori dan goal pribadi IDR milik sendiri yang aktif.',
      );
    }
    final current = plan;
    source.mutate(
      'emergency_plans',
      current == null ? 'CREATE' : 'UPDATE',
      {
        'currency': 'IDR',
        'baseline_mode': mode,
        'manual_baseline': manual == null ? null : goalMoney(manual),
        'coverage_months': coverageMonths,
        'history_months': historyMonths,
        'account_ids': accountIds,
        'category_ids': categoryIds,
        'goal_id': goalId,
      },
      id: current?['id'] as String?,
      local: {
        'created_at':
            current?['created_at'] ?? DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  void recover(String queueId, {bool discard = false}) {
    if (source.isSyncing) {
      throw const ApiFailure('Tunggu sinkronisasi selesai.');
    }
    final item = queue.where((e) => e['id'] == queueId).firstOrNull;
    if (item == null || !['rejected', 'conflict'].contains(item['status'])) {
      throw const ApiFailure(
        'Hanya perubahan yang ditolak/konflik dapat diselesaikan.',
      );
    }
    source.atomic(() {
      if (discard) {
        item['server_data'] ??= item['before'];
        source.resolve(queueId, useMine: false);
      } else if (item['status'] == 'conflict' &&
          (item['server_data'] as Map?)?['version'] != null) {
        if (item['operation'] == 'CREATE') {
          throw const ApiFailure(
            'Gunakan versi server sebelum mengubah rencana.',
          );
        }
        source.resolve(queueId, useMine: true);
      } else {
        item['status'] = 'pending';
        item.remove('error');
      }
    });
  }

  EmergencyAssessment assess(
    Map<String, dynamic> config, {
    DateTime? now,
    AppTimeZone? timeZone,
  }) {
    final instant = (now ?? DateTime.now()).toUtc();
    final current = timeZone?.at(instant) ?? instant;
    final calendarEnd = DateTime.utc(current.year, current.month, 1);
    final end = timeZone?.fromCalendar(calendarEnd) ?? calendarEnd;
    final months = config['history_months'] as int;
    final calendarStart = DateTime.utc(current.year, current.month - months, 1);
    final start = timeZone?.fromCalendar(calendarStart) ?? calendarStart;
    final warnings = <String>[];
    BigInt? baseline;
    var monthsWithExpenses = 0;
    if (config['baseline_mode'] == 'MANUAL') {
      baseline = goalMinor('${config['manual_baseline']}');
      if (baseline == BigInt.zero) baseline = null;
    } else {
      warnings.add(
        'Baseline histori adalah estimasi dari transaksi lokal, termasuk perubahan yang belum tersinkron. Kelengkapan rekening koran tidak dapat dipastikan.',
      );
      final selected = (config['category_ids'] as List).cast<String>();
      final eligible = categories
          .where((c) => selected.contains(c['id']))
          .map((c) => c['id'])
          .toSet();
      if (eligible.length != selected.length) {
        warnings.add(
          'Kategori yang hilang/tidak lagi memenuhi syarat diabaikan; tinjau pilihan.',
        );
      }
      if (!source.hasTransactionSnapshot) {
        warnings.add(
          'Riwayat transaksi belum lengkap di perangkat. Sinkronkan atau gunakan baseline manual.',
        );
      } else if (eligible.isEmpty) {
        warnings.add(
          'Pilih kategori pengeluaran wajib atau gunakan baseline manual.',
        );
      } else {
        final owned = {
          for (final a in source.rows('accounts'))
            if (a['user_id'] == source.userId && a['currency'] == 'IDR')
              a['id']: a,
        };
        var total = BigInt.zero;
        var missingAccounts = 0;
        final activeMonths = <String>{};
        TransactionCursor? cursor;
        do {
          final page = source.transactionPage(
            TransactionQuery(
              start: start,
              end: end,
              type: 'EXPENSE',
              after: cursor,
            ),
          );
          for (final row in page.rows) {
            if (row['deleted_at'] != null ||
                !eligible.contains(row['category_id'])) {
              continue;
            }
            if (!owned.containsKey(row['account_id'])) {
              missingAccounts++;
              continue;
            }
            final amount = goalMinor('${row['amount']}');
            total += amount;
            if (amount > BigInt.zero) {
              activeMonths.add(
                (timeZone?.at(DateTime.parse('${row['transacted_at']}')) ??
                        DateTime.parse('${row['transacted_at']}').toUtc())
                    .toIso8601String()
                    .substring(0, 7),
              );
            }
          }
          cursor = page.next;
        } while (cursor != null);
        monthsWithExpenses = activeMonths.length;
        if (missingAccounts > 0) {
          warnings.add(
            'Transaksi dari akun yang tidak tersedia/milik pihak lain tidak disertakan.',
          );
        }
        if (total > BigInt.zero) {
          baseline = (total + BigInt.from(months - 1)) ~/ BigInt.from(months);
        }
        warnings.add(
          'Ada pengeluaran wajib pada $monthsWithExpenses dari $months bulan; bulan tanpa transaksi dihitung nol.',
        );
        if (monthsWithExpenses < months) {
          warnings.add(
            'Bukti histori terbatas. Gunakan baseline manual jika ada pengeluaran yang belum dicatat.',
          );
        }
        if (total == BigInt.zero) {
          warnings.add(
            'Belum ada pengeluaran wajib untuk estimasi. Masukkan baseline manual.',
          );
        }
      }
    }
    final selected = (config['account_ids'] as List).cast<String>();
    final included = accounts.where((a) => selected.contains(a['id'])).toList();
    if (included.length != selected.length) {
      warnings.add(
        'Akun yang dihapus atau tidak lagi likuid/milik sendiri dikecualikan.',
      );
    }
    if (included.isEmpty) {
      warnings.add(
        'Belum ada akun kas/kantong yang dipilih untuk dana darurat.',
      );
    }
    final linkedId = config['goal_id'] as String?;
    final linkedValid =
        linkedId != null && privateGoals.any((g) => g['id'] == linkedId);
    if (linkedId != null && !linkedValid) {
      warnings.add(
        'Goal terhubung tidak lagi tersedia; alokasinya tidak dihitung sebagai dana darurat.',
      );
    }
    final backing = goals.backing();
    final rows = <EmergencyAccountFunds>[];
    var totalLiquid = BigInt.zero;
    for (final account in included) {
      final id = account['id'] as String;
      final free = goals.available(id);
      final earmarked = !linkedValid
          ? BigInt.zero
          : goals.allocations
                .where(
                  (a) =>
                      a['user_id'] == source.userId &&
                      a['account_id'] == id &&
                      a['goal_id'] == linkedId,
                )
                .fold(
                  BigInt.zero,
                  (sum, a) => sum + (backing['${a['id']}'] ?? BigInt.zero),
                );
      rows.add(
        EmergencyAccountFunds(id, '${account['name']}', free, earmarked),
      );
      totalLiquid += free + earmarked;
    }
    final liquid = goals.complete ? totalLiquid : null;
    if (liquid == null) {
      warnings.add(
        'Sinkronkan riwayat alokasi goal terlebih dahulu; dana likuid dan cakupan belum dapat dipastikan.',
      );
    }
    final target = baseline == null
        ? null
        : baseline * BigInt.from(config['coverage_months'] as int);
    final remaining = target == null || liquid == null
        ? null
        : target > liquid
        ? target - liquid
        : BigInt.zero;
    return EmergencyAssessment(
      baseline: baseline,
      liquid: liquid,
      target: target,
      remaining: remaining,
      coverageHundredths: baseline == null || liquid == null
          ? null
          : liquid * BigInt.from(100) ~/ baseline,
      accounts: rows,
      warnings: warnings,
      historyStart: start,
      historyEnd: end,
      monthsWithExpenses: monthsWithExpenses,
      historyMonths: months,
    );
  }
}
