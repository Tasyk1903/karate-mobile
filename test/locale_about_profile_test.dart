import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:karaterating_trainer/about/about_screen.dart';
import 'package:karaterating_trainer/api/api_client.dart';
import 'package:karaterating_trainer/api/video_upload.dart';
import 'package:karaterating_trainer/app/karate_rating_app.dart';
import 'package:karaterating_trainer/auth/auth_session.dart';
import 'package:karaterating_trainer/l10n/app_locale.dart';
import 'package:karaterating_trainer/profile/trainer_profile_screen.dart';
import 'package:karaterating_trainer/theme/app_theme.dart';
import 'package:karaterating_trainer/students/students_screen.dart';

void main() {
  test('mobile app name is KumiteRating in every locale', () {
    for (final locale in AppLocale.values) {
      final strings = AppStrings(locale);
      expect(strings.appTitle, 'KumiteRating');
      expect(strings.aboutHeadline, strings.appTitle);
    }
  });

  setUpAll(() async {
    const font = String.fromEnvironment('SCREENSHOT_FONT');
    if (font.isNotEmpty) {
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      await (FontLoader('ScreenshotFont')..addFont(
            File(font).readAsBytes().then((b) => ByteData.sublistView(b)),
          ))
          .load();
    }
  });
  ThemeData theme(bool dark) {
    final theme = dark ? AppTheme.dark() : AppTheme.light();
    return const String.fromEnvironment('SCREENSHOT_FONT').isEmpty
        ? theme
        : theme.copyWith(
            textTheme: theme.textTheme.apply(fontFamily: 'ScreenshotFont'),
          );
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('SAVE_SCREENSHOTS')) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('capture')),
    );
    await tester.runAsync(() async {
      final rendered = await boundary.toImage(pixelRatio: 2);
      final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/scope-screenshots/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      rendered.dispose();
    });
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test(
    'locale reaches JSON and multipart requests without token in URLs',
    () async {
      final requests = <http.Request>[];
      final api = ApiClient(
        session: AuthSession(await SharedPreferences.getInstance()),
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(jsonEncode({}), 200);
        }),
      )..locale = AppLocale.en;
      await api.getJson('/about');
      await api.postJson('/trainer/profile');
      await api.postMultipart('/trainer/profile', fields: {});
      expect(
        requests.every((r) => r.headers['Accept-Language'] == 'en'),
        isTrue,
      );
      expect(api.recoveryWebUri().queryParameters, {'locale': 'en'});
      expect(VideoUpload.maxBytes, 104857600);
      api.close();
    },
  );

  testWidgets('late student response cannot overwrite a refreshed list', (
    tester,
  ) async {
    final api = _Api(AuthSession(await SharedPreferences.getInstance()));
    api.heldStudents = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(
      MaterialApp(
        home: StudentsScreen(strings: const AppStrings(AppLocale.en), api: api),
      ),
    );
    await tester.pump();
    final refresh = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    final held = api.heldStudents!;
    api.heldStudents = null;
    await refresh.onRefresh();
    await tester.pumpAndSettle();
    expect(find.text('Fresh student'), findsOneWidget);
    held.complete({
      'data': [
        {'id': 99, 'full_name': 'Stale student'},
      ],
      'meta': {'last_page': 1},
    });
    await tester.pumpAndSettle();
    expect(find.text('Stale student'), findsNothing);
    expect(find.text('Fresh student'), findsOneWidget);
    api.close();
  });

  testWidgets(
    'saved language is restored before session validation and survives relaunch',
    (tester) async {
      SharedPreferences.setMockInitialValues({'app_locale': 'en'});
      final prefs = await SharedPreferences.getInstance();
      late _Api api;
      await tester.pumpWidget(
        KarateRatingApp(
          prefs: prefs,
          apiFactory: (session) => api = _Api(session),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sign in'), findsNWidgets(2));
      expect(api.locale, AppLocale.en);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        KarateRatingApp(
          prefs: prefs,
          apiFactory: (session) => api = _Api(session),
        ),
      );
      await tester.pumpAndSettle();
      expect(api.locale, AppLocale.en);
      expect(find.text('Sign in'), findsNWidgets(2));
    },
  );

  testWidgets(
    'about uses server details and offers retry instead of fake fallback',
    (tester) async {
      final api = _Api(AuthSession(await SharedPreferences.getInstance()))
        ..fail = true;
      const s = AppStrings(AppLocale.en);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: AboutScreen(strings: s, api: api),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(s.aboutLoadFailed), findsOneWidget);
      expect(find.text('610105235210'), findsNothing);
      api.fail = false;
      await tester.tap(find.text(s.retry));
      await tester.pumpAndSettle();
      expect(find.text('Server project'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Owner from API'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Owner from API'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('contact@example.test'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('contact@example.test'), findsOneWidget);
      expect(tester.takeException(), isNull);
      api.close();
    },
  );

  testWidgets(
    'about illustration is larger and fades into both themes without overflow',
    (tester) async {
      final api = _Api(AuthSession(await SharedPreferences.getInstance()));
      addTearDown(api.close);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final width in [360.0, 393.0, 430.0]) {
        for (final locale in AppLocale.values) {
          for (final dark in [false, true]) {
            tester.view.physicalSize = Size(width, 900);
            tester.view.devicePixelRatio = 1;
            await tester.pumpWidget(const SizedBox());
            await tester.pumpWidget(
              MaterialApp(
                theme: theme(dark),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(1.6)),
                  child: RepaintBoundary(
                    key: const ValueKey('capture'),
                    child: child!,
                  ),
                ),
                home: AboutScreen(strings: AppStrings(locale), api: api),
              ),
            );
            await tester.pumpAndSettle();
            final art = find.byKey(const ValueKey('about-image'));
            expect(tester.getSize(art).height, greaterThan(190));
            expect(tester.getSize(art).width, lessThanOrEqualTo(width));
            final masks = tester.widgetList<ShaderMask>(
              find.descendant(of: art, matching: find.byType(ShaderMask)),
            );
            expect(masks.length, 2);
            expect(
              masks.every((mask) => mask.blendMode == BlendMode.dstIn),
              true,
            );
            final asset = tester.widget<Image>(
              find.descendant(of: art, matching: find.byType(Image)),
            );
            await tester.runAsync(
              () => precacheImage(asset.image, tester.element(art)),
            );
            await tester.pumpAndSettle();
            if (width == 393 && locale == AppLocale.ru) {
              await capture(tester, 'about-image-${dark ? 'dark' : 'light'}');
            }
            expect(tester.takeException(), isNull);
          }
        }
      }
    },
  );

  testWidgets(
    'profile facts retain date at phone widths, both locales/themes and enlarged text',
    (tester) async {
      final api = _Api(AuthSession(await SharedPreferences.getInstance()));
      for (final width in [360.0, 393.0, 430.0]) {
        for (final locale in AppLocale.values) {
          for (final dark in [false, true]) {
            for (final scale in [1.0, 1.6, 2.0]) {
              tester.view.physicalSize = Size(width, 900);
              tester.view.devicePixelRatio = 1;
              await tester.pumpWidget(const SizedBox());
              await tester.pumpWidget(
                MaterialApp(
                  theme: theme(dark),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(scale)),
                    child: RepaintBoundary(
                      key: const ValueKey('capture'),
                      child: child!,
                    ),
                  ),
                  home: TrainerProfileScreen(
                    strings: AppStrings(locale),
                    api: api,
                  ),
                ),
              );
              await tester.pumpAndSettle();
              expect(find.text('03.02.1986'), findsOneWidget);
              if (width == 393 && locale == AppLocale.ru && scale == 1) {
                await capture(tester, 'profile-${dark ? 'dark' : 'light'}');
              }
              expect(
                tester.takeException(),
                isNull,
                reason: '$width $locale $dark $scale',
              );
            }
          }
        }
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      api.close();
    },
  );
}

