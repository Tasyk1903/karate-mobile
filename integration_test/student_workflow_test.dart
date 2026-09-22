import 'package:integration_test/integration_test.dart';

import '../test/student_workflow_test.dart' as scenarios;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  scenarios.studentWorkflowTests(
    screenshot: (name) async {
      await binding.takeScreenshot(name);
    },
  );
}
