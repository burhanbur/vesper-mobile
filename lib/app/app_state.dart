import 'package:flutter/material.dart';

import '../features/accounts/models/account.dart';
import '../features/categories/models/category.dart';
import '../features/household/models/group_category.dart';
import '../features/household/models/household.dart';
import '../features/investments/models/investment.dart';
import '../features/notifications/models/notification_item.dart';
import '../features/reports/models/budget.dart';
import '../features/sync/models/sync_conflict.dart';
import '../features/transactions/models/transaction.dart';

enum AppFlowStep {
  splash,
  onboarding,
  auth,
  main,
}

class SyncQueueItem {
  final String id;
  final String entityType;
  final String entityId;
  final String operation; // CREATE, UPDATE, DELETE
  final String description;
  final DateTime timestamp;
  // clientVersion is sent to POST /sync/push for optimistic locking (PRD Section 3 & Backend 5.10)
  final int clientVersion;
  bool isSynced;
  int retryCount;
  String? lastError;

  SyncQueueItem({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.description,
    required this.timestamp,
    this.clientVersion = 1,
    this.isSynced = false,
    this.retryCount = 0,
    this.lastError,
  });
}

class AppState extends ChangeNotifier {
  // Current User Profile
  String _currentUserId = 'u-1';
  String _userName = 'Burhan Mafazi';
  String _userEmail = 'burhan@mafazi.family';
  String _userPhone = '+62 812-3456-7890';
  final String baseCurrency = 'IDR';

  // Auth State
  bool _isAuthenticated = true;
  AppFlowStep _currentFlow = AppFlowStep.main;

  AppState({bool? isAuthenticated, AppFlowStep? initialFlow}) {
    if (isAuthenticated != null) {
      _isAuthenticated = isAuthenticated;
      _currentFlow = isAuthenticated ? AppFlowStep.main : AppFlowStep.auth;
    }
    if (initialFlow != null) {
      _currentFlow = initialFlow;
    }
  }

  String get currentUserId => _currentUserId;
  String get userName => _userName;
  String get userEmail => _userEmail;
  String get userPhone => _userPhone;
  bool get isAuthenticated => _isAuthenticated;
  AppFlowStep get currentFlow => _currentFlow;

  void setFlowStep(AppFlowStep step) {
    _currentFlow = step;
    notifyListeners();
  }

  void showSplash() {
    _currentFlow = AppFlowStep.splash;
    notifyListeners();
  }

  void showOnboarding() {
    _currentFlow = AppFlowStep.onboarding;
    notifyListeners();
  }

  void completeOnboarding() {
    _currentFlow = _isAuthenticated ? AppFlowStep.main : AppFlowStep.auth;
    notifyListeners();
  }

  // State flags
  bool _isOfflineMode = false;
  bool _isBalanceHidden = false;

  bool get isOfflineMode => _isOfflineMode;
  bool get isBalanceHidden => _isBalanceHidden;

  // Multi-Group / Household data
  String _activeHouseholdId = 'hh-1';

  final List<Household> _households = [
    const Household(
      id: 'hh-1',
      name: 'Keluarga Mafazi',
      type: GroupType.family,
      description: 'Finansial utama rumah tangga & tabungan bersama keluarga',
      inviteCode: 'FAM-7712',
      sharedBalance: 44700000,
      members: [
        HouseholdMember(
          id: 'u-1',
          name: 'Burhan Mafazi',
          roleName: 'Pengelola (Owner)',
          role: MemberRole.admin,
          avatarInitials: 'BM',
          email: 'burhan@mafazi.family',
        ),
        HouseholdMember(
          id: 'u-2',
          name: 'Sarah Mafazi',
          roleName: 'Admin Keuangan',
          role: MemberRole.admin,
          avatarInitials: 'SM',
          email: 'sarah@mafazi.family',
        ),
        HouseholdMember(
          id: 'u-3',
          name: 'Dimas Mafazi',
          roleName: 'Anggota',
          role: MemberRole.member,
          avatarInitials: 'DM',
          email: 'dimas@mafazi.family',
        ),
        HouseholdMember(
          id: 'u-4',
          name: 'Ibu Fatimah',
          roleName: 'Pemantau',
          role: MemberRole.viewer,
          avatarInitials: 'IF',
          email: 'fatimah@mafazi.family',
        ),
        HouseholdMember(
          id: 'u-5',
          name: 'Nenek Aminah',
          roleName: 'Pemantau',
          role: MemberRole.viewer,
          avatarInitials: 'NA',
          email: 'aminah@mafazi.family',
        ),
      ],
    ),
    const Household(
      id: 'hh-2',
      name: 'Kosan Senopati No. 12',
      type: GroupType.roommates,
      description: 'Patungan bulanan sewa kosan, listrik token, WiFi, & kas darurat',
      inviteCode: 'KSN-4491',
      sharedBalance: 3250000,
      members: [
        HouseholdMember(
          id: 'u-1',
          name: 'Burhan Mafazi',
          roleName: 'Admin / Bendahara',
          role: MemberRole.admin,
          avatarInitials: 'BM',
          email: 'burhan@mafazi.family',
        ),
        HouseholdMember(
          id: 'u-6',
          name: 'Reza Pratama',
          roleName: 'Anggota',
          role: MemberRole.member,
          avatarInitials: 'RP',
          email: 'reza.p@gmail.com',
        ),
        HouseholdMember(
          id: 'u-7',
          name: 'Kevin Jonathan',
          roleName: 'Anggota',
          role: MemberRole.member,
          avatarInitials: 'KJ',
          email: 'kevin.j@gmail.com',
        ),
      ],
    ),
    const Household(
      id: 'hh-3',
      name: 'Trip Labuan Bajo 2026',
      type: GroupType.trip,
      description: 'Patungan tiket kapal liveaboard, sewa mobil, diving & makan bersama',
      inviteCode: 'TRP-9023',
      sharedBalance: 12800000,
      members: [
        HouseholdMember(
          id: 'u-1',
          name: 'Burhan Mafazi',
          roleName: 'Koordinator Finansial',
          role: MemberRole.admin,
          avatarInitials: 'BM',
          email: 'burhan@mafazi.family',
        ),
        HouseholdMember(
          id: 'u-3',
          name: 'Dimas Mafazi',
          roleName: 'Anggota',
          role: MemberRole.member,
          avatarInitials: 'DM',
          email: 'dimas@mafazi.family',
        ),
        HouseholdMember(
          id: 'u-8',
          name: 'Andi Wijaya',
          roleName: 'Anggota',
          role: MemberRole.member,
          avatarInitials: 'AW',
          email: 'andi.w@gmail.com',
        ),
        HouseholdMember(
          id: 'u-9',
          name: 'Fajar Nugraha',
          roleName: 'Anggota',
          role: MemberRole.member,
          avatarInitials: 'FN',
          email: 'fajar.n@gmail.com',
        ),
      ],
    ),
  ];

