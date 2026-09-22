import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:karaterating_trainer/api/api_client.dart';
import 'package:karaterating_trainer/auth/auth_session.dart';
import 'package:karaterating_trainer/students/student_profile_setup_screen.dart';
import 'package:karaterating_trainer/theme/app_theme.dart';
import 'package:karaterating_trainer/l10n/app_locale.dart';

void main() {
  const font = String.fromEnvironment('SCREENSHOT_FONT');
  final boundary = GlobalKey();
  setUpAll(() async {
    if (font.isNotEmpty) {
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      await (FontLoader(
        'SetupScreenshot',
      )..addFont(File(font).readAsBytes().then(ByteData.sublistView))).load();
    }
  });
  Future<void> capture(WidgetTester tester, String name) async {
    if (font.isEmpty) return;
    await tester.runAsync(() async {
      final image =
          await (boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('/tmp/kr-student-setup-$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets(
    'profile setup validates, preserves input on error and excludes documents and patronymic',
    (tester) async {
      const s = AppStrings(AppLocale.en);
      var posts = 0, completed = 0;
      final session = AuthSession(await SharedPreferences.getInstance());
      await session.signIn(
        email: 'student@example.test',
        remember: true,
        token: 'test-token',
      );
      final api =
          ApiClient(
            session: session,
            httpClient: MockClient((request) async {
              if (request.method == 'POST') {
                posts++;
                expect(request.body, contains('name="weight"\r\n\r\n35'));
                for (final key in [
                  'patronymic',
                  'passport',
                  'insurance',
                  'number_iko',
                  'email',
                ]) {
                  expect(request.body, isNot(contains('name="$key"')));
                }
                return http.Response(
                  jsonEncode(posts == 1 ? {'message': 'Try again'} : {}),
                  posts == 1 ? 503 : 200,
                );
              }
              return http.Response(
                jsonEncode({
                  'student': {
                    'id': 526,
                    'first_name': 'New',
                    'last_name': 'Student',
                    'birthday': '2015-01-01',
                    'gender': 'm',
                    'rang': '9 кю',
                    'city_training': 'Warsaw',
                    'capabilities': {
                      'birthday': true,
                      'rang': true,
                      'weight': true,
                    },
                  },
                }),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
            }),
          )..setIdentity({
            'id': 526,
            'roles': ['Student'],
          });
      addTearDown(api.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: StudentProfileSetupScreen(
            api: api,
            strings: s,
            onCompleted: () async {
              completed++;
            },
            onLogout: () async {},
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pumpAndSettle();
      expect(find.text(s.patronymic), findsNothing);
      expect(find.text(s.documentUploads), findsNothing);
      expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
      final save = find.text(s.finishRegistration);
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(posts, 0);
      final weight = find.ancestor(
        of: find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.labelText == '${s.weight} *',
        ),
        matching: find.byType(TextFormField),
      );
      await tester.ensureVisible(weight);
      await tester.enterText(weight, '35');
      for (var i = 0; i < 2; i++) {
        await tester.ensureVisible(save);
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await tester.tap(save);
          await Future<void>.delayed(const Duration(milliseconds: 20));
        });
        await tester.pumpAndSettle();
        expect(tester.widget<TextFormField>(weight).controller!.text, '35');
      }
      expect(posts, 2);
      expect(completed, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('setup layout fits phones RU EN light dark and large text', (
    tester,
  ) async {
    final api =
        ApiClient(
          session: AuthSession(await SharedPreferences.getInstance()),
          httpClient: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'student': {
                  'id': 526,
                  'first_name': 'Александр',
                  'last_name': 'Константинопольский',
                  'capabilities': {
                    'birthday': true,
                    'rang': true,
                    'weight': true,
                  },
                },
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            ),
          ),
        )..setIdentity({
          'id': 526,
          'roles': ['Student'],
        });
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
                locale: Locale(locale.name),
                supportedLocales: const [Locale('ru'), Locale('en')],
                localizationsDelegates: GlobalMaterialLocalizations.delegates,
                theme: (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
                  textTheme: (dark ? AppTheme.dark() : AppTheme.light())
                      .textTheme
                      .apply(
                        fontFamily: font.isEmpty ? null : 'SetupScreenshot',
                      ),
                ),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: RepaintBoundary(
                  key: boundary,
                  child: StudentProfileSetupScreen(
                    key: ValueKey('$width/$locale/$dark/$scale'),
                    api: api,
                    strings: AppStrings(locale),
                    onCompleted: () async {},
                    onLogout: () async {},
                  ),
                ),
              ),
            );
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 20)),
            );
            await tester.pumpAndSettle();
            if (width == 360 && scale == 1) {
              await capture(
                tester,
                '${locale.name}-${dark ? 'dark' : 'light'}-top',
              );
            }
            await tester.ensureVisible(
              find.text(AppStrings(locale).finishRegistration),
            );
            await tester.pumpAndSettle();
            if (width == 360 && scale == 1) {
              await capture(
                tester,
                '${locale.name}-${dark ? 'dark' : 'light'}-bottom',
              );
            }
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
}
