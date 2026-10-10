import 'dart:async';

import 'package:flutter/material.dart';

import '../core/network/api_client.dart';
import '../database/local_store.dart';
import '../features/accounts/models/account.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/categories/models/category.dart';
import '../features/household/models/group_category.dart';
import '../features/household/models/household.dart';
import '../features/investments/models/investment.dart';
import '../features/notifications/models/notification_item.dart';
import '../features/reports/models/budget.dart';
import '../features/sync/data/finance_repository.dart';
import '../features/sync/models/sync_conflict.dart';
import '../features/transactions/models/transaction.dart';

/// Integer Rupiah presentation adapter. Never parse financial amounts as double.
/// Fractional Rupiah are rejected rather than silently rounded by this UI.
int rupiah(dynamic value) {
  final text = value?.toString() ?? '0';
  final match = RegExp(r'^(-?\d+)(?:\.(\d+))?$').firstMatch(text);
  if (match == null || (match[2] ?? '').contains(RegExp('[1-9]'))) {
    throw const ApiFailure('Nominal pecahan Rupiah belum didukung tampilan ini.');
  }
  return int.parse(match[1]!);
}

enum AppFlowStep { splash, onboarding, auth, main }

class SyncQueueItem {
  final String id, entityType, entityId, operation, description;
  final DateTime timestamp;
  final int clientVersion;
  final bool isSynced;
  final int retryCount;
  final String? lastError;
  const SyncQueueItem({required this.id, required this.entityType,
    required this.entityId, required this.operation, required this.description,
    required this.timestamp, this.clientVersion = 0, this.isSynced = false,
    this.retryCount = 0, this.lastError});
}

/// UI → observable state → repository → user-scoped SQLite/API.
/// The existing notifier scope is retained; no second state-management layer.
class AppState extends ChangeNotifier {
  final AuthRepository auth;
  FinanceRepository? repository;
  AppState({bool? isAuthenticated, AppFlowStep? initialFlow,
    AuthRepository? auth, this.repository})
      : auth = auth ?? AuthRepository(),
        _currentFlow = initialFlow ?? AppFlowStep.auth;
  String currentUserId = '', userName = '', userEmail = '', userPhone = '';
  final String baseCurrency = 'IDR';
  bool _authenticated = false, _offline = false, _hidden = false;
  bool loading = false;
  String? dataError;
  AppFlowStep _currentFlow;
  String _activeHouseholdId = '';
  bool _disposed = false;
  int _generation = 0;
  bool get isAuthenticated => _authenticated;
  AppFlowStep get currentFlow => _currentFlow;
  bool get isOfflineMode => _offline;
  bool get isBalanceHidden => _hidden;
  void _notify() { if (!_disposed) notifyListeners(); }
  void setFlowStep(AppFlowStep step) { _currentFlow = step; _notify(); }
  void showSplash() => setFlowStep(AppFlowStep.splash);
  void showOnboarding() => setFlowStep(AppFlowStep.onboarding);
  void completeOnboarding() => setFlowStep(_authenticated ? AppFlowStep.main : AppFlowStep.auth);

  Future<void> bootstrap() async {
    try {
      final user = await auth.bootstrap();
      if (_disposed) return;
      if (user != null) {
        await login(userId: user.id, name: user.name, email: user.email);
      } else { setFlowStep(AppFlowStep.auth); }
    } catch (error) {
      dataError = error.toString();
      setFlowStep(AppFlowStep.auth);
    }
  }

