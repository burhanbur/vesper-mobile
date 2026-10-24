import 'package:uuid/uuid.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/app_time_zone.dart';
import '../../settings/data/time_zone_preferences_repository.dart';
import '../../sync/data/finance_repository.dart';

BigInt goalMinor(String value) {
  if (!RegExp(r'^(0|[1-9]\d{0,17})(?:\.\d{1,2})?$').hasMatch(value)) {
    throw const ApiFailure(
      'Masukkan nominal positif dengan maksimal dua desimal.',
    );
  }
  final parts = value.split('.');
  return BigInt.parse(parts.first) * BigInt.from(100) +
      BigInt.parse(parts.length == 1 ? '0' : parts[1].padRight(2, '0'));
}

String goalMoney(BigInt value) =>
    '${value ~/ BigInt.from(100)}.${(value % BigInt.from(100)).toString().padLeft(2, '0')}';
DateTime goalDate(String value) {
  final parsed = DateTime.tryParse('${value}T00:00:00Z');
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) ||
      parsed == null ||
      parsed.toIso8601String().substring(0, 10) != value) {
    throw const ApiFailure('Tanggal harus YYYY-MM-DD yang valid.');
  }
  return parsed;
}

String goalDay(DateTime value) =>
    value.toUtc().toIso8601String().substring(0, 10);

class GoalProgress {
  final BigInt target, pledged, funded, expected, monthly;
  final bool overdue;
  const GoalProgress(
    this.target,
    this.pledged,
    this.funded,
    this.expected,
    this.monthly,
    this.overdue,
  );
  bool get achieved => funded >= target;
  bool get onTrack => funded >= expected;
  BigInt get shortfall => pledged > funded ? pledged - funded : BigInt.zero;
  int get percent => target == BigInt.zero
      ? 0
      : funded >= target
      ? 100
      : ((funded * BigInt.from(100)) ~/ target).toInt();
}

class GoalsRepository {
  final FinanceRepository source;
  GoalsRepository(this.source) {
    if (source.state['goal_history_coverage'] == null) {
      source.atomic(() {
        source.state['goal_history_coverage'] = {
          'schema': 1,
          'user_id': source.userId,
          'complete': false,
        };
        if (!source.isSyncing) {
          source.state['cursor'] = '0';
        }
      });
    }
  }
  bool get complete =>
      source.state['goal_history_coverage'] is Map &&
      source.state['goal_history_coverage']['complete'] == true;
  bool member(String? groupId) {
    if (groupId == null) return true;
    final group = source.row('groups', groupId);
    return group != null &&
        group['deleted_at'] == null &&
        group['is_active'] != false;
  }

  List<Map<String, dynamic>> get goals =>
      source
          .rows('goals')
          .where(
            (g) =>
                g['deleted_at'] == null &&
                (g['group_id'] == null
                    ? g['user_id'] == source.userId
                    : member(g['group_id'] as String)),
          )
          .toList()
        ..sort(
          (a, b) => '${a['target_date']}:${a['id']}'.compareTo(
            '${b['target_date']}:${b['id']}',
          ),
        );
  List<Map<String, dynamic>> get allocations => source
      .rows('goal_allocations')
      .where((a) => a['deleted_at'] == null)
      .toList();
  List<Map<String, dynamic>> get cashAccounts =>
      source.rows('accounts').where((a) {
        final type = source.row('account_types', '${a['account_type_id']}');
        return a['user_id'] == source.userId &&
            a['deleted_at'] == null &&
            type?['deleted_at'] == null &&
            type?['category'] == 'CASH' &&
            !source.isMappedObligationAccount('${a['id']}') &&
            !source
                .rows('accounts')
                .any(
                  (child) =>
                      child['parent_account_id'] == a['id'] &&
                      child['deleted_at'] == null,
                );
      }).toList();

  BigInt available(String accountId, {String? except}) {
    final account = cashAccounts.where((a) => a['id'] == accountId).firstOrNull;
    if (account == null || '${account['balance']}'.startsWith('-')) {
      return BigInt.zero;
    }
    final balance = goalMinor('${account['balance']}');
    final reserved = allocations
        .where(
          (a) =>
              a['user_id'] == source.userId &&
              a['account_id'] == accountId &&
              a['id'] != except,
        )
        .fold(BigInt.zero, (sum, a) => sum + goalMinor('${a['amount']}'));
    return balance > reserved ? balance - reserved : BigInt.zero;
  }

