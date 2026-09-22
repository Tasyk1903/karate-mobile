import 'package:integration_test/integration_test.dart';

import '../test/tournament_enrollment_test.dart' as scenarios;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  scenarios.tournamentEnrollmentTests(
    screenshot: (name) async {
      await binding.takeScreenshot(name);
    },
  );
}
