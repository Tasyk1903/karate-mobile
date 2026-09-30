import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:karaterating_trainer/api/api_client.dart';
import 'package:karaterating_trainer/app/karate_rating_app.dart';
import 'package:karaterating_trainer/app/launch_splash.dart';
import 'package:karaterating_trainer/auth/auth_session.dart';
import 'package:karaterating_trainer/auth/login_screen.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'launch logo stays briefly then yields to login without replay on resume',
    (tester) async {
      await tester.pumpWidget(
        KarateRatingApp(
          prefs: await SharedPreferences.getInstance(),
          apiFactory: (session) => _DelayedApi(session),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(LaunchSplash), findsOneWidget);
      expect(find.byType(LoginScreen).hitTestable(), findsNothing);
      await tester.pumpAndSettle();
      expect(find.byType(LaunchSplash), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.byType(LaunchSplash), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('slow restoration keeps logo and network failure opens retry', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await AuthSession(prefs)
        .signIn(email: 'test@example.test', remember: true, token: 'test-only');
    late _DelayedApi api;
    await tester.pumpWidget(
      KarateRatingApp(
        prefs: prefs,
        apiFactory: (session) => api = _DelayedApi(session),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LaunchSplash), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    api.identity.completeError(const ApiException('Offline', statusCode: 503));
    await tester.pumpAndSettle();
    expect(find.byType(LaunchSplash), findsNothing);
    expect(find.text('Повторить'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('logo is centered on white in both themes and phone sizes', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    for (final width in [360.0, 393.0, 430.0]) {
      for (final dark in [false, true]) {
        tester.view.physicalSize = Size(width, 852);
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? ThemeData.dark() : ThemeData.light(),
            home: RepaintBoundary(key: key, child: const LaunchSplash()),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
          Colors.white,
        );
        expect(tester.getCenter(find.byType(Image)), Offset(width / 2, 426));
        expect(tester.getSize(find.byType(Image)), const Size(192, 192));
        expect(tester.takeException(), isNull);
        if (width == 393 && !dark) {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await boundary.toImage();
            final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
            final file = File('build/auth-screenshots/launch-splash.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      }
    }
  });

  test('native launch screens use the same unmodified KR asset', () {
    final source = File('assets/images/kr.jpg').readAsBytesSync();
    expect(
      File('ios/Runner/Assets.xcassets/LaunchLogo.imageset/kr.jpg')
          .readAsBytesSync(),
      source,
    );
    expect(
      File('android/app/src/main/res/drawable-nodpi/kr_launch.jpg')
          .readAsBytesSync(),
      source,
    );
  });
}

class _DelayedApi extends ApiClient {
  _DelayedApi(AuthSession session) : super(session: session);
  final identity = Completer<Map<String, dynamic>>();

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String?> query = const {},
  }) => identity.future;
}