  List<Household> get households => List.unmodifiable(_households);
  String get activeHouseholdId => _activeHouseholdId;

  Household get activeHousehold => _households.firstWhere(
    (h) => h.id == _activeHouseholdId,
    orElse: () => _households.first,
  );

  Household get household => activeHousehold;

  // ==================== CATEGORIES (PRD 4.4 & Architecture) ====================
  final List<Category> _categories = List.from(Category.initialCategories);

  List<Category> get categories => List.unmodifiable(_categories);

  List<Category> get expenseCategories =>
      _categories.where((c) => c.type == CategoryType.expense).toList();

  List<Category> get incomeCategories =>
      _categories.where((c) => c.type == CategoryType.income).toList();

  Category? getCategoryByName(String name) {
    try {
      return _categories.firstWhere((c) => c.name.toLowerCase() == name.toLowerCase());
    } catch (_) {
      return null;
    }
  }

  void addCategory({
    required String name,
    required CategoryType type,
    required IconData icon,
    required Color color,
  }) {
    final trimmedName = name.trim();
    final newCat = Category(
      id: 'cat-custom-${DateTime.now().millisecondsSinceEpoch}',
      name: trimmedName,
      type: type,
      icon: icon,
      color: color,
      userId: _currentUserId,
      isDefault: false,
      sequenceOrder: _categories.length + 1,
    );
    _categories.add(newCat);

    final targetMap = type == CategoryType.expense ? _ownerExpenseCategories : _ownerIncomeCategories;
    final list = targetMap.putIfAbsent(_currentUserId, () => []);
    if (!list.contains(trimmedName)) {
      list.add(trimmedName);
    }

    _enqueueSync(
      entityType: 'category',
      entityId: newCat.id,
      operation: 'CREATE',
      description: 'Tambah kategori ${type == CategoryType.expense ? "pengeluaran" : "pemasukan"} "$name"',
    );
    notifyListeners();
  }

  void updateCategory({
    required String id,
    String? name,
    IconData? icon,
    Color? color,
  }) {
    final index = _categories.indexWhere((c) => c.id == id);
    if (index != -1) {
      final old = _categories[index];
      final newName = name?.trim();
      _categories[index] = old.copyWith(
        name: newName,
        icon: icon,
        color: color,
      );

      if (newName != null && newName != old.name) {
        final targetMap = old.type == CategoryType.expense ? _ownerExpenseCategories : _ownerIncomeCategories;
        final list = targetMap[_currentUserId];
        final listIdx = list?.indexOf(old.name) ?? -1;
        if (list != null && listIdx != -1) {
          list[listIdx] = newName;
        }
      }

      _enqueueSync(
        entityType: 'category',
        entityId: id,
        operation: 'UPDATE',
        description: 'Perbarui kategori "${_categories[index].name}"',
      );
      notifyListeners();
    }
  }

  bool deleteCategory(String id) {
    final index = _categories.indexWhere((c) => c.id == id);
    if (index != -1) {
      final cat = _categories[index];
      if (cat.isDefault) {
        // Protected system default category
        return false;
      }
      _categories.removeAt(index);
      final targetMap = cat.type == CategoryType.expense ? _ownerExpenseCategories : _ownerIncomeCategories;
      targetMap[_currentUserId]?.remove(cat.name);

      _enqueueSync(
        entityType: 'category',
        entityId: id,
        operation: 'DELETE',
        description: 'Hapus kategori "${cat.name}"',
      );
      notifyListeners();
      return true;
    }
    return false;
  }

  // ACCOUNTS (Supports Nested Accounts / Pockets per PRD 4.3)
  List<Account> _accounts = [
    // Parent Account with pockets: Bank Jago (isIncludeTotal = false so its sum is not double-counted)
    const Account(
      id: 'acc-jago',
      name: 'Bank Jago (Kantong)',
      type: AccountType.bank,
      balance: 13800000, // Computed from sum of pockets
      accountNumber: '5001 2345 6789',
      institution: 'Bank Jago',
      isShared: true,
      householdId: 'hh-1',
      isIncludeTotal: false, // Prevents double counting!
      sequenceOrder: 1,
      ownerUserId: 'u-1',
      ownerName: 'Burhan Mafazi',
    ),
    const Account(
      id: 'acc-jago-main',
      name: 'Kantong Utama',
      type: AccountType.bank,
      balance: 3500000,
      accountNumber: 'Jago - 01',
      institution: 'Bank Jago',
      isShared: true,
      householdId: 'hh-1',
      parentAccountId: 'acc-jago',
      isIncludeTotal: true,
      sequenceOrder: 1,
      ownerUserId: 'u-1',
      ownerName: 'Burhan Mafazi',
    ),
    const Account(
      id: 'acc-jago-pangan',
      name: 'Kantong Pangan & Belanja',
      type: AccountType.bank,
      balance: 1800000,
      accountNumber: 'Jago - 02',
      institution: 'Bank Jago',
      isShared: true,
      householdId: 'hh-1',
      parentAccountId: 'acc-jago',
      isIncludeTotal: true,
      sequenceOrder: 2,
      ownerUserId: 'u-1',
      ownerName: 'Burhan Mafazi',
    ),
    const Account(
      id: 'acc-jago-darurat',
      name: 'Kantong Dana Darurat',
      type: AccountType.bank,
      balance: 8500000,
      accountNumber: 'Jago - 03',
      institution: 'Bank Jago',
      isShared: true,
      householdId: 'hh-1',
      parentAccountId: 'acc-jago',
      isIncludeTotal: true,
      sequenceOrder: 3,
      ownerUserId: 'u-1',
      ownerName: 'Burhan Mafazi',
    ),

    // Standalone bank accounts
    const Account(
      id: 'acc-bca',
      name: 'BCA Utama',
      type: AccountType.bank,
      balance: 18400000,
      accountNumber: '1234 5678 90',
      institution: 'Bank BCA',
      isShared: true,
      householdId: 'hh-1',
      isIncludeTotal: true,
      sequenceOrder: 2,
      ownerUserId: 'u-1',
      ownerName: 'Burhan Mafazi',
    ),
    const Account(
      id: 'acc-mandiri',
      name: 'Bank Mandiri',
      type: AccountType.bank,
      balance: 12500000,
      accountNumber: '9876 5432 10',
      institution: 'Bank Mandiri',
      isShared: true,
      householdId: 'hh-1',
      isIncludeTotal: true,
      sequenceOrder: 3,
      ownerUserId: 'u-2',
      ownerName: 'Sarah Mafazi',
    ),
    const Account(
      id: 'acc-cash',
      name: 'Kas Tunai Dompet',
      type: AccountType.cash,
      balance: 1250000,
      accountNumber: 'Cash / Dompet',
      institution: 'Tunai',
      isShared: false,
      isIncludeTotal: true,
      sequenceOrder: 4,
      ownerUserId: 'u-1',
      ownerName: 'Burhan Mafazi',
    ),
    const Account(
      id: 'acc-wallet',
      name: 'GoPay / e-Wallet',
      type: AccountType.wallet,
      balance: 450000,
      accountNumber: '0812-3456-7890',
      institution: 'GoPay',
      isShared: false,
      isIncludeTotal: true,
      sequenceOrder: 5,
      ownerUserId: 'u-1',
      ownerName: 'Burhan Mafazi',
    ),
  ];

