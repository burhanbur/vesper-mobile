enum MemberRole {
  admin,
  member,
  viewer,
}

enum GroupType {
  family,
  roommates,
  trip,
  project,
  business,
  other;

  String get displayName {
    switch (this) {
      case GroupType.family:
        return 'Keluarga / Rumah Tangga';
      case GroupType.roommates:
        return 'Kosan / Roommates';
      case GroupType.trip:
        return 'Trip / Traveling';
      case GroupType.project:
        return 'Proyek / Komunitas';
      case GroupType.business:
        return 'Bisnis Sampingan';
      case GroupType.other:
        return 'Grup Finansial Lainnya';
    }
  }

  String get emoji {
    switch (this) {
      case GroupType.family:
        return '👨‍👩‍👧‍👦';
      case GroupType.roommates:
        return '🏠';
      case GroupType.trip:
        return '✈️';
      case GroupType.project:
        return '🚀';
      case GroupType.business:
        return '💼';
      case GroupType.other:
        return '👥';
    }
  }
}

class HouseholdMember {
  final String id;
  final String name;
  final String roleName;
  final MemberRole role;
  final String avatarInitials;
  final String email;

  const HouseholdMember({
    required this.id,
    required this.name,
    required this.roleName,
    required this.role,
    required this.avatarInitials,
    required this.email,
  });

  HouseholdMember copyWith({
    String? id,
    String? name,
    String? roleName,
    MemberRole? role,
    String? avatarInitials,
    String? email,
  }) {
    return HouseholdMember(
      id: id ?? this.id,
      name: name ?? this.name,
      roleName: roleName ?? this.roleName,
      role: role ?? this.role,
      avatarInitials: avatarInitials ?? this.avatarInitials,
      email: email ?? this.email,
    );
  }
}

class Household {
  final String id;
  final String name;
  final GroupType type;
  final String? description;
  final String inviteCode;
  final List<HouseholdMember> members;
  final int sharedBalance;

  const Household({
    required this.id,
    required this.name,
    this.type = GroupType.family,
    this.description,
    this.inviteCode = 'VSP-8821',
    required this.members,
    required this.sharedBalance,
  });

  int get memberCount => members.length;

  Household copyWith({
    String? id,
    String? name,
    GroupType? type,
    String? description,
    String? inviteCode,
    List<HouseholdMember>? members,
    int? sharedBalance,
  }) {
    return Household(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      description: description ?? this.description,
      inviteCode: inviteCode ?? this.inviteCode,
      members: members ?? this.members,
      sharedBalance: sharedBalance ?? this.sharedBalance,
    );
  }
}

class MemberExpenseContribution {
  final HouseholdMember member;
  final int amount;
  final int percentage;
  final int transactionCount;

  const MemberExpenseContribution({
    required this.member,
    required this.amount,
    required this.percentage,
    this.transactionCount = 0,
  });
}
