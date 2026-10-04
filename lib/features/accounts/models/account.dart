enum AccountType {
  bank,
  cash,
  wallet,
  investment,
}

class Account {
  final String id;
  final String name;
  final AccountType type;
  final int balance; // in Rupiah (integer)
  final String accountNumber;
  final bool isShared;
  final String? householdId;
  final String institution;
  final String? parentAccountId; // For nested accounts (Bank Jago pockets, etc.)
  final bool isIncludeTotal; // false if parent node with children to prevent double-count
  final bool isVisible;
  final int sequenceOrder;
  final String currency;
  final String ownerUserId;
  final String ownerName;

  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    required this.accountNumber,
    this.isShared = false,
    this.householdId,
    this.institution = '',
    this.parentAccountId,
    this.isIncludeTotal = true,
    this.isVisible = true,
    this.sequenceOrder = 0,
    this.currency = 'IDR',
    this.ownerUserId = 'u-1',
    this.ownerName = 'Burhan Mafazi',
  });

  bool get isParent => parentAccountId == null;
  bool get isPocket => parentAccountId != null;

  Account copyWith({
    String? id,
    String? name,
    AccountType? type,
    int? balance,
    String? accountNumber,
    bool? isShared,
    String? householdId,
    String? institution,
    String? parentAccountId,
    bool? isIncludeTotal,
    bool? isVisible,
    int? sequenceOrder,
    String? currency,
    String? ownerUserId,
    String? ownerName,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      balance: balance ?? this.balance,
      accountNumber: accountNumber ?? this.accountNumber,
      isShared: isShared ?? this.isShared,
      householdId: householdId ?? this.householdId,
      institution: institution ?? this.institution,
      parentAccountId: parentAccountId ?? this.parentAccountId,
      isIncludeTotal: isIncludeTotal ?? this.isIncludeTotal,
      isVisible: isVisible ?? this.isVisible,
      sequenceOrder: sequenceOrder ?? this.sequenceOrder,
      currency: currency ?? this.currency,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      ownerName: ownerName ?? this.ownerName,
    );
  }
}