  List<Account> get accounts => List.unmodifiable(_accounts);

  // Return only top-level (root) accounts for high-level lists
  List<Account> get rootAccounts =>
      _accounts.where((acc) => acc.parentAccountId == null && acc.isVisible).toList();

  // Return children for a parent account
  List<Account> getChildrenForAccount(String parentId) =>
      _accounts.where((acc) => acc.parentAccountId == parentId && acc.isVisible).toList();

  // Return selectable accounts (including pockets, but excluding parents that have children)
  List<Account> get selectableAccounts {
    final parentIds = _accounts
        .where((a) => a.parentAccountId != null)
        .map((a) => a.parentAccountId!)
        .toSet();
    return _accounts
        .where((acc) => acc.isVisible && !parentIds.contains(acc.id))
        .toList();
  }

  // CATEGORIES (Owner-based per PRD 4.4)
  final Map<String, List<String>> _ownerExpenseCategories = {
    'u-1': [
      'Makanan & Minuman',
      'Transportasi',
      'Belanja Bulanan',
      'Tagihan & Utilitas',
      'Keluarga',
      'Hiburan & Hobi',
      'Pendidikan',
      'Kesehatan',
      'Lainnya',
    ],
    'u-2': [
      'Dapur & Bahan Masak',
      'Kebutuhan Anak & Bayi',
      'Skincare & Perawatan',
      'Belanja Rumah Tangga',
      'Arisan & Sosial',
      'Lainnya',
    ],
  };

  final Map<String, List<String>> _ownerIncomeCategories = {
    'u-1': ['Gaji', 'Side Project', 'Bonus Tahunan', 'Dividen', 'Penjualan Aset'],
    'u-2': ['Gaji Kantor', 'Bisnis Fashion Online', 'Hadiah'],
  };

  List<String> getCategoriesForAccount(String accountId, {required bool isIncome}) {
    final account = getAccountById(accountId);
    final ownerId = account?.ownerUserId ?? currentUserId;
    if (isIncome) {
      return _ownerIncomeCategories[ownerId] ?? _ownerIncomeCategories['u-1']!;
    } else {
      return _ownerExpenseCategories[ownerId] ?? _ownerExpenseCategories['u-1']!;
    }
  }

  // INVESTMENTS (Holdings + Daily Price Update + Trade History per PRD 4.7 & 5.8)
  final List<InvestmentAsset> _investments = [
    InvestmentAsset(
      id: 'inv-btc',
      name: 'Bitcoin (BTC)',
      symbol: 'BTC',
      type: InvestmentAssetType.crypto,
      quantity: 0.015,
      quantityDisplay: '0.015 BTC',
      avgCostPrice: 1000000000,
      currentPrice: 1333333333,
      totalInvestedValue: 15000000,
      totalCurrentValue: 20000000,
      isPriceUpdatedToday: false, // Triggers quick update prompt in PRD 4.7!
      lastUpdated: DateTime.now().subtract(const Duration(hours: 18)),
      transactions: [
        InvestmentTransactionRecord(
          id: 'itx-1',
          type: InvestmentTradeType.buy,
          quantity: 0.010,
          pricePerUnit: 950000000,
          fee: 25000,
          totalAmount: 9525000,
          cashAccountId: 'acc-bca',
          transactedAt: DateTime.now().subtract(const Duration(days: 45)),
          note: 'DCA Awal Bulan',
        ),
        InvestmentTransactionRecord(
          id: 'itx-2',
          type: InvestmentTradeType.buy,
          quantity: 0.005,
          pricePerUnit: 1100000000,
          fee: 15000,
          totalAmount: 5515000,
          cashAccountId: 'acc-bca',
          transactedAt: DateTime.now().subtract(const Duration(days: 15)),
          note: 'DCA Tambahan',
        ),
      ],
    ),
    InvestmentAsset(
      id: 'inv-bbca',
      name: 'Saham Bank BCA (BBCA)',
      symbol: 'BBCA',
      type: InvestmentAssetType.stock,
      quantity: 35.0, // 35 lot = 3,500 lembar
      quantityDisplay: '35 Lot (3.500 lbr)',
      avgCostPrice: 8571,
      currentPrice: 10000,
      totalInvestedValue: 30000000,
      totalCurrentValue: 35000000,
      isPriceUpdatedToday: true,
      lastUpdated: DateTime.now().subtract(const Duration(hours: 2)),
      transactions: [
        InvestmentTransactionRecord(
          id: 'itx-3',
          type: InvestmentTradeType.buy,
          quantity: 35.0,
          pricePerUnit: 8571,
          fee: 50000,
          totalAmount: 30050000,
          cashAccountId: 'acc-mandiri',
          transactedAt: DateTime.now().subtract(const Duration(days: 90)),
          note: 'Investasi Jangka Panjang BBCA',
        ),
      ],
    ),
    InvestmentAsset(
      id: 'inv-rdpu',
      name: 'Reksadana Pasar Uang (Bibit)',
      symbol: 'RDPU',
      type: InvestmentAssetType.mutualFund,
      quantity: 25000.0,
      quantityDisplay: '25.000 Unit',
      avgCostPrice: 950,
      currentPrice: 1000,
      totalInvestedValue: 23750000,
      totalCurrentValue: 25000000,
      isPriceUpdatedToday: true,
      lastUpdated: DateTime.now().subtract(const Duration(hours: 4)),
      transactions: [
        InvestmentTransactionRecord(
          id: 'itx-4',
          type: InvestmentTradeType.buy,
          quantity: 25000.0,
          pricePerUnit: 950,
          fee: 0,
          totalAmount: 23750000,
          cashAccountId: 'acc-bca',
          transactedAt: DateTime.now().subtract(const Duration(days: 60)),
          note: 'Alokasi Likuiditas Bibit',
        ),
      ],
    ),
    InvestmentAsset(
      id: 'inv-gold',
      name: 'Emas Antam 10g',
      symbol: 'EMAS',
      type: InvestmentAssetType.gold,
      quantity: 10.0,
      quantityDisplay: '10.0 Gram',
      avgCostPrice: 1270000,
      currentPrice: 1450000,
      totalInvestedValue: 12700000,
      totalCurrentValue: 14500000,
      isPriceUpdatedToday: true,
      lastUpdated: DateTime.now().subtract(const Duration(days: 1)),
      transactions: [
        InvestmentTransactionRecord(
          id: 'itx-5',
          type: InvestmentTradeType.buy,
          quantity: 10.0,
          pricePerUnit: 1270000,
          fee: 0,
          totalAmount: 12700000,
          cashAccountId: 'acc-jago-darurat',
          transactedAt: DateTime.now().subtract(const Duration(days: 120)),
          note: 'Lindung Nilai Fisik',
        ),
      ],
    ),
  ];

