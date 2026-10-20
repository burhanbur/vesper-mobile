import 'package:flutter/foundation.dart';

import '../../../app/app_state.dart';
import '../../../core/network/api_client.dart';
import 'financial_export_repository.dart';

class FinancialExportController extends ChangeNotifier {
  final AppState state;
  final FinancialExportRepository repository;
  final String userId;
  String? error;
  FinancialExportController(this.state, this.repository)
    : userId = state.currentUserId;

  bool get isCurrent =>
      identical(state.repository, repository.source) &&
      state.currentUserId == userId &&
      repository.source.userId == userId;

  void requireCurrent() {
    if (!isCurrent) {
      throw const ApiFailure('Sesi berubah. Buka kembali halaman ini.');
    }
  }

  bool confirm(BalanceReconciliation comparison) {
    try {
      requireCurrent();
      final fresh = repository.compare(
        comparison.accountId,
        financialDecimal(comparison.statement),
        comparison.reference,
      );
      if (fresh.recorded != comparison.recorded) {
        throw const ApiFailure(
          'Saldo berubah. Bandingkan ulang sebelum konfirmasi.',
        );
      }
      state.adjustAccountBalance(
        comparison.accountId,
        (comparison.statement ~/ BigInt.from(100)).toInt(),
        expectedBalance: (comparison.recorded ~/ BigInt.from(100)).toInt(),
        description: comparison.description,
      );
      error = null;
      notifyListeners();
      return true;
    } catch (failure) {
      error = failure.toString();
      notifyListeners();
      return false;
    }
  }
}
