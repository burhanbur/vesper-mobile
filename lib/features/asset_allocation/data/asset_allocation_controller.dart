import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import 'asset_allocation_repository.dart';

class AssetAllocationController extends ChangeNotifier {
  final AssetAllocationRepository repository;
  final bool Function() isCurrent;
  AllocationSnapshot? snapshot;
  bool cached = true, loading = false, _disposed = false;
  int _request = 0;
  String? error;
  AssetAllocationController(this.repository, this.isCurrent) {
    snapshot = repository.cached;
  }
  Future<void> refresh() async {
    if (_disposed || !isCurrent()) return;
    final id = ++_request;
    bool current() => !_disposed && id == _request && isCurrent();
    loading = true;
    cached = true;
    error = null;
    notifyListeners();
    try {
      final data = await repository.fetch(isCurrent: current);
      if (current()) {
        snapshot = data;
        cached = false;
      }
    } catch (e) {
      if (current()) {
        if (e is ApiFailure && [401, 403, 404].contains(e.statusCode)) {
          snapshot = null;
          repository.clearCache();
        }
        error = e.toString();
      }
    } finally {
      if (current()) {
        loading = false;
        notifyListeners();
      }
    }
  }

  bool saveTargets(Map<String, String>? values) {
    try {
      if (_disposed || !isCurrent()) {
        throw const ApiFailure('Sesi telah berubah.');
      }
      repository.saveTargets(values);
      error = null;
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _request++;
    super.dispose();
  }
}
