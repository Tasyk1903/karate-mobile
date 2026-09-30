import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:karaterating_trainer/api/api_client.dart';
import 'package:karaterating_trainer/auth/auth_session.dart';
import 'package:karaterating_trainer/l10n/app_locale.dart';
import 'package:karaterating_trainer/navigation/coach_route_observer.dart';
import 'package:karaterating_trainer/notifications/notification_button.dart';
import 'package:karaterating_trainer/notifications/notification_counter.dart';
import 'package:karaterating_trainer/notifications/notification_message.dart';
import 'package:karaterating_trainer/notifications/notifications_screen.dart';
import 'package:karaterating_trainer/rating/rating_screen.dart';
import 'package:karaterating_trainer/theme/app_theme.dart';

void main() => notificationRatingTests();
void notificationRatingTests({Future<void> Function(String)? screenshot}) {
  late _Api api;
  const fontPath = String.fromEnvironment('SCREENSHOT_FONT');
  setUpAll(() async {
    if (fontPath.isNotEmpty) {
      await (FontLoader('TestFont')..addFont(
            File(fontPath)
                .readAsBytes()
                .then((bytes) => ByteData.sublistView(bytes)),
          ))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });
  ThemeData theme(bool dark) {
    final base = dark ? AppTheme.dark() : AppTheme.light();
    return fontPath.isEmpty
        ? base
        : base.copyWith(
            textTheme: base.textTheme.apply(fontFamily: 'TestFont'),
          );
  }

  const s = AppStrings(AppLocale.ru);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    api = _Api(AuthSession(await SharedPreferences.getInstance()));
  });
  tearDown(() => api.close());
  Future<void> capture(WidgetTester tester, String name) async {
    if (const bool.fromEnvironment('SAVE_SCREENSHOTS')) {
      await tester.pump();
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('capture')),
      );
      await tester.runAsync(() async {
        final rendered = await boundary.toImage(pixelRatio: 2);
        final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/auth-screenshots/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        rendered.dispose();
      });
    }
    await screenshot?.call(name);
  }

  Widget app(Widget child, {bool dark = false, double textScale = 1}) =>
      MaterialApp(
        theme: theme(dark),
        navigatorObservers: [coachRouteObserver],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: RepaintBoundary(key: const ValueKey('capture'), child: child!),
        ),
        home: child,
      );

  testWidgets(
    'notifications paginate and only successful marks update rows and shared badge',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        app(
          Scaffold(
            body: NotificationButton(api: api, strings: s),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(NotificationCounter.forApi(api).value, 42);
      expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isTrue);
      await tester.tap(find.byTooltip(s.notifications));
      await tester.pumpAndSettle();
      expect(api.pages, [1]);
      api.failMark = true;
      await tester.tap(find.text(s.markAsRead).first);
      await tester.pumpAndSettle();
      expect(find.text('mark failed'), findsOneWidget);
      expect(NotificationCounter.forApi(api).value, 42);
      expect(api.read, isEmpty);
      api.failMark = false;
      await tester.tap(find.text(s.markAsRead).first);
      await tester.pumpAndSettle();
      expect(api.read, contains(42));
      expect(NotificationCounter.forApi(api).value, 41);
      expect(api.pages, [1]);
      for (var i = 0; i < 14 && !api.pages.contains(3); i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -1600));
        await tester.pumpAndSettle();
      }
      expect(api.pages, containsAll([1, 2, 3]));
      await capture(tester, 'notifications-history');
      api.failMark = true;
      await tester.tap(find.byTooltip(s.markAllAsRead));
      await tester.pumpAndSettle();
      expect(NotificationCounter.forApi(api).value, 41);
      api.failMark = false;
      await tester.tap(find.byTooltip(s.markAllAsRead));
      await tester.pumpAndSettle();
      expect(NotificationCounter.forApi(api).value, 0);
      expect(find.text(s.markAsRead), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'notification pagination failure preserves history and retries same page',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      api.failPage = 2;
      await tester.pumpWidget(app(NotificationsScreen(api: api, strings: s)));
      await tester.pumpAndSettle();
      for (var i = 0; i < 10 && !api.pages.contains(2); i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -1400));
        await tester.pumpAndSettle();
      }
      await tester.scrollUntilVisible(find.text(s.retry), 400);
      expect(find.text('page failed'), findsOneWidget);
      api.failPage = null;
      await tester.tap(find.text(s.retry));
      await tester.pumpAndSettle();
      expect(api.pages.where((p) => p == 2).length, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'notification links keep caption and launch safe URI without bearer',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      Uri? opened;
      await tester.pumpWidget(
        app(
          Scaffold(
            body: NotificationMessage(
              api: api,
              strings: s,
              runs: const [
                {'text': 'Текст — "А"\n', 'href': null},
                {
                  'text': 'Подробнее',
                  'href': 'https://example.test/page?a=1&b=2',
                },
              ],
              openLink: (uri) async {
                opened = uri;
                return true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final rich = tester.widget<Text>(find.byType(Text).first).textSpan!;
      final link = (rich as TextSpan).children!.last as TextSpan;
      (link.recognizer as dynamic).onTap();
      await tester.pumpAndSettle();
      expect(opened.toString(), 'https://example.test/page?a=1&b=2');
      for (final href in [
        'javascript:alert(1)',
        'data:text/html,test',
        '//evil.test',
        'https://user:pass@example.test',
        '/api/mobile/auth/logout',
      ]) {
        expect(notificationLink(api, href), isNull);
      }
      expect(
        notificationLink(api, '/panel/documents/7')?.path,
        '/panel/documents/7',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'rating failure never invents athletes; retry and organization filter change content',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      api.failRating = true;
      await tester.pumpWidget(app(RatingScreen(api: api, strings: s)));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text(s.retry), 250);
      expect(find.text('rating failed'), findsOneWidget);
      expect(find.textContaining('Симонов'), findsNothing);
      expect(find.textContaining('Ли Сергей'), findsNothing);
      await capture(tester, 'rating-error');
      api.failRating = false;
      await tester.tap(find.text(s.retry));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text(s.organization), -250);
      await tester.tap(find.text(s.organization));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_Api.longOrganization));
      await tester.pumpAndSettle();
      expect(api.ratingQueries.last['organization_id'], '9');
      await tester.scrollUntilVisible(
        find.text('Selected organization category'),
        250,
      );
      expect(find.text('Selected organization category'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'coach photos are used in leader card and full ranking with error fallback',
    (tester) async {
      tester.view.physicalSize = const Size(393, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      api.withCoaches = true;
      await tester.pumpWidget(app(RatingScreen(api: api, strings: s)));
      await tester.pumpAndSettle();
      final photos = find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is NetworkImage &&
            (widget.image as NetworkImage).url ==
                'https://example.test/coach.jpg',
      );
      expect(photos, findsOneWidget);
      await tester.scrollUntilVisible(find.text(s.showFullCoachRating), 200);
      await tester.tap(find.text(s.showFullCoachRating));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: find.byType(BottomSheet), matching: photos),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'rating defaults to categories and switches modes without a selector',
    (tester) async {
      await tester.pumpWidget(app(RatingScreen(api: api, strings: s)));
      await tester.pumpAndSettle();
      expect(api.ratingQueries.last['view_mode'], 'all');
      expect(
        tester
            .widget<SegmentedButton<String>>(
              find.byType(SegmentedButton<String>),
            )
            .selected,
        {'all'},
      );
      expect(find.text(s.ratingType), findsNothing);
      await tester.tap(find.text(s.ratingP4p));
      await tester.pumpAndSettle();
      expect(api.ratingQueries.last['view_mode'], 'p4p');
      expect(api.ratingQueries.last['weight_category'], isNull);
      expect(find.byType(BottomSheet), findsNothing);
      await tester.tap(find.text(s.ratingCategories));
      await tester.pumpAndSettle();
      expect(api.ratingQueries.last['view_mode'], 'all');
      await tester.tap(find.text(s.kata).first);
      await tester.pumpAndSettle();
      expect(find.byType(SegmentedButton<String>), findsNothing);
      await tester.tap(find.text(s.kumite).first);
      await tester.pumpAndSettle();
      expect(api.ratingQueries.last['view_mode'], 'all');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'rating clears dependent filters and ignores stale discipline response',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(app(RatingScreen(api: api, strings: s)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(s.weight).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('30 kg'));
      await tester.pumpAndSettle();
      expect(api.ratingQueries.last['weight_category'], '30');
      await tester.tap(find.text(s.age).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('10-11'));
      await tester.pumpAndSettle();
      expect(api.ratingQueries.last['weight_category'], isNull);
      api.holdRating = Completer<Map<String, dynamic>>();
      await tester.tap(find.text(s.kata).first);
      await tester.pump();
      await tester.tap(find.text(s.kumite).first);
      await tester.pumpAndSettle();
      expect(api.ratingQueries.last['weight_category'], isNull);
      api.held!.complete(api.ratingData(label: 'Stale category'));
      await tester.pumpAndSettle();
      expect(find.text('Stale category'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'rating filters retain long labels in RU EN at phone widths and larger text',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      for (final width in [360.0, 393.0, 430.0]) {
        for (final locale in [AppLocale.ru, AppLocale.en]) {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          final strings = AppStrings(locale);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpWidget(
            app(
              RatingScreen(api: api, strings: strings),
              dark: locale == AppLocale.en,
              textScale: 1.35,
            ),
          );
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(find.text(strings.organization), 200);
          expect(
            tester.getTopLeft(find.text(strings.region).first).dy,
            closeTo(
              tester.getTopLeft(find.text(strings.organization).first).dy,
              1,
            ),
          );
          await tester.tap(find.text(strings.organization));
          await tester.pumpAndSettle();
          await tester.tap(find.text(_Api.longOrganization));
          await tester.pumpAndSettle();
          expect(find.text(_Api.longOrganization), findsOneWidget);
          expect(tester.takeException(), isNull, reason: '$width $locale');
          if (width == 393) {
            await capture(tester, 'rating-filters-${locale.name}');
          }
        }
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );
}

class _Api extends ApiClient {
  _Api(AuthSession session) : super(session: session);
  final pages = <int>[];
  final read = <int>{};
  bool failMark = false, failRating = false;
  bool withCoaches = false;
  int? failPage;
  Completer<Map<String, dynamic>>? holdRating, held;
  final ratingQueries = <Map<String, String?>>[];
  static const longOrganization =
      'Международная организация киокушин карате и спортивного развития';

  Map<String, dynamic> ratingData({String? label}) => {
    'groups': label == null
        ? []
        : [
            {
              'id': 1,
              'title': label,
              'gender': '',
              'items': [
                {
                  'name': 'Test Athlete',
                  'coach': 'Coach',
                  'club': 'Club',
                  'points': 5,
                },
              ],
            },
          ],
    'trainer_ranking': {
      if (withCoaches) 'leader': coach,
      'items': withCoaches ? [coach] : [],
    },
    'filter_options': {
      'organizations': {'9': longOrganization},
      'age_bands': {'10-11': '10-11'},
      'weights': {'30': '30 kg'},
      'regions': {'4': 'Region'},
      'view_modes': {'all': 'All', 'p4p': 'P4P'},
    },
  };
  Map<String, dynamic> get coach => {
    'name': 'Test Coach',
    'club': 'Test Club',
    'points': 15,
    'avatar_url': 'https://example.test/coach.jpg',
  };
  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String?> query = const {},
  }) async {
    if (path == '/notifications/unread') return {'unread': 42 - read.length};
    if (path == '/notifications') {
      final page = int.parse(query['page'] ?? '1');
      pages.add(page);
      if (page == failPage) throw const ApiException('page failed');
      return {
        'data': List.generate(page == 3 ? 2 : 20, (i) {
          final id = 42 - (page - 1) * 20 - i;
          return {
            'id': id,
            'is_read': read.contains(id),
            'content': [
              {
                'text':
                    'Сообщение администратора $id. Текст уведомления с подробностями.',
                'href': null,
              },
            ],
          };
        }),
        'meta': {'last_page': 3, 'unread': 42 - read.length},
      };
    }
    if (path == '/rating') {
      ratingQueries.add(Map.of(query));
      if (holdRating != null) {
        held = holdRating;
        holdRating = null;
        return held!.future;
      }
      if (failRating) throw const ApiException('rating failed');
      return ratingData(
        label: query['organization_id'] == '9'
            ? 'Selected organization category'
            : null,
      );
    }
    return {};
  }

  @override
  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic> body = const {},
    bool authenticated = true,
  }) async {
    if (failMark) throw const ApiException('mark failed');
    if (path == '/notifications/read-all') {
      read.addAll(List.generate(42, (i) => i + 1));
    } else {
      read.add(int.parse(path.split('/')[2]));
    }
    return {'unread': 42 - read.length};
  }
}
