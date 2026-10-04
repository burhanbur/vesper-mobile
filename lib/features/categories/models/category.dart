import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';

enum CategoryType {
  expense,
  income,
}

class Category {
  final String id;
  final String name;
  final CategoryType type;
  final IconData icon;
  final Color color;
  final String? userId; // owner of category (PRD 4.4)
  final bool isDefault;
  final int sequenceOrder;

  const Category({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
    this.userId,
    this.isDefault = false,
    this.sequenceOrder = 0,
  });

  Category copyWith({
    String? id,
    String? name,
    CategoryType? type,
    IconData? icon,
    Color? color,
    String? userId,
    bool? isDefault,
    int? sequenceOrder,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      userId: userId ?? this.userId,
      isDefault: isDefault ?? this.isDefault,
      sequenceOrder: sequenceOrder ?? this.sequenceOrder,
    );
  }

  // Pre-configured Default Categories per PRD & Indonesian Finance Habits
  static List<Category> get initialCategories => [
        // ================= EXPENSES =================
        const Category(
          id: 'cat-exp-1',
          name: 'Makanan & Minuman',
          type: CategoryType.expense,
          icon: Icons.restaurant_rounded,
          color: Color(0xFFE11D48), // Rose
          isDefault: true,
          sequenceOrder: 1,
        ),
        const Category(
          id: 'cat-exp-2',
          name: 'Belanja Bulanan',
          type: CategoryType.expense,
          icon: Icons.shopping_cart_rounded,
          color: Color(0xFF2563EB), // Blue
          isDefault: true,
          sequenceOrder: 2,
        ),
        const Category(
          id: 'cat-exp-3',
          name: 'Transportasi',
          type: CategoryType.expense,
          icon: Icons.directions_car_rounded,
          color: Color(0xFF0284C7), // Sky
          isDefault: true,
          sequenceOrder: 3,
        ),
        const Category(
          id: 'cat-exp-4',
          name: 'Tagihan & WiFi',
          type: CategoryType.expense,
          icon: Icons.receipt_long_rounded,
          color: Color(0xFFD97706), // Amber
          isDefault: true,
          sequenceOrder: 4,
        ),
        const Category(
          id: 'cat-exp-5',
          name: 'Keluarga & Orang Tua',
          type: CategoryType.expense,
          icon: Icons.favorite_rounded,
          color: Color(0xFFEC4899), // Pink
          isDefault: true,
          sequenceOrder: 5,
        ),
        const Category(
          id: 'cat-exp-6',
          name: 'Kesehatan & Obat',
          type: CategoryType.expense,
          icon: Icons.medical_services_rounded,
          color: Color(0xFF059669), // Emerald
          isDefault: true,
          sequenceOrder: 6,
        ),
        const Category(
          id: 'cat-exp-7',
          name: 'Hiburan & Hobi',
          type: CategoryType.expense,
          icon: Icons.movie_filter_rounded,
          color: Color(0xFF7C3AED), // Violet
          isDefault: true,
          sequenceOrder: 7,
        ),
        const Category(
          id: 'cat-exp-8',
          name: 'Pendidikan & Kursus',
          type: CategoryType.expense,
          icon: Icons.school_rounded,
          color: Color(0xFF4F46E5), // Indigo
          isDefault: true,
          sequenceOrder: 8,
        ),
        const Category(
          id: 'cat-exp-9',
          name: 'Cicilan & Pinjaman',
          type: CategoryType.expense,
          icon: Icons.credit_card_rounded,
          color: Color(0xFF9333EA), // Purple
          isDefault: true,
          sequenceOrder: 9,
        ),
        const Category(
          id: 'cat-exp-10',
          name: 'Donasi & Zakat',
          type: CategoryType.expense,
          icon: Icons.volunteer_activism_rounded,
          color: Color(0xFF10B981), // Mint
          isDefault: true,
          sequenceOrder: 10,
        ),
        const Category(
          id: 'cat-exp-11',
          name: 'Lain-lain (Pengeluaran)',
          type: CategoryType.expense,
          icon: Icons.category_rounded,
          color: Color(0xFF6B7280), // Gray
          isDefault: true,
          sequenceOrder: 11,
        ),

        // ================= INCOME =================
        const Category(
          id: 'cat-inc-1',
          name: 'Gaji Pokok',
          type: CategoryType.income,
          icon: Icons.payments_rounded,
          color: Color(0xFF16A34A), // Green
          isDefault: true,
          sequenceOrder: 1,
        ),
        const Category(
          id: 'cat-inc-2',
          name: 'Bonus & THR',
          type: CategoryType.income,
          icon: Icons.card_giftcard_rounded,
          color: Color(0xFFEA580C), // Orange
          isDefault: true,
          sequenceOrder: 2,
        ),
        const Category(
          id: 'cat-inc-3',
          name: 'Hasil Usaha / Bisnis',
          type: CategoryType.income,
          icon: Icons.storefront_rounded,
          color: Color(0xFF0D9488), // Teal
          isDefault: true,
          sequenceOrder: 3,
        ),
        const Category(
          id: 'cat-inc-4',
          name: 'Dividen & Investasi',
          type: CategoryType.income,
          icon: Icons.trending_up_rounded,
          color: Color(0xFF7C3AED), // Violet
          isDefault: true,
          sequenceOrder: 4,
        ),
        const Category(
          id: 'cat-inc-5',
          name: 'Hadiah / Cashback',
          type: CategoryType.income,
          icon: Icons.stars_rounded,
          color: Color(0xFFCA8A04), // Yellow
          isDefault: true,
          sequenceOrder: 5,
        ),
        const Category(
          id: 'cat-inc-6',
          name: 'Lain-lain (Pemasukan)',
          type: CategoryType.income,
          icon: Icons.account_balance_wallet_rounded,
          color: Color(0xFF4B5563), // Slate
          isDefault: true,
          sequenceOrder: 6,
        ),
      ];