  List<InvestmentAsset> get investments => List.unmodifiable(_investments);

  // BUDGETS (PRD 4.6 & contoh-2)
  List<BudgetItem> _budgets = [
    BudgetItem(
      id: 'b-1',
      categoryId: 'cat-food',
      categoryName: 'Makanan & Minuman',
      icon: 'restaurant',
      allocatedAmount: 2000000,
      spentAmount: 1665000,
      anchorDate: DateTime(2026, 9, 1),
    ),
    BudgetItem(
      id: 'b-2',
      categoryId: 'cat-groceries',
      categoryName: 'Belanja Bulanan',
      icon: 'shopping_cart',
      allocatedAmount: 1800000,
      spentAmount: 1250000,
      anchorDate: DateTime(2026, 9, 1),
    ),
    BudgetItem(
      id: 'b-3',
      categoryId: 'cat-parents',
      categoryName: 'Kasih ke Orang Tua',
      icon: 'favorite',
      allocatedAmount: 1000000,
      spentAmount: 1000000,
      anchorDate: DateTime(2026, 9, 1),
    ),
    BudgetItem(
      id: 'b-4',
      categoryId: 'cat-transport',
      categoryName: 'Transportasi',
      icon: 'directions_car',
      allocatedAmount: 800000,
      spentAmount: 500000,
      anchorDate: DateTime(2026, 9, 1),
    ),
    BudgetItem(
      id: 'b-5',
      categoryId: 'cat-bills',
      categoryName: 'Tagihan & WiFi',
      icon: 'receipt',
      allocatedAmount: 700000,
      spentAmount: 585000,
      anchorDate: DateTime(2026, 9, 1),
    ),
    BudgetItem(
      id: 'b-6',
      categoryId: 'cat-entertainment',
      categoryName: 'Hiburan & Liburan',
      icon: 'movie',
      allocatedAmount: 1700000,
      spentAmount: 300000,
      anchorDate: DateTime(2026, 9, 1),
    ),
  ];

  List<BudgetItem> get budgets => List.unmodifiable(_budgets);

  int get totalBudgetAllocated =>
      _budgets.fold(0, (sum, b) => sum + b.allocatedAmount);
  int get totalBudgetSpent =>
      _budgets.fold(0, (sum, b) => sum + b.spentAmount);

  void setCategoryBudget({
    required String categoryName,
    required int allocatedAmount,
  }) {
    final idx = _budgets.indexWhere((b) => b.categoryName == categoryName);
    if (idx != -1) {
      _budgets[idx] = _budgets[idx].copyWith(allocatedAmount: allocatedAmount);
    } else {
      _budgets.add(
        BudgetItem(
          id: 'b-${DateTime.now().millisecondsSinceEpoch}',
          categoryId: 'cat-${DateTime.now().millisecondsSinceEpoch}',
          categoryName: categoryName,
          icon: 'category',
          allocatedAmount: allocatedAmount,
          spentAmount: 0,
          anchorDate: DateTime(2026, 9, 1),
        ),
      );
    }
    notifyListeners();
  }

  // GROUP CATEGORIES & MAPPING (PRD 4.8)
  final List<GroupCategory> _groupCategories = [
    const GroupCategory(
      id: 'gc-1',
      groupId: 'hh-1',
      name: 'Kebutuhan Pangan Keluarga',
      type: 'EXPENSE',
      mappedUserCategories: ['Makanan & Minuman', 'Dapur & Bahan Masak'],
      totalAggregatedAmount: 3250000,
    ),
    const GroupCategory(
      id: 'gc-2',
      groupId: 'hh-1',
      name: 'Operasional Rumah & Tagihan',
      type: 'EXPENSE',
      mappedUserCategories: ['Tagihan & Utilitas', 'Belanja Rumah Tangga'],
      totalAggregatedAmount: 1450000,
    ),
    const GroupCategory(
      id: 'gc-3',
      groupId: 'hh-1',
      name: 'Pendidikan & Anak',
      type: 'EXPENSE',
      mappedUserCategories: ['Pendidikan', 'Kebutuhan Anak & Bayi'],
      totalAggregatedAmount: 1200000,
    ),
  ];

  List<GroupCategory> get groupCategories =>
      List.unmodifiable(_groupCategories);

