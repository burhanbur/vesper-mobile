import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';

enum AccountType { bank, cash, wallet, creditCard, investment }

class AccountTypeDefinition {
  final AccountType type;
  final String label;
  final String categoryGroup;
  final String description;
  final IconData icon;
  final Color color;
  final bool isLiability;
  final bool isLiquid;

  const AccountTypeDefinition({
    required this.type,
    required this.label,
    required this.categoryGroup,
    required this.description,
    required this.icon,
    required this.color,
    this.isLiability = false,
    this.isLiquid = true,
  });

  static const List<AccountTypeDefinition> allDefinitions = [
    AccountTypeDefinition(
      type: AccountType.bank,
      label: 'Rekening Bank',
      categoryGroup: 'Bank & Tabungan',
      description: 'Tabungan reguler, giro, atau bank digital (BCA, Mandiri, Jago, dll).',
      icon: Icons.account_balance_rounded,
      color: AppColors.primary,
      isLiquid: true,
    ),
    AccountTypeDefinition(
      type: AccountType.wallet,
      label: 'Dompet Digital',
      categoryGroup: 'E-Wallet',
      description:
          'Saldo aplikasi dompet digital seperti GoPay, OVO, Dana, ShopeePay.',
      icon: Icons.phone_android_rounded,
      color: Color(0xFF0284C7),
      isLiquid: true,
    ),
    AccountTypeDefinition(
      type: AccountType.cash,
      label: 'Kas Tunai Dompet',
      categoryGroup: 'Kas Tunai',
      description:
          'Uang fisik di dompet, amplop budgeting, atau brankas rumah.',
      icon: Icons.payments_rounded,
      color: Color(0xFF16A34A),
      isLiquid: true,
    ),
    AccountTypeDefinition(
      type: AccountType.creditCard,
      label: 'Kartu Kredit / Paylater',
      categoryGroup: 'Kewajiban / Liabilitas',
      description:
          'Tagihan kartu kredit, limit paylater, atau pinjaman konsumtif.',
      icon: Icons.credit_card_rounded,
      color: Color(0xFFDC2626),
      isLiability: true,
      isLiquid: false,
    ),
    AccountTypeDefinition(
      type: AccountType.investment,
      label: 'Portofolio Investasi',
      categoryGroup: 'Investasi',
      description:
          'Rekening RDN saham, reksadana, crypto, emas, atau obligasi.',
      icon: Icons.trending_up_rounded,
      color: Color(0xFF7C3AED),
      isLiability: false,
      isLiquid: false,
    ),
  ];

  static AccountTypeDefinition getDefinition(AccountType type) {
    return allDefinitions.firstWhere(
      (d) => d.type == type,
      orElse: () => allDefinitions.first,
    );
  }
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
  final String?
  parentAccountId; // For nested accounts (Bank Jago pockets, etc.)
  final bool
  isIncludeTotal; // false if parent node with children to prevent double-count
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
    this.ownerUserId = '',
    this.ownerName = '',
  });

  bool get isParent => parentAccountId == null;
  bool get isPocket => parentAccountId != null;

  /// Whether this account is liquid cash, bank, or e-wallet account,
  /// matching the formula requirement for total balance.
  bool get isCashBankOrWallet {
    if (type == AccountType.investment || type == AccountType.creditCard) {
      return false;
    }
    final normInst = institution.toLowerCase().replaceAll(
      RegExp(r'[\s_-]'),
      '',
    );
    final normName = name.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
    if (normInst.contains('hutang') ||
        normInst.contains('piutang') ||
        normInst.contains('loan') ||
        normInst.contains('debt') ||
        normInst.contains('kredit') ||
        normInst.contains('credit') ||
        normInst.contains('paylater') ||
        normInst.contains('saham') ||
        normInst.contains('reksadana') ||
        normInst.contains('invest') ||
        normInst.contains('crypto') ||
        normInst.contains('kripto') ||
        normInst.contains('obligasi') ||
        normInst.contains('emas')) {
      return false;
    }
    if (normName.contains('hutang') ||
        normName.contains('piutang') ||
        normName.contains('paylater')) {
      return false;
    }
    if (type == AccountType.bank ||
        type == AccountType.cash ||
        type == AccountType.wallet) {
      return true;
    }
    return normInst.contains('cash') ||
        normInst.contains('kas') ||
        normInst.contains('bank') ||
        normInst.contains('wallet') ||
        normInst.contains('dompet');
  }

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
