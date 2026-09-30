import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:karaterating_trainer/api/api_client.dart';
import 'package:karaterating_trainer/auth/auth_session.dart';
import 'package:karaterating_trainer/l10n/app_locale.dart';
import 'package:karaterating_trainer/theme/app_theme.dart';
import 'package:karaterating_trainer/tournaments/tournament_detail_screen.dart';
import 'package:karaterating_trainer/tournaments/tournament_student_picker.dart';
import 'package:karaterating_trainer/tournaments/tournament_models.dart';

void main() => tournamentEnrollmentTests();

void tournamentEnrollmentTests({Future<void> Function(String)? screenshot}) {
  late _TournamentApi api;
  const strings = AppStrings(AppLocale.ru);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    api = _TournamentApi(AuthSession(await SharedPreferences.getInstance()));
  });
  tearDown(() => api.close());

  testWidgets(
    'collapsible tournament information fits phone widths and large text',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final width in [360.0, 393.0, 430.0]) {
        for (final locale in AppLocale.values) {
          for (final dark in [false, true]) {
            tester.view.physicalSize = Size(width, 852);
            tester.view.devicePixelRatio = 1;
            await tester.pumpWidget(
              MaterialApp(
                theme: dark ? AppTheme.dark() : AppTheme.light(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(1.35)),
                  child: child!,
                ),
                home: TournamentDetailScreen(
                  api: api,
                  strings: AppStrings(locale),
                  championship: Championship.fromJson({
                    'id': 1,
                    'name': 'Международный чемпионат по киокушинкай',
                  }),
                  item: TournamentItem.fromJson({
                    'id': 2,
                    'name': 'Ката · Мальчики 10–11 лет',
                    'championship_id': 1,
                  }),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(
              tester.getSize(find.byType(ExpansionTile)).height,
              lessThan(135),
            );
            await tester.tap(find.byType(ExpansionTile));
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '$width $locale $dark',
            );
            await tester.pumpWidget(const SizedBox());
          }
        }
      }
    },
  );

  testWidgets(
    'tournament picker preserves selection across pages and search; failure stays open',
    (tester) async {
      List<int>? selected;
      var reject = true;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  child: const Text('Open'),
                  onPressed: () => showModalBottomSheet<bool>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => TournamentStudentPicker(
                      api: api,
                      strings: strings,
                      path: '/tournament',
                      submit: (students) async {
                        if (reject) {
                          throw const ApiException(
                            'Ученик недоступен',
                            statusCode: 422,
                          );
                        }
                        selected = students.map((s) => s.id).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ученик 1'));
      await tester.tap(find.text(strings.moreRecords));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ученик 2'));
      await tester.enterText(find.byType(TextField), 'Третий');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Третий ученик'));
      await tester.pumpAndSettle();
      expect(find.text('${strings.selected}: 3'), findsOneWidget);
      await screenshot?.call('tournament-picker-keyboard');
      expect(tester.takeException(), isNull);
      if (tester.testTextInput.isRegistered) tester.testTextInput.hide();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, strings.attach));
      await tester.pumpAndSettle();
      expect(find.text('Ученик недоступен'), findsOneWidget);
      expect(find.byType(TournamentStudentPicker), findsOneWidget);
      await screenshot?.call('tournament-picker-error');
      reject = false;
      await tester.tap(find.widgetWithText(FilledButton, strings.attach));
      await tester.pumpAndSettle();
      expect(selected, [1, 2, 3]);
      expect(find.byType(TournamentStudentPicker), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'tournament header starts collapsed and expands all details inside it; 403 has retry',
    (tester) async {
      Widget screen() => MaterialApp(
        theme: AppTheme.light(),
        home: TournamentDetailScreen(
          api: api,
          strings: strings,
          championship: Championship.fromJson({
            'id': 1,
            'name': 'Чемпионат России',
          }),
          item: TournamentItem.fromJson({
            'id': 2,
            'name': 'Ката',
            'championship_id': 1,
          }),
        ),
      );
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      expect(find.text(strings.attach), findsNothing);
      expect(find.text('${strings.chiefJudge}: Главный Судья'), findsNothing);
      expect(find.text('${strings.tatami}: A, B'), findsNothing);
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();
      expect(find.text('${strings.chiefJudge}: Главный Судья'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ExpansionTile),
          matching: find.text('${strings.tatami}: A, B'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(ExpansionTile),
          matching: find.text('${strings.age}: 10–11'),
        ),
        findsOneWidget,
      );
      expect(find.text(strings.regulationDocument), findsNothing);
      await screenshot?.call('tournament-information');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.denied = true;
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      expect(find.text(strings.retry), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

class _TournamentApi extends ApiClient {
  _TournamentApi(AuthSession session) : super(session: session);
  bool denied = false;

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String?> query = const {},
  }) async {
    if (denied) throw const ApiException('Доступ закрыт', statusCode: 403);
    if (path.endsWith('/attach-options')) {
      final searching = (query['search'] ?? '').isNotEmpty;
      final page = int.parse(query['page'] ?? '1');
      final id = searching ? 3 : page;
      return {
        'data': [
          {
            'id': id,
            'name': searching ? 'Третий ученик' : 'Ученик $id',
            'age': 11,
            'weight': '35',
            'rang': '5 кю',
            'club': 'Название клуба тренера',
          },
        ],
        'meta': {'current_page': page, 'last_page': searching ? 1 : 2},
      };
    }
    if (path.endsWith('/students')) {
      return {
        'data': [],
        'meta': {'last_page': 1, 'total': 0},
      };
    }
    return {
      'tournament': {
        'id': 2,
        'name': 'Ката · Мальчики 10–11 лет',
        'championship_name': 'Чемпионат России',
        'type': 'kata',
        'date_label': '20.09.2026',
        'age_from': 10,
        'age_to': 11,
        'tatami': 'A, B',
        'date_commission_label': '19.09.2026 18:00',
        'date_finish_label': '21.09.2026 20:00',
        'address': 'Москва, Спортивная улица, 10',
        'chief_judge': 'Главный Судья',
        'chief_secretary': 'Главный Секретарь',
        'can_attach_students': false,
        'documents': [
          {
            'key': 'regulation_document',
            'url': '/document',
            'name': 'regulation.pdf',
          },
          {
            'key': 'application_document',
            'url': '/application',
            'name': 'application.pdf',
          },
        ],
      },
    };
  }
}