  Map<String, BigInt> backing() {
    final remaining = <String, BigInt>{};
    final result = <String, BigInt>{};
    final ordered = allocations
      ..sort(
        (a, b) => '${a['created_at']}:${a['id']}'.compareTo(
          '${b['created_at']}:${b['id']}',
        ),
      );
    for (final a in ordered) {
      final amount = goalMinor('${a['amount']}');
      if (a['user_id'] != source.userId) {
        result['${a['id']}'] = goalMinor('${a['backed_amount'] ?? '0'}');
        continue;
      }
      final id = '${a['account_id']}';
      remaining.putIfAbsent(id, () {
        final account = cashAccounts.where((r) => r['id'] == id).firstOrNull;
        if (account == null || '${account['balance']}'.startsWith('-')) {
          return BigInt.zero;
        }
        return goalMinor('${account['balance']}');
      });
      final backed = remaining[id]! < amount ? remaining[id]! : amount;
      result['${a['id']}'] = backed;
      remaining[id] = remaining[id]! - backed;
    }
    return result;
  }

  GoalProgress progress(
    Map<String, dynamic> goal, {
    DateTime? now,
    AppTimeZone? timeZone,
  }) {
    final backed = backing();
    final entries = allocations.where((a) => a['goal_id'] == goal['id']);
    final pledged = entries.fold(
      BigInt.zero,
      (sum, a) => sum + goalMinor('${a['amount']}'),
    );
    final funded = entries.fold(
      BigInt.zero,
      (sum, a) => sum + (backed['${a['id']}'] ?? BigInt.zero),
    );
    final target = goalMinor('${goal['target_amount']}');
    final start = goalDate('${goal['start_date']}');
    final end = goalDate('${goal['target_date']}');
    final today = (timeZone ?? TimeZonePreferencesRepository(source).selected)
        .calendarDate(now ?? DateTime.now());
    final days = end.difference(start).inDays;
    final elapsed = today
        .difference(start)
        .inDays
        .clamp(0, days < 0 ? 0 : days);
    final expected = days <= 0
        ? target
        : (target * BigInt.from(elapsed) + BigInt.from(days - 1)) ~/
              BigInt.from(days);
    final months = ((end.year - today.year) * 12 + end.month - today.month + 1)
        .clamp(1, 120000);
    final remaining = target > funded ? target - funded : BigInt.zero;
    return GoalProgress(
      target,
      pledged,
      funded,
      expected,
      (remaining + BigInt.from(months - 1)) ~/ BigInt.from(months),
      today.isAfter(end),
    );
  }

  void ready() {
    if (source.isSyncing) {
      throw const ApiFailure('Tunggu sinkronisasi selesai.');
    }
  }

  void recover(String queueId, {bool discard = false}) {
    ready();
    final item =
        source.outbox
                .where(
                  (e) =>
                      e['id'] == queueId &&
                      ['goals', 'goal_allocations'].contains(e['entity_type']),
                )
                .firstOrNull
            as Map?;
    if (item == null || !['rejected', 'conflict'].contains(item['status'])) {
      throw const ApiFailure(
        'Hanya perubahan yang sudah ditolak/konflik dapat diselesaikan.',
      );
    }
    source.atomic(() {
      if (discard) {
        if (item['entity_type'] == 'goals' &&
            item['operation'] == 'CREATE' &&
            item['server_data'] == null) {
          final dependents = source.outbox
              .where(
                (e) =>
                    e['entity_type'] == 'goal_allocations' &&
                    (e['payload'] as Map?)?['goal_id'] == item['entity_id'],
              )
              .toList();
          if (dependents.any((e) => e['attempts'] != 0)) {
            throw const ApiFailure(
              'Selesaikan alokasi terkait sebelum membatalkan goal.',
            );
          }
          for (final dependency in dependents) {
            (source.entities['goal_allocations'] as Map?)?.remove(
              dependency['entity_id'],
            );
            source.outbox.remove(dependency);
          }
        }
        item['server_data'] ??= item['before'];
        source.resolve(queueId, useMine: false);
      } else if (item['status'] == 'conflict' &&
          (item['server_data'] as Map?)?['version'] != null) {
        if (item['operation'] == 'CREATE') {
          throw const ApiFailure(
            'Identitas sudah ada. Gunakan versi server, lalu ubah goal/alokasi.',
          );
        }
        source.resolve(queueId, useMine: true);
      } else {
        item['status'] = 'pending';
        item.remove('error');
      }
    });
  }

