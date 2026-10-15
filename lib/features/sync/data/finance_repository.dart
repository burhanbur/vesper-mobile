import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:cryptography/dart.dart';

import '../../../core/network/api_client.dart';
import '../../../database/local_store.dart';
import '../../../database/transaction_query.dart';
import '../../household/models/category_report.dart';
import '../../investments/models/investment_history.dart';
import '../../investments/models/investment_trade_command.dart';

/// Raw contracts stay lossless (decimal/version strings) in the durable cache.
class FinanceRepository {
  final ApiClient client;
  final LocalStore store;
  final String userId;
  late Map<String, dynamic> state;
  Future<void>? _syncing;
  bool offline = false;
  FinanceRepository(this.client, this.store, this.userId) {
    state = store.read();
  }

  Map<String, dynamic> get entities =>
      state['entities'] as Map<String, dynamic>;
  List<dynamic> get outbox => state['outbox'] as List<dynamic>;
  List<Map<String, dynamic>> rows(String type) =>
      ((entities[type] as Map?)?.values ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
  Map<String, dynamic>? row(String type, String id) {
    final value = (entities[type] as Map?)?[id];
    return value == null ? null : Map<String, dynamic>.from(value as Map);
  }

  TransactionPage transactionPage(TransactionQuery query) {
    if (store.isIndexed) return store.transactionPage(query);
    final search = query.search.trim().toLowerCase();
    final filtered =
        rows('transactions').where((record) {
          if (record['deleted_at'] != null) return false;
          final date = DateTime.parse(record['transacted_at'] as String);
          if (query.start != null && date.isBefore(query.start!)) return false;
          if (query.end != null && !date.isBefore(query.end!)) return false;
          if (query.accountId != null &&
              record['account_id'] != query.accountId) {
            return false;
          }
          if (query.type != null && record['type'] != query.type) return false;
          if (search.isNotEmpty) {
            final category =
                row('categories', '${record['category_id']}')?['name'] ?? '';
            final categoryName = category == '' && record['type'] == 'TRANSFER'
                ? 'Transfer Antar Akun'
                : '$category';
            final actor = record['created_by'] == query.actorId
                ? query.actorName
                : '';
            if (!'${record['description'] ?? ''}'.toLowerCase().contains(
                  search,
                ) &&
                !categoryName.toLowerCase().contains(search) &&
                !actor.toLowerCase().contains(search)) {
              return false;
            }
          }
          if (query.after != null) {
            final stamp = int.parse(query.after!.microseconds);
            if (date.microsecondsSinceEpoch > stamp ||
                (date.microsecondsSinceEpoch == stamp &&
                    (record['id'] as String).compareTo(query.after!.id) <= 0)) {
              return false;
            }
          }
          return true;
        }).toList()..sort((a, b) {
          final comparison = DateTime.parse(b['transacted_at'] as String)
              .compareTo(DateTime.parse(a['transacted_at'] as String));
          return comparison == 0
              ? (a['id'] as String).compareTo(b['id'] as String)
              : comparison;
        });
    final visible = filtered.take(query.limit.clamp(1, 100)).toList();
    return TransactionPage(
      visible,
      filtered.length > visible.length
          ? TransactionCursor(
              '${DateTime.parse(visible.last['transacted_at'] as String).microsecondsSinceEpoch}',
              visible.last['id'] as String,
            )
          : null,
    );
  }

  void _save() => store.write(state);
  void _put(String type, String id, dynamic payload) {
    if (store.isIndexed) {
      if (!entities.containsKey(type)) entities[type] = <String, dynamic>{};
      final table = entities[type] as Map<String, dynamic>;
      if (payload == null) {
        table.remove(id);
      } else {
        table[id] = payload;
      }
      return;
    }
    // Cached maps can have narrower runtime value types before JSON reload.
    // Normalize the write boundary rather than requiring a reload to mutate.
    final table = Map<String, dynamic>.from(
      (entities[type] as Map?) ?? const <String, dynamic>{},
    );
    if (payload == null) {
      table.remove(id);
    } else {
      table[id] = payload;
    }
    entities[type] = table;
  }

  /// Roll back the in-memory snapshot as well if the atomic SQLite commit fails.
  bool _inAtomic = false;
  void atomic(void Function() action) {
    if (_inAtomic) {
      action();
      return;
    }
    if (store.isIndexed) {
      _inAtomic = true;
      try {
        store.atomicState(action);
      } finally {
        _inAtomic = false;
      }
      return;
    }
    final previous = jsonEncode(state);
    _inAtomic = true;
    try {
      action();
      _save();
    } catch (_) {
      state = Map<String, dynamic>.from(jsonDecode(previous) as Map);
      rethrow;
    } finally {
      _inAtomic = false;
    }
  }

  bool get isSyncing => _syncing != null;

  bool get supportsInvestmentTradeCommands => true;

  bool get hasUnresolvedInvestmentTrade => outbox.any(_isTrade);

  /// Read-only support references, never a financial export or a recovery
  /// authorization. Status/retry counters are excluded from the fingerprint.
  Map<String, String> investmentRecoveryReference(String queueId) {
    final matches = outbox.where((e) => e['id'] == queueId && _isTrade(e));
    if (matches.length != 1) {
      throw const ApiFailure('Perintah investasi tidak ditemukan.');
    }
    final item = matches.single as Map;
    final payload = item['payload'] as Map;
    dynamic canonical(dynamic value) {
      if (value is Map) {
        final keys = value.keys.cast<String>().toList()..sort();
        return <String, dynamic>{
          for (final key in keys) key: canonical(value[key]),
        };
      }
      if (value is List) return value.map(canonical).toList();
      return value;
    }

    final command = <String, dynamic>{
      for (final key in [
        'id',
        'entity_type',
        'entity_id',
        'operation',
        'client_version',
        'payload',
      ])
        key: item[key],
    };
    final fingerprint = const DartSha256().hashSync(
      utf8.encode(jsonEncode(canonical(command))),
    );
    return Map<String, String>.unmodifiable({
      'schema': 'vesper.investment-recovery-reference.v1',
      'user_id': userId,
      'command_id': queueId,
      'trade_id': '${item['entity_id']}',
      'status': '${item['status']}',
      for (final key in [
        'linked_transaction_id',
        'account_id',
        'cash_account_id',
        'instrument_id',
      ])
        if (payload[key] is String) key: payload[key] as String,
      'command_sha256': fingerprint.bytes
          .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
          .join(),
    });
  }

  /// Recovery only retries the original immutable command. Server idempotency
  /// decides whether it committed; neither local rollback nor rebasing is safe.
  void retryInvestmentTrade(String queueId) {
    if (isSyncing) {
      throw const ApiFailure('Tunggu hingga sinkronisasi selesai.');
    }
    final matches = outbox.where((e) => e['id'] == queueId && _isTrade(e));
    if (matches.length != 1 ||
        !['rejected', 'conflict'].contains(matches.single['status'])) {
      throw const ApiFailure('Perintah investasi tidak dapat dicoba ulang.');
    }
    atomic(() {
      final item = matches.single as Map;
      item['status'] = 'pending';
      item.remove('error');
      item.remove('server_data');
    });
  }

  bool _isTrade(dynamic item) =>
      item['entity_type'] == 'investment_transactions';

  bool _tradeTouches(String type, String id) => outbox.any((item) {
    if (!_isTrade(item)) return false;
    final p = item['payload'] as Map;
    return (type == 'accounts' &&
            [p['account_id'], p['cash_account_id']].contains(id)) ||
        (type == 'instruments' && p['instrument_id'] == id) ||
        (type == 'account_types' &&
            [p['account_id'], p['cash_account_id']].any(
              (accountId) =>
                  row('accounts', '$accountId')?['account_type_id'] == id,
            )) ||
        (type == 'transactions' && p['linked_transaction_id'] == id) ||
        (type == 'investment_transactions' && item['entity_id'] == id);
  });

  /// Only actor-owned cached accounts are safe for offline authorization.
  bool canTradeAccount(String id, String category) {
    final account = row('accounts', id);
    final type = row('account_types', '${account?['account_type_id']}');
    return account != null &&
        account['user_id'] == userId &&
        account['deleted_at'] == null &&
        account['is_visible'] != false &&
        account['currency'] == 'IDR' &&
        type != null &&
        type['user_id'] == userId &&
        type['deleted_at'] == null &&
        type['category'] == category;
  }

  InvestmentTradeCommand previewInvestmentTrade({
    required String accountId,
    required String cashAccountId,
    required String instrumentId,
    required String type,
    required String quantity,
    required String pricePerUnit,
    required DateTime at,
    String fee = '0',
    String? description,
  }) {
    final instrument = row('instruments', instrumentId);
    if (!canTradeAccount(accountId, 'INVESTMENT') ||
        !canTradeAccount(cashAccountId, 'CASH') ||
        instrument == null ||
        instrument['deleted_at'] != null ||
        instrument['currency'] != 'IDR' ||
        isSyncing ||
        outbox.any((e) {
          final p = e['payload'] as Map?;
          return _isTrade(e) ||
              (e['entity_type'] == 'instruments' &&
                  e['entity_id'] == instrumentId) ||
              (e['entity_type'] == 'account_types' &&
                  [
                    row('accounts', accountId)?['account_type_id'],
                    row('accounts', cashAccountId)?['account_type_id'],
                  ].contains(e['entity_id'])) ||
              [accountId, cashAccountId].contains(e['entity_id']) ||
              [accountId, cashAccountId].contains(p?['account_id']) ||
              [accountId, cashAccountId].contains(p?['from_account_id']) ||
              [accountId, cashAccountId].contains(p?['to_account_id']);
        })) {
      throw const ApiFailure(
        'Sinkronkan perubahan sebelumnya dan pilih akun IDR milik sendiri yang aktif.',
      );
    }
    return InvestmentTradeCommand.prepare(
      history: investmentHistory(accountId),
      accountId: accountId,
      cashAccountId: cashAccountId,
      instrumentId: instrumentId,
      cashBalance: '${row('accounts', cashAccountId)!['balance']}',
      type: type,
      quantity: quantity,
      pricePerUnit: pricePerUnit,
      fee: fee,
      at: at,
      description: description,
    );
  }

  String createInvestmentTrade({
    required String accountId,
    required String cashAccountId,
    required String instrumentId,
    required String type,
    required String quantity,
    required String pricePerUnit,
    required DateTime at,
    String fee = '0',
    String? description,
  }) {
    final command = previewInvestmentTrade(
      accountId: accountId,
      cashAccountId: cashAccountId,
      instrumentId: instrumentId,
      type: type,
      quantity: quantity,
      pricePerUnit: pricePerUnit,
      at: at,
      fee: fee,
      description: description,
    );
    atomic(() {
      final envelope = command.toPushItem();
      outbox.add({
        ...envelope,
        'id': const Uuid().v4(),
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'attempts': 0,
        'status': 'pending',
      });
      _put('investment_transactions', command.id, {
        ...envelope['payload'] as Map,
        'id': command.id,
        'created_by': userId,
        'version': '0',
      });
      _put('transactions', command.linkedTransactionId, {
        'id': command.linkedTransactionId,
        'account_id': cashAccountId,
        'type': type == 'BUY' ? 'EXPENSE' : 'INCOME',
        'amount': command.settlement.amount,
        'category_id': null,
        'investment_transaction_id': command.id,
        'transacted_at': command.transactedAt,
        'description': command.description,
        'created_by': userId,
        'version': '0',
      });
      _put('accounts', cashAccountId, {
        ...row('accounts', cashAccountId)!,
        'balance': command.cashBalanceAfter,
      });
    });
    return command.id;
  }

  void _stageTradeChange(String type, String id, dynamic payload) {
    final snapshots = state.putIfAbsent(
      'investment_command_snapshots',
      () => <String, dynamic>{},
    ) as Map;
    snapshots['$type:$id'] = {'type': type, 'id': id, 'payload': payload};
  }

  void _finishTrades() {
    final snapshots = state['investment_command_snapshots'] as Map?;
    for (final item
        in outbox
            .where((e) => _isTrade(e) && e['status'] == 'acknowledged')
            .toList()) {
      final p = item['payload'] as Map;
      final keys = [
        'accounts:${p['cash_account_id']}',
        'transactions:${p['linked_transaction_id']}',
        'investment_transactions:${item['entity_id']}',
      ];
      if (snapshots == null || !keys.every(snapshots.containsKey)) continue;
      // Commit all derived authoritative rows together, never page by page.
      for (final key in snapshots.keys.toList()) {
        final snapshot = snapshots.remove(key) as Map;
        _put(
          snapshot['type'] as String,
          snapshot['id'] as String,
          snapshot['payload'],
        );
      }
      outbox.remove(item);
    }
  }

  bool get hasCompleteInvestmentHistory {
    final coverage = state['investment_history_coverage'];
    return coverage is Map &&
        coverage['schema'] == 1 &&
        coverage['user_id'] == userId &&
        coverage['complete'] == true &&
        coverage['cursor'] == state['cursor'];
  }

  /// Coverage is a completed feed checkpoint, not proof of current online access.
  /// Write authorization must still be revalidated by the command path/server.
  InvestmentHistory investmentHistory(String accountId) {
    final account = row('accounts', accountId);
    final type = account == null
        ? null
        : row('account_types', account['account_type_id'] as String? ?? '');
    if (!hasCompleteInvestmentHistory ||
        account == null ||
        account['user_id'] != userId ||
        account['deleted_at'] != null ||
        type?['category'] != 'INVESTMENT' ||
        type?['deleted_at'] != null ||
        outbox.any(
          (e) =>
              (e['entity_type'] == 'accounts' && e['entity_id'] == accountId),
        )) {
      throw const ApiFailure(
        'Histori investasi belum siap atau akun tidak tersedia.',
      );
    }
    return InvestmentHistory.fromCompleteRows(
      accountId: accountId,
      rows: rows('investment_transactions')
          .where((r) => r['account_id'] == accountId),
    );
  }

  Future<void> waitForSync() async {
    await _syncing;
  }

  String mutate(
    String type,
    String operation,
    Map<String, dynamic>? payload, {
    String? id,
    Map<String, dynamic>? local,
    Map<String, int> balanceDelta = const {},
  }) {
    final entityId = id ?? const Uuid().v4();
    final old = row(type, entityId);
    if (_tradeTouches(type, entityId) ||
        (type == 'transactions' &&
            [payload?['account_id'], old?['account_id']].any(
              (accountId) =>
                  accountId != null && _tradeTouches('accounts', '$accountId'),
            ))) {
      throw const ApiFailure('Perintah investasi masih menunggu rekonsiliasi.');
    }
    // Settlement DTOs deliberately expose no private investment relation.
    // Like the backend, treat category-null server ledger rows as derived.
    if (type == 'transactions' &&
        old != null &&
        old.containsKey('category_id') &&
        old['category_id'] == null) {
      throw const ApiFailure(
        'Transaksi turunan tidak dapat diubah atau dihapus secara langsung.',
      );
    }
    if (type == 'investment_transactions' ||
        (type == 'transactions' &&
            (payload?['linked_transaction_id'] != null ||
                old?['investment_transaction_id'] != null ||
                payload?['type'] == 'INVESTMENT_BUY' ||
                payload?['type'] == 'INVESTMENT_SELL'))) {
      throw const ApiFailure(
        'Sinkronisasi transaksi investasi belum tersedia.',
      );
    }
    if (type == 'transactions' &&
        (payload?['type'] == 'TRANSFER' ||
            old?['type'] == 'TRANSFER' ||
            old?['transfer_id'] != null)) {
      throw const ApiFailure('Gunakan perintah transfer atomik.');
    }
    if (outbox.any(
      (e) => e['entity_type'] == type && e['entity_id'] == entityId,
    )) {
      throw const ApiFailure(
        'Sinkronkan perubahan sebelumnya terlebih dahulu.',
      );
    }
    if (operation != 'CREATE' && old == null) {
      throw const ApiFailure('Data tidak ditemukan.');
    }
    atomic(() {
      outbox.add({
        'id': const Uuid().v4(),
        'entity_type': type,
        'entity_id': entityId,
        'operation': operation,
        'payload': payload,
        'client_version': operation == 'CREATE' ? '0' : old!['version'],
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'attempts': 0,
        'status': 'pending',
        'balance_delta': balanceDelta,
        'before': old,
      });
      _put(
        type,
        entityId,
        operation == 'DELETE'
            ? null
            : {
                ...?old,
                ...?payload,
                ...?local,
                'id': entityId,
                'user_id': old?['user_id'] ?? userId,
                'version': old?['version'] ?? '0',
              },
      );
      for (final entry in balanceDelta.entries) {
        final account = row('accounts', entry.key)!;
        final parts = (account['balance'] as String).split('.');
        if (parts.length > 1 && int.parse(parts[1]) != 0) {
          throw const ApiFailure('Saldo pecahan Rupiah belum didukung.');
        }
        _put('accounts', entry.key, {
          ...account,
          'balance': '${int.parse(parts[0]) + entry.value}.00',
        });
      }
    });
    return entityId;
  }

  /// Persist the push-only command and both optimistic ledgers in one commit.
  /// The presentation layer supports whole Rupiah within JS's safe integer range.
  String createTransfer({
    required String fromAccountId,
    required String toAccountId,
    required int amount,
    required DateTime date,
    String? description,
  }) {
    const max = 9007199254740991;
    final from = row('accounts', fromAccountId);
    final to = row('accounts', toAccountId);
    final note = description?.trim();
    if (_tradeTouches('accounts', fromAccountId) ||
        _tradeTouches('accounts', toAccountId) ||
        fromAccountId == toAccountId ||
        from == null ||
        to == null ||
        amount <= 0 ||
        amount > max ||
        (note?.length ?? 0) > 5000) {
      throw const ApiFailure('Pilih dua akun berbeda dan nominal yang valid.');
    }
    final balances = <String, String>{};
    for (final account in [from, to]) {
      if (account['deleted_at'] != null || account['currency'] != 'IDR') {
        throw const ApiFailure('Transfer membutuhkan dua akun IDR aktif.');
      }
      final text = '${account['balance']}';
      if (!RegExp(r'^-?\d+(?:\.00)?$').hasMatch(text)) {
        throw const ApiFailure('Saldo pecahan Rupiah belum didukung.');
      }
      final balance =
          BigInt.parse(text.split('.').first) +
          BigInt.from(account == from ? -amount : amount);
      if (balance.abs() > BigInt.from(max)) {
        throw const ApiFailure('Saldo melampaui batas presisi aman.');
      }
      balances[account['id'] as String] = '$balance.00';
    }
    final id = const Uuid().v4();
    final fromId = const Uuid().v4();
    final toId = const Uuid().v4();
    final timestamp = DateTime.fromMillisecondsSinceEpoch(
      date.millisecondsSinceEpoch,
      isUtc: true,
    ).toIso8601String();
    final payload = <String, dynamic>{
      'from_account_id': fromAccountId,
      'to_account_id': toAccountId,
      'from_transaction_id': fromId,
      'to_transaction_id': toId,
      'amount': '$amount.00',
      'transacted_at': timestamp,
      'description': note == null || note.isEmpty ? null : note,
    };
    atomic(() {
      mutate('transfers', 'CREATE', payload, id: id);
      for (final leg in [
        (fromId, fromAccountId, '-$amount.00'),
        (toId, toAccountId, '$amount.00'),
      ]) {
        _put('transactions', leg.$1, {
          'id': leg.$1,
          'account_id': leg.$2,
          'amount': leg.$3,
          'type': 'TRANSFER',
          'category_id': null,
          'transfer_id': id,
          'transacted_at': timestamp,
          'description': payload['description'],
          'created_by': userId,
          'version': '0',
        });
      }
      for (final account in [from, to]) {
        _put('accounts', account['id'] as String, {
          ...account,
          'balance': balances[account['id']],
        });
      }
    });
    return id;
  }

  bool _transferTouches(String accountId) => outbox.any(
    (item) =>
        item['entity_type'] == 'transfers' &&
        (item['payload']['from_account_id'] == accountId ||
            item['payload']['to_account_id'] == accountId),
  );

  bool _pendingLeg(String id) => outbox.any(
    (item) =>
        item['entity_type'] == 'transfers' &&
        (item['payload']['from_transaction_id'] == id ||
            item['payload']['to_transaction_id'] == id),
  );

  HouseholdCategoryReport? cachedCategoryReport(String groupId, String period) {
    validateReportPeriod(period);
    final cached = row('household_category_reports:$groupId', period);
    if (cached == null) return null;
    return HouseholdCategoryReport.fromJson(
      Map<String, dynamic>.from(cached['report'] as Map),
      period,
      DateTime.parse(cached['fetched_at'] as String),
    );
  }

  Future<HouseholdCategoryReport> fetchCategoryReport(
    String groupId,
    String period, {
    required bool Function() isCurrent,
  }) async {
    validateReportPeriod(period);
    await requireOnline();
    final data = await client.request(
      'GET',
      '/groups/$groupId/category-report',
      query: {'period': period},
    );
    final payload = Map<String, dynamic>.from(data as Map);
    final fetchedAt = DateTime.now().toUtc();
    final report = HouseholdCategoryReport.fromJson(payload, period, fetchedAt);
    if (isCurrent() && !offline) {
      atomic(
        () => _put('household_category_reports:$groupId', period, {
          'report': payload,
          'fetched_at': fetchedAt.toIso8601String(),
        }),
      );
    }
    return report;
  }

  Future<void> requireOnline() async {
    if (offline) {
      throw const ApiFailure('Tindakan ini membutuhkan koneksi internet.');
    }
  }

  Future<dynamic> writeOnline(
    String method,
    String path,
    Map<String, dynamic> body,
  ) async {
    if (path.split('?').first.replaceAll(RegExp(r'/+$'), '') ==
        '/investment-transactions') {
      throw const ApiFailure(
        'Sinkronisasi transaksi investasi belum tersedia.',
      );
    }
    await requireOnline();
    return client.request(method, path, body: body);
  }

  Future<void> sync() {
    if (_syncing != null) return _syncing!;
    final future = _runSync();
    _syncing = future;
    return future.whenComplete(() {
      _syncing = null;
    });
  }

  Future<void> _runSync() async {
    await requireOnline();
    atomic(() {
      if (outbox.any((e) => _isTrade(e) && e['status'] == 'acknowledged')) {
        state['cursor'] = '0';
        state.remove('investment_command_snapshots');
      }
      final coverage = state['investment_history_coverage'];
      // Legacy cursors do not prove the investment feed was ever bootstrapped.
      if (coverage is! Map ||
          coverage['schema'] != 1 ||
          coverage['user_id'] != userId ||
          coverage['cursor'] != state['cursor']) {
        state['cursor'] = '0';
      }
      state['investment_history_coverage'] = {
        'schema': 1,
        'user_id': userId,
        'complete': false,
        'cursor': state['cursor'],
      };
    });
    var deviceId = state['device_id'] as String?;
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      atomic(() {
        state['device_id'] = deviceId;
      });
    }
    // Idempotent registration, including recovery after a lost response.
    await client.request(
      'POST',
      '/devices',
      body: {
        'id': deviceId,
        'name': kIsWeb ? 'Vesper Web' : 'Vesper mobile',
        'platform': kIsWeb
            ? 'Web'
            : defaultTargetPlatform == TargetPlatform.iOS
            ? 'iOS'
            : 'Android',
        'app_version': const String.fromEnvironment(
          'FLUTTER_BUILD_NAME',
          defaultValue: '1.0.0',
        ),
      },
    );
    final attempted = <String>{};
    while (true) {
      await requireOnline();
      final pending = outbox
          .where((e) {
            if (e['status'] != 'pending' || attempted.contains(e['id'])) {
              return false;
            }
            if (_isTrade(e)) {
              final p = e['payload'] as Map;
              if (outbox.any(
                (d) =>
                    d != e &&
                    ((d['entity_type'] == 'accounts' &&
                            [
                              p['account_id'],
                              p['cash_account_id'],
                            ].contains(d['entity_id'])) ||
                        (d['entity_type'] == 'instruments' &&
                            d['entity_id'] == p['instrument_id'])),
              )) {
                return false;
              }
            }
            if (e['entity_type'] == 'transfers') {
              final payload = e['payload'] as Map;
              if (outbox.any(
                (dependency) =>
                    dependency['entity_type'] == 'accounts' &&
                    [
                      payload['from_account_id'],
                      payload['to_account_id'],
                    ].contains(dependency['entity_id']),
              )) {
                return false;
              }
            }
            final categoryId = (e['payload'] as Map?)?['category_id'];
            return categoryId == null ||
                !outbox.any(
                  (dependency) =>
                      dependency['entity_type'] == 'categories' &&
                      dependency['entity_id'] == categoryId,
                );
          })
          .take(100)
          .toList();
      if (pending.isEmpty) break;
      attempted.addAll(pending.map((e) => e['id'] as String));
      dynamic response;
      try {
        response = await client.request(
          'POST',
          '/sync/push',
          body: {
            'device_id': deviceId,
            'items': pending
                .map(
                  (e) => {
                    'entity_type': e['entity_type'],
                    'entity_id': e['entity_id'],
                    'operation': e['operation'],
                    'payload': e['payload'],
                    'client_version': e['client_version'],
                  },
                )
                .toList(),
          },
        );
      } catch (error) {
        atomic(() {
          for (final item in pending) {
            item['attempts'] = (item['attempts'] as int) + 1;
            item['error'] = error.toString();
          }
        });
        rethrow;
      }
      atomic(() {
        final seen = <int>{};
        for (final result in response['results'] as List) {
          final index = result['index'] as int;
          if (index < 0 ||
              index >= pending.length ||
              !seen.add(index) ||
              !['applied', 'conflict', 'rejected'].contains(result['status'])) {
            throw const ApiFailure('Respons sinkronisasi tidak valid.');
          }
          final item = pending[index] as Map;
          if ((result['entity_id'] != null &&
                  result['entity_id'] != item['entity_id']) ||
              ((item['entity_type'] == 'transfers' || _isTrade(item)) &&
                  result['entity_id'] != item['entity_id'])) {
            throw const ApiFailure(
              'Identitas respons sinkronisasi tidak valid.',
            );
          }
          if (result['status'] == 'applied') {
            if (_isTrade(item)) {
              item['status'] = 'acknowledged';
              // Discard pre-ack staging; only a fresh complete replay can settle.
              state.remove('investment_command_snapshots');
              // Replay from zero: an earlier pull may have consumed only some
              // command events after a lost push acknowledgement.
              state['cursor'] = '0';
              continue;
            }
            if (item['entity_type'] == 'transfers') {
              // Pull pages may have advanced past deferred account events while
              // the command was unresolved. Replay the feed after acknowledgement.
              state['cursor'] = '0';
              _put(
                'transfers',
                item['entity_id'] as String,
                result['server_data'] ??
                    row('transfers', item['entity_id'] as String),
              );
            }
            outbox.remove(item);
            final deferred = state['transfer_account_snapshots'] as Map?;
            for (final id in deferred?.keys.toList() ?? <dynamic>[]) {
              if (!_transferTouches(id as String)) {
                _put(
                  'accounts',
                  id,
                  _reconcileBalance('accounts', id, deferred![id]),
                );
                deferred.remove(id);
              }
            }
          } else {
            item['status'] = result['status'];
            item['server_data'] = result['server_data'];
            item['error'] = result['message'] ?? 'Perubahan ditolak.';
            item['attempts'] = (item['attempts'] as int) + 1;
          }
        }
        if (seen.length != pending.length) {
          throw const ApiFailure('Respons sinkronisasi tidak lengkap.');
        }
      });
    }
    while (true) {
      await requireOnline();
      final response = await client.request(
        'GET',
        '/sync/pull',
        query: {
          'device_id': deviceId,
          'since_version': state['cursor'],
          'limit': 100,
        },
      );
      final next = response['next_version'];
      final more = response['has_more'];
      if (next is! String ||
          !RegExp(r'^(0|[1-9]\d*)$').hasMatch(next) ||
          more is! bool ||
          response['changes'] is! List ||
          BigInt.parse(next) < BigInt.parse(state['cursor'] as String) ||
          (more && next == state['cursor'])) {
        throw const ApiFailure('Halaman sinkronisasi tidak valid.');
      }
      atomic(() {
        for (final change in response['changes'] as List) {
          final type = change['entity_type'] as String;
          final id = change['entity_id'] as String;
          if (_tradeTouches(type, id)) {
            _stageTradeChange(
              type,
              id,
              change['operation'] == 'DELETE' ? null : change['payload'],
            );
            continue;
          }
          // A lost push response may mean the command already committed. Do not
          // add its delta to an authoritative balance or assume a pull is an ack.
          if (change['entity_type'] == 'accounts' &&
              _transferTouches(change['entity_id'] as String)) {
            final deferred = state.putIfAbsent(
              'transfer_account_snapshots',
              () => <String, dynamic>{},
            ) as Map;
            deferred[change['entity_id']] = change['operation'] == 'DELETE'
                ? null
                : change['payload'];
            continue;
          }
          // Never overwrite an unacknowledged local edit with a remote snapshot.
          if (outbox.any(
            (e) =>
                e['entity_type'] == change['entity_type'] &&
                e['entity_id'] == change['entity_id'],
          )) {
            continue;
          }
          _put(
            change['entity_type'] as String,
            change['entity_id'] as String,
            change['operation'] == 'DELETE'
                ? null
                : _reconcileBalance(
                    change['entity_type'] as String,
                    change['entity_id'] as String,
                    change['payload'],
                  ),
          );
        }
        if (!more) _finishTrades();
        state['cursor'] = next;
        state['investment_history_coverage'] = {
          'schema': 1,
          'user_id': userId,
          'complete': !more,
          'cursor': next,
        };
      });
      if (!more) break;
    }
  }

