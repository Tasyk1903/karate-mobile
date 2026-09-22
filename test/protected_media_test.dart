import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:karaterating_trainer/api/api_client.dart';
import 'package:karaterating_trainer/auth/auth_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'bearer is sent only to protected files on the configured API origin',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      final session = AuthSession(await SharedPreferences.getInstance());
      await session.signIn(
        email: 'coach@example.test',
        remember: true,
        token: 'test-token',
      );
      final api = ApiClient(
        session: session,
        baseUrl: 'https://api.example.test/api/mobile',
      );
      expect(
        api.mediaHeaders('/api/mobile/files/users/1/passport')['Authorization'],
        'Bearer test-token',
      );
      expect(
        api.mediaHeaders(
          'https://other.example.test/api/mobile/files/users/1/passport',
        ),
        isEmpty,
      );
      expect(
        api.mediaHeaders(
          'http://api.example.test/api/mobile/files/users/1/passport',
        ),
        isEmpty,
      );
      expect(api.mediaHeaders('/storage/avatar/test.png'), isEmpty);
      expect(api.mediaHeaders('/api/mobile/feed'), isEmpty);
      final trailingSlashApi = ApiClient(
        session: session,
        baseUrl: 'https://api.example.test/api/mobile/',
      );
      expect(
        trailingSlashApi.mediaHeaders(
          '/api/mobile/files/users/1/passport',
        )['Authorization'],
        'Bearer test-token',
      );
    },
  );
}
