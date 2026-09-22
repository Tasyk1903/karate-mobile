import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:karaterating_trainer/api/api_client.dart';
import 'package:karaterating_trainer/auth/auth_session.dart';
import 'package:karaterating_trainer/l10n/app_locale.dart';
import 'package:karaterating_trainer/l10n/staff_strings.dart';
import 'package:karaterating_trainer/navigation/coach_navigation.dart';
import 'package:karaterating_trainer/staff/staff_queue_screen.dart';
import 'package:karaterating_trainer/staff/judge_table_screen.dart';
import 'package:karaterating_trainer/staff/master_review_screen.dart';
import 'package:karaterating_trainer/staff/staff_profile_screen.dart';
import 'package:karaterating_trainer/theme/app_theme.dart';

void main() {
  setUpAll(() async {
    const font = String.fromEnvironment('SCREENSHOT_FONT');
    if (font.isNotEmpty) {
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      await (FontLoader('StaffScreenshotFont')..addFont(
            File(font).readAsBytes().then((b) => ByteData.sublistView(b)),
          ))
          .load();
    }
  });
  late _StaffApi api;
  const s = AppStrings(AppLocale.ru);
  final boundary = GlobalKey();
  late ValueNotifier<CoachNavItem> selected;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    api = _StaffApi(AuthSession(await SharedPreferences.getInstance()));
    selected = ValueNotifier(CoachNavItem.judging);
  });
  tearDown(() {
    api.close();
    selected.dispose();
  });
  Future<void> mount(
    WidgetTester tester,
    Widget child, {
    double width = 393,
    double scale = 1,
    bool dark = false,
  }) async {
    tester.view.reset();
    tester.view.physicalSize = Size(width, 852);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        theme: (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
          textTheme: (dark ? AppTheme.dark() : AppTheme.light()).textTheme
              .apply(
                fontFamily:
                    const String.fromEnvironment('SCREENSHOT_FONT').isEmpty
                    ? null
                    : 'StaffScreenshotFont',
              ),
        ),
        builder: (context, child) => CoachNavigation(
          selected: selected,
          onLogout: () async {},
          child: MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
        home: RepaintBoundary(key: boundary, child: child),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> screenshot(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('STAFF_SCREENSHOTS')) return;
    await tester.runAsync(() async {
      final image =
          await (boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('/tmp/kr-staff-$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  test('staff identities reject mixed roles and restrict fallback menus', () {
    expect(
      api.setIdentity({
        'id': 1,
        'roles': ['Judge'],
      }),
      true,
    );
    expect(api.bottomAvailable('feed'), false);
    expect(api.bottomAvailable('judging'), true);
    expect(api.menuAvailable('students'), false);
    expect(
      api.setIdentity({
        'id': 1,
        'roles': ['Coach', 'Judge'],
      }),
      false,
    );
    expect(
      api.setIdentity({
        'id': 1,
        'roles': ['Master'],
      }),
      true,
    );
    expect(api.bottomAvailable('reviews'), true);
    expect(api.bottomAvailable('judging'), false);
  });

  testWidgets(
    'judge pagination retries failed page and filters do not expose coaching menu',
    (tester) async {
      addTearDown(tester.view.reset);
      await mount(tester, StaffQueueScreen(api: api, strings: s));
      expect(find.text(s.feed), findsNothing);
      expect(find.text(s.masterReviews), findsNothing);
      await tester.tap(find.text(s.loadMore));
      await tester.pumpAndSettle();
      expect(find.text(s.retry), findsOneWidget);
      await tester.tap(find.text(s.retry));
      await tester.pumpAndSettle();
      expect(api.pages, [1, 2, 2]);
      expect(find.text('Вторая категория'), findsOneWidget);
      await screenshot(tester, 'judge-queue');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'judge edits only own score, preserves input on conflict and rebases explicitly',
    (tester) async {
      addTearDown(tester.view.reset);
      await mount(tester, JudgeTableScreen(api: api, strings: s, listId: 1));
      expect(find.textContaining('9.9'), findsNothing);
      await screenshot(tester, 'judge-table');
      await tester.tap(find.text('${s.ownScore}: 8.0'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '8,5');
      api.failScore = true;
      await tester.tap(find.text(s.save));
      await tester.pumpAndSettle();
      expect(find.text('8,5'), findsOneWidget);
      expect(find.text(s.scoreConflict), findsOneWidget);
      await tester.tap(find.text(s.refreshRecord));
      await tester.pumpAndSettle();
      expect(find.text('${s.ownScore}: 8.2'), findsOneWidget);
      await tester.tap(find.text(s.save));
      await tester.pumpAndSettle();
      expect(api.saved?['original_value'], '8.2');
      expect(api.saved?['value'], '8.5');
      expect(api.saved?['field'], 'judge1_score');
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('${s.ownScore}: 8.5'), findsOneWidget);
      await tester.tap(find.text(s.finalRound));
      await tester.pumpAndSettle();
      expect(api.rounds, ['pre', 'final']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'master saves draft, publishes, and explicitly confirms reopening',
    (tester) async {
      addTearDown(tester.view.reset);
      api.accountRole = 'Master';
      await mount(tester, MasterReviewScreen(api: api, strings: s, workId: 2));
      await screenshot(tester, 'master-review');
      await tester.enterText(find.byType(TextField).first, 'Новый разбор');
      await tester.scrollUntilVisible(
        find.text(s.saveDraft),
        250,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.ensureVisible(find.text(s.saveDraft));
      await tester.pumpAndSettle();
      await tester.tap(find.text(s.saveDraft));
      await tester.pumpAndSettle();
      expect(api.saved?['is_review'], false);
      expect(api.saved?['description'], 'Новый разбор');
      await tester.tap(find.text(s.publishReview));
      await tester.pumpAndSettle();
      expect(api.saved?['is_review'], true);
      await tester.tap(find.text(s.reopenReview));
      await tester.pumpAndSettle();
      expect(find.text(s.reopenQuestion), findsOneWidget);
      await tester.tap(find.text(s.confirm));
      await tester.pumpAndSettle();
      expect(api.saved?['confirmed'], true);
      expect(api.saved?['is_review'], false);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('staff screens fit small viewports in RU EN and both themes', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    for (final width in [360.0, 393.0, 430.0]) {
      for (final locale in AppLocale.values) {
        for (final role in ['Judge', 'Master']) {
          api.accountRole = role;
          final strings = AppStrings(locale);
          await tester.pumpWidget(const SizedBox());
          await mount(
            tester,
            StaffQueueScreen(api: api, strings: strings),
            width: width,
            scale: 1.6,
            dark: locale == AppLocale.en,
          );
          expect(
            tester.takeException(),
            isNull,
            reason: '$width $locale $role queue',
          );
          await tester.pumpWidget(const SizedBox());
          await mount(
            tester,
            StaffProfileScreen(api: api, strings: strings),
            width: width,
            scale: 1.6,
            dark: locale == AppLocale.en,
          );
          expect(
            tester.takeException(),
            isNull,
            reason: '$width $locale $role profile',
          );
          if (role == 'Master') {
            await tester.tap(find.byIcon(Icons.edit_outlined));
            await tester.pumpAndSettle();
            expect(find.text('Иванович'), findsOneWidget);
            expect(
              tester.takeException(),
              isNull,
              reason: '$width $locale Master editor',
            );
          }
        }
      }
    }
    await screenshot(tester, 'master-profile-edit');
  });

  testWidgets(
    'master profile keeps patronymic and controllers across failed and successful save',
    (tester) async {
      addTearDown(tester.view.reset);
      api.accountRole = 'Master';
      await mount(tester, StaffProfileScreen(api: api, strings: s));
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Новое имя');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(s.save),
        250,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.ensureVisible(find.text(s.save));
      await tester.pumpAndSettle();
      api.failProfile = true;
      await tester.tap(find.text(s.save));
      await tester.pumpAndSettle();
      expect(api.saved?['patronymic'], 'Иванович');
      expect(api.saved?['first_name'], 'Новое имя');
      await tester.ensureVisible(find.text(s.save));
      await tester.pumpAndSettle();
      await tester.tap(find.text(s.save));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(s.cancel));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}

class _StaffApi extends ApiClient {
  _StaffApi(AuthSession session) : super(session: session) {
    accountRole = 'Judge';
    accountId = 1;
  }
  final pages = <int>[];
  final rounds = <String>[];
  bool failedPage = false, failScore = false;
  bool failProfile = false;
  Map<String, dynamic>? saved;
  Map<String, dynamic> work = {
    'id': 2,
    'title': 'Александров Александр Александрович',
    'coach': 'Мартиросян Эдуард',
    'club': 'HAYABUSA',
    'category': 'Тайкёку соно сан: полный разбор техники',
    'rank': '9 кю',
    'is_review': false,
    'revision': 'revision',
    'video_url': null,
    'review': {
      'description': 'Черновик',
      'point': '',
      'detail_point': '',
      'recommendation': '',
    },
  };
  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String?> query = const {},
  }) async {
    if (path == '/judge/tables' || path == '/master/works') {
      final page = int.parse(query['page'] ?? '1');
      pages.add(page);
      if (page == 2 && !failedPage) {
        failedPage = true;
        throw const ApiException('Offline');
      }
      return {
        'data': [
          {
            'id': page,
            'title': page == 1
                ? 'Мальчики и девочки 10–11 лет: личная ката'
                : 'Вторая категория',
            'tournament': 'Первенство региона',
            'championship': 'Открытый чемпионат по карате',
            'tatami': 'A',
            'is_review': false,
          },
        ],
        'meta': {'current_page': page, 'last_page': 2},
      };
    }
    if (path.endsWith('/scores/10')) return {'score': '8.2'};
    if (path == '/judge/tables/1') {
      rounds.add(query['round'] ?? 'pre');
      return {
        'table': {
          'id': 1,
          'title': 'Мальчики 10–11 лет: ката',
          'championship': 'Открытый чемпионат',
          'tournament': 'Ката',
        },
        'field': 'judge1_score',
        'can_score': true,
        'reason': null,
        'data': [
          {
            'id': 10,
            'number': '12',
            'score': '8.0',
            'students': [
              {
                'id': 3,
                'name': 'Александров Александр Александрович',
                'coach': 'Тренер',
                'club': 'HAYABUSA',
                'rank': '9 кю',
              },
            ],
          },
        ],
        'meta': {'current_page': 1, 'last_page': 1},
      };
    }
    if (path == '/master/works/2') return {'data': work};
    if (path == '/staff/profile') {
      return {
        'data': {
          'id': 1,
          'name': 'Иванов Александр Иванович',
          'email': 'master@example.test',
          'role': accountRole,
          'position': 'judge1_score',
          'capabilities': {
            'edit': isMaster,
            'weight': true,
            'delete_account': true,
          },
          if (isMaster)
            'fields': {
              'first_name': 'Александр',
              'last_name': 'Иванов',
              'patronymic': 'Иванович',
              'gender': 'm',
              'rang': '1 дан',
              'birthday': '1986-01-01',
            },
          'documents': <String, String?>{},
        },
      };
    }
    throw StateError('Unexpected GET $path');
  }

  @override
  Future<Map<String, dynamic>> postMultipartFiles(
    String path, {
    required Map<String, String> fields,
    required Map<String, File> files,
  }) async {
    saved = fields;
    if (failProfile) {
      failProfile = false;
      throw const ApiException('Offline');
    }
    return getJson(path);
  }

  @override
  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic> body = const {},
    bool authenticated = true,
  }) async {
    saved = body;
    if (path.endsWith('/scores/10')) {
      if (failScore) {
        failScore = false;
        throw const ApiException('Conflict', statusCode: 409);
      }
      return {'saved': true};
    }
    if (path == '/master/works/2') {
      work = {
        ...work,
        'is_review': body['is_review'],
        'review': {...body},
        'revision': 'next',
      };
      return {'data': work};
    }
    throw StateError('Unexpected POST $path');
  }
}