  // Curated icon choices for custom category creation
  static const List<IconData> availableIcons = [
    Icons.restaurant_rounded,
    Icons.shopping_cart_rounded,
    Icons.shopping_bag_rounded,
    Icons.directions_car_rounded,
    Icons.local_gas_station_rounded,
    Icons.receipt_long_rounded,
    Icons.favorite_rounded,
    Icons.medical_services_rounded,
    Icons.fitness_center_rounded,
    Icons.movie_filter_rounded,
    Icons.sports_esports_rounded,
    Icons.school_rounded,
    Icons.credit_card_rounded,
    Icons.volunteer_activism_rounded,
    Icons.home_rounded,
    Icons.pets_rounded,
    Icons.flight_rounded,
    Icons.beach_access_rounded,
    Icons.work_rounded,
    Icons.payments_rounded,
    Icons.card_giftcard_rounded,
    Icons.storefront_rounded,
    Icons.trending_up_rounded,
    Icons.savings_rounded,
    Icons.stars_rounded,
    Icons.category_rounded,
  ];

  // Curated color choices for custom category creation
  static const List<Color> availableColors = [
    Color(0xFFE11D48), // Rose
    Color(0xFFEA580C), // Orange
    Color(0xFFD97706), // Amber
    Color(0xFFCA8A04), // Yellow
    Color(0xFF16A34A), // Green
    Color(0xFF0D9488), // Teal
    Color(0xFF0284C7), // Sky
    Color(0xFF2563EB), // Blue
    Color(0xFF4F46E5), // Indigo
    Color(0xFF7C3AED), // Violet
    Color(0xFF9333EA), // Purple
    Color(0xFFEC4899), // Pink
    AppColors.primary, // Vesper Forest Green
    Color(0xFF4B5563), // Slate Gray
  ];
}
