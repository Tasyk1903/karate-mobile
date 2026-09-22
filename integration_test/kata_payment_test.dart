import 'package:integration_test/integration_test.dart';

import '../test/kata_payment_workflow_test.dart' as scenarios;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  scenarios.kataPaymentTests(
    screenshot: (name) async {
      await binding.takeScreenshot(name);
    },
  );
}
