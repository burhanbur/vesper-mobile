import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import 'portfolio_repository.dart';

/// Selection/request lifecycle is independent of widget rendering and sync writes.
class PortfolioController extends ChangeNotifier {
  final PortfolioRepository repository;
  final bool Function() isSessionCurrent;
  String? accountId, date, error;
  PortfolioRead? read;
  bool loading = false;
  bool stale = true;
  bool _disposed = false;
  int _generation = 0;
  PortfolioController(this.repository, this.isSessionCurrent);

  Future<void> select(String? id, String? selectedDate) async {
    final generation = ++_generation;
    accountId = id;
    date = selectedDate;
    error = null;
    loading = false;
    stale = true;
    read = id == null ? null : repository.cached(id, selectedDate);
    bool current() =>
        !_disposed &&
        generation == _generation &&
        isSessionCurrent() &&
        id != null &&
        repository.owns(id);
    if (!current()) {
      read = null;
      notifyListeners();
      return;
    }
    if (repository.source.offline) {
      error = 'Offline — data cache mungkin sudah usang.';
      notifyListeners();
      return;
    }
    loading = true;
    notifyListeners();
    try {
      final result = await repository.fetch(
        id!,
        selectedDate,
        isCurrent: current,
      );
      if (!current() || repository.source.offline) return;
      read = result;
      stale = false;
    } on ApiFailure catch (failure) {
      if (!current()) return;
      if (failure.statusCode == 401 ||
          failure.statusCode == 403 ||
          failure.statusCode == 404) {
        read = null;
      }
      error = failure.message;
    } catch (_) {
      if (current()) error = 'Portofolio belum dapat dimuat. Coba lagi.';
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        if (!isSessionCurrent() || id == null || !repository.owns(id)) {
          read = null;
        }
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
