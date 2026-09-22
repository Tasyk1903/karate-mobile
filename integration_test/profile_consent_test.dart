import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:karaterating_trainer/account/agreements_screen.dart';
import 'package:karaterating_trainer/api/api_client.dart';
import 'package:karaterating_trainer/auth/auth_session.dart';
import 'package:karaterating_trainer/l10n/app_locale.dart';
import 'package:karaterating_trainer/profile/trainer_profile_screen.dart';
import 'package:karaterating_trainer/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native coach profile and agreements without real data mutations',
    (tester) async {
      final api = _ProfileApi(
        AuthSession(await SharedPreferences.getInstance()),
      );
      addTearDown(api.close);
      for (final locale in [AppLocale.ru, AppLocale.en]) {
        final strings = AppStrings(locale);
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey(locale),
            theme: AppTheme.light(),
            home: TrainerProfileScreen(strings: strings, api: api),
          ),
        );
        await tester.pumpAndSettle();
        await binding.takeScreenshot('profile-${locale.name}');
        await tester.tap(find.byTooltip(strings.edit));
        await tester.pumpAndSettle();
        await binding.takeScreenshot('profile-edit-${locale.name}');
        final patronymic = find.byWidgetPredicate(
          (widget) =>
              widget is TextFormField && widget.controller?.text == 'Иванович',
        );
        await tester.ensureVisible(patronymic);
        await tester.tap(patronymic);
        await tester.pumpAndSettle();
        await binding.takeScreenshot('profile-keyboard-${locale.name}');
        expect(tester.takeException(), isNull);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text(strings.save),
          240,
          scrollable: find
              .byWidgetPredicate(
                (widget) =>
                    widget is Scrollable &&
                    widget.axisDirection == AxisDirection.down,
              )
              .last,
        );
        await tester.tap(find.text(strings.save));
        await tester.pumpAndSettle();
        expect(api.saved?['patronymic'], 'Иванович');
        expect(api.saved?.containsKey('rang'), false);
      }
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        final strings = AppStrings(
          mode == ThemeMode.light ? AppLocale.ru : AppLocale.en,
        );
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey(mode),
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: mode,
            home: AgreementsScreen(api: api, strings: strings, gate: true),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Условия использования / Terms'));
        await tester.pumpAndSettle();
        await binding.takeScreenshot('agreement-${mode.name}');
        expect(tester.takeException(), isNull);
      }
    },
  );
}

class _ProfileApi extends ApiClient {
  _ProfileApi(AuthSession session) : super(session: session);
  Map<String, String>? saved;

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String?> query = const {},
  }) async {
    if (path == '/trainer/profile') {
      return {
        'trainer': {
          'id': 1,
          'first_name': 'Эдуард',
          'last_name': 'Тест',
          'full_name': 'Тест Эдуард',
          'patronymic': 'Иванович',
          'email': 'coach@example.test',
          'club': 'DOJO',
          'gender': 'm',
          'gender_label': 'Мужской',
          'age': 40,
          'birthday': '03.02.1986',
          'weight': 80,
          'height': 180,
          'rang': '1 дан',
          'capabilities': {
            'birthday': false,
            'rang': false,
            'weight': true,
            'delete_account': true,
          },
        },
      };
    }
    if (path == '/agreements') {
      return {
        'data': [
          {'id': 2, 'title': 'Условия использования / Terms', 'required': true},
        ],
        'last_page': 1,
      };
    }
    if (path == '/agreements/2') {
      return {
        'id': 2,
        'title': 'Условия использования / Terms',
        'version': 'test',
        'content': '<h2>1. Общие условия / General terms</h2><p>Тестовый документ для проверки отображения. Это не соглашение проекта.</p><p>A test document for display verification, not a project agreement.</p><ul><li>Первый пункт / First item</li><li>Второй пункт / Second item</li></ul>',
      };
    }
    throw StateError('Unexpected test request: $path');
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
