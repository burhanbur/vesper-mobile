import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import 'goals_repository.dart';

class GoalsController extends ChangeNotifier {
  final GoalsRepository repository;
  final bool Function() isCurrent;
  final VoidCallback onSaved;
  String? error;
  GoalsController(this.repository, this.isCurrent, this.onSaved);
  bool save(VoidCallback action) {
    try {
      if (!isCurrent()) throw const ApiFailure('Sesi telah berubah.');
      action();
      error = null;
      onSaved();
      return true;
    } catch (failure) {
      error = failure.toString();
      return false;
    }
  }
}
