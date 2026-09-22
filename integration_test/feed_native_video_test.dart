import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:video_player/video_player.dart';
import 'package:karaterating_trainer/feed/feed_media.dart';
import 'package:karaterating_trainer/feed/feed_models.dart';
import 'package:karaterating_trainer/l10n/app_locale.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('feed native video plays and seeks without bearer in URL', (
    tester,
  ) async {
    const s = AppStrings(AppLocale.ru);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FeedVideo(
            attachment: FeedAttachment(
              type: FeedAttachmentType.video,
              remoteUrl: 'http://127.0.0.1:8201/video.mp4',
            ),
            strings: s,
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
    final controller = tester
        .widget<VideoPlayer>(find.byType(VideoPlayer))
        .controller;
    await tester.tap(find.byTooltip(s.playPause));
    await tester.pump(const Duration(seconds: 2));
    expect(controller.value.position.inMilliseconds, greaterThan(0));
    await controller.seekTo(const Duration(seconds: 4));
    await tester.pump(const Duration(seconds: 1));
    expect(controller.value.position.inSeconds, greaterThanOrEqualTo(4));
    expect(controller.value.hasError, false);
    await binding.takeScreenshot('feed-native-video');
    await tester.pumpWidget(const SizedBox());
  });
}