  Map<String, dynamic> editable(String id) {
    final goal = goals
        .where((g) => g['id'] == id && g['user_id'] == source.userId)
        .firstOrNull;
    if (goal == null) {
      throw const ApiFailure(
        'Hanya pembuat goal yang aktif dapat mengubahnya.',
      );
    }
    return goal;
  }

  String create({
    required String name,
    required String target,
    required String currency,
    required String targetDate,
    String? groupId,
  }) {
    ready();
    final start = goalDay(
      TimeZonePreferencesRepository(source).selected
          .calendarDate(DateTime.now()),
    );
    if (name.trim().isEmpty ||
        name.trim().length > 120 ||
        !RegExp(r'^[A-Z]{3}$').hasMatch(currency) ||
        goalMinor(target) <= BigInt.zero ||
        goalDate(targetDate).isBefore(goalDate(start)) ||
        !member(groupId)) {
      throw const ApiFailure(
        'Periksa nama, target, mata uang, tanggal dan rumah tangga.',
      );
    }
    final id = const Uuid().v4();
    source.mutate(
      'goals',
      'CREATE',
      {
        'name': name.trim(),
        'currency': currency,
        'target_amount': goalMoney(goalMinor(target)),
        'start_date': start,
        'target_date': targetDate,
        'group_id': groupId,
      },
      id: id,
      local: {
        'status': 'ACTIVE',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
    return id;
  }

  void update(
    String id, {
    required String name,
    required String target,
    required String targetDate,
    required String status,
  }) {
    ready();
    final goal = editable(id);
    if (name.trim().isEmpty ||
        name.trim().length > 120 ||
        goalMinor(target) <= BigInt.zero ||
        goalDate(targetDate).isBefore(goalDate('${goal['start_date']}')) ||
        !['ACTIVE', 'COMPLETED'].contains(status)) {
      throw const ApiFailure('Periksa data goal.');
    }
    if (status == 'COMPLETED' && progress(goal).funded < goalMinor(target)) {
      throw const ApiFailure('Dana yang didukung saldo belum mencapai target.');
    }
    source.mutate('goals', 'UPDATE', {
      'name': name.trim(),
      'target_amount': goalMoney(goalMinor(target)),
      'target_date': targetDate,
      'status': status,
    }, id: id);
  }

  void remove(String id) {
    ready();
    editable(id);
    source.mutate('goals', 'DELETE', null, id: id);
  }

  void allocate(String goalId, String accountId, String value) {
    ready();
    final goal = goals.where((g) => g['id'] == goalId).firstOrNull;
    final existing = allocations
        .where(
          (a) =>
              a['goal_id'] == goalId &&
              a['account_id'] == accountId &&
              a['user_id'] == source.userId,
        )
        .firstOrNull;
    final amount = goalMinor(value);
    final old = existing == null
        ? BigInt.zero
        : goalMinor('${existing['amount']}');
    if (amount > old || existing == null) {
      if (!complete) {
        throw const ApiFailure(
          'Sinkronkan riwayat goal sebelum menambah alokasi.',
        );
      }
      final account = cashAccounts
          .where((a) => a['id'] == accountId)
          .firstOrNull;
      if (goal == null ||
          account == null ||
          account['currency'] != goal['currency'] ||
          amount > available(accountId, except: existing?['id'] as String?)) {
        throw const ApiFailure(
          'Saldo tersedia tidak cukup atau akun/goal tidak sesuai.',
        );
      }
    }
    if (existing == null) {
      source.mutate(
        'goal_allocations',
        'CREATE',
        {
          'goal_id': goalId,
          'account_id': accountId,
          'amount': goalMoney(amount),
        },
        local: {'created_at': DateTime.now().toUtc().toIso8601String()},
      );
    } else {
      source.mutate('goal_allocations', 'UPDATE', {
        'amount': goalMoney(amount),
      }, id: existing['id'] as String);
    }
  }
}
