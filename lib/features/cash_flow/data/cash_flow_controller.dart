import '../../../core/network/api_client.dart';
import 'cash_flow_repository.dart';

class CashFlowController {
  final CashFlowRepository repository;
  final bool Function() isCurrent;
  String? error;
  CashFlowController(this.repository, this.isCurrent);
  bool save(Map<String, dynamic> values) {
    try {
      if (!isCurrent()) throw const ApiFailure('Sesi telah berubah.');
      repository.saveAssumptions(values);
      error = null;
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    }
  }
}
