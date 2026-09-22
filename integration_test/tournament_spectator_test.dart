import 'package:integration_test/integration_test.dart';

import '../test/tournament_spectator_test.dart' as scenarios;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  scenarios.spectatorTests(
    screenshot: (name) async {
      await binding.takeScreenshot(name);
    },
  );
}
