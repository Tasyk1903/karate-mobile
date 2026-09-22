import 'package:integration_test/integration_test.dart';

import '../test/education_test.dart' as education;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  education.educationTests();
}
