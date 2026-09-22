import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:karaterating_trainer/l10n/app_locale.dart';
import 'package:karaterating_trainer/media/video_player_surface.dart';
import 'package:karaterating_trainer/theme/app_theme.dart';

import 'education_test.dart' show EducationVideoPlatform;

void main() {
  testWidgets(
    'fullscreen keeps controller and position, controls work, back restores inline',
    (tester) async {
      final original = VideoPlayerPlatform.instance;
      final platform = _Platform();
      VideoPlayerPlatform.instance = platform;
      addTearDown(() => VideoPlayerPlatform.instance = original);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = VideoPlayerController.networkUrl(
        Uri.parse('https://example.test/video'),
      );
      await controller.initialize();
      for (final width in [360.0, 393.0, 430.0]) {
        for (final locale in [AppLocale.ru, AppLocale.en]) {
          for (final dark in [false, true]) {
            for (final ratio in [16 / 9, 9 / 16]) {
              tester.view.physicalSize = Size(width, 852);
              controller.value = controller.value.copyWith(
                size: Size(320 * ratio, 320),
              );
              final s = AppStrings(locale);
              await tester.pumpWidget(
                MaterialApp(
                  theme: dark ? AppTheme.dark() : AppTheme.light(),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: const TextScaler.linear(2)),
                    child: child!,
                  ),
                  home: Scaffold(
                    body: VideoPlayerSurface(
                      controller: controller,
                      strings: s,
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              await controller.seekTo(const Duration(seconds: 4));
              await tester.tap(find.byTooltip(s.fullscreen));
              await tester.pumpAndSettle();
              expect(find.byType(VideoPlayer), findsOneWidget);
              expect(
                tester.widget<VideoPlayer>(find.byType(VideoPlayer)).controller,
                same(controller),
              );
              expect(controller.value.position, const Duration(seconds: 4));
              expect(tester.getSize(find.byType(Scaffold).last).height, 852);
              await tester.tap(find.byTooltip(s.playPause));
              await tester.pump();
              expect(controller.value.isPlaying, true);
              await tester.tap(find.byTooltip(s.muteVideo));
              await tester.pump();
              expect(controller.value.volume, 0);
              await tester.tap(find.byTooltip(s.playPause));
              await tester.pump();
              expect(controller.value.isPlaying, false);
              // Fullscreen adapts without cropping when the phone rotates.
              tester.view.physicalSize = Size(852, width);
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
              await tester.tap(find.byTooltip(s.exitFullscreen));
              await tester.pumpAndSettle();
              expect(find.byTooltip(s.fullscreen), findsOneWidget);
              expect(controller.value.position, const Duration(seconds: 4));
              expect(platform.created, 1);
              await tester.tap(find.byTooltip(s.fullscreen));
              await tester.pumpAndSettle();
              await tester.binding.handlePopRoute();
              await tester.pumpAndSettle();
              expect(find.byTooltip(s.fullscreen), findsOneWidget);
              await controller.setVolume(1);
              await tester.pumpWidget(const SizedBox());
            }
          }
        }
      }
      await tester.runAsync(controller.dispose);
    },
  );
}

class _Platform extends EducationVideoPlatform {
  Duration position = Duration.zero;
  @override
  Future<void> seekTo(int playerId, Duration position) async {
    this.position = position;
  }

  @override
  Future<Duration> getPosition(int playerId) async => position;
}
