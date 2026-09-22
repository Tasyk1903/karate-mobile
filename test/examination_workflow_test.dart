import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:karaterating_trainer/api/api_client.dart';
import 'package:karaterating_trainer/auth/auth_session.dart';
import 'package:karaterating_trainer/examinations/examination_detail_screen.dart';
import 'package:karaterating_trainer/examinations/examination_models.dart';
import 'package:karaterating_trainer/l10n/app_locale.dart';
import 'package:karaterating_trainer/theme/app_theme.dart';
import 'package:karaterating_trainer/tournaments/tournament_student_picker.dart';

void main() => examinationTests();

void examinationTests({Future<void> Function(String)? screenshot}) {
  late _ExamApi api;
  const strings = AppStrings(AppLocale.ru);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    api = _ExamApi(AuthSession(await SharedPreferences.getInstance()));
  });
  tearDown(() => api.close());

  Widget screen() => MaterialApp(
    theme: AppTheme.light(),
    home: ExaminationDetailScreen(api: api, strings: strings, examinationId: 7),
  );

  testWidgets(
    'student exam joins self with confirmation, refreshes and hides coach selection and export',
    (tester) async {
      api.accountRole = 'Student';
      api.accountId = 10;
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      expect(find.text(strings.excel), findsNothing);
      expect(find.text(strings.attachStudent), findsNothing);
      await tester.ensureVisible(find.text(strings.joinExam));
      await tester.tap(find.text(strings.joinExam));
      await tester.pumpAndSettle();
      expect(find.byType(TournamentStudentPicker), findsNothing);
      await tester.tap(find.widgetWithText(TextButton, strings.joinExam));
      await tester.pumpAndSettle();
      expect(api.selected, [10]);
      expect(find.text(strings.joinExam), findsNothing);
      await tester.ensureVisible(find.text(strings.detach).first);
      await tester.tap(find.text(strings.detach).first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, strings.detach).last);
      await tester.pumpAndSettle();
      expect(api.selected, isEmpty);
      expect(find.text(strings.joinExam), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'exam picker preserves page and search selection, rejects empty success and refreshes after attaching',
    (tester) async {
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(strings.attachStudent));
      await tester.tap(find.text(strings.attachStudent));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ученик 1'));
      await tester.tap(find.text(strings.moreRecords));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ученик 2'));
      await tester.enterText(
        find.descendant(
          of: find.byType(TournamentStudentPicker),
          matching: find.byType(TextField),
        ),
        'Третий',
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Третий ученик'));
      await tester.pumpAndSettle();
      expect(find.text('${strings.selected}: 3'), findsOneWidget);
      await screenshot?.call('exam-selection-search');
      expect(tester.takeException(), isNull);
      if (tester.testTextInput.isRegistered) tester.testTextInput.hide();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      api.emptyAttach = true;
      await tester.tap(find.widgetWithText(FilledButton, strings.attach));
      await tester.pumpAndSettle();
      expect(find.byType(TournamentStudentPicker), findsOneWidget);
      expect(
        find.textContaining(strings.examNoStudentsAttached),
        findsOneWidget,
      );
      api.emptyAttach = false;
      api.rejectAttach = true;
      await tester.tap(find.widgetWithText(FilledButton, strings.attach));
      await tester.pumpAndSettle();
      expect(find.text('Ученик недоступен'), findsOneWidget);
      expect(find.byType(TournamentStudentPicker), findsOneWidget);
      await screenshot?.call('exam-selection-error');
      api.rejectAttach = false;
      await tester.tap(find.widgetWithText(FilledButton, strings.attach));
      await tester.pumpAndSettle();
      expect(api.selected, [1, 2, 3]);
      expect(find.byType(TournamentStudentPicker), findsNothing);
      expect(find.text('Добавленный ученик'), findsOneWidget);
      expect(api.studentLoads, greaterThan(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'other coach participants are visible, detach only own, filter is passed to Excel',
    (tester) async {
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Чужой ученик'));
      expect(find.text('Свой ученик'), findsOneWidget);
      expect(find.text('Чужой ученик'), findsOneWidget);
      expect(find.text(strings.detach), findsOneWidget);
      await screenshot?.call('exam-participants');
      await tester.ensureVisible(find.byIcon(Icons.tune_rounded));
      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Другой тренер'));
      await tester.pumpAndSettle();
      expect(api.studentQuery['coach_id'], '12');
      expect(find.text(strings.detach), findsNothing);
      expect(find.text('Чужой ученик'), findsOneWidget);
      final excel = find.text('Excel');
      await tester.ensureVisible(excel);
      await tester.tap(excel);
      await tester.pumpAndSettle();
      expect(api.exportQuery['coach_id'], '12');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'denied exam stops loading and allows retry; missing detach capability is false',
    (tester) async {
      api.denied = true;
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text(strings.retry), findsOneWidget);
      expect(ExaminationStudent.fromJson({'id': 1}).canDetach, isFalse);
      api.denied = false;
      await tester.tap(find.text(strings.retry));
      await tester.pumpAndSettle();
      expect(find.text('Кю-тест'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _ExamApi extends ApiClient {
  _ExamApi(AuthSession session) : super(session: session);
  bool emptyAttach = false, rejectAttach = false, denied = false;
  List<int> selected = [];
  int studentLoads = 0;
  Map<String, String?> studentQuery = {}, exportQuery = {};

  Map<String, dynamic> student(int id, String name, bool own) => {
    'id': id,
    'full_name': name,
    'age': '11 лет',
    'age_years': 11,
    'rang': '5 кю',
    'weight': '35',
    'club': 'Клуб тренера',
    'can_detach': own,
  };

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String?> query = const {},
  }) async {
    if (denied) throw const ApiException('Доступ закрыт', statusCode: 403);
    if (path.endsWith('/attach-options')) {
      final searching = (query['search'] ?? '').isNotEmpty;
      final page = int.parse(query['page'] ?? '1');
      return {
        'data': [
          student(
            searching ? 3 : page,
            searching ? 'Третий ученик' : 'Ученик $page',
            true,
          ),
        ],
        'meta': {'current_page': page, 'last_page': searching ? 1 : 2},
      };
    }
    if (path.endsWith('/students')) {
      studentLoads++;
      studentQuery = query;
      return {
        'data': [
          if (query['coach_id'] == null && (!isStudent || selected.isNotEmpty))
            student(10, 'Свой ученик', true),
          student(11, 'Чужой ученик', false),
          if (selected.isNotEmpty && !isStudent)
            student(1, 'Добавленный ученик', true),
        ],
        'meta': {
          'current_page': 1,
          'last_page': 1,
          'total': selected.isEmpty ? 2 : 3,
        },
        'filters': {
          'coaches': [
            {'id': 12, 'full_name': 'Другой тренер'},
          ],
        },
      };
    }
    return {
      'item': {
        'id': 7,
        'can_attach_self': isStudent && selected.isEmpty,
        'name': 'Кю-тест',
        'city': 'Москва',
        'date_label': '09.09.2026',
        'receiving': 'Иванов Иван Иванович',
        'students_count': selected.isEmpty ? 2 : 3,
      },
    };
  }

  @override
  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic> body = const {},
    bool authenticated = true,
  }) async {
    if (rejectAttach) {
      throw const ApiException('Ученик недоступен', statusCode: 403);
    }
    if (emptyAttach) return {'attached': []};
    if (isStudent && path.endsWith('/self')) {
      selected = [10];
      return {'attached': selected};
    }
    selected = List<int>.from(body['student_ids'] as List);
    return {'attached': selected};
  }

  @override
  Future<Map<String, dynamic>> deleteJson(String path) async {
    selected = [];
    return {'detached': true};
  }

  @override
  Future<Uint8List> getBytes(
    String path, {
    Map<String, String?> query = const {},
  }) async {
    exportQuery = query;
    // Stop before the native share dialog; actual XLSX contents are covered by API tests.
    throw const ApiException('Тест выгрузки', statusCode: 503);
  }
}