class _Api extends ApiClient {
  _Api(AuthSession session) : super(session: session);
  bool fail = false;
  Completer<Map<String, dynamic>>? heldStudents;

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String?> query = const {},
  }) async {
    if (fail) throw const ApiException('offline');
    if (path == '/students') {
      return heldStudents?.future ??
          Future.value({
            'data': [
              {'id': 1, 'full_name': 'Fresh student'},
            ],
            'meta': {'last_page': 1},
          });
    }
    if (path == '/about') {
      return {
        'project': {
          'title': 'Server project',
          'lead': 'Server lead',
          'description': 'Server description',
          'features': [],
          'goal': 'Server goal',
        },
        'company': {
          'name': 'Owner from API',
          'inn': '12345',
          'address': 'Server address',
        },
        'bank': {
          'bank': 'Server bank',
          'bik': '111',
          'account': '222',
          'correspondent_account': '333',
        },
        'contacts': {
          'email': 'contact@example.test',
          'partners_email': 'partner@example.test',
          'work_time': 'Server work time',
        },
      };
    }
    if (path == '/trainer/profile') {
      return {
        'trainer': {
          'id': 1,
          'full_name': 'Константинопольский Александр',
          'first_name': 'Александр',
          'last_name': 'Константинопольский',
          'email': 'long.trainer.name@example.test',
          'club': 'Международный спортивный клуб',
          'gender_label': 'Мужской',
          'birthday': '03.02.1986',
          'age': 40,
          'weight': 100,
          'height': 190,
          'rang': '1 дан',
          'belt': {
            'label_key': 'blackBelt',
            'color': '#111827',
            'accent': '#d6a233',
            'progress': 100,
          },
        },
      };
    }
    return {};
  }
}
