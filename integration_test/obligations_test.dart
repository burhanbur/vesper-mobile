import 'package:integration_test/integration_test.dart';

import '../test/widget/obligations_page_test.dart' as obligations;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  obligations.main(); // Synthetic in-memory owner; no real accounts or network.
}