  Future<void> login({String? userId, String? name, String? email, String? phone}) async {
    if (userId == null || userId.isEmpty) throw const ApiFailure('Identitas server diperlukan.');
    final generation = ++_generation;
    currentUserId = userId; userName = name ?? ''; userEmail = email ?? ''; userPhone = phone ?? '';
    if (repository?.userId != userId) {
      final store = await LocalStore.open(userId);
      if (_disposed || generation != _generation) { store.close(); return; }
      repository?.store.close();
      repository = FinanceRepository(auth.client, store, userId);
    }
    _authenticated = true; _currentFlow = AppFlowStep.main; _notify();
    await refresh();
  }
  Future<void> logout() async {
    ++_generation;
    _authenticated = false; _currentFlow = AppFlowStep.auth;
    final old = repository; repository = null;
    currentUserId = ''; userName = ''; userEmail = ''; userPhone = '';
    _activeHouseholdId = ''; dataError = null; _notify();
    // Let an in-flight request finish before closing its database.
    try { await auth.logout(); } finally {
      if (old != null) {
        try { await old.waitForSync(); } finally { old.store.close(); }
      }
    }
  }
  void register({required String name, required String email, String? phone, String? groupName}) {
    throw const ApiFailure('Daftar melalui autentikasi server terlebih dahulu.');
  }

  FinanceRepository get _repo => repository ?? (throw const ApiFailure('Data lokal belum siap.'));
  List<Map<String, dynamic>> _rows(String type) => repository?.rows(type) ?? [];
  Future<void> refresh() async {
    final repo = repository;
    if (repo == null || loading || _offline) return;
    loading = true; dataError = null; _notify();
    try {
      // A sync failure must not prevent reading unrelated server resources.
      // refreshList preserves locally queued mutations over server snapshots.
      try {
        await repo.sync();
      } catch (error) {
        dataError = error.toString();
      }
      for (final resource in ['account_types', 'accounts', 'categories', 'transactions',
        'ref_account_types', 'ref_categories', 'groups', 'budgets', 'notifications']) {
        try { await repo.refreshList(resource, '/${resource.replaceAll('_', '-')}'); }
        catch (error) { dataError ??= error.toString(); }
      }
      for (final group in repo.rows('groups')) {
        try {
          await repo.refreshList('members:${group['id']}', '/groups/${group['id']}/members');
          await repo.refreshList('group_categories:${group['id']}', '/groups/${group['id']}/categories');
        } catch (error) { dataError ??= error.toString(); }
      }
      for (final budget in repo.rows('budgets')) {
        final now = DateTime.now().toUtc();
        final period = switch (budget['period_type']) {
          'ANNUAL' => '${now.year}',
          'DAILY' || 'WEEKLY' => now.toIso8601String().substring(0, 10),
          _ => '${now.year}-${now.month.toString().padLeft(2, '0')}',
        };
        try { await repo.cacheValue('progress:${budget['id']}', () => repo.client.request(
          'GET', '/budgets/${budget['id']}/progress', query: {'period': period})); }
        catch (error) { dataError ??= error.toString(); }
      }
    } catch (error) { dataError = error.toString(); }
    finally { loading = false; _notify(); }
  }
  Future<void> syncPendingNow() => refresh();
  void _changed() { _notify(); if (!_offline) unawaited(refresh()); }
  void toggleOfflineMode() { _offline = !_offline; repository?.offline = _offline; _notify(); if (!_offline) unawaited(refresh()); }
  void toggleHideBalance() { _hidden = !_hidden; _notify(); }

