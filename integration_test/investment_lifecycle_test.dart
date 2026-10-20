import 'package:integration_test/integration_test.dart';

import '../test/widget/investment_lifecycle_page_test.dart' as lifecycle;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  lifecycle
      .main(); // Synthetic in-memory owner, no network or real financial data.
}
