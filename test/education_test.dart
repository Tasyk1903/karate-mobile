import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:karaterating_trainer/api/api_client.dart';
import 'package:karaterating_trainer/auth/auth_session.dart';
import 'package:karaterating_trainer/education/education_screen.dart';
import 'package:karaterating_trainer/education/education_video_screen.dart';
import 'package:karaterating_trainer/l10n/app_locale.dart';
import 'package:karaterating_trainer/navigation/coach_bottom_nav.dart';
import 'package:karaterating_trainer/theme/app_theme.dart';

void main() => educationTests();
void educationTests() {
  late EducationTestApi api;
  late EducationVideoPlatform platform;
  late VideoPlayerPlatform original;
  const s = AppStrings(AppLocale.ru);
  const font = String.fromEnvironment('SCREENSHOT_FONT');
  setUpAll(() async {
    if (font.isNotEmpty) {
      await (FontLoader(
        'TestFont',
      )..addFont(File(font).readAsBytes().then(ByteData.sublistView))).load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final session = AuthSession(await SharedPreferences.getInstance());
    await session.signIn(
      email: 'test@example.test',
      remember: false,
      token: 'education-test',
    );
    api = EducationTestApi(session);
    original = VideoPlayerPlatform.instance;
    platform = EducationVideoPlatform();
    VideoPlayerPlatform.instance = platform;
  });
  tearDown(() {
    api.close();
    VideoPlayerPlatform.instance = original;
  });
  Widget app(Widget child, {bool dark = false, double scale = 1}) {
    var theme = dark ? AppTheme.dark() : AppTheme.light();
    if (font.isNotEmpty) {
      theme = theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: 'TestFont'),
      );
    }
    return MaterialApp(
      theme: theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: RepaintBoundary(key: const ValueKey('capture'), child: child!),
      ),
      home: child,
    );
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('SAVE_SCREENSHOTS')) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('capture')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/auth-screenshots/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  void phone(WidgetTester tester, double width) {
    tester.view.physicalSize = Size(width, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  testWidgets(
    'student work editor saves category without replacing video and shows own payment state',
    (tester) async {
      phone(tester, 393);
      api.accountRole = 'Student';
      api.accountId = 1;
      api.reviewed = false;
      await tester.pumpWidget(
        app(
          EducationVideoScreen(api: api, strings: s, video: api.row, workId: 1),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip(s.edit), findsOneWidget);
      expect(find.text(s.educationUnpaid), findsOneWidget);
      expect(find.byTooltip(s.delete), findsOneWidget);
      expect(find.text('8.5'), findsNothing);
      await tester.tap(find.byTooltip(s.edit));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(s.save));
      await tester.tap(find.text(s.save));
      await tester.pumpAndSettle();
      expect(api.saved?['category_id'], '1');
      expect(api.saved!.containsKey('video'), false);
      expect(find.text(s.save), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('student sees legacy kata review title in catalogue and works', (
    tester,
  ) async {
    api.accountRole = 'Student';
    for (final locale in AppLocale.values) {
      final strings = AppStrings(locale);
      await tester.pumpWidget(app(EducationScreen(api: api, strings: strings)));
      await tester.pumpAndSettle();
      final title = strings.educationSection('works', ownWorks: true);
      expect(find.text(title), findsOneWidget);
      expect(find.text(strings.educationSection('works')), findsNothing);
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets(
    'menu opens education, allowed sections only, categories and protected lesson player',
    (tester) async {
      phone(tester, 393);
      await tester.pumpWidget(
        app(
          Scaffold(
            bottomNavigationBar: CoachBottomNav(
              api: api,
              strings: s,
              active: null,
            ),
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(s.education));
      await tester.tap(find.text(s.education));
      await tester.pumpAndSettle();
      expect(find.text(s.educationSection('works')), findsOneWidget);
      expect(find.text(s.educationSection('competition')), findsNothing);
      await capture(tester, 'education-sections');
      await tester.tap(find.text(s.educationSection('kihon')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Основная техника'));
      await tester.pumpAndSettle();
      expect(
        find.text('Техника передвижений и базовые стойки'),
        findsOneWidget,
      );
      await capture(tester, 'education-catalog');
      await tester.tap(find.text('Техника передвижений и базовые стойки'));
      await tester.pumpAndSettle();
      expect(
        platform.source?.httpHeaders['Authorization'],
        'Bearer education-test',
      );
      expect(
        platform.source?.uri,
        contains('/files/education/catalog/kihon/1/video'),
      );
      await tester.tap(find.byTooltip(s.playPause));
      await tester.pump();
      expect(platform.played, true);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        find.text('Техника передвижений и базовые стойки'),
        findsOneWidget,
      );
      expect(find.text(s.save), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'own work shows review only when reviewed, includes full category and scores, no writing actions',
    (tester) async {
      phone(tester, 393);
      for (final reviewed in [false, true]) {
        api.reviewed = reviewed;
        await tester.pumpWidget(
          app(
            EducationVideoScreen(
              key: ValueKey(reviewed),
              api: api,
              strings: s,
              video: api.row,
              workId: 1,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Тренер: Мартиросян Эдуард'), findsOneWidget);
        expect(find.text('HAYABUSA'), findsOneWidget);
        expect(
          find.text(reviewed ? s.educationReviewed : s.educationWaiting),
          findsOneWidget,
        );
        expect(
          find.text('Продолжать отработку стоек'),
          reviewed ? findsOneWidget : findsNothing,
        );
        expect(find.text('8.5'), reviewed ? findsOneWidget : findsNothing);
        expect(find.text('9'), reviewed ? findsOneWidget : findsNothing);
        expect(find.byType(TextField), findsNothing);
        expect(find.byType(FilledButton), findsNothing);
        expect(tester.takeException(), isNull);
        if (reviewed) await capture(tester, 'education-reviewed-work');
      }
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'pagination error keeps rows; refresh failure retries first page; stale search discarded',
    (tester) async {
      phone(tester, 393);
      await tester.pumpWidget(
        app(EducationScreen(api: api, strings: s, section: 'works')),
      );
      await tester.pumpAndSettle();
      api.failPage = 2;
      await tester.tap(find.text(s.loadMore));
      await tester.pumpAndSettle();
      expect(find.text('Саркисов Артём'), findsOneWidget);
      expect(find.text(s.educationLoadFailed), findsOneWidget);
      api.failPage = null;
      await tester.tap(find.text(s.retry));
      await tester.pumpAndSettle();
      expect(find.text('Бурмистров Илья'), findsOneWidget);
      api.failPage = 1;
      await tester.enterText(find.byType(TextField), 'нет');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.text(s.educationLoadFailed), findsOneWidget);
      api.failPage = null;
      await tester.tap(find.text(s.retry));
      await tester.pumpAndSettle();
      expect(api.queries.last['page'], '1');
      final stale = Completer<Map<String, dynamic>>();
      api.stale = stale;
      await tester.enterText(find.byType(TextField), 'old');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.enterText(find.byType(TextField), 'fresh');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      stale.complete({
        'data': [
          {'id': 100, 'title': 'STALE'},
        ],
        'meta': {'last_page': 1},
      });
      await tester.pumpAndSettle();
      expect(find.text('STALE'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'revoked work fails without exposing stale details, retry rechecks server',
    (tester) async {
      phone(tester, 393);
      api.failPage = 1;
      await tester.pumpWidget(
        app(
          EducationVideoScreen(api: api, strings: s, video: api.row, workId: 1),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(s.educationLoadFailed), findsOneWidget);
      expect(find.text('Саркисов Артём'), findsNothing);
      expect(platform.source, isNull);
      api.failPage = null;
      await tester.tap(find.text(s.retry));
      await tester.pumpAndSettle();
      expect(find.text('Саркисов Артём'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('RU EN long labels fit phones at larger text in both themes', (
    tester,
  ) async {
    for (final width in [360.0, 393.0, 430.0]) {
      api.accountRole = 'Student';
      api.accountId = 1;
      api.reviewed = false;
      phone(tester, width);
      for (final locale in [AppLocale.ru, AppLocale.en]) {
        for (final dark in [false, true]) {
          await tester.pumpWidget(
            app(
              EducationScreen(
                key: UniqueKey(),
                api: api,
                strings: AppStrings(locale),
                section: 'works',
              ),
              dark: dark,
              scale: 1.35,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(
            app(
              EducationVideoScreen(
                key: UniqueKey(),
                api: api,
                strings: AppStrings(locale),
                video: api.row,
                workId: 1,
              ),
              dark: dark,
              scale: 1.35,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (width == 393 && dark && locale == AppLocale.en) {
            await capture(tester, 'education-works-en');
          }
        }
      }
    }
  });
}

class EducationTestApi extends ApiClient {
  EducationTestApi(AuthSession session)
    : super(session: session, baseUrl: 'https://example.test/api/mobile');
  final queries = <Map<String, String?>>[];
  int? failPage;
  bool reviewed = true;
  Map<String, dynamic>? saved;
  Completer<Map<String, dynamic>>? stale;
  Map<String, dynamic> get row => {
    'id': 1,
    'category_id': 1,
    'price': '500.00',
    'is_payment': false,
    'can_edit': isStudent && !reviewed,
    'can_delete': isStudent && !reviewed,
    'can_pay': isStudent && !reviewed,
    'title': 'Саркисов Артём',
    'coach_name': 'Мартиросян Эдуард',
    'rank': '5 кю',
    'club': 'HAYABUSA',
    'category': 'Тайкёку соно сан: подробный разбор техники выполнения',
    'is_review': reviewed,
    'video_url': 'https://example.test/api/mobile/files/education/works/1',
    'review': {
      'description': 'Продолжать отработку стоек',
      'point': '8.5',
      'detail_point': '9',
      'recommendation': 'Регулярно повторять комплекс',
    },
  };
  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String?> query = const {},
  }) async {
    queries.add(query);
    if (path == '/education/works/1/payment') return {'payment': null};
    if (path == '/education/work-options') {
      return {
        'data': [
          {'id': 1, 'name': 'Ката', 'price': '500.00'},
        ],
      };
    }
    if (query['search'] == 'old') return stale!.future;
    final page = int.parse(query['page'] ?? '1');
    if (failPage == page) throw const ApiException('denied');
    if (path == '/education') {
      return {
        'data': [
          {'id': 'kihon'},
          {'id': 'works'},
        ],
      };
    }
    if (path == '/education/catalog/kihon') {
      return {
        'data': [
          {'id': 1, 'title': 'Основная техника'},
        ],
      };
    }
    if (path == '/education/catalog/kihon/1') {
      return {
        'data': [
          {
            'id': 1,
            'title': 'Техника передвижений и базовые стойки',
            'poster_url': null,
            'video_url': 'https://example.test/api/mobile/files/education/catalog/kihon/1/video',
          },
        ],
      };
    }
    if (path == '/education/works/1') return {'data': row};
    return {
      'data': [
        page == 1 ? row : {...row, 'id': 2, 'title': 'Бурмистров Илья'},
      ],
      'meta': {'last_page': 2},
    };
  }

  @override
  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic> body = const {},
    bool authenticated = true,
  }) async {
    saved = body;
    return {'data': row};
  }
}

class EducationVideoPlatform extends VideoPlayerPlatform {
  DataSource? source;
  int created = 0;
  bool played = false;
  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    source = options.dataSource;
    return ++created;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => Stream.value(
    VideoEvent(
      eventType: VideoEventType.initialized,
      duration: const Duration(seconds: 10),
      size: const Size(320, 180),
    ),
  );
  @override
  Future<void> dispose(int playerId) async {}
  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> play(int playerId) async {
    played = true;
  }

  @override
  Future<void> pause(int playerId) async {}
  @override
  Future<void> setVolume(int playerId, double volume) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;
  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const ColoredBox(color: Colors.black);
}