  // TRANSACTIONS (Rich history with actor name and transfer info)
  List<TransactionItem> _transactions = [
    TransactionItem(
      id: 'tx-1',
      type: TransactionType.income,
      amount: 15200000,
      accountId: 'acc-bca',
      categoryName: 'Gaji',
      note: 'Gaji Bulanan September & Tunjangan',
      date: DateTime.now().subtract(const Duration(hours: 3)),
      householdId: 'hh-1',
      syncStatus: SyncStatus.synced,
      createdByUserId: 'u-1',
      createdByName: 'Burhan Mafazi',
    ),
    TransactionItem(
      id: 'tx-2',
      type: TransactionType.expense,
      amount: 45000,
      accountId: 'acc-cash',
      categoryName: 'Makanan & Minuman',
      note: 'Makan Siang Nasi Padang',
      date: DateTime.now().subtract(const Duration(hours: 7)),
      householdId: 'hh-1',
      syncStatus: SyncStatus.synced,
      createdByUserId: 'u-1',
      createdByName: 'Burhan Mafazi',
    ),
    TransactionItem(
      id: 'tx-3',
      type: TransactionType.expense,
      amount: 125000,
      accountId: 'acc-jago-pangan',
      categoryName: 'Dapur & Bahan Masak',
      note: 'Sayuran & Buah Segar Pasar',
      date: DateTime.now().subtract(const Duration(hours: 11)),
      householdId: 'hh-1',
      syncStatus: SyncStatus.synced,
      createdByUserId: 'u-2',
      createdByName: 'Sarah Mafazi',
    ),
    TransactionItem(
      id: 'tx-4',
      type: TransactionType.expense,
      amount: 25000,
      accountId: 'acc-wallet',
      categoryName: 'Transportasi',
      note: 'Bensin & Parkir Motor',
      date: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
      householdId: 'hh-1',
      syncStatus: SyncStatus.synced,
      createdByUserId: 'u-1',
      createdByName: 'Burhan Mafazi',
    ),
    TransactionItem(
      id: 'tx-5',
      type: TransactionType.expense,
      amount: 1000000,
      accountId: 'acc-mandiri',
      categoryName: 'Keluarga',
      note: 'Transfer Bulanan Orang Tua',
      date: DateTime.now().subtract(const Duration(days: 2)),
      householdId: 'hh-1',
      syncStatus: SyncStatus.synced,
      createdByUserId: 'u-1',
      createdByName: 'Burhan Mafazi',
    ),
    TransactionItem(
      id: 'tx-6',
      type: TransactionType.expense,
      amount: 450000,
      accountId: 'acc-bca',
      categoryName: 'Belanja Bulanan',
      note: 'Belanja Supermarket Sabun & Beras',
      date: DateTime.now().subtract(const Duration(days: 3)),
      householdId: 'hh-1',
      syncStatus: SyncStatus.synced,
      createdByUserId: 'u-2',
      createdByName: 'Sarah Mafazi',
    ),
    TransactionItem(
      id: 'tx-7',
      type: TransactionType.transfer,
      amount: 500000,
      accountId: 'acc-bca',
      toAccountId: 'acc-jago-pangan',
      categoryName: 'Transfer Antar Akun',
      note: 'Isi Kantong Belanja Jago',
      date: DateTime.now().subtract(const Duration(days: 4)),
      householdId: 'hh-1',
      syncStatus: SyncStatus.synced,
      createdByUserId: 'u-1',
      createdByName: 'Burhan Mafazi',
    ),
  ];

  List<TransactionItem> get transactions => List.unmodifiable(_transactions);

  List<TransactionItem> get activeHouseholdTransactions =>
      _transactions.where((tx) => tx.householdId == activeHousehold.id).toList();

  int get activeHouseholdTotalExpense {
    return _transactions
        .where((tx) => tx.householdId == activeHousehold.id && tx.type == TransactionType.expense)
        .fold(0, (sum, tx) => sum + tx.amount);
  }

  Map<String, int> get activeHouseholdExpenseByMember {
    final map = <String, int>{};
    for (final tx in _transactions) {
      if (tx.householdId == activeHousehold.id && tx.type == TransactionType.expense) {
        final name = tx.createdByName;
        map[name] = (map[name] ?? 0) + tx.amount;
      }
    }
    return map;
  }

  List<MemberExpenseContribution> get activeHouseholdContributions {
    final total = activeHouseholdTotalExpense;
    final map = activeHouseholdExpenseByMember;
    final txCounts = <String, int>{};

    for (final tx in _transactions) {
      if (tx.householdId == activeHousehold.id && tx.type == TransactionType.expense) {
        final name = tx.createdByName;
        txCounts[name] = (txCounts[name] ?? 0) + 1;
      }
    }

    for (final m in activeHousehold.members) {
      map.putIfAbsent(m.name, () => 0);
      txCounts.putIfAbsent(m.name, () => 0);
    }

    return map.entries.map((e) {
      final member = activeHousehold.members.firstWhere(
        (m) => m.name == e.key,
        orElse: () => HouseholdMember(
          id: 'unknown',
          name: e.key,
          roleName: 'Anggota',
          role: MemberRole.member,
          avatarInitials: e.key.isNotEmpty ? e.key[0] : '?',
          email: '',
        ),
      );
      final amount = e.value;
      final percentage = total > 0 ? (amount / total * 100).round() : 0;
      return MemberExpenseContribution(
        member: member,
        amount: amount,
        percentage: percentage,
        transactionCount: txCounts[e.key] ?? 0,
      );
    }).toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
  }

