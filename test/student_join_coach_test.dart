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
import 'package:karaterating_trainer/students/student_join_coach_screen.dart';
import 'package:karaterating_trainer/students/student_profile_screen.dart';
import 'package:karaterating_trainer/theme/app_theme.dart';

void main() {
  const s = AppStrings(AppLocale.ru);
  const font = String.fromEnvironment('SCREENSHOT_FONT');
  late _JoinApi api;
  final boundary = GlobalKey();
  setUpAll(() async {
    if (font.isNotEmpty) {
      await (FontLoader(
        'JoinScreenshot',
      )..addFont(File(font).readAsBytes().then(ByteData.sublistView))).load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    api = _JoinApi(AuthSession(await SharedPreferences.getInstance()))
      ..setIdentity({
        'id': 526,
        'roles': ['Student'],
      });
  });
  tearDown(() => api.close());

  testWidgets(
    'join is self-only, previews coach, preserves input on error, confirms and refreshes profile',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: StudentProfileScreen(
            strings: s,
            api: api,
            studentId: 526,
            ownProfile: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text(s.joinCoach), 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text(s.joinCoach));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'KR-C123');
      await tester.pump();
      await tester.tap(find.text(s.findCoach));
      await tester.pumpAndSettle();
      expect(find.text(_JoinApi.name), findsOneWidget);
      expect(find.text(_JoinApi.club), findsOneWidget);
      expect(api.joinCalls, 0);
      api.failJoin = true;
      await tester.tap(find.text(s.confirmJoinCoach));
      await tester.pumpAndSettle();
      expect(find.text('Temporary failure'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'KR-C123',
      );
      expect(find.text(_JoinApi.name), findsOneWidget);
      api.failJoin = false;
      await tester.tap(find.text(s.confirmJoinCoach));
      await tester.pumpAndSettle();
      expect(api.sent, {
        'coach_code': 'KR-C123',
        'coach_id': 42,
        'confirmed': true,
      });
      expect(find.byType(StudentJoinCoachScreen), findsNothing);
      expect(find.text(s.joinCoach), findsNothing);
      expect(find.text(s.coachJoined), findsOneWidget);
      expect(api.menuAvailable('exams'), true);
      expect(api.profileReads, 2);
      expect(api.accountId, 526);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('code edits and membership conflict invalidate preview', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StudentJoinCoachScreen(strings: s, api: api),
      ),
    );
    await tester.enterText(find.byType(TextField), 'first');
    await tester.pump();
    await tester.tap(find.text(s.findCoach));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'second');
    await tester.pump();
    expect(find.text(s.confirmJoinCoach), findsNothing);
    await tester.tap(find.text(s.findCoach));
    await tester.pumpAndSettle();
    api.conflict = true;
    await tester.tap(find.text(s.confirmJoinCoach));
    await tester.pumpAndSettle();
    expect(find.text(s.confirmJoinCoach), findsNothing);
    expect(find.text('Already attached'), findsOneWidget);
    expect(api.joined, false);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'second',
    );
  });

  testWidgets(
    'profile hides action without capability and on another student',
    (tester) async {
      for (final own in [true, false]) {
        api.joined = own;
        await tester.pumpWidget(
          MaterialApp(
            home: StudentProfileScreen(
              key: ValueKey(own),
              strings: s,
              api: api,
              studentId: 526,
              ownProfile: own,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(s.joinCoach), findsNothing);
      }
    },
  );

  testWidgets(
    'confirmation fits mobile widths, both languages/themes and large text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final locale in AppLocale.values) {
        final strings = AppStrings(locale);
        for (final dark in [false, true]) {
          for (final width in [360.0, 393.0, 430.0]) {
            for (final scale in [1.0, 2.0]) {
              tester.view.physicalSize = Size(width, 852);
              final theme = dark ? AppTheme.dark() : AppTheme.light();
              await tester.pumpWidget(const SizedBox());
              await tester.pumpWidget(
                MaterialApp(
                  theme: font.isEmpty
                      ? theme
                      : theme.copyWith(
                          textTheme: theme.textTheme.apply(
                            fontFamily: 'JoinScreenshot',
                          ),
                        ),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                  home: RepaintBoundary(
                    key: boundary,
                    child: StudentJoinCoachScreen(strings: strings, api: api),
                  ),
                ),
              );
              await tester.enterText(find.byType(TextField), 'KR-C123');
              await tester.pump();
              await tester.tap(find.text(strings.findCoach));
              await tester.pumpAndSettle();
              await tester.scrollUntilVisible(find.text(strings.confirmJoinCoach), 150, scrollable: find.byType(Scrollable).last);
              await tester.pumpAndSettle();
              expect(find.text(_JoinApi.name), findsOneWidget);
              expect(
                tester.takeException(),
                isNull,
                reason: '$locale $dark $width $scale',
              );
              if (font.isNotEmpty && width == 393 && scale == 1) {
                await tester.runAsync(() async {
                  final image =
                      await (boundary.currentContext!.findRenderObject()
                              as RenderRepaintBoundary)
                          .toImage();
                  final bytes = await image.toByteData(
                    format: ui.ImageByteFormat.png,
                  );
                  await File('/tmp/kr-join-coach-${locale.name}-$dark.png')
                      .writeAsBytes(bytes!.buffer.asUint8List());
                  image.dispose();
                });
              }
            }
          }
        }
      }
    },
  );
}

class _JoinApi extends ApiClient {
  _JoinApi(AuthSession session) : super(session: session);
  static const name = 'Константинопольский Александр Александрович';
  static const club = 'Международный спортивный клуб единоборств';
  bool joined = false, failJoin = false, conflict = false;
  int joinCalls = 0, profileReads = 0;
  Map<String, dynamic>? sent;

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String?> query = const {},
  }) async {
    if (path == '/students/526') {
      profileReads++;
      return {
        'student': {
          'id': 526,
          'full_name': 'Александр Иванов',
          'coach_name': joined ? name : null,
          'club': joined ? club : null,
          'capabilities': {'join_coach': !joined},
        },
        'rating': <String, dynamic>{},
        'documents': <String, dynamic>{},
      };
    }
    if (path == '/notifications/unread') return {'unread': 0};
    throw StateError(path);
  }

  @override
  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic> body = const {},
    bool authenticated = true,
  }) async {
    if (path == '/account/coach/preview') {
      return {
        'coach': {'id': 42, 'name': name, 'club': club},
      };
    }
    if (path == '/account/coach/join') {
      joinCalls++;
      sent = body;
      if (failJoin) {
        throw const ApiException('Temporary failure', statusCode: 503);
      }
      if (conflict) {
        throw const ApiException('Already attached', statusCode: 409);
      }
      joined = true;
      return {
        'joined': true,
        'user': {
          'id': 526,
          'roles': ['Student'],
          'navigation': {
            'menu': ['exams'],
            'bottom': ['rating', 'feed', 'profile'],
          },
        },
      };
    }
    throw StateError(path);
  }
}
