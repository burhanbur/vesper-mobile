import 'package:flutter/foundation.dart';

import '../../../app/app_state.dart';
import '../../../core/network/api_client.dart';
import '../data/group_pocket_repository.dart';

class GroupPocketState extends ChangeNotifier {
  final AppState app;
  final String group;
  late final Object _session = app.netWorthSessionKey;
  late final String owner = app.repository?.userId ?? '';
  int _generation = 0;
  bool _disposed = false, _suspended = false;
  bool loading = false, busy = false, fresh = false;
  String? error;
  List<GroupPocket> pockets = const [];
  GroupPocketState(this.app, this.group) {
    app.addListener(_appChanged);
  }
  bool get available =>
      !_disposed &&
      !_suspended &&
      _session == app.netWorthSessionKey &&
      app.repository != null &&
      !app.isOfflineMode &&
      app.activeHouseholdId == group;
  bool get canWrite => available && fresh && !loading && !busy;
  void _clear() {
    ++_generation;
    pockets = const [];
    fresh = false;
    loading = false;
    busy = false;
  }

  void _appChanged() {
    if (!available) {
      _clear();
      error = null;
    }
    notifyListeners();
  }

  void suspend(bool value) {
    _suspended = value;
    _clear();
    error = null;
    notifyListeners();
    if (!value && available) load();
  }

  Future<void> load() async {
    if (!available || busy) return;
    _clear();
    final token = _generation;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final rows = await GroupPocketRepository(app.repository!.client)
          .read(group);
      if (!available || token != _generation) return;
      pockets = rows;
      fresh = true;
    } catch (e) {
      if (!available || token != _generation) return;
      error = e is ApiFailure
          ? e.message
          : 'Respons kantong tidak valid. Muat ulang.';
    } finally {
      if (!_disposed && token == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> _write(
    Future<void> Function(GroupPocketRepository) action,
  ) async {
    if (!canWrite) return false;
    final token = ++_generation;
    busy = true;
    fresh = false;
    pockets = const [];
    error = null;
    notifyListeners();
    try {
      await action(GroupPocketRepository(app.repository!.client));
      if (!available || token != _generation) return false;
      busy = false;
      await load();
      return fresh;
    } catch (e) {
      if (!available || token != _generation) return false;
      error = e is ApiFailure
          ? switch (e.statusCode) {
              409 => 'Akun sudah ditautkan ke kantong lain. Muat ulang sebelum mencoba lagi.',
              422 => 'Akun tidak lagi memenuhi syarat. Sinkronkan akun dan muat ulang.',
              _ => e.message,
            }
          : 'Permintaan belum dapat dipastikan. Muat ulang sebelum mencoba lagi.';
      return false;
    } finally {
      if (!_disposed && token == _generation) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<bool> create(String name, String description) {
    if (name.trim().isEmpty ||
        name.trim().length > 120 ||
        description.trim().length > 2000) {
      return Future.value(false);
    }
    return _write((repo) => repo.create(group, name, description));
  }

  Future<bool> update(String pocket, String name, String description) {
    if (name.trim().isEmpty ||
        name.trim().length > 120 ||
        description.trim().length > 2000) {
      return Future.value(false);
    }
    return _write((repo) => repo.update(group, pocket, name, description));
  }

  Future<bool> delete(String pocket) {
    return _write((repo) => repo.delete(group, pocket));
  }

  Future<bool> assign(String pocket, String account, {required bool remove}) {
    if (!remove && !candidates.any((row) => row.id == account)) {
      return Future.value(false);
    }
    return _write(
      (repo) => repo.assign(group, pocket, account, remove: remove),
    );
  }

  List<PocketCandidate> get candidates {
    if (!canWrite) return const [];
    final repo = app.repository!;
    return pocketCandidates(
      owner,
      repo.rows('accounts'),
      repo.rows('account_types'),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    app.removeListener(_appChanged);
    super.dispose();
  }
}
