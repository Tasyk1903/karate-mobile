import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:karaterating_trainer/api/api_client.dart';
import 'package:karaterating_trainer/api/video_upload.dart';
import 'package:karaterating_trainer/auth/auth_session.dart';
import 'package:karaterating_trainer/l10n/app_locale.dart';
import 'package:karaterating_trainer/theme/app_theme.dart';
import 'package:karaterating_trainer/tournaments/kata_payments_panel.dart';
import 'package:karaterating_trainer/tournaments/kata_payment_return_screen.dart';
import 'package:karaterating_trainer/tournaments/kata_video_upload_sheet.dart';
import 'package:karaterating_trainer/media/protected_video_player.dart';
import 'package:karaterating_trainer/tournaments/tournament_models.dart';

void main() => kataPaymentTests();

void kataPaymentTests({Future<void> Function(String)? screenshot}) {
  late PaymentTestApi api;
  late Directory temp;
  late ImagePickerPlatform oldPicker;
  late VideoPlayerPlatform oldPlayer;
  const s = AppStrings(AppLocale.ru);
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    final session = AuthSession(await SharedPreferences.getInstance());
    await session.signIn(
      email: 'test@example.test',
      remember: false,
      token: 'test-video',
    );
    api = PaymentTestApi(session);
    temp = await Directory.systemTemp.createTemp('kata-video-test');
    final file = await File('${temp.path}/video.mp4').writeAsBytes([0, 1, 2]);
    oldPicker = ImagePickerPlatform.instance;
    oldPlayer = VideoPlayerPlatform.instance;
    ImagePickerPlatform.instance = _Picker(file.path);
  });
  tearDown(() async {
    ImagePickerPlatform.instance = oldPicker;
    VideoPlayerPlatform.instance = oldPlayer;
    api.close();
    await temp.delete(recursive: true);
  });

  test(
    'payment link accepts only explicit UUID route and never a web/token URL',
    () {
      const id = 'ab123456-1234-1234-1234-123456789012';
      expect(kataPaymentId(Uri.parse('karaterating://payment/$id')), id);
      expect(
        kataPaymentId(Uri.parse('https://example.test/payment/$id')),
        null,
      );
      expect(
        kataPaymentId(Uri.parse('karaterating://payment/not-an-id')),
        null,
      );
    },
  );

  testWidgets(
    'payment state survives recreation and resume; canceled retry is confirmed',
    (tester) async {
      final key = GlobalKey<KataPaymentsPanelState>();
      var fulfilled = 0;
      Widget screen() => MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                KataPaymentsPanel(
                  key: key,
                  api: api,
                  strings: s,
                  tournamentId: 2,
                  onFulfilled: () async {
                    fulfilled++;
                  },
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      expect(find.text(s.kataPaymentStatus('pending')), findsOneWidget);
      await screenshot?.call('kata-payment-pending');
      api.status = 'fulfilled';
      await key.currentState!.refresh();
      await tester.pumpAndSettle();
      expect(find.text(s.kataPaymentStatus('fulfilled')), findsOneWidget);
      expect(fulfilled, 1);
      await tester.pumpWidget(const SizedBox());
      api.status = 'canceled';
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      expect(find.text(s.kataPaymentStatus('canceled')), findsOneWidget);
      await tester.tap(find.text(s.paymentRetryTitle));
      await tester.pumpAndSettle();
      expect(api.retries, 0);
      await tester.tap(find.text(s.save));
      await tester.pumpAndSettle();
      expect(api.retries, 1);
      api.status = 'conflict';
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text(s.paymentConflictHelp), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      await screenshot?.call('kata-payment-conflict');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'compact upload keeps full category, progress, cancel and retry',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  child: const Text('Open'),
                  onPressed: () => showModalBottomSheet<Map<String, dynamic>>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => KataVideoUploadSheet(
                      api: api,
                      strings: s,
                      path: '/upload',
                      title: s.uploadFinalVideo,
                      name: 'Колесников Савва',
                      categoryField: 'category_id',
                      categoryId: 2,
                      submitLabel: s.save,
                      categories: [
                        TournamentEducationCategory.fromJson({
                          'id': 2,
                          'name': 'Тайкёку соно сан · Полное длинное название категории',
                        }),
                      ],
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
      await tester.runAsync(() async {
        await tester.tap(find.text(s.chooseVideo));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(find.text(s.videoSelected), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, s.save));
      await tester.pump();
      expect(find.text('50%'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      await screenshot?.call('kata-video-upload-progress');
      await tester.tap(find.widgetWithText(TextButton, s.cancel));
      api.uploadResult!.completeError(const ApiException('cancel'));
      await tester.pumpAndSettle();
      expect(api.upload!.canceled, true);
      expect(find.text(s.uploadCanceled), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, s.save));
      await tester.pump();
      api.uploadResult!.complete({'ok': true});
      await tester.pumpAndSettle();
      expect(find.byType(KataVideoUploadSheet), findsNothing);
      expect(api.fields!['category_id'], '2');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'owned video uses authenticated stream and supports play; foreign URL never creates player',
    (tester) async {
      final platform = _VideoPlatform();
      VideoPlayerPlatform.instance = platform;
      Widget screen(String url) => MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: ProtectedVideoPlayer(api: api, url: url, strings: s),
          ),
        ),
      );
      await tester.pumpWidget(
        screen('https://example.test/api/mobile/files/kata/1/1'),
      );
      await tester.pumpAndSettle();
      expect(
        platform.source?.httpHeaders['Authorization'],
        'Bearer test-video',
      );
      await tester.tap(find.byTooltip(s.playPause));
      await tester.pump();
      expect(platform.played, true);
      await tester.tap(find.byTooltip(s.fullscreen));
      await tester.pumpAndSettle();
      expect(platform.created, 1);
      expect(
        platform.source?.httpHeaders['Authorization'],
        'Bearer test-video',
      );
      await tester.tap(find.byTooltip(s.exitFullscreen));
      await tester.pumpAndSettle();
      expect(find.byTooltip(s.fullscreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      final before = platform.created;
      await tester.pumpWidget(screen('https://foreign.test/video.mp4'));
      await tester.pumpAndSettle();
      expect(platform.created, before);
      expect(find.text(s.videoUnavailable), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

class PaymentTestApi extends ApiClient {
  PaymentTestApi(AuthSession session)
    : super(session: session, baseUrl: 'https://example.test/api/mobile');
  String status = 'pending';
  int retries = 0;
  bool retryAllowed = true;
  VideoUpload? upload;
  Completer<Map<String, dynamic>>? uploadResult;
  Map<String, String>? fields;
  Map<String, dynamic> get payment => {
    'id': 'ab123456-1234-1234-1234-123456789012',
    'student_id': 1,
    'student_name': 'Колесников Савва',
    'tournament_id': 2,
    'championship_id': 1,
    'status': status,
    'can_retry': status == 'canceled' && retryAllowed,
  };
  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String?> query = const {},
  }) async => path.endsWith('/applications')
      ? {
          'data': [payment],
          'meta': {'last_page': 1},
        }
      : {'payment': payment};
  @override
  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic> body = const {},
    bool authenticated = true,
  }) async {
    retries++;
    retryAllowed = false;
    return {'ok': true};
  }

  @override
  Future<Map<String, dynamic>> uploadVideo(
    String path, {
    required Map<String, String> fields,
    required File file,
    required VideoUpload upload,
    required void Function(double) onProgress,
  }) async {
    this.fields = fields;
    this.upload = upload;
    uploadResult = Completer<Map<String, dynamic>>();
    onProgress(0.5);
    return uploadResult!.future;
  }
}

class _Picker extends ImagePickerPlatform {
  _Picker(this.path);
  final String path;
  @override
  Future<XFile?> getVideo({
    required ImageSource source,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    Duration? maxDuration,
  }) async => XFile(path);
}

class _VideoPlatform extends VideoPlayerPlatform {
  DataSource? source;
  bool played = false;
  int created = 0;
  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    source = options.dataSource;
    return ++created;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => Stream.value(
    VideoEvent(
      eventType: VideoEventType.initialized,
      duration: const Duration(seconds: 10),
      size: const Size(320, 180),
    ),
  );
  @override
  Future<void> dispose(int playerId) async {}
  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> play(int playerId) async {
    played = true;
  }

  @override
  Future<void> pause(int playerId) async {}
  @override
  Future<void> setVolume(int playerId, double volume) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;
  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const ColoredBox(color: Colors.black);
}
