class GroupCategory {
  final String id;
  final String groupId;
  final String name;
  final String type; // 'EXPENSE' or 'INCOME'
  final List<String> mappedUserCategories;
  final int totalAggregatedAmount; // aggregate sum across all household members

  const GroupCategory({
    required this.id,
    required this.groupId,
    required this.name,
    required this.type,
    this.mappedUserCategories = const [],
    this.totalAggregatedAmount = 0,
  });

  GroupCategory copyWith({
    String? id,
    String? groupId,
    String? name,
    String? type,
    List<String>? mappedUserCategories,
    int? totalAggregatedAmount,
  }) {
    return GroupCategory(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      name: name ?? this.name,
      type: type ?? this.type,
      mappedUserCategories: mappedUserCategories ?? this.mappedUserCategories,
      totalAggregatedAmount:
          totalAggregatedAmount ?? this.totalAggregatedAmount,
    );
  }
}