  List<Map<String, dynamic>> get accountTypes => _rows('account_types');
  List<Map<String, dynamic>> get referenceAccountTypes => _rows('ref_account_types');
  List<Map<String, dynamic>> get referenceCategories => _rows('ref_categories');
  AccountType _accountType(Map<String, dynamic> row) {
    final types = accountTypes.where((t) => t['id'] == row['account_type_id']);
    if (types.isEmpty) return AccountType.cash;
    return types.first['category'] == 'INVESTMENT' ? AccountType.investment : AccountType.cash;
  }
  List<Account> get accounts => _rows('accounts').map((r) => Account(
    id: r['id'], name: r['name'], type: _accountType(r), balance: rupiah(r['balance']),
    accountNumber: '', institution: accountTypes.where((t) => t['id'] == r['account_type_id']).map((t) => t['name'] as String).firstOrNull ?? '',
    parentAccountId: r['parent_account_id'], isIncludeTotal: r['is_include_total'] ?? true,
    isVisible: r['is_visible'] ?? true, sequenceOrder: int.parse('${r['sequence_order'] ?? 0}'),
    currency: r['currency'] ?? 'IDR', ownerUserId: r['user_id'] ?? '',
    ownerName: r['user_id'] == currentUserId ? userName : '',
  )).toList();
  List<Account> get rootAccounts => accounts.where((a) => a.parentAccountId == null && a.isVisible).toList();
  List<Account> getChildrenForAccount(String id) => accounts.where((a) => a.parentAccountId == id && a.isVisible).toList();
  List<Account> get selectableAccounts {
    final parents = accounts.map((a) => a.parentAccountId).whereType<String>().toSet();
    return accounts.where((a) => a.isVisible && !parents.contains(a.id)).toList();
  }
  Account? getAccountById(String id) => accounts.where((a) => a.id == id).firstOrNull;
  void addAccount({required String name, required AccountType type, required int initialBalance,
    required String accountNumber, required String institution, bool isShared = false,
    String? householdId, String? parentAccountId, String? accountTypeId}) {
    if (initialBalance != 0 || isShared || householdId != null) {
      throw const ApiFailure('Saldo awal harus dicatat sebagai transaksi; sharing dilakukan setelah akun tersinkronisasi.');
    }
    if (accountTypeId == null) throw const ApiFailure('Pilih jenis akun dari server.');
    _repo.mutate('accounts', 'CREATE', {'name': name.trim(), 'account_type_id': accountTypeId,
      'parent_account_id': parentAccountId, 'currency': 'IDR', 'icon': null,
      'description': null, 'is_visible': true, 'is_include_total': true, 'sequence_order': '${accounts.length}'},
      local: {'balance': '0.00'});
    _changed();
  }
  Future<void> updateAccountSharing({required String accountId, required bool isShared, String? householdId}) async {
    if (householdId == null) throw const ApiFailure('Pilih grup terlebih dahulu.');
    await _repo.writeOnline(isShared ? 'POST' : 'DELETE', '/groups/$householdId/accounts', {'account_id': accountId});
    await refresh();
  }

  List<Category> get categories => _rows('categories').map((r) => Category(
    id: r['id'], name: r['name'], type: r['type'] == 'INCOME' ? CategoryType.income : CategoryType.expense,
    icon: Icons.category_rounded, color: const Color(0xFF0D9488), userId: r['user_id'],
  )).toList();
  List<Category> get expenseCategories => categories.where((c) => c.type == CategoryType.expense).toList();
  List<Category> get incomeCategories => categories.where((c) => c.type == CategoryType.income).toList();
  Category? getCategoryByName(String name) => categories.where((c) => c.name.toLowerCase() == name.toLowerCase()).firstOrNull;
  List<String> getCategoriesForAccount(String id, {required bool isIncome}) {
    final owner = getAccountById(id)?.ownerUserId ?? currentUserId;
    return categories.where((c) => c.userId == owner && c.type == (isIncome ? CategoryType.income : CategoryType.expense)).map((c) => c.name).toList();
  }
  void addCategory({required String name, required CategoryType type, required IconData icon, required Color color}) {
    _repo.mutate('categories', 'CREATE', {'name': name.trim(), 'type': type == CategoryType.income ? 'INCOME' : 'EXPENSE'}); _changed();
  }
  void updateCategory({required String id, String? name, IconData? icon, Color? color}) {
    if (name == null) throw const ApiFailure('Server hanya mendukung nama dan tipe kategori.');
    _repo.mutate('categories', 'UPDATE', {'name': name.trim()}, id: id); _changed();
  }
  bool deleteCategory(String id) { _repo.mutate('categories', 'DELETE', null, id: id); _changed(); return true; }

