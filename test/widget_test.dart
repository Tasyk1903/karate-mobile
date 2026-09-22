import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:karaterating_trainer/feed/feed_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karaterating_trainer/api/api_client.dart';
import 'package:karaterating_trainer/app/karate_rating_app.dart';
import 'package:karaterating_trainer/auth/auth_session.dart';
import 'package:karaterating_trainer/l10n/app_locale.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  Future<_FakeApiClient> login(
    WidgetTester tester, {
    bool consent = false,
    bool student = false,
    bool profileSetup = false,
  }) async {
    SharedPreferences.setMockInitialValues({});
    late _FakeApiClient api;
    await tester.pumpWidget(
      KarateRatingApp(
        prefs: await SharedPreferences.getInstance(),
        apiFactory: (session) => api = _FakeApiClient(session)
          ..consentRequired = consent
          ..profileSetupRequired = profileSetup
          ..studentRole = student,
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(EditableText).at(0),
      'coach@example.com',
    );
    await tester.enterText(find.byType(EditableText).at(1), 'password');
    await tester.tap(find.text('Войти'));
    await tester.pumpAndSettle();
    return api;
  }

  Future<void> acceptDocuments(WidgetTester tester) async {
    for (final id in [2, 3]) {
      await tester.tap(find.text('Документ $id'));
      await tester.pumpAndSettle();
      expect(
        find.text('Полный текст документа', findRichText: true),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Продолжить'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Продолжить'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  }

  testWidgets(
    'student signs in to own native profile and gets only student menu and feed audiences',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = await login(tester, student: true);
      expect(api.isStudent, true);
      expect(find.text('Иван Петров'), findsOneWidget);
      expect(api.feedCalls, 0);
      expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
      await tester.tap(find.byTooltip('Ещё'));
      await tester.pumpAndSettle();
      expect(find.text('Ученики'), findsNothing);
      expect(find.text('Настройки'), findsNothing);
      expect(find.text('Экзамены'), findsNothing);
      expect(find.text('Заявки и оплата'), findsNothing);
      expect(api.menuAvailable('payments'), isFalse);
      expect(find.text('Соглашения'), findsOneWidget);
      Navigator.of(tester.element(find.text('Соглашения'))).pop();
      await tester.pumpAndSettle();
      for (var repeat = 0; repeat < 2; repeat++) {
        await tester.tap(find.text('Лента').last);
        await tester.pumpAndSettle();
        expect(find.text('Мои ученики'), findsNothing);
        expect(find.text('Тренеры'), findsNothing);
        await tester.tap(find.text('Профиль').last);
        await tester.pumpAndSettle();
        expect(find.text('Иван Петров'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('initial consent gates feed until both explicit acceptances', (
    tester,
  ) async {
    final api = await login(tester, consent: true);
    expect(api.feedCalls, 0);
    expect(find.text('Соглашения'), findsOneWidget);
    await acceptDocuments(tester);
    expect(api.feedCalls, 1);
    expect(find.text('Лента участников'), findsOneWidget);
  });

  testWidgets(
    'new student must accept agreements then complete profile before opening shell',
    (tester) async {
      final api = await login(
        tester,
        consent: true,
        student: true,
        profileSetup: true,
      );
      expect(find.text('Соглашения'), findsOneWidget);
      expect(find.text('Анкета ученика'), findsNothing);
      await acceptDocuments(tester);
      expect(find.text('Анкета ученика'), findsOneWidget);
      expect(find.text('Лента'), findsNothing);
      expect(find.text('Документы'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Анкета ученика'), findsOneWidget);
      final complete = find.text('Завершить регистрацию');
      await tester.ensureVisible(complete);
      await tester.pumpAndSettle();
      await tester.tap(complete);
      await tester.pumpAndSettle();
      expect(api.savedProfile?['city_training'], 'Москва');
      expect(api.savedProfile!.containsKey('patronymic'), false);
      expect(find.text('Анкета ученика'), findsNothing);
      expect(find.text('Иван Петров'), findsOneWidget);
      expect(find.text('Лента'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'runtime consent returns to original detail route and preserves feed',
    (tester) async {
      final api = await login(tester);
      final feed = tester.state(find.byType(FeedScreen));
      await tester.tap(find.byIcon(Icons.notifications_none_rounded));
      await tester.pumpAndSettle();
      api.consentRequired = true;
      await api.onConsentRequired!();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Соглашения'), findsOneWidget);
      await acceptDocuments(tester);
      expect(find.text('Уведомления'), findsOneWidget);
      Navigator.of(tester.element(find.text('Уведомления'))).pop();
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(FeedScreen)), same(feed));
      expect(api.feedCalls, 2);
    },
  );

  testWidgets(
    'account deletion requires password and clears protected navigation',
    (tester) async {
      final api = await login(tester);
      await tester.tap(find.text('Профиль').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Редактировать'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Удалить аккаунт'),
        260,
        scrollable: find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            )
            .last,
      );
      await tester.tap(find.text('Удалить аккаунт'));
      await tester.pumpAndSettle();
      final dialog = find.byType(AlertDialog);
      final password = find.descendant(
        of: dialog,
        matching: find.byType(TextField),
      );
      expect(tester.widget<TextField>(password).obscureText, true);
      await tester.tap(
        find.descendant(
          of: dialog,
          matching: find.widgetWithText(FilledButton, 'Удалить аккаунт'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Введите пароль'), findsOneWidget);
      expect(api.deleted, false);
      await tester.enterText(password, 'password');
      await tester.tap(
        find.descendant(
          of: dialog,
          matching: find.widgetWithText(FilledButton, 'Удалить аккаунт'),
        ),
      );
      await tester.pumpAndSettle();
      expect(api.deleted, true);
      expect(api.authSession.token, isNull);
      expect(find.text('Вход'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('profile editor preserves patronymic and omits locked fields', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = await login(tester);
    await tester.tap(find.text('Профиль').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Редактировать'));
    await tester.pumpAndSettle();
    expect(find.text('Иванович'), findsOneWidget);
    final birthField = find.byWidgetPredicate(
      (widget) =>
          widget is TextFormField && widget.controller?.text == '03.02.1986',
    );
    await tester.scrollUntilVisible(
      birthField,
      240,
      scrollable: find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .last,
    );
    expect(tester.widget<TextFormField>(birthField).enabled, false);
    await tester.scrollUntilVisible(
      find.text('Сохранить'),
      240,
      scrollable: find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .last,
    );
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(api.savedProfile?['patronymic'], 'Иванович');
    expect(api.savedProfile?['gender'], 'f');
    for (final field in ['birthday', 'rang', 'weight']) {
      expect(api.savedProfile?.containsKey(field), false);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'repeated tabs and menu routes preserve feed and return correctly',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        KarateRatingApp(
          prefs: await SharedPreferences.getInstance(),
          apiFactory: _FakeApiClient.new,
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(EditableText).at(0),
        'coach@example.com',
      );
      await tester.enterText(find.byType(EditableText).at(1), 'password');
      await tester.tap(find.text('Войти'));
      await tester.pumpAndSettle();
      final feedState = tester.state(find.byType(FeedScreen));
      for (var cycle = 0; cycle < 2; cycle++) {
        for (final label in ['Рейтинг', 'Профиль', 'Лента']) {
          await tester.tap(find.text(label).last);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        expect(tester.state(find.byType(FeedScreen)), same(feedState));
        await tester.tap(find.byIcon(Icons.menu_rounded));
        await tester.pumpAndSettle();
        expect(find.text('Заявки и оплата'), findsNothing);
        final menuLabels = [
          'Ученики',
          'Турниры',
          'Экзамены',
          'Обучение',
          'Соглашения',
          'Настройки',
          'О нас',
          'Выйти',
        ];
        for (var i = 1; i < menuLabels.length; i++) {
          expect(
            tester.getTopLeft(find.text(menuLabels[i])).dy,
            greaterThan(tester.getTopLeft(find.text(menuLabels[i - 1])).dy),
          );
        }
        await tester.tap(find.text('Ученики'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Иван Петров'));
        await tester.pumpAndSettle();
        expect(find.text('Профиль ученика'), findsOneWidget);
        final detailContext = tester.element(find.text('Профиль ученика'));
        Navigator.of(detailContext).pop();
        await tester.pumpAndSettle();
        await tester.tap(find.text('Лента'));
        await tester.pumpAndSettle();
        expect(tester.state(find.byType(FeedScreen)), same(feedState));
      }
      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Настройки'));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.text('Настройки тренера'))).pop();
      await tester.pumpAndSettle();
      expect(find.text('Лента участников'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('logout from a menu section clears every protected route', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    late _FakeApiClient api;
    await tester.pumpWidget(
      KarateRatingApp(
        prefs: await SharedPreferences.getInstance(),
        apiFactory: (session) => api = _FakeApiClient(session),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(EditableText).at(0),
      'coach@example.com',
    );
    await tester.enterText(find.byType(EditableText).at(1), 'password');
    await tester.tap(find.text('Войти'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ученики'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Выйти'));
    await tester.pumpAndSettle();
    expect(find.text('Выйти из аккаунта?'), findsOneWidget);
    await tester.tap(find.text('Выйти'));
    await tester.pumpAndSettle();
    expect(api.logoutCalls, 1);
    expect(api.authSession.token, isNull);
    expect(find.text('Вход'), findsOneWidget);
    expect(Navigator.of(tester.element(find.text('Вход'))).canPop(), isFalse);
    expect(find.byType(FeedScreen, skipOffstage: false), findsNothing);
  });

  testWidgets('401 on a detail route resets navigator to login', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    late _FakeApiClient api;
    await tester.pumpWidget(
      KarateRatingApp(
        prefs: await SharedPreferences.getInstance(),
        apiFactory: (session) => api = _FakeApiClient(session),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(EditableText).at(0),
      'coach@example.com',
    );
    await tester.enterText(find.byType(EditableText).at(1), 'password');
    await tester.tap(find.text('Войти'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.notifications_none_rounded));
    await tester.pumpAndSettle();
    await api.onUnauthorized!();
    await tester.pumpAndSettle();
    expect(find.text('Вход'), findsOneWidget);
    expect(find.text('Уведомления'), findsNothing);
    expect(Navigator.of(tester.element(find.text('Вход'))).canPop(), isFalse);
  });

  testWidgets(
    'registration stays native for both roles; recovery opens web without auth headers',
    (tester) async {
      final urls = <String>[];
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        if (call.method == 'launch') {
          urls.add(call.arguments['url'] as String);
          expect(call.arguments['headers'], isEmpty);
          expect(call.arguments['useWebView'], isFalse);
        }
        return true;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        KarateRatingApp(
          prefs: await SharedPreferences.getInstance(),
          apiFactory: _FakeApiClient.new,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Забыли пароль?'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Зарегистрироваться'));
      await tester.tap(find.text('Зарегистрироваться'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Тренер'));
      await tester.pumpAndSettle();
      expect(find.text('Регистрация тренера'), findsOneWidget);
      expect(find.text('Код организации'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Зарегистрироваться'));
      await tester.tap(find.text('Зарегистрироваться'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ученик'));
      await tester.pumpAndSettle();
      expect(find.text('Регистрация ученика'), findsOneWidget);
      expect(find.text('Код тренера'), findsOneWidget);
      expect(urls, ['http://127.0.0.1:8080/forgot-password?locale=ru']);
    },
  );

  testWidgets('shows login screen by default', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      KarateRatingApp(prefs: prefs, apiFactory: _FakeApiClient.new),
    );

    await tester.pumpAndSettle();
    expect(find.text('Вход'), findsOneWidget);
    expect(find.text('Войти'), findsOneWidget);
  });

  testWidgets('fits login screen on phone viewport', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      KarateRatingApp(prefs: prefs, apiFactory: _FakeApiClient.new),
    );

    await tester.pumpAndSettle();
    expect(find.text('Вход'), findsOneWidget);
    expect(find.text('Войти'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens feed after sign in', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      KarateRatingApp(prefs: prefs, apiFactory: _FakeApiClient.new),
    );

    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(EditableText).at(0),
      'coach@example.com',
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).at(1), 'password');
    await tester.tap(find.text('Войти'));
    await tester.pumpAndSettle();

    expect(find.text('Лента участников'), findsOneWidget);
    expect(find.text('Опубликовать'), findsOneWidget);
  });

  testWidgets('fits feed screen on phone viewport', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      KarateRatingApp(prefs: prefs, apiFactory: _FakeApiClient.new),
    );

    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(EditableText).at(0),
      'coach@example.com',
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).at(1), 'password');
    await tester.tap(find.text('Войти'));
    await tester.pumpAndSettle();

    expect(find.text('Лента участников'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens rating from bottom navigation', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      KarateRatingApp(prefs: prefs, apiFactory: _FakeApiClient.new),
    );

    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(EditableText).at(0),
      'coach@example.com',
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).at(1), 'password');
    await tester.tap(find.text('Войти'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Рейтинг'));
    await tester.pumpAndSettle();

    expect(find.text('Кумитэ'), findsOneWidget);
    expect(find.text('ТОП 15 РЕЙТИНГА ПО ТРЕНЕРАМ'), findsOneWidget);
  });

  testWidgets('opens trainer settings from bottom navigation', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      KarateRatingApp(prefs: prefs, apiFactory: _FakeApiClient.new),
    );

    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(EditableText).at(0),
      'coach@example.com',
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).at(1), 'password');
    await tester.tap(find.text('Войти'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Профиль'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Настройки'));
    await tester.pumpAndSettle();
    expect(find.text('Настройки тренера'), findsOneWidget);
    expect(find.text('Доступ ученикам заявляться на турнир'), findsOneWidget);
  });

  testWidgets('opens notifications from feed header', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      KarateRatingApp(prefs: prefs, apiFactory: _FakeApiClient.new),
    );

    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(EditableText).at(0),
      'coach@example.com',
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).at(1), 'password');
    await tester.tap(find.text('Войти'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.notifications_none_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Уведомления'), findsOneWidget);
    expect(
      find.text('Мы улучшили безопасность и скорость работы платформы.'),
      findsOneWidget,
    );
  });

  testWidgets('opens students list and student profile', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      KarateRatingApp(prefs: prefs, apiFactory: _FakeApiClient.new),
    );

    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(EditableText).at(0),
      'coach@example.com',
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).at(1), 'password');
    await tester.tap(find.text('Войти'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ученики'));
    await tester.pumpAndSettle();

    expect(find.text('Иван Петров'), findsOneWidget);

    await tester.tap(find.text('Иван Петров'));
    await tester.pumpAndSettle();

    expect(find.text('Профиль ученика'), findsOneWidget);
    expect(find.text('Кумитэ'), findsOneWidget);
    expect(find.text('Рекорд'), findsOneWidget);
  });

  testWidgets('opens examinations list and examination detail', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      KarateRatingApp(prefs: prefs, apiFactory: _FakeApiClient.new),
    );

    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(EditableText).at(0),
      'coach@example.com',
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).at(1), 'password');
    await tester.tap(find.text('Войти'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Экзамены'));
    await tester.pumpAndSettle();

    expect(find.text('Кю тест 22 марта 2026'), findsOneWidget);

    await tester.tap(find.text('Кю тест 22 марта 2026'));
    await tester.pumpAndSettle();

    expect(find.text('Экзамен'), findsOneWidget);
    expect(find.text('Бурмистрова Алевтина'), findsOneWidget);
  });
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient(AuthSession session) : super(session: session);
  int logoutCalls = 0;
  bool consentRequired = false;
  bool studentRole = false;
  bool profileSetupRequired = false;
  bool deleted = false;
  final acceptedDocuments = <int>{};
  Map<String, String>? savedProfile;
  int feedCalls = 0;

  @override
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    required bool remember,
    required AppLocale locale,
  }) async {
    return {
      'token': 'test-token',
      'expires_at': DateTime.now()
          .add(const Duration(days: 30))
          .toIso8601String(),
      'user': {
        'id': studentRole ? 7 : 1,
        'roles': [studentRole ? 'Student' : 'Coach'],
        if (studentRole)
          'navigation': {
            'bottom': ['rating', 'feed', 'profile'],
            'menu': ['about', 'agreements', 'logout'],
          },
        'name': 'Тренер',
        'email': email,
        'agreements_required': consentRequired,
        'profile_setup_required': profileSetupRequired,
      },
    };
  }

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String?> query = const {},
  }) async {
    if (path == '/auth/user') {
      return {
        'user': {
          'id': studentRole ? 7 : 1,
          'roles': [studentRole ? 'Student' : 'Coach'],
          if (studentRole)
            'navigation': {
              'bottom': ['rating', 'feed', 'profile'],
              'menu': ['about', 'agreements', 'logout'],
            },
          'agreements_required': consentRequired,
          'profile_setup_required': profileSetupRequired,
        },
      };
    }
    if (path == '/agreements') {
      return {
        'data': [
          for (final id in [2, 3])
            {
              'id': id,
              'title': 'Документ $id',
              'required': true,
              'accepted_at': acceptedDocuments.contains(id)
                  ? '2026-09-08'
                  : null,
            },
        ],
        'last_page': 1,
      };
    }
    if (path == '/agreements/2' || path == '/agreements/3') {
      final id = int.parse(path.split('/').last);
      return {
        'id': id,
        'title': 'Документ $id',
        'version': 'version-$id',
        'content': '<p>Полный текст документа</p>',
      };
    }
    if (path == '/trainer/profile') {
      return {
        'trainer': {
          'id': 1,
          'first_name': 'Эдуард',
          'last_name': 'Тест',
          'full_name': 'Тест Эдуард',
          'patronymic': 'Иванович',
          'email': 'coach@example.com',
          'birthday': '03.02.1986',
          'gender': 'f',
          'gender_label': 'Женский',
          'rang': '1 dan',
          'weight': 80,
          'height': 180,
          'club': 'DOJO',
          'capabilities': {
            'birthday': false,
            'rang': false,
            'weight': false,
            'delete_account': true,
          },
        },
      };
    }
    if (path == '/feed') {
      feedCalls++;
      return {
        'data': [
          {
            'id': 1,
            'text': 'Тестовый пост',
            'scope': 'all',
            'created_at': DateTime.now().toIso8601String(),
            'is_mine': true,
            'author': {'name': 'Тренер'},
            'reactions': {
              'counts': {'heart': 1},
              'selected': null,
            },
            'comments': [],
          },
        ],
      };
    }

    if (path == '/rating') {
      return {
        'trainer_ranking': {
          'leader': {
            'name': 'Ли Сергей',
            'coach': '—',
            'club': 'Ли Додзё',
            'points': 358,
          },
        },
        'groups': [
          {
            'id': 1,
            'title': '8-9 лет • 30 кг',
            'gender': 'Мальчики',
            'leader': {
              'name': 'Романцов Артем',
              'coach': 'Меняйло Н.',
              'club': 'КОДА',
              'points': 208,
            },
            'items': [],
          },
        ],
      };
    }

    if (path == '/about') {
      return {
        'project': {
          'title': 'Karate Rating',
          'lead': 'Платформа для тренеров',
          'description': 'Описание проекта',
        },
        'stats': {'athletes': '1', 'clubs': '2', 'tournaments': '3'},
      };
    }

    if (path == '/trainer/settings') {
      return {
        'settings': {
          'can_attach_to_tournaments_for_students': false,
          'can_visible_number_fight_to_tournaments_for_students': true,
          'can_attach_to_examination_for_students': true,
        },
      };
    }

    if (path == '/notifications') {
      return {
        'data': [
          {
            'id': 1,
            'source_label': 'Karate Rating',
            'message': 'Мы улучшили безопасность и скорость работы платформы.',
            'created_at': DateTime.now()
                .subtract(const Duration(minutes: 10))
                .toIso8601String(),
            'is_read': false,
          },
        ],
        'meta': {'unread': 1},
      };
    }

    if (path == '/students') {
      return {
        'data': [
          {
            'id': 7,
            'full_name': 'Иван Петров',
            'age_label': '10 лет',
            'gender_label': 'Мальчик',
            'club': 'Воин ветра',
            'rang': '8 кю',
            'belt': {
              'label_key': 'yellowBelt',
              'color': '#facc15',
              'accent': '#f8fafc',
              'progress': 50,
            },
            'active_tournaments': 1,
            'documents_ok': true,
          },
        ],
        'meta': {'current_page': 1, 'last_page': 1, 'per_page': 10, 'total': 1},
      };
    }

    if (path == '/students/7') {
      return {
        'student': {
          'id': 7,
          'full_name': 'Иван Петров',
          if (profileSetupRequired) ...{
            'first_name': 'Иван',
            'last_name': 'Петров',
            'gender': 'm',
            'city_training': 'Москва',
            'capabilities': {'birthday': true, 'rang': true, 'weight': true},
          },
          'club': 'Воин ветра',
          'coach_name': 'Ли Сергей',
          'age_label': '10 лет',
          'gender_label': 'Мальчик',
          'birthday': '04.06.2016',
          'weight': 30,
          'height': 140,
          'rang': '8 кю',
          'belt': {
            'label_key': 'yellowBelt',
            'color': '#facc15',
            'accent': '#f8fafc',
            'progress': 50,
          },
        },
        'rating': {
          'kumite': {
            'label': 'ТОП-3',
            'points': 96,
            'year': '2026',
            'medals': {'gold': 2, 'silver': 1, 'bronze': 0},
          },
          'kata': {
            'label': 'ТОП-1',
            'points': 3,
            'year': '2026',
            'subtitle': '10-11 лет · Мальчики',
            'medals': {'gold': 0, 'silver': 0, 'bronze': 0},
          },
          'record': {'wins': 9, 'losses': 3, 'total': 12},
        },
        'documents': {
          'items': [
            {'key': 'insurance', 'confirmed': true},
            {'key': 'ikoCard', 'confirmed': false},
          ],
        },
        'tournaments': [
          {
            'id': 1,
            'name': 'HAYABUSA CUP 2025',
            'date': '17.05.2025',
            'type': 'kumite',
          },
        ],
        'recent_results': [
          {
            'id': 1,
            'name': 'HAYABUSA CUP 2025',
            'date': '17.05.2025',
            'type': 'kumite',
          },
        ],
      };
    }

    if (path == '/examinations') {
      return {
        'data': [
          {
            'id': 3,
            'name': 'Кю тест 22 марта 2026',
            'city': 'Ростов-на-Дону',
            'date': '2026-03-22',
            'date_label': '22.03.2026',
            'receiving': 'Ли Сергей Леонидович',
            'students_count': 1,
            'status': 'planned',
          },
        ],
        'meta': {'current_page': 1, 'last_page': 1, 'per_page': 10, 'total': 1},
      };
    }

    if (path == '/examinations/3') {
      return {
        'item': {
          'id': 3,
          'name': 'Кю тест 22 марта 2026',
          'city': 'Ростов-на-Дону',
          'date': '2026-03-22',
          'date_label': '22.03.2026',
          'receiving': 'Ли Сергей Леонидович',
          'students_count': 1,
          'status': 'planned',
        },
      };
    }

    if (path == '/examinations/3/students') {
      return {
        'data': [
          {
            'id': 11,
            'full_name': 'Бурмистрова Алевтина',
            'age': 14,
            'rang': '6 кю',
            'weight': 45,
            'can_detach': true,
          },
        ],
        'meta': {'current_page': 1, 'last_page': 1, 'per_page': 10, 'total': 1},
      };
    }

    if (path == '/examinations/3/attach-options') {
      return {
        'data': [
          {
            'id': 12,
            'full_name': 'Мирошников Никита',
            'age': 13,
            'rang': '8 кю',
            'weight': 38,
            'can_detach': true,
          },
        ],
      };
    }

    return {};
  }

  @override
  Future<Map<String, dynamic>> postMultipartFiles(
    String path, {
    required Map<String, String> fields,
    required Map<String, File> files,
  }) async {
    savedProfile = fields;
    if (path == '/students/7') profileSetupRequired = false;
    return {};
  }

  @override
  Future<Map<String, dynamic>> putJson(
    String path, {
    Map<String, dynamic> body = const {},
  }) async {
    if (path == '/trainer/settings') {
      return {'settings': body};
    }

    return {};
  }

  @override
  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic> body = const {},
    bool authenticated = true,
  }) async {
    if (path.startsWith('/agreements/') && path.endsWith('/accept')) {
      final id = int.parse(path.split('/')[2]);
      expect(body['accepted'], true);
      expect(body['version'], 'version-$id');
      acceptedDocuments.add(id);
      consentRequired = acceptedDocuments.length != 2;
      return {'agreements_required': consentRequired};
    }
    if (path == '/account/delete') {
      expect(body['confirmed'], true);
      expect(body['password'], 'password');
      deleted = true;
      return {'deleted': true};
    }
    if (path == '/auth/logout') logoutCalls++;
    if (path == '/examinations/3/students') {
      return {'attached': body['student_ids'] ?? []};
    }

    return {};
  }

  @override
  Future<Map<String, dynamic>> deleteJson(String path) async {
    if (path == '/examinations/3/students/11') {
      return {'detached': true};
    }

    return {};
  }

  @override
  Future<List<int>> getBytes(
    String path, {
    Map<String, String?> query = const {},
  }) async {
    if (path == '/examinations/3/students/export') {
      return [1, 2, 3];
    }

    return [];
  }
}
