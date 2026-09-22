import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:karaterating_trainer/api/api_client.dart';
import 'package:karaterating_trainer/auth/auth_session.dart';
import 'package:karaterating_trainer/auth/session_controller.dart';
import 'package:karaterating_trainer/l10n/app_locale.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  late AuthSession session;
  final storage = const FlutterSecureStorage();

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    session = AuthSession(prefs);
  });

  Future<void> login([String token = 'secret']) =>
      session.signIn(email: 'coach@example.test', remember: true, token: token);

  SessionController controller(http.Client client) {
    final auth = SessionController(
      session,
      ApiClient(
        session: session,
        httpClient: client,
        baseUrl: 'https://example.test/api/mobile',
      ),
    );
    addTearDown(auth.dispose);
    return auth;
  }

  test(
    'secure persistence, restore and cleanup never write bearer to preferences',
    () async {
      await login();
      expect(prefs.getKeys(), isEmpty);
      expect(
        await storage.read(key: AuthSession.storageKey),
        contains('secret'),
      );
      final restored = AuthSession(prefs);
      expect(restored.token, isNull);
      await restored.restore();
      expect(restored.token, 'secret');
      expect(restored.isActive, isTrue);
      await restored.signOut();
      expect(await storage.readAll(), isEmpty);
      expect(restored.token, isNull);
    },
  );

  test(
    'migrates legacy plaintext only after a successful secure write',
    () async {
      await prefs.setString('auth_token', 'legacy');
      await prefs.setInt(
        'auth_until',
        DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch,
      );
      await session.restore();
      expect(session.token, 'legacy');
      expect(prefs.getKeys(), isEmpty);
      expect(
        await storage.read(key: AuthSession.storageKey),
        contains('legacy'),
      );
    },
  );

  test(
    'storage failure does not authorize or silently discard legacy credentials',
    () async {
      await prefs.setString('auth_token', 'legacy');
      final broken = AuthSession(prefs, storage: _BrokenStorage());
      await expectLater(broken.restore(), throwsStateError);
      expect(broken.isActive, isFalse);
      expect(broken.token, isNull);
      expect(prefs.getString('auth_token'), 'legacy');
    },
  );

  test('expired, malformed and missing sessions are not restored', () async {
    for (final data in [
      'invalid',
      '[]',
      jsonEncode({'token': 'expired', 'until': 1}),
    ]) {
      await storage.write(key: AuthSession.storageKey, value: data);
      await session.restore();
      expect(session.isActive, isFalse);
      expect(await storage.read(key: AuthSession.storageKey), isNull);
    }
  });

  test('restoration validates the current coach before authorizing', () async {
    await login();
    final pending = Completer<http.Response>();
    final auth = controller(
      MockClient((request) {
        expect(request.url.path, '/api/mobile/auth/user');
        expect(request.headers['Authorization'], 'Bearer secret');
        expect(request.followRedirects, isFalse);
        return pending.future;
      }),
    );
    final restoring = auth.restore();
    expect(auth.status, SessionStatus.restoring);
    pending.complete(
      http.Response(
        jsonEncode({
          'user': {
            'id': 1,
            'roles': ['Coach'],
          },
        }),
        200,
      ),
    );
    await restoring;
    expect(auth.status, SessionStatus.authorized);
  });

  test(
    'registration session is stored securely and profile gate survives restore',
    () async {
      var required = true;
      final user = <String, dynamic>{
        'id': 526,
        'email': 'student@example.test',
        'roles': ['Student'],
        'agreements_required': true,
        'profile_setup_required': true,
      };
      final auth = controller(
        MockClient((request) async {
          expect(request.url.path, '/api/mobile/auth/user');
          expect(request.headers['Authorization'], 'Bearer signup-token');
          return http.Response(
            jsonEncode({
              'user': {...user, 'profile_setup_required': required},
            }),
            200,
          );
        }),
      );
      await auth.acceptSession({
        'token': 'signup-token',
        'user': user,
        'expires_at': DateTime.now()
            .add(const Duration(days: 30))
            .toIso8601String(),
      });
      expect(auth.status, SessionStatus.authorized);
      expect(auth.agreementsRequired, true);
      expect(auth.profileSetupRequired, true);
      expect(prefs.getKeys(), isEmpty);
      expect(
        await storage.read(key: AuthSession.storageKey),
        contains('signup-token'),
      );
      await auth.restore();
      expect(auth.profileSetupRequired, true);
      required = false;
      await auth.refreshIdentity();
      expect(auth.profileSetupRequired, false);
      await auth.invalidate();
      expect(auth.profileSetupRequired, false);
    },
  );

  test(
    'network failure offers retry without destroying saved session',
    () async {
      await login();
      var offline = true;
      final auth = controller(
        MockClient((_) async {
          if (offline) throw http.ClientException('Offline');
          return http.Response(
            jsonEncode({
              'user': {
                'id': 1,
                'roles': ['Coach'],
              },
            }),
            200,
          );
        }),
      );
      await auth.restore();
      expect(auth.status, SessionStatus.unavailable);
      expect(session.token, 'secret');
      offline = false;
      await auth.restore();
      expect(auth.status, SessionStatus.authorized);
    },
  );

  test('revoked or unsupported role returns to login', () async {
    for (final response in [
      http.Response('<html>Unauthorized</html>', 401),
      http.Response(
        jsonEncode({
          'user': {
            'id': 1,
            'roles': ['Secretary'],
          },
        }),
        200,
      ),
    ]) {
      await login();
      final auth = controller(MockClient((_) async => response));
      await auth.restore();
      expect(auth.status, SessionStatus.signedOut);
      expect(session.token, isNull);
    }
  });

  test('student restoration and role changes replace the shell without trusting cached role', () async {
    await login();
    var role = 'Student';
    final auth = controller(
      MockClient(
        (_) async => http.Response(
          jsonEncode({
            'user': {
              'id': 7,
              'roles': [role],
              'navigation': {
                'bottom': ['rating', 'feed', 'profile'],
                'menu': ['about', 'agreements', 'logout'],
              },
            },
          }),
          200,
        ),
      ),
    );
    await auth.restore();
    expect(auth.status, SessionStatus.authorized);
    expect(auth.api.isStudent, true);
    expect(auth.api.menuAvailable('students'), false);
    final generation = auth.generation;
    role = 'Coach';
    await auth.revalidate();
    expect(auth.api.isStudent, false);
    expect(auth.generation, generation + 1);
    role = 'Secretary';
    await auth.revalidate();
    expect(auth.status, SessionStatus.signedOut);
    expect(auth.api.accountId, isNull);
  });

  test(
    'logout revokes current bearer before removing secure credentials',
    () async {
      await login();
      final auth = controller(
        MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/mobile/auth/logout');
          expect(request.headers['Authorization'], 'Bearer secret');
          expect(session.token, 'secret');
          return http.Response('{}', 200);
        }),
      );
      await auth.logout();
      expect(session.token, isNull);
      expect(await storage.readAll(), isEmpty);
      expect(auth.status, SessionStatus.signedOut);
    },
  );

  test(
    'failed logout keeps credentials for retry; revoked logout clears them',
    () async {
      await login();
      var status = 500;
      final auth = controller(
        MockClient((_) async => http.Response('{}', status)),
      );
      await expectLater(auth.logout(), throwsA(isA<ApiException>()));
      expect(session.token, 'secret');
      status = 401;
      await auth.logout();
      expect(session.token, isNull);
    },
  );

  test(
    'all authenticated request types handle 401 including files and multipart',
    () async {
      final auth = controller(
        MockClient((_) async => http.Response('{}', 401)),
      );
      final calls = <Future<dynamic> Function()>[
        () => auth.api.getJson('/feed'),
        () => auth.api.postJson('/feed'),
        () => auth.api.putJson('/feed/1'),
        () => auth.api.deleteJson('/feed/1'),
        () => auth.api.getBytes('/files/1'),
        () => auth.api.postMultipart('/feed', fields: {}),
        () => auth.api.postMultipartFiles('/feed', fields: {}, files: {}),
      ];
      for (final call in calls) {
        await login();
        await expectLater(call(), throwsA(isA<ApiException>()));
        expect(session.token, isNull);
        expect(auth.status, SessionStatus.signedOut);
      }
    },
  );

  test('late 401 from previous token and anonymous login failure do not revoke new login', () async {
    await login('old');
    final pending = Completer<http.Response>();
    final auth = controller(MockClient((_) => pending.future));
    final request = auth.api.getJson('/feed');
    await login('new');
    pending.complete(http.Response('{}', 401));
    await expectLater(request, throwsA(isA<ApiException>()));
    expect(session.token, 'new');
    await expectLater(
      auth.api.login(
        email: 'a@b.test',
        password: 'wrong',
        remember: true,
        locale: AppLocale.ru,
      ),
      throwsA(isA<ApiException>()),
    );
    expect(session.token, 'new');
  });

  test(
    '428 requires consent without revoking token and ignores previous sessions',
    () async {
      await login();
      final auth = controller(
        MockClient((_) async => http.Response('{}', 428)),
      );
      await expectLater(
        auth.api.getJson('/trainer/profile'),
        throwsA(isA<ApiException>()),
      );
      expect(auth.agreementsRequired, true);
      expect(session.token, 'secret');
      final pending = Completer<http.Response>();
      final other = controller(MockClient((_) => pending.future));
      final request = other.api.getJson('/feed');
      await login('new');
      pending.complete(http.Response('{}', 428));
      await expectLater(request, throwsA(isA<ApiException>()));
      expect(other.agreementsRequired, false);
      expect(session.token, 'new');
    },
  );

  test('ordinary forbidden resource does not sign out; browser URLs never contain bearer', () async {
    await login();
    final auth = controller(MockClient((_) async => http.Response('{}', 403)));
    await expectLater(
      auth.api.getJson('/students/1'),
      throwsA(isA<ApiException>()),
    );
    expect(session.token, 'secret');
    expect(
      auth.api.recoveryWebUri().toString(),
      'https://example.test/forgot-password?locale=ru',
    );
    expect(auth.api.recoveryWebUri().queryParameters, {'locale': 'ru'});
  });
}

class _BrokenStorage extends FlutterSecureStorage {
  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    throw StateError('Keychain unavailable');
  }
}
