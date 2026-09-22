import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:karaterating_trainer/api/api_client.dart';
import 'package:karaterating_trainer/auth/auth_session.dart';
import 'package:karaterating_trainer/l10n/app_locale.dart';
import 'package:karaterating_trainer/media/protected_video_player.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native player reads authorized range stream and advances frames',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      final session = AuthSession(await SharedPreferences.getInstance());
      await session.signIn(
        email: 'test@example.test',
        remember: false,
        token: 'test-video',
      );
      final api = ApiClient(
        session: session,
        baseUrl: const String.fromEnvironment(
          'MEDIA_TEST_BASE',
          defaultValue: 'http://127.0.0.1:8199/api/mobile',
        ),
      );
      const s = AppStrings(AppLocale.ru);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ProtectedVideoPlayer(
                  api: api,
                  url: api.publicUrl('/api/mobile/files/kata/1/1'),
                  strings: s,
                ),
              ),
            ),
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
      expect(controller.value.hasError, false);
      await binding.takeScreenshot('kata-native-video');
      await tester.pumpWidget(const SizedBox());
      api.close();
    },
  );
}
