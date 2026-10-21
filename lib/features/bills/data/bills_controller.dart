import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import 'bills_repository.dart';

class BillsController extends ChangeNotifier {
  final BillsRepository repository;
  final bool Function() isCurrent;
  final VoidCallback onSaved;
  String? error;
  BillsController(this.repository, this.isCurrent, this.onSaved);
  bool save(VoidCallback action) {
    try {
      if (!isCurrent()) throw const ApiFailure('Sesi telah berubah.');
      action();
      error = null;
      onSaved();
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    }
  }
}
