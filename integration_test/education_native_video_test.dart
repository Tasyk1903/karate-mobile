import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:karaterating_trainer/api/api_client.dart';
import 'package:karaterating_trainer/auth/auth_session.dart';
import 'package:karaterating_trainer/l10n/app_locale.dart';
import 'package:karaterating_trainer/education/education_video_screen.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('education work native video plays authorized stream and seeks', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    final session = AuthSession(await SharedPreferences.getInstance());
    await session.signIn(
      email: 'test@example.test',
      remember: false,
      token: 'education-native-test',
    );
    final api = _Api(session);
    const s = AppStrings(AppLocale.ru);
    await tester.pumpWidget(
      MaterialApp(
        home: EducationVideoScreen(
          api: api,
          strings: s,
          video: const {},
          workId: 1,
        ),
      ),
    );
    for (
      var i = 0;
      i < 100 && find.byType(VideoPlayer).evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.byType(VideoPlayer), findsOneWidget);
    await tester.tap(find.byTooltip(s.playPause));
    await tester.pump(const Duration(seconds: 2));
    final controller = tester
        .widget<VideoPlayer>(find.byType(VideoPlayer))
        .controller;
    expect(controller.value.position.inMilliseconds, greaterThan(0));
    await controller.seekTo(const Duration(seconds: 4));
    await tester.pump(const Duration(seconds: 1));
    expect(controller.value.position.inSeconds, greaterThanOrEqualTo(4));
    expect(controller.value.hasError, false);
    await binding.takeScreenshot('education-native-video');
    await controller.pause();
    final position = controller.value.position;
    await tester.tap(find.byTooltip(s.fullscreen));
    await tester.pumpAndSettle();
    expect(
      tester.widget<VideoPlayer>(find.byType(VideoPlayer)).controller,
      same(controller),
    );
    expect(controller.value.position, position);
    await binding.takeScreenshot('education-native-fullscreen');
    await tester.tap(find.byTooltip(s.exitFullscreen));
    await tester.pumpAndSettle();
    expect(controller.value.position, position);
    expect(find.byTooltip(s.fullscreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    api.close();
  });
}

class _Api extends ApiClient {
  _Api(AuthSession session)
    : super(session: session, baseUrl: 'http://127.0.0.1:8202/api/mobile');
  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String?> query = const {},
  }) async => {
    'data': {
      'id': 1,
      'title': 'Учебная работа',
      'category': 'Кихон',
      'coach_name': 'Тренер',
      'rank': '5 кю',
      'club': 'HAYABUSA',
      'is_review': true,
      'video_url': 'http://127.0.0.1:8202/api/mobile/files/education/works/1',
      'review': {
        'description': 'Тест воспроизведения',
        'point': '8.5',
        'detail_point': '9',
        'recommendation': 'Продолжать занятия',
      },
    },
  };
}
