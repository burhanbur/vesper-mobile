import 'package:flutter/foundation.dart';

import 'investment_lifecycle_repository.dart';

class InvestmentLifecycleController extends ChangeNotifier {
  final InvestmentLifecycleRepository repository;
  final bool Function() isCurrent;
  final VoidCallback onSaved;
  bool loading = false, _disposed = false;
  String? error;
  InvestmentLifecycleController(this.repository, this.isCurrent, this.onSaved);

  Future<void> refresh() async {
    if (loading || !isCurrent()) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      await repository.discover(isCurrent: isCurrent);
    } catch (failure) {
      if (isCurrent()) error = failure.toString();
    } finally {
      loading = false;
      if (!_disposed && isCurrent()) notifyListeners();
    }
  }

  void saveInstrument(String code, String name, String type) {
    if (!isCurrent()) throw StateError('Sesi telah berubah.');
    repository.source.saveInstrumentLocal(
      code: code.trim().toUpperCase(),
      name: name,
      type: type,
    );
    onSaved();
    notifyListeners();
  }

  void savePrice(String id, String date, String price) {
    if (!isCurrent()) throw StateError('Sesi telah berubah.');
    repository.source.saveInvestmentPriceLocal(id, date, price);
    onSaved();
    notifyListeners();
  }

  void discardCatalog(String id) {
    if (!isCurrent()) throw StateError('Sesi telah berubah.');
    repository.source.discardInvestmentCatalog(id);
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
