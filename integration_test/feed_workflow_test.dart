import 'package:integration_test/integration_test.dart';

import '../test/feed_workflow_test.dart' as scenarios;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  scenarios.feedTests(
    screenshot: (name) async {
      await binding.takeScreenshot(name);
    },
  );
}