  List<TransactionItem> get transactions => _rows('transactions').map((r) {
    final pending = _repo.outbox.where((e) => e['entity_id'] == r['id']).firstOrNull;
    final amount = rupiah(r['amount']);
    return TransactionItem(id: r['id'], type: switch(r['type']) {'INCOME' => TransactionType.income, 'TRANSFER' => TransactionType.transfer, _ => TransactionType.expense},
      amount: amount.abs(), accountId: r['account_id'], categoryName: categories.where((c) => c.id == r['category_id']).map((c) => c.name).firstOrNull ?? (r['type'] == 'TRANSFER' ? 'Transfer Antar Akun' : ''),
      note: r['description'], date: DateTime.parse(r['transacted_at']), householdId: '',
      transferId: r['transfer_id'], createdByUserId: r['created_by'] ?? '',
      createdByName: r['created_by'] == currentUserId ? userName : '',
      syncStatus: pending == null ? SyncStatus.synced : pending['status'] == 'pending' ? SyncStatus.pending : SyncStatus.failed);
  }).toList()..sort((a,b) => b.date.compareTo(a.date));
  void addTransaction({required TransactionType type, required int amount, required String accountId,
    String? toAccountId, required String categoryName, String? note, required DateTime date,
    bool isDebt = false, bool isReceivable = false}) {
    if (type != TransactionType.income && type != TransactionType.expense || isDebt || isReceivable) {
      throw const ApiFailure('Transfer, utang, dan piutang belum mendukung antrean offline.');
    }
    final account = _repo.row('accounts', accountId);
    final category = categories.where((c) => c.name == categoryName && c.userId == account?['user_id'] && c.type == (type == TransactionType.income ? CategoryType.income : CategoryType.expense)).firstOrNull;
    if (account == null || category == null || amount <= 0) throw const ApiFailure('Pilih akun, kategori, dan nominal yang valid.');
    // One durable SQLite commit contains the mutation, outbox, and optimistic cash balance.
    _repo.mutate('transactions', 'CREATE', {'account_id': accountId, 'category_id': category.id,
      'type': type == TransactionType.income ? 'INCOME' : 'EXPENSE', 'amount': '$amount.00',
      'transacted_at': date.toUtc().toIso8601String(), 'description': note?.trim().isEmpty == true ? null : note},
      local: {'created_by': currentUserId}, balanceDelta: {accountId: type == TransactionType.income ? amount : -amount});
    _changed();
  }

  List<Household> get households => _rows('groups').map((r) => Household(
    id: r['id'], name: r['name'], type: GroupType.other, inviteCode: r['code'] ?? '', sharedBalance: 0,
    members: _rows('members:${r['id']}').map((m) => HouseholdMember(id: m['user_id'], name: m['name'],
      roleName: m['role'] == 'OWNER' ? 'Owner' : 'Anggota', role: m['role'] == 'OWNER' ? MemberRole.admin : MemberRole.member,
      avatarInitials: (m['name'] as String).split(' ').where((s) => s.isNotEmpty).take(2).map((s) => s[0]).join().toUpperCase(), email: '')).toList(),
  )).toList();
  String get activeHouseholdId => activeHousehold.id;
  Household get activeHousehold => households.where((h) => h.id == _activeHouseholdId).firstOrNull ?? households.firstOrNull ?? const Household(id: '', name: 'Belum ada grup', type: GroupType.other, inviteCode: '', members: [], sharedBalance: 0);
  Household get household => activeHousehold;
  void switchHousehold(String id) { _activeHouseholdId = id; _notify(); }
  Future<void> createHousehold({required String name, required GroupType type, String? description}) async {
    final result = await _repo.writeOnline('POST', '/groups', {'name': name.trim()});
    _repo.atomic(() { (_repo.entities.putIfAbsent('groups', () => <String,dynamic>{}) as Map)[result['id']] = result; });
    _activeHouseholdId = result['id']; await refresh();
  }
  bool joinHouseholdWithCode(String code) => throw const ApiFailure('Backend memerlukan ID grup dan kode undangan 12 karakter.');
  void updateHouseholdName(String name) => throw const ApiFailure('API perubahan grup belum tersedia.');
  void updateActiveHousehold({String? name, GroupType? type, String? description}) => throw const ApiFailure('API perubahan grup belum tersedia.');
  void addMemberToHousehold({required String householdId, required String name, required String email, required MemberRole role, required String roleName}) => throw const ApiFailure('Gunakan undangan grup; API tambah anggota langsung belum tersedia.');
  void deleteOrLeaveHousehold(String id) => throw const ApiFailure('API keluar/hapus grup belum tersedia.');
  List<TransactionItem> get activeHouseholdTransactions => [];
  int get activeHouseholdTotalExpense => 0;
  Map<String,int> get activeHouseholdExpenseByMember => {};
  List<MemberExpenseContribution> get activeHouseholdContributions => [];
  List<GroupCategory> get groupCategories => _rows('group_categories:${activeHousehold.id}').map((r) => GroupCategory(id: r['id'], groupId: r['group_id'], name: r['name'], type: r['type'], mappedUserCategories: [], totalAggregatedAmount: 0)).toList();

