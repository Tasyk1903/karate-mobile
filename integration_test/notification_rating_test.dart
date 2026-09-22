import 'package:integration_test/integration_test.dart';

import '../test/notification_rating_test.dart' as scenarios;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  scenarios.notificationRatingTests();
}
