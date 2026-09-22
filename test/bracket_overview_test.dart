import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:karaterating_trainer/auth/auth_session.dart';
import 'package:karaterating_trainer/l10n/app_locale.dart';
import 'package:karaterating_trainer/theme/app_theme.dart';
import 'package:karaterating_trainer/tournaments/bracket_overview.dart';
import 'package:karaterating_trainer/tournaments/tournament_bracket_screen.dart';
import 'package:karaterating_trainer/tournaments/tournament_models.dart';

import 'tournament_spectator_test.dart' show SpectatorApi;

Map<String, dynamic> fixture(int participants) {
  var count = participants ~/ 2, round = 1, id = 0;
  final rounds = <Map<String, dynamic>>[];
  Map<String, dynamic> pool(int position, int round) => {
    'id': ++id,
    'round': round,
    'position': position,
    'fight_number': 'A-$id',
    'winner_id': 526,
    'student': {
      'id': 526,
      'name': 'Галстян Григорий Александрович',
      'club': 'Клуб киокушинкай HAYABUSA',
    },
    'opponent': {
      'id': 2,
      'name': 'Александр Длиннаяфамилия',
      'club': 'Спортивная школа единоборств',
    },
  };
  while (count > 0) {
    rounds.add({
      'number': round,
      'title': count == 1 ? 'Финал' : '1/$count',
      'pools': [for (var p = 1; p <= count; p++) pool(p, round)],
    });
    count ~/= 2;
    round++;
  }
  return {
    'kind': 'kumite',
    'title': 'Юноши 16–17 лет · весовая категория 65+ кг',
    'tatami': 'A',
    'rounds': rounds,
    if (participants >= 4) 'third_place': pool(1, round),
    'podium': [
      {
        'place': 1,
        'participant': {'id': 526, 'name': 'Галстян Григорий Александрович'},
      },
    ],
  };
}