  void resolve(String queueId, {required bool useMine}) {
    final item = outbox.firstWhere((e) => e['id'] == queueId) as Map;
    if (item['entity_type'] == 'transfers' || _isTrade(item)) {
      throw const ApiFailure(
        'Konflik transfer/investasi memerlukan pemeriksaan server; perintah asli tetap disimpan.',
      );
    }
    final server = item['server_data'] as Map?;
    if (useMine && (server == null || server['version'] == null)) {
      throw const ApiFailure('Versi server tidak tersedia; muat ulang data.');
    }
    atomic(() {
      if (useMine) {
        item['client_version'] = server!['version'];
        item['status'] = 'pending';
        item.remove('error');
      } else {
        _put(
          item['entity_type'] as String,
          item['entity_id'] as String,
          server,
        );
        outbox.remove(item);
      }
    });
  }

  Future<void> refreshList(
    String type,
    String path, {
    Map<String, dynamic>? query,
  }) async {
    await requireOnline();
    final rows = await client.list(path, query: query);
    atomic(() {
      final table = <String, dynamic>{
        for (final row in rows)
          (row['id'] ?? row['user_id']) as String: _reconcileBalance(
            type,
            (row['id'] ?? row['user_id']) as String,
            type == 'groups' && row['code'] == null
                ? {...row, 'code': this.row(type, row['id'] as String)?['code']}
                : row,
          ),
      };
      // Preserve local edits across online refreshes.
      for (final item in outbox.where((e) => e['entity_type'] == type)) {
        final id = item['entity_id'] as String;
        final local = row(type, id);
        if (local == null) {
          table.remove(id);
        } else {
          table[id] = local;
        }
      }
      if (type == 'transactions') {
        for (final local in this.rows(type)) {
          if (_pendingLeg(local['id'] as String)) {
            table[local['id'] as String] = local;
          }
        }
      }
      if (type == 'accounts') {
        for (final local in this.rows(type)) {
          if (_transferTouches(local['id'] as String)) {
            table[local['id'] as String] = local;
          }
        }
      }
      for (final local in this.rows(type)) {
        if (_tradeTouches(type, local['id'] as String)) {
          table[local['id'] as String] = local;
        }
      }
      entities[type] = table;
    });
  }

  dynamic _reconcileBalance(String type, String id, dynamic payload) {
    if (type != 'accounts' || payload == null) return payload;
    var delta = 0;
    for (final item in outbox) {
      delta += ((item['balance_delta'] as Map?)?[id] as int?) ?? 0;
    }
    if (delta == 0) return payload;
    final balance = BigInt.parse('${payload['balance']}'.split('.').first);
    final result = balance + BigInt.from(delta);
    if (result.abs() > BigInt.from(9007199254740991)) {
      throw const ApiFailure('Saldo melampaui batas presisi aman.');
    }
    return {...payload as Map, 'balance': '$result.00'};
  }

  Future<void> cacheValue(String key, Future<dynamic> Function() load) async {
    await requireOnline();
    final value = await load();
    atomic(() {
      state[key] = value;
    });
  }
}
