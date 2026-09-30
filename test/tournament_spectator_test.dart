import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:karaterating_trainer/api/api_client.dart';
import 'package:karaterating_trainer/auth/auth_session.dart';
import 'package:karaterating_trainer/l10n/app_locale.dart';
import 'package:karaterating_trainer/theme/app_theme.dart';
import 'package:karaterating_trainer/tournaments/tournament_models.dart';
import 'package:karaterating_trainer/tournaments/tournament_bracket_screen.dart';
import 'package:karaterating_trainer/tournaments/tournament_lists_screen.dart';
import 'package:karaterating_trainer/tournaments/quick_fights_screen.dart';

void main() => spectatorTests();
void spectatorTests({Future<void> Function(String)? screenshot}) {
  late SpectatorApi api;
  const s = AppStrings(AppLocale.ru);
  final championship = Championship.fromJson({'id': 1});
  final tournament = TournamentItem.fromJson({'id': 2});
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    api = SpectatorApi(AuthSession(await SharedPreferences.getInstance()));
  });
  tearDown(() => api.close());

  testWidgets('quick fight status and sides fit both themes and phone widths', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in [360.0, 393.0, 430.0]) {
      for (final locale in AppLocale.values) {
        for (final dark in [false, true]) {
          tester.view.physicalSize = Size(width, 852);
          tester.view.devicePixelRatio = 1;
          api.quickStatus = dark ? 'absent' : 'won';
          final strings = AppStrings(locale);
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? AppTheme.dark() : AppTheme.light(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(1.35)),
                child: child!,
              ),
              home: QuickFightsScreen(api: api, strings: strings),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<Text>(find.text('${strings.fightNumberLabel} A-2'))
                .style
                ?.decoration,
            TextDecoration.lineThrough,
          );
          expect(
            tester
                .widget<Text>(find.text('${strings.fightNumberLabel} A-4'))
                .style
                ?.fontStyle,
            FontStyle.italic,
          );
          expect(find.byTooltip(strings.whiteSide), findsOneWidget);
          expect(find.byTooltip(strings.redSide), findsOneWidget);
          expect(
            tester
                .widget<Text>(find.text('Александр Длиннаяфамилия'))
                .style
                ?.decoration,
            dark ? TextDecoration.lineThrough : null,
          );
          expect(
            tester.takeException(),
            isNull,
            reason: '$width $locale $dark',
          );
          await tester.pumpWidget(const SizedBox());
        }
      }
    }
  });

  testWidgets(
    'original lists show fallback and paginated members without management',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: TournamentListsScreen(
            api: api,
            strings: s,
            championship: championship,
            tournament: tournament,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Не попали'), findsOneWidget);
      expect(find.textContaining(s.notGenerated), findsOneWidget);
      await tester.tap(find.textContaining('Не попали'));
      await tester.pumpAndSettle();
      expect(find.textContaining('HAYABUSA'), findsOneWidget);
      expect(find.textContaining('Команда 1'), findsOneWidget);
      expect(find.text('Сгенерировать'), findsNothing);
      if (screenshot != null) await screenshot('spectator-source-members');
      await tester.tap(find.byTooltip(s.nextPage));
      await tester.pumpAndSettle();
      expect(api.lastQuery['page'], '2');
      expect(find.text('Ученик на второй странице'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'quick data opens exact final and swipe updates stage without edits',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: QuickFightsScreen(api: api, strings: s),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Текущий: A-2'), findsOneWidget);
      if (screenshot != null) await screenshot('spectator-quick-data');
      await tester.tap(find.text('Бой A-4'));
      await tester.pumpAndSettle();
      expect(find.text('Финал'), findsOneWidget);
      expect(find.textContaining('Вазари: 1'), findsOneWidget);
      expect(find.text('Неявка'), findsNothing);
      expect(find.byType(TextField), findsNothing);
      if (screenshot != null) await screenshot('spectator-final');
      await tester.drag(
        find.byType(PageView),
        Offset(tester.getSize(find.byType(PageView)).width * 0.85, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('1/2'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'group kata preserves all names coaches and team results on small phone',
    (tester) async {
      api.kata = true;
      if (screenshot == null) {
        tester.view.physicalSize = const Size(320, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
      }
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: TournamentBracketScreen(
            api: api,
            strings: s,
            championship: championship,
            tournament: tournament,
            table: TournamentTableItem.fromJson({'id': 3}),
            initialPoolId: 8,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Александр'), findsWidgets);
      expect(find.textContaining('SPARTA'), findsWidgets);
      expect(find.text('24'), findsWidgets);
      expect(find.text('Загрузить видео финала'), findsNothing);
      expect(tester.takeException(), isNull);
      if (screenshot != null) await screenshot('spectator-group-kata');
      await tester.pumpWidget(const SizedBox());
    },
  );
}

class SpectatorApi extends ApiClient {
  SpectatorApi(AuthSession session)
    : super(session: session, baseUrl: 'https://example.test/api/mobile');
  bool kata = false;
  String quickStatus = 'upcoming';
  Map<String, String?> lastQuery = {};
  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String?> query = const {},
  }) async {
    lastQuery = query;
    if (path == '/quick-fights') {
      return {
        'data': [
          {
            'student_id': 1,
            'name': 'Александр Длиннаяфамилия',
            'club': 'HAYABUSA',
            'tournament_id': 2,
            'championship_id': 1,
            'list_id': 3,
            'list_name': 'Мальчики 10–11 лет · 35 кг',
            'tournament_name': 'Турнир',
            'tatami': 'A',
            'generated': true,
            'path': [
              {
                'id': 4,
                'round': 1,
                'stage': '1/2',
                'number': 'A-2',
                'status': quickStatus,
                'side': 'white',
              },
              {
                'id': 5,
                'round': 2,
                'stage': 'Финал',
                'number': 'A-4',
                'status': 'possible',
                'side': 'red',
              },
            ],
            'current': {'number': 'A-2'},
            'next': {'number': 'A-3'},
          },
        ],
        'tournaments': [
          {'id': 2, 'name': 'Турнир'},
        ],
        'meta': {'last_page': 1},
      };
    }
    if (path.endsWith('/members')) {
      return {
        'data': [
          {
            'student_id': 1,
            'name': query['page'] == '2'
                ? 'Ученик на второй странице'
                : 'Александр Длиннаяфамилия',
            'club': 'HAYABUSA',
            'coach_name': 'Мартиросян Эдуард',
            'group_id': 'team',
            'group_number': 1,
            'weight': 35,
            'rang': '5 кю',
            'age': 11,
          },
        ],
        'meta': {'last_page': 2},
      };
    }
    if (path.endsWith('/lists')) {
      return {
        'data': [
          {
            'id': 3,
            'name': 'Не попали в списки',
            'generated': false,
            'students_count': 31,
          },
        ],
        'meta': {'last_page': 1},
      };
    }
    if (path.endsWith('/bracket')) {
      if (kata) {
        return {
          'kind': 'kata',
          'title': 'Групповая ката · мальчики и девочки 10–11 лет',
          'rounds': [
            {
              'key': 'final',
              'title': 'Финал',
              'rows': [
                {
                  'id': 8,
                  'name': 'Александр Длиннаяфамилия\nИлья Бурмистров',
                  'participant_number': '1',
                  'winner_place': 1,
                  'total_score': '24',
                  'referee_score': '8',
                  'judge1_score': '8',
                  'judge2_score': '8',
                  'judge3_score': '8',
                  'judge4_score': '8',
                  'members': [
                    {
                      'id': 1,
                      'name': 'Александр Длиннаяфамилия',
                      'club': 'HAYABUSA',
                      'coach_name': 'Мартиросян Эдуард',
                    },
                    {
                      'id': 2,
                      'name': 'Илья Бурмистров',
                      'club': 'SPARTA',
                      'coach_name': 'Манас ян Арман',
                    },
                  ],
                },
              ],
            },
          ],
        };
      }
      Map<String, dynamic> pool(int id, int round) => {
        'id': id,
        'round': round,
        'position': 1,
        'fight_number': round == 1 ? 'A-2' : 'A-4',
        'winner_id': round == 2 ? 1 : null,
        'student_wazari_count': round == 2 ? 1 : 0,
        'student': {
          'id': 1,
          'name': 'Александр Длиннаяфамилия',
          'club': 'HAYABUSA · Мартиросян Эдуард',
        },
        'opponent': {
          'id': 2,
          'name': 'Илья Бурмистров',
          'club': 'SPARTA · Манас ян Арман',
        },
      };
      return {
        'kind': 'kumite',
        'title': 'Мальчики 10–11 лет · 35 кг',
        'rounds': [
          {
            'number': 1,
            'title': '1/2',
            'pools': [pool(4, 1)],
          },
          {
            'number': 2,
            'title': 'Финал',
            'pools': [pool(5, 2)],
          },
        ],
      };
    }
    throw StateError('Unexpected $path');
  }
}
