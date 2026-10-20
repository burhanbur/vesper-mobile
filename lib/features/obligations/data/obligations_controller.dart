import 'package:flutter/foundation.dart';

import 'obligations_repository.dart';

class ObligationsController extends ChangeNotifier {
  final ObligationsRepository repository;
  final bool Function() isCurrent;
  final VoidCallback onSaved;
  String? error;
  bool _disposed = false;
  ObligationsController(this.repository, this.isCurrent, this.onSaved);
  bool save(
    void Function() operation, {
    List<String> amounts = const [],
    List<String> accountIds = const [],
  }) {
    if (_disposed) return false;
    try {
      if (!isCurrent()) throw StateError('Sesi telah berubah.');
      repository.validateMobileEntry(amounts);
      repository.validateMobileAccounts(accountIds);
      operation();
      error = null;
      onSaved();
      notifyListeners();
      return true;
    } catch (failure) {
      error = failure.toString();
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
