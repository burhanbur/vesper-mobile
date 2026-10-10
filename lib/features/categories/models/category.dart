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
  const Category({required this.id, required this.name, required this.type,
    required this.icon, required this.color, this.userId, this.isDefault = false,
    this.sequenceOrder = 0});
  Category copyWith({String? id, String? name, CategoryType? type, IconData? icon,
    Color? color, String? userId, bool? isDefault, int? sequenceOrder}) => Category(
      id: id ?? this.id, name: name ?? this.name, type: type ?? this.type,
      icon: icon ?? this.icon, color: color ?? this.color, userId: userId ?? this.userId,
      isDefault: isDefault ?? this.isDefault, sequenceOrder: sequenceOrder ?? this.sequenceOrder);
  // Presentation choices, not business categories.
  static const availableIcons = [Icons.category_rounded, Icons.restaurant_rounded,
    Icons.shopping_cart_rounded, Icons.directions_car_rounded, Icons.home_rounded,
    Icons.payments_rounded, Icons.work_rounded, Icons.favorite_rounded];
  static const availableColors = [Color(0xFF0D9488), Color(0xFFE11D48),
    Color(0xFF2563EB), Color(0xFFD97706), Color(0xFF7C3AED)];
}