  // NOTIFICATIONS (DBML notifications table)
  final List<AppNotificationItem> _notifications = [
    AppNotificationItem(
      id: 'notif-1',
      type: NotificationType.info,
      title: 'Mutasi Akun Bersama',
      body: 'Sarah Mafazi mencatat belanja Rp 125.000 di Kantong Pangan Jago.',
      createdAt: DateTime.now().subtract(const Duration(hours: 11)),
    ),
    AppNotificationItem(
      id: 'notif-2',
      type: NotificationType.warning,
      title: 'Peringatan Budget 80%',
      body: 'Pengeluaran Makanan & Minuman sudah mencapai 83% dari batas budget bulan ini.',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    AppNotificationItem(
      id: 'notif-3',
      type: NotificationType.info,
      title: 'Sinkronisasi Berhasil',
      body: '4 mutasi lokal telah tersinkronisasi ke PostgreSQL server.',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      isRead: true,
    ),
  ];

  List<AppNotificationItem> get notifications =>
      List.unmodifiable(_notifications);

  int get unreadNotificationCount =>
      _notifications.where((n) => !n.isRead).length;

  void markNotificationsAsRead() {
    for (final n in _notifications) {
      n.isRead = true;
    }
    notifyListeners();
  }

  // SYNC QUEUE & CONFLICT RESOLUTION (PRD Section 5)
  final List<SyncQueueItem> _syncQueue = [];
  List<SyncQueueItem> get syncQueue => List.unmodifiable(_syncQueue);
  int get pendingSyncCount => _syncQueue.where((item) => !item.isSynced).length;

  void _enqueueSync({
    required String entityType,
    required String entityId,
    required String operation,
    required String description,
  }) {
    _syncQueue.insert(
      0,
      SyncQueueItem(
        id: 'sync-${DateTime.now().millisecondsSinceEpoch}',
        entityType: entityType,
        entityId: entityId,
        operation: operation,
        description: description,
        timestamp: DateTime.now(),
        clientVersion: 1,
        isSynced: !_isOfflineMode,
      ),
    );
  }

  final List<SyncConflictItem> _conflicts = [
    SyncConflictItem(
      id: 'conflict-1',
      entityType: 'accounts',
      entityName: 'BCA Utama',
      fieldName: 'Catatan Deskripsi Akun',
      localValue: 'Akun Gaji & Tabungan Pokok Keluarga (Diubah di HP)',
      serverValue: 'Akun Operasional Kas Bersama (Diubah via Web oleh Sarah)',
      localVersion: 2,
      serverVersion: 3,
      conflictTimestamp: DateTime.now().subtract(const Duration(hours: 1)),
    ),
  ];

  List<SyncConflictItem> get conflicts => List.unmodifiable(_conflicts);
  int get conflictCount => _conflicts.length;

  // Resolve conflict: Overwrite server (Use Mine) per PRD Section 6
  // Sends local change back with clientVersion bumped to server's version (so optimistic lock passes)
  void resolveConflictUseMine(String conflictId) {
    final conflict = _conflicts.firstWhere((c) => c.id == conflictId, orElse: () => _conflicts.first);
    _conflicts.removeWhere((c) => c.id == conflictId);
    _syncQueue.insert(
      0,
      SyncQueueItem(
        id: 'sync-${DateTime.now().millisecondsSinceEpoch}',
        entityType: conflict.entityType,
        entityId: 'acc-bca',
        operation: 'UPDATE',
        description: 'Resolusi Konflik: Pakai data lokal ${conflict.entityName}',
        timestamp: DateTime.now(),
        clientVersion: conflict.serverVersion, // Use server version so optimistic lock passes
        isSynced: !_isOfflineMode,
      ),
    );
    notifyListeners();
  }

  // Resolve conflict: Discard local and accept server per PRD Section 5
  void resolveConflictUseServer(String conflictId) {
    _conflicts.removeWhere((c) => c.id == conflictId);
    notifyListeners();
  }

  // CALCULATIONS (Finance Rules: liquid cash excludes parent node to prevent double counting!)
  int get totalLiquidCash {
    int sum = 0;
    for (final acc in _accounts) {
      if (acc.isIncludeTotal && acc.type != AccountType.investment) {
        sum += acc.balance;
      }
    }
    return sum;
  }

  int get totalInvestmentValue {
    int sum = 0;
    for (final inv in _investments) {
      sum += inv.totalCurrentValue;
    }
    return sum;
  }

  int get totalNetWorth => totalLiquidCash + totalInvestmentValue;

  int get monthIncome {
    int sum = 0;
    for (final tx in _transactions) {
      if (tx.type == TransactionType.income) {
        sum += tx.amount;
      }
    }
    return sum;
  }

  int get monthExpense {
    int sum = 0;
    for (final tx in _transactions) {
      if (tx.type == TransactionType.expense) {
        sum += tx.amount;
      }
    }
    return sum;
  }

  int get monthNetSavings => monthIncome - monthExpense;

  // TOGGLES
  void toggleOfflineMode() {
    _isOfflineMode = !_isOfflineMode;
    notifyListeners();
  }

  void toggleHideBalance() {
    _isBalanceHidden = !_isBalanceHidden;
    notifyListeners();
  }

  Account? getAccountById(String id) {
    try {
      return _accounts.firstWhere((acc) => acc.id == id);
    } catch (_) {
      return null;
    }
  }

  // ADD TRANSACTION MUTATION (Local-First, Atomically updates Balance & Sync Queue)
  void addTransaction({
    required TransactionType type,
    required int amount,
    required String accountId,
    String? toAccountId,
    required String categoryName,
    String? note,
    required DateTime date,
    bool isDebt = false,
    bool isReceivable = false,
  }) {
    // If user picked a parent account with pockets, redirect to first child per PRD 4.4
    String effectiveAccountId = accountId;
    final childPockets = getChildrenForAccount(accountId);
    if (childPockets.isNotEmpty) {
      effectiveAccountId = childPockets.first.id;
    }

    final newId = 'tx-${DateTime.now().millisecondsSinceEpoch}';
    final syncStatus = _isOfflineMode ? SyncStatus.pending : SyncStatus.synced;

    final newTx = TransactionItem(
      id: newId,
      type: type,
      amount: amount,
      accountId: effectiveAccountId,
      toAccountId: toAccountId,
      categoryName: categoryName,
      note: note,
      date: date,
      householdId: activeHousehold.id,
      syncStatus: syncStatus,
      createdByUserId: currentUserId,
      createdByName: userName,
      isDebt: isDebt,
      isReceivable: isReceivable,
    );

    // 1. Insert into transactions list
    _transactions = [newTx, ..._transactions];

    // 2. Update Account balances
    _accounts = _accounts.map((acc) {
      if (type == TransactionType.expense && acc.id == effectiveAccountId) {
        return acc.copyWith(balance: acc.balance - amount);
      } else if (type == TransactionType.income && acc.id == effectiveAccountId) {
        return acc.copyWith(balance: acc.balance + amount);
      } else if (type == TransactionType.transfer) {
        if (acc.id == effectiveAccountId) {
          return acc.copyWith(balance: acc.balance - amount);
        } else if (toAccountId != null && acc.id == toAccountId) {
          return acc.copyWith(balance: acc.balance + amount);
        }
      }
      return acc;
    }).toList();

    // 3. Recompute parent account balances from children
    _recomputeParentAccountBalances();

    // 4. Update Budget spent amount if expense
    if (type == TransactionType.expense) {
      _budgets = _budgets.map((b) {
        if (b.categoryName == categoryName) {
          return b.copyWith(spentAmount: b.spentAmount + amount);
        }
        return b;
      }).toList();
    }

    // 5. For transfers: locally insert the INCOME leg on the to-account as well (PRD 5.5 offline-first).
    // The server will create both rows from POST /transfers; we mirror this locally so the
    // UI stays consistent without waiting for a server response.
    if (type == TransactionType.transfer && toAccountId != null) {
      final toLegId = 'tx-to-${DateTime.now().millisecondsSinceEpoch}';
      final toTx = TransactionItem(
        id: toLegId,
        // Keep type=transfer so monthIncome/monthExpense getters skip it (PRD: transfers ≠ income/expense)
        type: TransactionType.transfer,
        amount: amount,
        accountId: toAccountId,
        categoryName: categoryName,
        note: note,
        date: date,
        householdId: activeHousehold.id,
        syncStatus: syncStatus,
        createdByUserId: currentUserId,
        createdByName: userName,
        // Link both legs via the same transferId for dedup / display
        transferId: newId,
      );
      _transactions = [toTx, ..._transactions];
    }

    // 6. Enqueue to Sync Queue with clientVersion for optimistic locking (PRD 3 & Backend 5.10)
    final queueItem = SyncQueueItem(
      id: 'sync-${DateTime.now().millisecondsSinceEpoch}',
      entityType: 'transactions',
      entityId: newId,
      operation: 'CREATE',
      description: 'Mutasi $categoryName: Rp $amount',
      timestamp: DateTime.now(),
      clientVersion: 1,
      isSynced: !_isOfflineMode,
    );
    _syncQueue.insert(0, queueItem);

    notifyListeners();
  }

  void _recomputeParentAccountBalances() {
    _accounts = _accounts.map((acc) {
      if (acc.parentAccountId == null) {
        final children = getChildrenForAccount(acc.id);
        if (children.isNotEmpty) {
          final totalPocketSum = children.fold(0, (sum, c) => sum + c.balance);
          return acc.copyWith(balance: totalPocketSum);
        }
      }
      return acc;
    }).toList();
  }

  // ADD ACCOUNT MUTATION
  void addAccount({
    required String name,
    required AccountType type,
    required int initialBalance,
    required String accountNumber,
    required String institution,
    bool isShared = false,
    String? householdId,
    String? parentAccountId,
  }) {
    final newId = 'acc-${DateTime.now().millisecondsSinceEpoch}';
    final newAccount = Account(
      id: newId,
      name: name,
      type: type,
      balance: initialBalance,
      accountNumber: accountNumber,
      institution: institution,
      isShared: isShared || householdId != null,
      householdId: householdId,
      parentAccountId: parentAccountId,
      isIncludeTotal: true,
      sequenceOrder: _accounts.length + 1,
      ownerUserId: currentUserId,
      ownerName: userName,
    );

    _accounts = [..._accounts, newAccount];
    _recomputeParentAccountBalances();

    // Enqueue with clientVersion for optimistic locking
    _syncQueue.insert(
      0,
      SyncQueueItem(
        id: 'sync-${DateTime.now().millisecondsSinceEpoch}',
        entityType: 'accounts',
        entityId: newId,
        operation: 'CREATE',
        description: 'Tambah Akun $name',
        timestamp: DateTime.now(),
        clientVersion: 1,
        isSynced: !_isOfflineMode,
      ),
    );

    notifyListeners();
  }

  // UPDATE ACCOUNT SHARING MUTATION
  void updateAccountSharing({
    required String accountId,
    required bool isShared,
    String? householdId,
  }) {
    _accounts = _accounts.map((acc) {
      if (acc.id == accountId) {
        return acc.copyWith(
          isShared: isShared,
          householdId: isShared ? householdId : null,
        );
      }
      return acc;
    }).toList();

    _syncQueue.insert(
      0,
      SyncQueueItem(
        id: 'sync-${DateTime.now().millisecondsSinceEpoch}',
        entityType: 'accounts',
        entityId: accountId,
        operation: 'UPDATE',
        description: 'Update Sharing Akun $accountId',
        timestamp: DateTime.now(),
        clientVersion: 1,
        isSynced: !_isOfflineMode,
      ),
    );

    notifyListeners();
  }

  // INVESTMENT TRADE MUTATION (PRD 4.7 & 5.8: Online-Required)
  // BUY: cash account decreases, holding quantity & value increase
  // SELL: cash account increases, holding quantity & value decrease, realized P/L calculated
  // DIVIDEND: cash account increases
  void recordInvestmentTrade({
    required String assetId,
    required InvestmentTradeType tradeType,
    required double quantity,
    required double pricePerUnit,
    required int fee,
    String? cashAccountId,
    String? note,
  }) {
    if (_isOfflineMode) {
      throw Exception('Investasi membutuhkan koneksi internet (online-required)');
    }

    final assetIndex = _investments.indexWhere((inv) => inv.id == assetId);
    if (assetIndex == -1) return;

    final asset = _investments[assetIndex];
    final totalTradeAmount = (quantity * pricePerUnit).round() + fee;

    int? realizedPl;
    double newQuantity = asset.quantity;
    double newAvgCostPrice = asset.avgCostPrice;

    if (tradeType == InvestmentTradeType.buy) {
      final oldCostTotal = asset.quantity * asset.avgCostPrice;
      final newCostTotal = oldCostTotal + (quantity * pricePerUnit) + fee;
      newQuantity = asset.quantity + quantity;
      newAvgCostPrice = newQuantity > 0 ? (newCostTotal / newQuantity) : 0;
    } else if (tradeType == InvestmentTradeType.sell) {
      realizedPl = ((quantity * (pricePerUnit - asset.avgCostPrice)) - fee).round();
      newQuantity = (asset.quantity - quantity).clamp(0.0, double.infinity);
    }

    final newTotalCurrentValue = (newQuantity * asset.currentPrice).round();
    final newTotalInvestedValue = (newQuantity * newAvgCostPrice).round();

    final newTradeRecord = InvestmentTransactionRecord(
      id: 'itx-${DateTime.now().millisecondsSinceEpoch}',
      type: tradeType,
      quantity: quantity,
      pricePerUnit: pricePerUnit,
      fee: fee,
      totalAmount: totalTradeAmount,
      cashAccountId: cashAccountId,
      realizedPl: realizedPl,
      transactedAt: DateTime.now(),
      note: note,
    );

    _investments[assetIndex] = asset.copyWith(
      quantity: newQuantity,
      avgCostPrice: newAvgCostPrice,
      totalCurrentValue: newTotalCurrentValue,
      totalInvestedValue: newTotalInvestedValue,
      quantityDisplay: '${newQuantity.toStringAsFixed(newQuantity.truncateToDouble() == newQuantity ? 0 : 3)} ${asset.symbol}',
      transactions: [newTradeRecord, ...asset.transactions],
      lastUpdated: DateTime.now(),
    );

    // Atomically link cash account transaction per PRD 5.8
    if (cashAccountId != null) {
      if (tradeType == InvestmentTradeType.buy) {
        addTransaction(
          type: TransactionType.expense,
          amount: totalTradeAmount,
          accountId: cashAccountId,
          categoryName: 'Investasi: Beli ${asset.name}',
          note: 'Beli $quantity ${asset.symbol} @ Rp ${pricePerUnit.toInt()}',
          date: DateTime.now(),
        );
      } else if (tradeType == InvestmentTradeType.sell ||
          tradeType == InvestmentTradeType.dividend) {
        addTransaction(
          type: TransactionType.income,
          amount: totalTradeAmount,
          accountId: cashAccountId,
          categoryName: tradeType == InvestmentTradeType.sell
              ? 'Investasi: Jual ${asset.name}'
              : 'Investasi: Dividen ${asset.name}',
          note: tradeType == InvestmentTradeType.sell
              ? 'Jual $quantity ${asset.symbol} (Realized P/L: Rp $realizedPl)'
              : 'Dividen ${asset.name}',
          date: DateTime.now(),
        );
      }
    }

    notifyListeners();
  }

  // UPDATE INSTRUMENT PRICE (PRD 4.7 & 5.8.1)
  void updateInstrumentPrice(String assetId, double newPrice) {
    if (_isOfflineMode) {
      throw Exception('Update harga instrumen butuh koneksi internet');
    }

    final index = _investments.indexWhere((inv) => inv.id == assetId);
    if (index == -1) return;

    final asset = _investments[index];
    final newMarketValue = (asset.quantity * newPrice).round();

    _investments[index] = asset.copyWith(
      currentPrice: newPrice,
      totalCurrentValue: newMarketValue,
      isPriceUpdatedToday: true,
      lastUpdated: DateTime.now(),
    );

    notifyListeners();
  }

  // TRIGGER SYNC
  void syncPendingNow() {
    for (final item in _syncQueue) {
      item.isSynced = true;
    }
    _transactions = _transactions.map((tx) {
      if (tx.syncStatus == SyncStatus.pending) {
        return tx.copyWith(syncStatus: SyncStatus.synced);
      }
      return tx;
    }).toList();

    notifyListeners();
  }

  void switchHousehold(String id) {
    if (_activeHouseholdId != id && _households.any((h) => h.id == id)) {
      _activeHouseholdId = id;
      notifyListeners();
    }
  }

  void createHousehold({
    required String name,
    required GroupType type,
    String? description,
  }) {
    final newId = 'hh-${DateTime.now().millisecondsSinceEpoch}';
    final randomSuffix = (1000 + _households.length * 37) % 9000;
    final code = '${type.name.substring(0, 3).toUpperCase()}-$randomSuffix';

    final newGroup = Household(
      id: newId,
      name: name,
      type: type,
      description: description,
      inviteCode: code,
      sharedBalance: 0,
      members: [
        HouseholdMember(
          id: currentUserId,
          name: userName,
          roleName: 'Pengelola / Owner',
          role: MemberRole.admin,
          avatarInitials: 'BM',
          email: userEmail,
        ),
      ],
    );

    _households.add(newGroup);
    _activeHouseholdId = newId;
    notifyListeners();
  }

  bool joinHouseholdWithCode(String code) {
    final trimmed = code.trim().toUpperCase();
    final existing = _households.where((h) => h.inviteCode.toUpperCase() == trimmed);
    if (existing.isNotEmpty) {
      _activeHouseholdId = existing.first.id;
      notifyListeners();
      return true;
    }

    // Simulate joining an external shared group via code
    final newId = 'hh-${DateTime.now().millisecondsSinceEpoch}';
    final joinedGroup = Household(
      id: newId,
      name: 'Grup Gabungan ($trimmed)',
      type: GroupType.project,
      description: 'Grup finansial bersama yang digabung via kode undangan $trimmed',
      inviteCode: trimmed,
      sharedBalance: 5000000,
      members: [
        HouseholdMember(
          id: 'u-ext',
          name: 'Host Komunitas',
          roleName: 'Owner',
          role: MemberRole.admin,
          avatarInitials: 'HK',
          email: 'host@community.org',
        ),
        HouseholdMember(
          id: currentUserId,
          name: userName,
          roleName: 'Anggota',
          role: MemberRole.member,
          avatarInitials: 'BM',
          email: userEmail,
        ),
      ],
    );

    _households.add(joinedGroup);
    _activeHouseholdId = newId;
    notifyListeners();
    return true;
  }

  void updateHouseholdName(String newName) {
    final index = _households.indexWhere((h) => h.id == _activeHouseholdId);
    if (index != -1) {
      _households[index] = _households[index].copyWith(name: newName);
      notifyListeners();
    }
  }

  void updateActiveHousehold({
    String? name,
    GroupType? type,
    String? description,
  }) {
    final index = _households.indexWhere((h) => h.id == _activeHouseholdId);
    if (index != -1) {
      _households[index] = _households[index].copyWith(
        name: name,
        type: type,
        description: description,
      );
      notifyListeners();
    }
  }

  void addMemberToHousehold({
    required String householdId,
    required String name,
    required String email,
    required MemberRole role,
    required String roleName,
  }) {
    final index = _households.indexWhere((h) => h.id == householdId);
    if (index != -1) {
      final current = _households[index];
      final words = name.trim().split(' ');
      final initials = words.take(2).map((w) => w.isNotEmpty ? w[0] : '').join().toUpperCase();
      final newMember = HouseholdMember(
        id: 'u-${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        roleName: roleName,
        role: role,
        avatarInitials: initials.isEmpty ? 'U' : initials,
        email: email,
      );
      _households[index] = current.copyWith(
        members: [...current.members, newMember],
      );
      notifyListeners();
    }
  }

  void deleteOrLeaveHousehold(String id) {
    if (_households.length <= 1) return;
    _households.removeWhere((h) => h.id == id);
    if (_activeHouseholdId == id) {
      _activeHouseholdId = _households.first.id;
    }
    notifyListeners();
  }

  // ==================== AUTHENTICATION & SESSION ====================

  void login({
    String? userId,
    String? name,
    String? email,
    String? phone,
  }) {
    if (userId != null) _currentUserId = userId;
    if (name != null) _userName = name;
    if (email != null) _userEmail = email;
    if (phone != null) _userPhone = phone;
    _isAuthenticated = true;
    _currentFlow = AppFlowStep.main;
    notifyListeners();
  }

  void logout() {
    _isAuthenticated = false;
    _currentFlow = AppFlowStep.auth;
    notifyListeners();
  }

  void register({
    required String name,
    required String email,
    String? phone,
    String? groupName,
  }) {
    _currentUserId = 'u-${DateTime.now().millisecondsSinceEpoch}';
    _userName = name;
    _userEmail = email;
    if (phone != null && phone.isNotEmpty) _userPhone = phone;
    if (groupName != null && groupName.trim().isNotEmpty) {
      createHousehold(
        name: groupName.trim(),
        type: GroupType.family,
        description: 'Ruang finansial bersama baru',
      );
    }
    _isAuthenticated = true;
    _currentFlow = AppFlowStep.main;
    notifyListeners();
  }
}

/// InheritedWidget to easily access AppState anywhere in the widget tree
class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({
    super.key,
    required AppState state,
    required super.child,
  }) : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'No AppStateScope found in context');
    return scope!.notifier!;
  }
}