  List<BudgetItem> get budgets => _rows('budgets').map((r) {
    final progress = repository?.state['progress:${r['id']}'] as Map?;
    return BudgetItem(id: r['id'], categoryId: r['category_id'], categoryName: categories.where((c) => c.id == r['category_id']).map((c) => c.name).firstOrNull ?? '',
      icon: r['icon'] ?? 'category', allocatedAmount: rupiah(progress?['allowance'] ?? r['current_amount']),
      spentAmount: rupiah(progress?['total_amount']), periodType: r['period_type'], anchorDate: DateTime.parse(r['anchor_date']));
  }).toList();
  int get totalBudgetAllocated => budgets.fold(0, (sum,b) => sum + b.allocatedAmount);
  int get totalBudgetSpent => budgets.fold(0, (sum,b) => sum + b.spentAmount);
  Future<void> setCategoryBudget({required String categoryName, required int allocatedAmount}) async {
    final category = getCategoryByName(categoryName);
    if (category == null) throw const ApiFailure('Kategori tidak ditemukan.');
    final existing = budgets.where((b) => b.categoryId == category.id).firstOrNull;
    await _repo.writeOnline(existing == null ? 'POST' : 'PATCH', existing == null ? '/budgets' : '/budgets/${existing.id}',
      {'amount': '$allocatedAmount.00', if (existing == null) ...{'category_id': category.id, 'anchor_date': DateTime.now().toUtc().toIso8601String().substring(0,10), 'period_type': 'MONTHLY'}});
    await refresh();
  }
  // No fabricated holdings. Portfolio integration requires account-scoped snapshots.
  List<InvestmentAsset> get investments => [];
  void recordInvestmentTrade({required String assetId, required InvestmentTradeType tradeType, required double quantity, required double pricePerUnit, required int fee, String? cashAccountId, String? note}) => throw const ApiFailure('Pilih portofolio dan instrumen server terlebih dahulu.');
  void updateInstrumentPrice(String assetId, double newPrice) => throw const ApiFailure('Instrumen server diperlukan untuk memperbarui harga.');
  List<AppNotificationItem> get notifications => _rows('notifications').map((r) => AppNotificationItem(id: r['id'], type: NotificationType.values.byName(r['type']), title: r['title'], body: r['body'], createdAt: DateTime.parse(r['created_at']), isRead: r['is_read'])).toList();
  int get unreadNotificationCount => notifications.where((n) => !n.isRead).length;
  Future<void> markNotificationsAsRead() async {
    for (final item in notifications.where((n) => !n.isRead)) { await _repo.writeOnline('PATCH', '/notifications/${item.id}/read', {}); }
    await refresh();
  }
  List<SyncQueueItem> get syncQueue => (repository?.outbox ?? []).map((e) => SyncQueueItem(
    id: e['id'], entityType: e['entity_type'], entityId: e['entity_id'], operation: e['operation'],
    description: '${e['operation']} ${e['entity_type']}', timestamp: DateTime.parse(e['created_at']),
    clientVersion: int.parse('${e['client_version']}'), retryCount: e['attempts'], lastError: e['error'])).toList();
  int get pendingSyncCount => syncQueue.length;
  List<SyncConflictItem> get conflicts => (repository?.outbox ?? []).where((e) => e['status'] == 'conflict').map((e) => SyncConflictItem(
    id: e['id'], entityType: e['entity_type'], entityName: e['entity_id'], fieldName: 'Data',
    localValue: '${e['payload']}', serverValue: '${e['server_data']}', localVersion: int.parse('${e['client_version']}'),
    serverVersion: int.parse('${e['server_data']?['version'] ?? 0}'), conflictTimestamp: DateTime.parse(e['created_at']))).toList();
  int get conflictCount => conflicts.length;
  void resolveConflictUseMine(String id) { _repo.resolve(id, useMine: true); _changed(); }
  void resolveConflictUseServer(String id) { _repo.resolve(id, useMine: false); _changed(); }
  int get totalLiquidCash => accounts.where((a) => a.isIncludeTotal && a.type != AccountType.investment).fold(0, (sum,a) => sum + a.balance);
  int get totalInvestmentValue => investments.fold(0, (sum,a) => sum + a.totalCurrentValue);
  int get totalNetWorth => totalLiquidCash + totalInvestmentValue;
  bool _thisMonth(DateTime date) { final now = DateTime.now(); final local = date.toLocal(); return local.year == now.year && local.month == now.month; }
  int get monthIncome => transactions.where((t) => t.type == TransactionType.income && _thisMonth(t.date)).fold(0, (sum,t) => sum + t.amount);
  int get monthExpense => transactions.where((t) => t.type == TransactionType.expense && _thisMonth(t.date)).fold(0, (sum,t) => sum + t.amount);
  int get monthNetSavings => monthIncome - monthExpense;

