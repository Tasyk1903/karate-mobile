import 'package:integration_test/integration_test.dart';

import '../test/examination_workflow_test.dart' as scenarios;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  scenarios.examinationTests(
    screenshot: (name) async {
      await binding.takeScreenshot(name);
    },
  );
}
