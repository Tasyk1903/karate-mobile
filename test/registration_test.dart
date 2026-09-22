import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:karaterating_trainer/api/api_client.dart';
import 'package:karaterating_trainer/auth/auth_session.dart';
import 'package:karaterating_trainer/auth/login_screen.dart';
import 'package:karaterating_trainer/auth/registration_screen.dart';
import 'package:karaterating_trainer/l10n/app_locale.dart';
import 'package:karaterating_trainer/theme/app_theme.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  Future<void> fill(WidgetTester tester, String key, String value) async {
    final field = find.byKey(ValueKey(key));
    await tester.ensureVisible(field);
    await tester.enterText(field, value);
    await tester.pump();
  }

  Future<void> submit(WidgetTester tester) async {
    final button = find.byType(FilledButton).last;
    await tester.ensureVisible(button);
    await tester.runAsync(() async {
      await tester.tap(button);
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pumpAndSettle();
  }

  for (final student in [false, true]) {
    testWidgets(
      'native ${student ? 'student' : 'coach'} signup preserves input on failure and verifies email',
      (tester) async {
        final requests = <http.Request>[];
        var failStart = true, failConfirm = true;
        var registeredCalls = 0;
        final token = List.filled(64, 'a').join();
        final api = ApiClient(
          session: AuthSession(await SharedPreferences.getInstance()),
          baseUrl: 'https://example.test/api/mobile',
          httpClient: MockClient((request) async {
            requests.add(request);
            expect(request.url.query, isEmpty);
            expect(request.headers.containsKey('Authorization'), false);
            expect(request.headers['Accept-Language'], 'en');
            if (request.url.path.endsWith('/confirm')) {
              expect(jsonDecode(request.body), {
                'challenge_token': token,
                'code': '123456',
              });
              if (failConfirm) {
                failConfirm = false;
                return http.Response(
                  jsonEncode({'message': 'Wrong code'}),
                  422,
                );
              }
              return http.Response(
                jsonEncode({
                  'registered': true,
                  if (student) ...{
                    'token': 'student-token',
                    'user': {
                      'id': 2,
                      'roles': ['Student'],
                      'profile_setup_required': true,
                    },
                  },
                }),
                200,
              );
            }
            expect(
              request.url.path,
              '/api/mobile/auth/registration/${student ? 'student' : 'trainer'}',
            );
            final data = jsonDecode(request.body) as Map;
            expect(
              data[student ? 'coach_code' : 'organization_code'],
              'KR-TEST',
            );
            expect(data['existing_account'], false);
            expect(data['password_confirmation'], 'password123');
            if (failStart) {
              failStart = false;
              return http.Response(
                jsonEncode({'message': 'Please retry'}),
                503,
              );
            }
            return http.Response(
              jsonEncode({
                'verification_required': true,
                'challenge_token': token,
              }),
              200,
            );
          }),
        )..locale = AppLocale.en;
        addTearDown(api.close);
        const s = AppStrings(AppLocale.en);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: RegistrationScreen(
              api: api,
              strings: s,
              student: student,
              onRegistered: student
                  ? (response) async {
                      registeredCalls++;
                      expect(response['token'], 'student-token');
                      if (registeredCalls == 1) {
                        throw StateError('Storage temporarily locked');
                      }
                    }
                  : null,
            ),
          ),
        );
        for (final entry in {
          'join-code': 'KR-TEST',
          'email': 'user@example.test',
          'first-name': 'Name',
          'last-name': 'Surname',
          'password': 'password123',
          'password-confirmation': 'password123',
        }.entries) {
          await fill(tester, entry.key, entry.value);
        }
        expect(
          tester
              .widget<TextFormField>(find.byKey(const ValueKey('password')))
              .controller!
              .text,
          'password123',
        );
        final passwordField = find.descendant(
          of: find.byKey(const ValueKey('password')),
          matching: find.byType(EditableText),
        );
        expect(tester.widget<EditableText>(passwordField).obscureText, true);
        await submit(tester);
        expect(find.text('Please retry'), findsOneWidget);
        expect(
          tester
              .widget<TextFormField>(find.byKey(const ValueKey('email')))
              .controller!
              .text,
          'user@example.test',
        );
        await submit(tester);
        expect(find.byKey(const ValueKey('email-code')), findsOneWidget);
        await fill(tester, 'email-code', '123456');
        await submit(tester);
        expect(find.text('Wrong code'), findsOneWidget);
        expect(find.byKey(const ValueKey('email-code')), findsOneWidget);
        await submit(tester);
        if (student) {
          expect(
            find.textContaining('Storage temporarily locked'),
            findsOneWidget,
          );
          await submit(tester);
          expect(registeredCalls, 2);
          expect(find.text(s.signIn), findsNothing);
          expect(find.text(s.registrationComplete), findsNothing);
        } else {
          expect(find.text(s.registrationComplete), findsOneWidget);
          expect(find.text(s.signIn), findsOneWidget);
        }
        expect(requests.length, 4);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('registration layout RU EN both themes and large text', (
    tester,
  ) async {
    final api = ApiClient(
      session: AuthSession(await SharedPreferences.getInstance()),
      httpClient: MockClient((_) async => http.Response('{}', 200)),
    );
    addTearDown(api.close);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final width in [360.0, 393.0, 430.0]) {
      tester.view.physicalSize = Size(width, 850);
      for (final locale in AppLocale.values) {
        for (final dark in [false, true]) {
          for (final scale in [1.0, 1.6, 2.0]) {
            await tester.pumpWidget(
              MaterialApp(
                theme: dark ? AppTheme.dark() : AppTheme.light(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: RegistrationScreen(
                  api: api,
                  strings: AppStrings(locale),
                  student: locale == AppLocale.ru,
                ),
              ),
            );
            await tester.pumpAndSettle();
            await tester.ensureVisible(find.byType(FilledButton));
            expect(
              tester.takeException(),
              isNull,
              reason: '$width/$locale/$dark/$scale',
            );
          }
        }
      }
    }
  });

  testWidgets('login opens native role registration callback without browser', (
    tester,
  ) async {
    bool? selected;
    const s = AppStrings(AppLocale.en);
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          strings: s,
          locale: AppLocale.en,
          onLocaleChanged: (_) {},
          onSignIn: (_, _, _) async {},
          recoveryUri: Uri.parse('https://example.test/forgot-password'),
          onRegister: (student) async {
            selected = student;
            return 'registered@example.test';
          },
        ),
      ),
    );
    await tester.ensureVisible(find.text(s.register));
    await tester.tap(find.text(s.register));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.studentRole));
    await tester.pumpAndSettle();
    expect(selected, true);
    expect(find.text('registered@example.test'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
