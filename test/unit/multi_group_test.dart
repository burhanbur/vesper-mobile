import 'package:flutter_test/flutter_test.dart';
import 'package:vesper_mobile/app/app_state.dart';
import 'package:vesper_mobile/features/household/models/household.dart';

void main() {
  group('Multi-Group & Shared Spaces Tests', () {
    late AppState appState;

    setUp(() {
      appState = AppState();
    });

    test('Loads initial presets for family, roommates, and trip groups', () {
      expect(appState.households.length, 3);

      final family = appState.households[0];
      expect(family.type, GroupType.family);
      expect(family.name, 'Keluarga Mafazi');

      final roommates = appState.households[1];
      expect(roommates.type, GroupType.roommates);
      expect(roommates.name, 'Kosan Senopati No. 12');

      final trip = appState.households[2];
      expect(trip.type, GroupType.trip);
      expect(trip.name, 'Trip Labuan Bajo 2026');

      expect(appState.activeHousehold.id, family.id);
    });

    test('Switches active group correctly', () {
      expect(appState.activeHousehold.id, 'hh-1');

      appState.switchHousehold('hh-2');
      expect(appState.activeHousehold.id, 'hh-2');
      expect(appState.household.name, 'Kosan Senopati No. 12');

      appState.switchHousehold('hh-3');
      expect(appState.activeHousehold.id, 'hh-3');
      expect(appState.household.name, 'Trip Labuan Bajo 2026');
    });

    test('Creates new group and sets it as active with auto-generated invite code', () {
      final initialCount = appState.households.length;

      appState.createHousehold(
        name: 'Kas Proyek Freelance',
        type: GroupType.project,
        description: 'Dana operasional dan honor tim freelancer',
      );

      expect(appState.households.length, initialCount + 1);
      final newGroup = appState.activeHousehold;
      expect(newGroup.name, 'Kas Proyek Freelance');
      expect(newGroup.type, GroupType.project);
      expect(newGroup.inviteCode.startsWith('PRO-'), isTrue);
      expect(newGroup.members.length, 1);
      expect(newGroup.members.first.role, MemberRole.admin);
    });

    test('Joins existing group with code or joins new group via valid invite code', () {
      // 1. Join existing code
      final joinedExisting = appState.joinHouseholdWithCode('KSN-4491');
      expect(joinedExisting, isTrue);
      expect(appState.activeHousehold.id, 'hh-2');

      // 2. Join new external code
      final initialCount = appState.households.length;
      final joinedNew = appState.joinHouseholdWithCode('EVT-5520');
      expect(joinedNew, isTrue);
      expect(appState.households.length, initialCount + 1);
      expect(appState.activeHousehold.inviteCode, 'EVT-5520');
    });

    test('Adds member to specified group', () {
      final initialMembers = appState.activeHousehold.members.length;

      appState.addMemberToHousehold(
        householdId: appState.activeHousehold.id,
        name: 'Gilang Ramadhan',
        email: 'gilang@vesper.app',
        role: MemberRole.member,
        roleName: 'Anggota',
      );

      expect(appState.activeHousehold.members.length, initialMembers + 1);
      expect(appState.activeHousehold.members.last.name, 'Gilang Ramadhan');
      expect(appState.activeHousehold.members.last.avatarInitials, 'GR');
    });

    test('Deletes/leaves group and updates active group if needed', () {
      expect(appState.households.length, 3);
      appState.switchHousehold('hh-2');
      expect(appState.activeHouseholdId, 'hh-2');

      appState.deleteOrLeaveHousehold('hh-2');
      expect(appState.households.length, 2);
      expect(appState.households.any((h) => h.id == 'hh-2'), isFalse);
      expect(appState.activeHouseholdId, isNot('hh-2'));
    });
  });
}
