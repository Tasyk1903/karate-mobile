import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:karaterating_trainer/api/api_client.dart';
import 'package:karaterating_trainer/auth/auth_session.dart';
import 'package:karaterating_trainer/l10n/app_locale.dart';
import 'package:karaterating_trainer/theme/app_theme.dart';
import 'package:karaterating_trainer/tournaments/championship_documents_screen.dart';

void main() {
  late _Api api;
  const s = AppStrings(AppLocale.ru);
  final launched = <String>[];
  final shared = <Map>[];
  late Directory temp;
  bool shareFails = false;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    api = _Api(AuthSession(await SharedPreferences.getInstance()));
    launched.clear();
    shared.clear();
    shareFails = false;
    temp = await Directory.systemTemp.createTemp('kr-documents-widget-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => temp.path,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/share'),
          (call) async {
            if (shareFails) throw PlatformException(code: 'unavailable');
            final args = call.arguments as Map;
            for (final path in args['paths'] as List) {
              expect(await File(path as String).readAsBytes(), [
                37,
                80,
                68,
                70,
              ]);
            }
            shared.add(args);
            return '';
          },
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/url_launcher'),
          (call) async {
            if (call.method == 'launch') {
              launched.add((call.arguments as Map)['url'] as String);
            }
            return true;
          },
        );
  });
  tearDown(() async {
    api.close();
    await temp.delete(recursive: true);
    for (final channel in [
      'plugins.flutter.io/path_provider',
      'dev.fluttercommunity.plus/share',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(channel), null);
    }
  });

  Future<void> openDocuments(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChampionshipDocumentsScreen(
          api: api,
          strings: s,
          championshipId: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> finishWork(WidgetTester tester) async {
    await tester.runAsync(() async {
      for (var attempt = 0; attempt < 100; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
        if (find.byType(LinearProgressIndicator).evaluate().isEmpty) return;
      }
      fail('Document preparation did not finish');
    });
    await tester.pumpAndSettle();
  }

  testWidgets(
    'one native sheet receives all pages and an iPad anchor without any bearer URL',
    (tester) async {
      await openDocuments(tester);
      await tester.runAsync(
        () => tester.tap(find.byTooltip(s.shareAllDocuments)),
      );
      await tester.pump();
      await finishWork(tester);
      expect(api.pages, [1, 1, 2]);
      expect(shared, hasLength(1));
      expect(shared.single['paths'], hasLength(2));
      expect(shared.single['originWidth'], greaterThan(0));
      expect(shared.single['originHeight'], greaterThan(0));
      expect(shared.single.containsKey('uri'), isFalse);
      expect(shared.single.containsKey('text'), isFalse);
      expect(find.text('Документ 1'), findsOneWidget);
      expect(find.text('Документ 2'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed download shares nothing, preserves list and allows retry',
    (tester) async {
      await openDocuments(tester);
      api.failDownload = true;
      await tester.runAsync(
        () => tester.tap(find.byTooltip(s.shareAllDocuments)),
      );
      await tester.pump();
      await finishWork(tester);
      expect(shared, isEmpty);
      expect(find.text(s.documentShareFailed), findsOneWidget);
      expect(find.text('Документ 1'), findsOneWidget);
      api.failDownload = false;
      await tester.runAsync(
        () => tester.tap(find.byTooltip(s.shareAllDocuments)),
      );
      await tester.pump();
      await finishWork(tester);
      expect(shared, hasLength(1));
    },
  );

  testWidgets('native share failure is reported and incomplete cache removed', (
    tester,
  ) async {
    await openDocuments(tester);
    shareFails = true;
    await tester.runAsync(
      () => tester.tap(find.byTooltip(s.shareAllDocuments)),
    );
    await tester.pump();
    await finishWork(tester);
    expect(shared, isEmpty);
    expect(find.text(s.documentShareFailed), findsOneWidget);
    expect(
      await tester.runAsync(
        () => Directory('${temp.path}/championship-shares').list().toList(),
      ),
      isEmpty,
    );
  });

  testWidgets(
    'cancel during download blocks duplicate taps and never opens share sheet',
    (tester) async {
      await openDocuments(tester);
      api.downloadGate = Completer<void>();
      await tester.runAsync(() async {
        await tester.tap(find.byTooltip(s.shareAllDocuments));
        await api.downloadStarted.future;
      });
      await tester.pump();
      expect(find.text(s.documentShareProgress(0, 2)), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.share_outlined),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip(s.cancel));
      await finishWork(tester);
      // The UI cancels immediately, without waiting for the in-flight response.
      await tester.runAsync(() async => api.downloadGate!.complete());
      expect(shared, isEmpty);
      expect(find.text(s.documentShareFailed), findsNothing);
      expect(api.downloads, 1);
    },
  );
  testWidgets('leaving during preparation never opens a share sheet later', (
    tester,
  ) async {
    await openDocuments(tester);
    api.downloadGate = Completer<void>();
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip(s.shareAllDocuments));
      await api.downloadStarted.future;
    });
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      api.downloadGate!.complete();
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
    expect(shared, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'documents paginate retry the same page and open only a signed link',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChampionshipDocumentsScreen(
            api: api,
            strings: s,
            championshipId: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Документ 1'), findsOneWidget);
      api.failPage = 2;
      await tester.tap(find.text(s.moreRecords));
      await tester.pumpAndSettle();
      expect(find.text('Документ 1'), findsOneWidget);
      api.failPage = null;
      await tester.tap(find.text(s.retry));
      await tester.pumpAndSettle();
      expect(api.pages, [1, 2, 2]);
      expect(find.text('Документ 2'), findsOneWidget);
      await tester.tap(find.text(s.openDocument).first);
      await tester.pumpAndSettle();
      expect(launched.single, 'https://example.test/open?signature=limited');
      api.failPage = 1;
      final refresh = tester
          .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
          .show();
      await tester.pumpAndSettle();
      await refresh;
      expect(find.text('Документ 2'), findsOneWidget);
      api.failPage = null;
      await tester.tap(find.text(s.retry));
      await tester.pumpAndSettle();
      expect(api.pages, [1, 2, 2, 1, 1]);
      expect(find.text('Документ 2'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('documents fit both themes locales and phone widths', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    api.longTitle = true;
    for (final width in [360.0, 393.0, 430.0]) {
      for (final locale in AppLocale.values) {
        for (final dark in [false, true]) {
          tester.view.physicalSize = Size(width, 852);
          tester.view.devicePixelRatio = 1;
          await tester.pumpWidget(const SizedBox());
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? AppTheme.dark() : AppTheme.light(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(1.35)),
                child: child!,
              ),
              home: ChampionshipDocumentsScreen(
                api: api,
                strings: AppStrings(locale),
                championshipId: 1,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '$width $locale $dark',
          );
        }
      }
    }
  });
}

class _Api extends ApiClient {
  _Api(AuthSession session) : super(session: session);
  final pages = <int>[];
  int? failPage;
  bool longTitle = false;
  bool failDownload = false;
  int downloads = 0;
  Completer<void>? downloadGate;
  final downloadStarted = Completer<void>();
  @override
  Future<List<int>> getBytes(
    String path, {
    Map<String, String?> query = const {},
  }) async {
    downloads++;
    if (!downloadStarted.isCompleted) downloadStarted.complete();
    await downloadGate?.future;
    if (failDownload) throw const ApiException('Failed', statusCode: 503);
    return [37, 80, 68, 70];
  }

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String?> query = const {},
  }) async {
    if (path.endsWith('/link')) {
      return {'url': 'https://example.test/open?signature=limited'};
    }
    final page = int.parse(query['page']!);
    pages.add(page);
    if (page == failPage) {
      throw const ApiException('Network error', statusCode: 503);
    }
    return {
      'data': [
        {
          'id': page,
          'name': longTitle
              ? 'Положение о международном чемпионате по киокушинкай / International championship regulations'
              : 'Документ $page',
          'file_name': '$page-document.pdf',
          'extension': 'pdf',
        },
      ],
      'meta': {'last_page': 2},
    };
  }
}
