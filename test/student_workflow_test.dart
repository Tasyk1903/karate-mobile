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
import 'package:karaterating_trainer/students/student_profile_screen.dart';
import 'package:karaterating_trainer/students/student_invitations_screen.dart';
import 'package:karaterating_trainer/students/student_history_list.dart';
import 'package:karaterating_trainer/students/students_screen.dart';
import 'package:karaterating_trainer/students/student_models.dart';
import 'package:karaterating_trainer/widgets/rank_belt.dart';
import 'package:karaterating_trainer/theme/app_theme.dart';

void main() => studentWorkflowTests();

void studentWorkflowTests({Future<void> Function(String)? screenshot}) {
  late _StudentApi api;
  const s = AppStrings(AppLocale.ru);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    api = _StudentApi(AuthSession(await SharedPreferences.getInstance()));
  });
  tearDown(() => api.close());
  setUpAll(() async {
    const font = String.fromEnvironment('SCREENSHOT_FONT');
    if (font.isNotEmpty) {
      await (FontLoader(
        'StudentTestFont',
      )..addFont(File(font).readAsBytes().then(ByteData.sublistView))).load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      await (FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(
            rootBundle.load(
              'packages/cupertino_icons/assets/CupertinoIcons.ttf',
            ),
          ))
          .load();
    }
  });
  Future<void> mount(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light(), home: child));
    await tester.pumpAndSettle();
  }

  testWidgets('student views fit phone widths locales themes and large text', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in [360.0, 393.0, 430.0]) {
      for (final locale in AppLocale.values) {
        for (final dark in [false, true]) {
          final strings = AppStrings(locale);
          for (final view in ['expanded', 'compact', 'profile', 'record']) {
            tester.view.physicalSize = Size(width, 852);
            tester.view.devicePixelRatio = 1;
            await tester.pumpWidget(const SizedBox.shrink());
            final base = dark ? AppTheme.dark() : AppTheme.light();
            await tester.pumpWidget(
              MaterialApp(
                theme: const String.fromEnvironment('SCREENSHOT_FONT').isEmpty
                    ? base
                    : base.copyWith(
                        textTheme: base.textTheme.apply(
                          fontFamily: 'StudentTestFont',
                        ),
                      ),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(1.35)),
                  child: RepaintBoundary(
                    key: const ValueKey('student-capture'),
                    child: child!,
                  ),
                ),
                home: view == 'profile'
                    ? StudentProfileScreen(
                        api: api,
                        strings: strings,
                        studentId: 1,
                      )
                    : view == 'record'
                    ? StudentFightHistoryScreen(
                        api: api,
                        strings: strings,
                        studentId: 1,
                        initialKind: 'wins',
                      )
                    : StudentsScreen(api: api, strings: strings),
              ),
            );
            await tester.pumpAndSettle();
            if (view == 'expanded') {
              await tester.tap(find.text(strings.studentListExpanded));
              await tester.pumpAndSettle();
            }
            expect(
              tester.takeException(),
              isNull,
              reason: '$view $width $locale $dark',
            );
            if (const bool.fromEnvironment('SAVE_SCREENSHOTS') &&
                width == 393 &&
                locale == AppLocale.ru) {
              final boundary = tester.renderObject<RenderRepaintBoundary>(
                find.byKey(const ValueKey('student-capture')),
              );
              await tester.runAsync(() async {
                final image = await boundary.toImage(pixelRatio: 2);
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                final file = File(
                  'build/auth-screenshots/student-$view-${dark ? 'dark' : 'light'}.png',
                );
                await file.parent.create(recursive: true);
                await file.writeAsBytes(bytes!.buffer.asUint8List());
                image.dispose();
              });
            }
          }
        }
      }
    }
  });

  testWidgets(
    'student list changes density without reloading and opens profile',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await mount(tester, StudentsScreen(api: api, strings: s));
      expect(find.textContaining('Клуб тренера'), findsNothing);
      await tester.tap(find.text(s.studentListExpanded));
      await tester.pumpAndSettle();
      expect(find.textContaining('Клуб тренера'), findsOneWidget);
      final requests = api.listRequests;
      await tester.tap(find.text(s.studentListCompact));
      await tester.pumpAndSettle();
      expect(find.textContaining('Клуб тренера'), findsNothing);
      expect(api.listRequests, requests);
      await tester.tap(find.text('Оченьдлиннаяфамилия Александр'));
      await tester.pumpAndSettle();
      expect(find.byType(StudentProfileScreen), findsOneWidget);
      expect(find.text(s.birthDate), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'record uses a full page and changes wins losses with independent pagination',
    (tester) async {
      await mount(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showStudentHistory(context, api, s, 1, 'wins', s.wins),
            child: const Text('Open record'),
          ),
        ),
      );
      await tester.tap(find.text('Open record'));
      await tester.pumpAndSettle();
      expect(find.byType(StudentFightHistoryScreen), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      await tester.tap(find.text(s.moreRecords));
      await tester.pumpAndSettle();
      await tester.tap(find.text(s.losses));
      await tester.pumpAndSettle();
      expect(api.historyKinds, ['wins', 'wins', 'losses']);
      expect(api.pages, ['1', '2', '1']);
      expect(find.textContaining('Константинович 2'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('belt has no decorative stripe and renders all dan stripes', (
    tester,
  ) async {
    final belt = StudentBelt.fromJson({'color': '#FFFFFF', 'stripes': []});
    expect(belt.color, Colors.white);
    await mount(
      tester,
      Center(
        child: RankBelt(color: belt.color, stripes: belt.stripes, width: 42),
      ),
    );
    expect(find.byType(Positioned), findsNothing);
    await mount(
      tester,
      Center(
        child: RankBelt(
          color: Colors.black,
          stripes: List.filled(10, const Color(0xFFFFD700)),
          width: 42,
        ),
      ),
    );
    expect(find.byType(Positioned), findsNWidgets(10));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'student private error and tournament public summary never expose editor',
    (tester) async {
      api.foreign = true;
      await mount(
        tester,
        StudentProfileScreen(api: api, strings: s, studentId: 1),
      );
      expect(find.text(s.retry), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await mount(
        tester,
        StudentProfileScreen(
          api: api,
          strings: s,
          studentId: 1,
          tournamentId: 10,
          championshipId: 20,
        ),
      );
      expect(find.byIcon(Icons.edit_rounded), findsNothing);
      expect(find.text(s.documents), findsNothing);
      await screenshot?.call('student-public');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'student editor omits locked fields and explicitly removes saved document',
    (tester) async {
      await mount(
        tester,
        StudentProfileScreen(api: api, strings: s, studentId: 1),
      );
      await screenshot?.call('student-private');
      await tester.tap(find.byIcon(Icons.edit_rounded));
      await tester.pumpAndSettle();
      final birthday = find.byWidgetPredicate(
        (w) => w is TextFormField && w.controller?.text == '02.01.2015',
      );
      expect(tester.widget<TextFormField>(birthday).enabled, false);
      await tester.scrollUntilVisible(
        find.byTooltip(s.delete).first,
        300,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .last,
      );
      await tester.ensureVisible(find.byTooltip(s.delete).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(s.delete).first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, s.delete));
      await tester.pumpAndSettle();
      expect(find.text(s.documentRemoved), findsOneWidget);
      await screenshot?.call('student-document-removal');
      await tester.scrollUntilVisible(
        find.text(s.save),
        250,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .last,
      );
      await tester.ensureVisible(find.text(s.save));
      await tester.pumpAndSettle();
      await tester.tap(find.text(s.save));
      await tester.pumpAndSettle();
      expect(api.saved?['remove_documents[0]'], 'passport');
      expect(api.saved?.containsKey('birthday'), false);
      expect(api.saved?.containsKey('rang'), false);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'self editor sends identity and preserves patronymic without locked weight or rank',
    (tester) async {
      api.accountRole = 'Student';
      api.accountId = 1;
      await mount(
        tester,
        StudentProfileScreen(
          api: api,
          strings: s,
          studentId: 1,
          ownProfile: true,
        ),
      );
      await tester.tap(find.byIcon(Icons.edit_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Александрович'), findsOneWidget);
      final weight = find.byWidgetPredicate(
        (w) => w is TextFormField && w.controller?.text == '35',
      );
      expect(tester.widget<TextFormField>(weight).enabled, false);
      await tester.scrollUntilVisible(
        find.text(s.save),
        300,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .last,
      );
      await tester.ensureVisible(find.text(s.save));
      await tester.pumpAndSettle();
      await tester.tap(find.text(s.save));
      await tester.pumpAndSettle();
      expect(api.saved?['first_name'], 'Александр');
      expect(api.saved?['patronymic'], 'Александрович');
      expect(api.saved?['gender'], 'm');
      expect(api.saved?.containsKey('weight'), false);
      expect(api.saved?.containsKey('rang'), false);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'invitation email outcomes and pending removal update immediately',
    (tester) async {
      await mount(tester, StudentInvitationsScreen(api: api, strings: s));
      expect(find.text('KR-CTESTCODE1234'), findsOneWidget);
      await tester.tap(find.byTooltip(s.copyCoachCode));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'new@example.test, invalid',
      );
      await tester.tap(find.text(s.sendInvitations));
      await tester.pumpAndSettle();
      expect(api.sent, ['new@example.test', 'invalid']);
      expect(find.text(s.invitationResult('invalid_email')), findsOneWidget);
      await screenshot?.call('student-invitations');
      await tester.ensureVisible(find.byTooltip(s.delete));
      await tester.tap(find.byTooltip(s.delete));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, s.delete));
      await tester.pumpAndSettle();
      expect(find.text('${s.pendingInvitations}: 0'), findsOneWidget);
      expect(api.deleted, true);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'fight history loads later pages and keeps complete opponent names',
    (tester) async {
      await mount(
        tester,
        Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                StudentHistoryList(
                  api: api,
                  strings: s,
                  studentId: 1,
                  kind: 'wins',
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.text(s.moreRecords));
      await tester.pumpAndSettle();
      expect(
        find.text('Оченьдлиннаяфамилия Александр Константинович 2'),
        findsOneWidget,
      );
      expect(api.pages, ['1', '2']);
      expect(find.text(s.moreRecords), findsNothing);
      await screenshot?.call('student-fight-history');
      expect(tester.takeException(), isNull);
    },
  );
}

class _StudentApi extends ApiClient {
  _StudentApi(AuthSession session) : super(session: session);
  bool foreign = false, deleted = false;
  Map<String, String>? saved;
  List? sent;
  final pages = <String>[];
  final historyKinds = <String?>[];
  int listRequests = 0;
  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String?> query = const {},
  }) async {
    if (path == '/notifications/unread') return {'unread': 0};
    if (path == '/students') {
      listRequests++;
      return {
        'data': [
          {
            'id': 1,
            'full_name': 'Оченьдлиннаяфамилия Александр',
            'club': 'Клуб тренера',
            'age_label': '11 лет',
            'rang': '9 кю',
            'documents_ok': true,
            'belt': {
              'color': '#FF7F00',
              'stripes': ['#0000FF'],
            },
          },
        ],
        'meta': {'current_page': 1, 'last_page': 1},
      };
    }
    if (path == '/student-invitations') {
      return {
        'code': 'KR-CTESTCODE1234',
        'data': deleted
            ? []
            : [
                {'id': 1, 'email': 'new@example.test'},
              ],
        'meta': {'current_page': 1, 'last_page': 1, 'total': deleted ? 0 : 1},
      };
    }
    if (path.endsWith('/history')) {
      historyKinds.add(query['kind']);
      pages.add(query['page']!);
      return {
        'meta': {
          'current_page': int.parse(query['page']!),
          'last_page': 2,
          'total': 2,
        },
        'data': [
          {
            'id': int.parse(query['page']!),
            'opponent': {
              'full_name':
                  'Оченьдлиннаяфамилия Александр Константинович ${query['page']}',
              'age_at_fight': '11 лет',
              'coach_name': 'Тренер Полное Имя',
              'club': 'Название клуба без обрезания',
            },
            'tournament': {'name': 'Чемпионат длинное название турнира'},
            'pool': 'Мальчики 10–11 лет, 35 кг',
            'fight_date': '08.09.2026',
          },
        ],
      };
    }
    if (path == '/students/1' && foreign) {
      throw const ApiException('Access denied', statusCode: 403);
    }
    if (path == '/students/1' || path == '/students/1/public') {
      return {
        'public_only': foreign,
        'student': {
          'id': 1,
          'full_name': 'Оченьдлиннаяфамилия Александр',
          'first_name': 'Александр',
          'last_name': 'Оченьдлиннаяфамилия',
          'patronymic': 'Александрович',
          'gender': 'm',
          'club': 'Клуб тренера',
          'coach_name': 'Полное Имя Тренера',
          'birthday': foreign ? null : '02.01.2015',
          'weight': 35,
          'height': 150,
          'rang': '5 кю',
          'belt': {
            'label_key': 'yellowBelt',
            'color': '#FFD700',
            'accent': '#00FF00',
            'stripes': ['#00FF00'],
            'progress': 60,
          },
          'age_label': '11 лет',
          'gender_label': 'Мужской',
          'capabilities': {
            'edit': !foreign,
            'detach': !foreign,
            'birthday': false,
            'rang': false,
          },
        },
        'rating': {
          'record': {'wins': 115, 'losses': 23, 'total': 138},
        },
        'documents': {
          'items': [
            {
              'key': 'passport',
              'field': 'passport',
              'included': true,
              'ok': false,
              'confirmed': false,
              'issue_key': 'documentIssuePassport',
              'file_url': '/api/mobile/test-document',
            },
          ],
        },
      };
    }
    throw StateError(path);
  }

  @override
  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic> body = const {},
    bool authenticated = true,
  }) async {
    sent = body['emails'] as List?;
    return {
      'results': [
        {'email': 'new@example.test', 'status': 'queued'},
        {'email': 'invalid', 'status': 'invalid_email'},
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> deleteJson(String path) async {
    deleted = true;
    return {};
  }

  @override
  Future<Map<String, dynamic>> postMultipartFiles(
    String path, {
    required Map<String, String> fields,
    required Map<String, File> files,
  }) async {
    saved = fields;
    return {};
  }
}