void main() {
  const font = String.fromEnvironment('SCREENSHOT_FONT');
  setUpAll(() async {
    if (font.isNotEmpty) {
      await (FontLoader(
        'OverviewTest',
      )..addFont(File(font).readAsBytes().then(ByteData.sublistView))).load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });
  test('positions, connectors and third place remain disjoint for 2 through 64 entrants', () {
    for (final count in [2, 4, 8, 16, 32, 64]) {
      final detail = TournamentBracketDetail.fromJson(fixture(count));
      final layout = BracketOverviewLayout(detail, 180);
      expect(layout.connections.length, count - 2);
      for (var i = 0; i < layout.nodes.length; i++) {
        final a = layout.nodes[i];
        expect(
          (Offset.zero & layout.size).contains(a.rect.bottomRight),
          isTrue,
        );
        for (final b in layout.nodes.skip(i + 1)) {
          expect(
            a.rect.overlaps(b.rect),
            isFalse,
            reason: '$count: ${a.pool.id}/${b.pool.id}',
          );
        }
      }
      if (count >= 4) {
        final finalNode = layout.nodes.firstWhere(
          (n) => !n.third && n.pool.round == detail.rounds.last.number,
        );
        final bronze = layout.nodes.firstWhere((n) => n.third);
        expect(bronze.rect.center.dy, finalNode.rect.center.dy);
        expect(bronze.rect.right, lessThan(finalNode.rect.left));
      }
    }
    final data = fixture(8);
    final rounds = data['rounds'] as List;
    (rounds.first['pools'] as List).removeAt(0);
    final sparse = BracketOverviewLayout(
      TournamentBracketDetail.fromJson(data),
      180,
    );
    expect(sparse.nodes.first.pool.position, 2);
    expect(sparse.connections.length, 5);
  });

  test('every connector joins the participant rail, with only right-angle segments', () {
    for (final count in [2, 4, 8, 16, 32, 64]) {
      for (final header in [30.0, 54.0]) {
        final layout = BracketOverviewLayout(
          TournamentBracketDetail.fromJson(fixture(count)),
          180 + header,
          headerHeight: header,
        );
        var connection = 0;
        for (final node in layout.nodes) {
          expect(node.studentLine.dy, node.rect.top + header + node.rowHeight);
          expect(node.opponentLine.dy, node.rect.bottom);
          expect(
            node.output.dy,
            (node.studentLine.dy + node.opponentLine.dy) / 2,
          );
          final rail = node.rails.computeMetrics().single;
          expect(
            (rail.getTangentForOffset(0)!.position - node.studentLine).distance,
            lessThan(.001),
          );
          expect(
            (rail.getTangentForOffset(rail.length)!.position -
                    node.opponentLine)
                .distance,
            lessThan(.001),
          );
          if (node.third) continue;
          final targets = layout.nodes.where(
            (n) =>
                !n.third &&
                n.pool.round == node.pool.round + 1 &&
                n.pool.position == (node.pool.position + 1) ~/ 2,
          );
          if (targets.isEmpty) continue;
          final end = node.pool.position.isOdd
              ? targets.single.studentLine
              : targets.single.opponentLine;
          final metric = layout.connections[connection++]
              .computeMetrics()
              .single;
          expect(
            (metric.getTangentForOffset(0)!.position - node.output).distance,
            lessThan(.001),
          );
          expect(
            (metric.getTangentForOffset(metric.length)!.position - end)
                .distance,
            lessThan(.001),
          );
          expect(
            metric.length,
            closeTo(
              (end.dx - node.output.dx).abs() + (end.dy - node.output.dy).abs(),
              .001,
            ),
          );
          for (var fraction = .05; fraction < 1; fraction += .1) {
            final vector = metric
                .getTangentForOffset(metric.length * fraction)!
                .vector;
            expect(vector.dx.abs() < .001 || vector.dy.abs() < .001, isTrue);
          }
        }
        expect(connection, layout.connections.length);
      }
    }
  });

  testWidgets(
    'overview fits, zooms, pans and opens fights across phone themes and locales',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final width in [360.0, 393.0, 430.0]) {
        for (final locale in AppLocale.values) {
          for (final dark in [false, true]) {
            tester.view.physicalSize = Size(width, 852);
            tester.view.devicePixelRatio = 1;
            final s = AppStrings(locale);
            final key = GlobalKey();
            int? opened;
            var theme = dark ? AppTheme.dark() : AppTheme.light();
            if (font.isNotEmpty) {
              theme = theme.copyWith(
                textTheme: theme.textTheme.apply(fontFamily: 'OverviewTest'),
              );
            }
            await tester.pumpWidget(
              MaterialApp(
                theme: theme,
                home: MediaQuery(
                  data: MediaQueryData(
                    size: Size(width, 852),
                    textScaler: const TextScaler.linear(1.6),
                  ),
                  child: RepaintBoundary(
                    key: key,
                    child: Scaffold(
                      body: SafeArea(
                        child: BracketOverview(
                          detail: TournamentBracketDetail.fromJson(fixture(16)),
                          strings: s,
                          heading: 'Кубок России FKK\nКумитэ',
                          onOpenFight: (p) => opened = p.id,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            final viewer = tester.widget<InteractiveViewer>(
              find.byType(InteractiveViewer),
            );
            final fit = viewer.transformationController!.value.clone();
            await tester.tap(find.byKey(const ValueKey('overview-fight-1')));
            await tester.pumpAndSettle();
            expect(opened, 1);
            await tester.tap(find.byTooltip(s.zoomIn));
            await tester.pumpAndSettle();
            expect(
              viewer.transformationController!.value.getMaxScaleOnAxis(),
              greaterThan(fit.getMaxScaleOnAxis()),
            );
            await tester.drag(
              find.byType(InteractiveViewer),
              const Offset(35, 25),
            );
            await tester.pumpAndSettle();
            expect(viewer.transformationController!.value, isNot(fit));
            await tester.tap(find.byTooltip(s.fitBracket));
            await tester.pumpAndSettle();
            expect(viewer.transformationController!.value, fit);
            if (width == 393 &&
                locale == AppLocale.ru &&
                const bool.fromEnvironment('SAVE_SCREENSHOTS')) {
              await tester.runAsync(() async {
                final rendered =
                    await (key.currentContext!.findRenderObject()
                            as RenderRepaintBoundary)
                        .toImage(pixelRatio: 2);
                final bytes = await rendered.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                final file = File(
                  'build/scope-screenshots/bracket-overview-${dark ? 'dark' : 'light'}.png',
                );
                await file.parent.create(recursive: true);
                await file.writeAsBytes(bytes!.buffer.asUint8List());
                rendered.dispose();
              });
            }
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
          }
        }
      }
    },
  );

  testWidgets(
    'switching keeps selected round and opens read-only fight details',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final api = SpectatorApi(
        AuthSession(await SharedPreferences.getInstance()),
      );
      addTearDown(api.close);
      const s = AppStrings(AppLocale.ru);
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: TournamentBracketScreen(
            api: api,
            strings: s,
            championship: Championship.fromJson({'id': 1}),
            tournament: TournamentItem.fromJson({'id': 2}),
            table: TournamentTableItem.fromJson({'id': 3}),
            initialRound: 2,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Финал'), findsOneWidget);
      await tester.tap(find.text(s.bracketOverview));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('overview-fight-5')));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      Navigator.of(tester.element(find.byType(BottomSheet))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text(s.bracketRounds));
      await tester.pumpAndSettle();
      expect(
        tester.widget<PageView>(find.byType(PageView)).controller!.page,
        1,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'round robin and kata retain their own views without elimination tree',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final api = _NonEliminationApi(
        AuthSession(await SharedPreferences.getInstance()),
      );
      addTearDown(api.close);
      for (final kata in [false, true]) {
        api.kata = kata;
        await tester.pumpWidget(
          MaterialApp(
            home: TournamentBracketScreen(
              api: api,
              strings: const AppStrings(AppLocale.en),
              championship: Championship.fromJson({'id': 1}),
              tournament: TournamentItem.fromJson({'id': 2}),
              table: TournamentTableItem.fromJson({'id': 3}),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(SegmentedButton<bool>), findsNothing);
        expect(find.byType(BracketOverview), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );
}

class _NonEliminationApi extends SpectatorApi {
  _NonEliminationApi(super.session);
  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String?> query = const {},
  }) async {
    return {
      ...await super.getJson(path, query: query),
      'is_round_robin': !kata,
    };
  }
}