  double get monthGrowthPercentage {
    final savings = monthNetSavings;
    final startNetWorth = totalNetWorth - savings;
    if (startNetWorth == 0) {
      if (totalNetWorth > 0) return 100.0;
      if (totalNetWorth < 0) return -100.0;
      return 0.0;
    }
    return (savings / startNetWorth.abs()) * 100.0;
  }

  List<double> get monthNetWorthTrend {
    final now = DateTime.now();
    final startVal = (totalNetWorth - monthNetSavings).toDouble();
    final monthTx = transactions
        .where((t) => _thisMonth(t.date))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    if (monthTx.isEmpty) {
      return [startVal, totalNetWorth.toDouble()];
    }

    final dailyDeltas = <int, double>{};
    for (final t in monthTx) {
      final day = t.date.toLocal().day;
      final delta = t.type == TransactionType.income
          ? t.amount.toDouble()
          : t.type == TransactionType.expense
              ? -t.amount.toDouble()
              : 0.0;
      dailyDeltas[day] = (dailyDeltas[day] ?? 0.0) + delta;
    }

    final points = <double>[startVal];
    var running = startVal;
    for (var day = 1; day <= now.day; day++) {
      if (dailyDeltas.containsKey(day)) {
        running += dailyDeltas[day]!;
        points.add(running);
      }
    }
    if (points.last != totalNetWorth.toDouble()) {
      points.add(totalNetWorth.toDouble());
    }
    return points;
  }
  @override
  void dispose() {
    _disposed = true; ++_generation;
    final repo = repository;
    if (repo != null) unawaited(repo.waitForSync().whenComplete(repo.store.close));
    super.dispose();
  }
}

class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({super.key, required AppState state, required super.child}) : super(notifier: state);
  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'No AppStateScope found in context');
    return scope!.notifier!;
  }
}
