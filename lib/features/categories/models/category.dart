import 'package:flutter/material.dart';

enum CategoryType { expense, income }

class Category {
  final String id, name;
  final CategoryType type;
  final IconData icon;
  final Color color;
  final String? userId;
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
  }) => Category(
    id: id ?? this.id,
    name: name ?? this.name,
    type: type ?? this.type,
    icon: icon ?? this.icon,
    color: color ?? this.color,
    userId: userId ?? this.userId,
    isDefault: isDefault ?? this.isDefault,
    sequenceOrder: sequenceOrder ?? this.sequenceOrder,
  );

  // Stable string keys mapped to rounded Material icons for cross-device sync.
  static const Map<String, IconData> _iconsByKey = {
    'category': Icons.category_rounded,
    'restaurant': Icons.restaurant_rounded,
    'local_cafe': Icons.local_cafe_rounded,
    'shopping_cart': Icons.shopping_cart_rounded,
    'directions_car': Icons.directions_car_rounded,
    'home': Icons.home_rounded,
    'receipt_long': Icons.receipt_long_rounded,
    'payments': Icons.payments_rounded,
    'work': Icons.work_rounded,
    'trending_up': Icons.trending_up_rounded,
    'card_giftcard': Icons.card_giftcard_rounded,
    'storefront': Icons.storefront_rounded,
    'favorite': Icons.favorite_rounded,
    'school': Icons.school_rounded,
    'sports_esports': Icons.sports_esports_rounded,
    'movie': Icons.movie_filter_rounded,
    'flight': Icons.flight_rounded,
    'savings': Icons.savings_rounded,
  };

  static const availableIcons = [
    Icons.category_rounded,
    Icons.restaurant_rounded,
    Icons.local_cafe_rounded,
    Icons.shopping_cart_rounded,
    Icons.directions_car_rounded,
    Icons.home_rounded,
    Icons.receipt_long_rounded,
    Icons.payments_rounded,
    Icons.work_rounded,
    Icons.trending_up_rounded,
    Icons.card_giftcard_rounded,
    Icons.storefront_rounded,
    Icons.favorite_rounded,
    Icons.school_rounded,
    Icons.sports_esports_rounded,
    Icons.movie_filter_rounded,
    Icons.flight_rounded,
    Icons.savings_rounded,
  ];

  static const availableColors = [
    Color(0xFF0D9488),
    Color(0xFF137548),
    Color(0xFFE11D48),
    Color(0xFFEA580C),
    Color(0xFFD97706),
    Color(0xFF2563EB),
    Color(0xFF7C3AED),
    Color(0xFFEC4899),
  ];

  static String? iconKey(IconData icon) {
    for (final entry in _iconsByKey.entries) {
      if (entry.value == icon) return entry.key;
    }
    return null;
  }

  static IconData iconFromKey(
    String? key, {
    String? fallbackName,
    bool isIncome = false,
  }) {
    if (key != null && _iconsByKey.containsKey(key)) {
      return _iconsByKey[key]!;
    }
    if (fallbackName != null && fallbackName.isNotEmpty) {
      final cat = fallbackName.toLowerCase();
      if (isIncome) {
        if (cat.contains('gaji') || cat.contains('salary')) {
          return Icons.work_rounded;
        }
        if (cat.contains('bonus') || cat.contains('reward')) {
          return Icons.card_giftcard_rounded;
        }
        if (cat.contains('invest') || cat.contains('dividen')) {
          return Icons.trending_up_rounded;
        }
        if (cat.contains('usaha') || cat.contains('bisnis')) {
          return Icons.storefront_rounded;
        }
        return Icons.payments_rounded;
      }
      if (cat.contains('kopi') || cat.contains('cafe') || cat.contains('coffee')) {
        return Icons.local_cafe_rounded;
      }
      if (cat.contains('makan') || cat.contains('kuliner') || cat.contains('food')) {
        return Icons.restaurant_rounded;
      }
      if (cat.contains('belanja') || cat.contains('shopping') || cat.contains('market')) {
        return Icons.shopping_cart_rounded;
      }
      if (cat.contains('transpor') || cat.contains('bensin') || cat.contains('ojek') || cat.contains('kendaraan')) {
        return Icons.directions_car_rounded;
      }
      if (cat.contains('rumah') || cat.contains('home') || cat.contains('kos')) {
        return Icons.home_rounded;
      }
      if (cat.contains('tagihan') || cat.contains('bill') || cat.contains('listrik') || cat.contains('air') || cat.contains('pulsa') || cat.contains('internet')) {
        return Icons.receipt_long_rounded;
      }
      if (cat.contains('hiburan') || cat.contains('game') || cat.contains('entertain')) {
        return Icons.sports_esports_rounded;
      }
      if (cat.contains('kesehatan') || cat.contains('health') || cat.contains('obat') || cat.contains('medis')) {
        return Icons.favorite_rounded;
      }
      if (cat.contains('pendidikan') || cat.contains('edu') || cat.contains('sekolah') || cat.contains('kursus')) {
        return Icons.school_rounded;
      }
      if (cat.contains('travel') || cat.contains('liburan') || cat.contains('tiket')) {
        return Icons.flight_rounded;
      }
    }
    return Icons.category_rounded;
  }

  static String colorToHex(Color color) {
    final r = (color.r * 255.0).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    final g = (color.g * 255.0).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    final b = (color.b * 255.0).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    return '#$r$g$b'.toUpperCase();
  }

  static Color colorFromHex(
    String? hex, {
    Color fallback = const Color(0xFF0D9488),
  }) {
    if (hex == null) return fallback;
    final clean = hex.trim().replaceFirst('#', '');
    if (!RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(clean)) return fallback;
    final value = int.tryParse(clean, radix: 16);
    if (value == null) return fallback;
    return Color(0xFF000000 | value);
  }
}
