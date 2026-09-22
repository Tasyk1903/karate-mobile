import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_locale.dart';
import '../theme/app_colors.dart';
import 'tournament_models.dart';

class BracketNode {
  const BracketNode(
    this.pool,
    this.rect, {
    this.third = false,
    this.headerHeight = 30,
  });
  final TournamentBracketPool pool;
  final Rect rect;
  final bool third;
  final double headerHeight;
  double get rowHeight => (rect.height - headerHeight) / 2;
  Offset get studentLine =>
      Offset(rect.left, rect.top + headerHeight + rowHeight);
  Offset get opponentLine => rect.bottomLeft;
  Offset get output =>
      Offset(rect.right + 12, (studentLine.dy + opponentLine.dy) / 2);

  Path get rails => Path()
    ..moveTo(studentLine.dx, studentLine.dy)
    ..lineTo(output.dx, studentLine.dy)
    ..lineTo(output.dx, opponentLine.dy)
    ..lineTo(opponentLine.dx, opponentLine.dy);
}

/// Coordinates use bracket positions, not array indices: byes retain their slots.
class BracketOverviewLayout {
  BracketOverviewLayout(
    TournamentBracketDetail detail,
    double nodeHeight, {
    double top = 170,
    double headerHeight = 30,
  }) {
    final rounds = [...detail.rounds]
      ..sort((a, b) => a.number.compareTo(b.number));
    if (rounds.isEmpty) return;
    final first = rounds.first.number;
    final last = rounds.last.number;
    var slots = math.pow(2, last - first).toInt();
    for (final round in rounds) {
      for (final pool in round.pools) {
        slots = math.max(
          slots,
          pool.position * math.pow(2, round.number - first).toInt(),
        );
      }
    }
    final pitch = nodeHeight + 48;
    final centralGap = detail.thirdPlace == null ? 0.0 : nodeHeight + 60;
    for (final round in rounds) {
      final level = round.number - first;
      final span = math.pow(2, level).toDouble();
      for (final pool in round.pools) {
        final start = (pool.position - 1) * span;
        final end = start + span;
        final below = start >= slots / 2 ? 1.0 : (end <= slots / 2 ? 0.0 : .5);
        final y = top + (start + span / 2) * pitch + centralGap * below;
        nodes.add(
          BracketNode(
            pool,
            Rect.fromLTWH(
              24 + level * step,
              y - nodeHeight / 2,
              width,
              nodeHeight,
            ),
            headerHeight: headerHeight,
          ),
        );
      }
    }
    final finals = nodes.where(
      (n) => n.pool.round == last && n.pool.position == 1,
    );
    if (detail.thirdPlace != null && finals.isNotEmpty) {
      final finalRect = finals.first.rect;
      nodes.add(
        BracketNode(
          detail.thirdPlace!,
          Rect.fromLTWH(
            math.max(24, finalRect.left - step),
            finalRect.top,
            width,
            nodeHeight,
          ),
          third: true,
          headerHeight: headerHeight,
        ),
      );
    }
    for (final node in nodes.where((n) => !n.third)) {
      final targets = nodes.where(
        (n) =>
            !n.third &&
            n.pool.round == node.pool.round + 1 &&
            n.pool.position == (node.pool.position + 1) ~/ 2,
      );
      if (targets.isEmpty) continue;
      final target = targets.first;
      final a = node.output;
      final b = node.pool.position.isOdd
          ? target.studentLine
          : target.opponentLine;
      final elbow = (a.dx + b.dx) / 2;
      connections.add(
        Path()
          ..moveTo(a.dx, a.dy)
          ..lineTo(elbow, a.dy)
          ..lineTo(elbow, b.dy)
          ..lineTo(b.dx, b.dy),
      );
    }
    size = Size(
      48 + (last - first) * step + width,
      nodes.fold<double>(top, (v, n) => math.max(v, n.rect.bottom)) + 32,
    );
  }

  static const width = 260.0, step = 304.0;
  final nodes = <BracketNode>[];
  final connections = <Path>[];
  Size size = Size.zero;
}

class BracketOverview extends StatefulWidget {
  const BracketOverview({
    super.key,
    required this.detail,
    required this.strings,
    required this.heading,
    required this.onOpenFight,
  });
  final TournamentBracketDetail detail;
  final AppStrings strings;
  final String heading;
  final ValueChanged<TournamentBracketPool> onOpenFight;

  @override
  State<BracketOverview> createState() => _BracketOverviewState();
}

class _BracketOverviewState extends State<BracketOverview> {
  final _transform = TransformationController();
  Size? _viewport, _content;
  double _fit = 1;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _reset() {
    if (_viewport == null || _content == null) return;
    _transform.value = Matrix4.identity()
      ..translateByDouble(
        (_viewport!.width - _content!.width * _fit) / 2,
        (_viewport!.height - _content!.height * _fit) / 2,
        0,
        1,
      )
      ..scaleByDouble(_fit, _fit, 1, 1);
  }

  void _zoom(double factor) {
    final center = _viewport!.center(Offset.zero);
    final scene = _transform.toScene(center);
    final scale = (_transform.value.getMaxScaleOnAxis() * factor).clamp(
      _fit,
      4.0,
    );
    _transform.value = Matrix4.identity()
      ..translateByDouble(
        center.dx - scene.dx * scale,
        center.dy - scene.dy * scale,
        0,
        1,
      )
      ..scaleByDouble(scale, scale, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    final scaler = MediaQuery.textScalerOf(context);
    final nameStyle = Theme.of(context).textTheme.bodyMedium!.copyWith(
      fontSize: 12,
      height: 1.25,
      fontWeight: FontWeight.w600,
      color: AppColors.inkFor(context),
    );
    final clubStyle = nameStyle.copyWith(
      fontSize: 10,
      fontWeight: FontWeight.w400,
      color: AppColors.mutedFor(context),
    );
    double textHeight(String text, TextStyle style, double width) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: scaler,
      )..layout(maxWidth: width);
      final height = painter.height;
      painter.dispose();
      return height;
    }

    final pools = [
      ...widget.detail.rounds.expand((r) => r.pools),
      if (widget.detail.thirdPlace != null) widget.detail.thirdPlace!,
    ];
    var rowHeight = 54.0;
    var labelHeight = scaler.scale(16);
    for (final p in pools) {
      labelHeight = math.max(
        labelHeight,
        textHeight(
          '${s.thirdPlace} · ${p.fightNumber ?? '${s.fight} #${p.position}'}',
          clubStyle,
          BracketOverviewLayout.width,
        ),
      );
      for (final person in [p.student, p.opponent]) {
        rowHeight = math.max(
          rowHeight,
          textHeight(person?.name ?? s.freePlace, nameStyle, 206) +
              textHeight(person?.club ?? '-', clubStyle, 206) +
              16,
        );
      }
    }
    final heading = [
      widget.heading.trim(),
      widget.detail.title,
      if ((widget.detail.tatami ?? '').isNotEmpty)
        '${s.tatami} ${widget.detail.tatami}',
    ].where((v) => v.isNotEmpty).join('\n');
    final headingHeight = textHeight(
      heading,
      nameStyle.copyWith(fontSize: 16),
      math.min(
        500,
        260 + (widget.detail.rounds.length - 1) * BracketOverviewLayout.step,
      ),
    );
    final layout = BracketOverviewLayout(
      widget.detail,
      rowHeight * 2 + labelHeight + 12,
      top: headingHeight + 82,
      headerHeight: labelHeight + 12,
    );
    final resultHeight = widget.detail.podium.fold<double>(
      0,
      (h, p) =>
          h +
          textHeight(
            '${p.place}. ${p.participant.name}',
            nameStyle,
            layout.size.width - 48,
          ) +
          8,
    );
    final contentSize = Size(
      layout.size.width,
      layout.size.height +
          (widget.detail.podium.isEmpty ? 0 : resultHeight + 56),
    );
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final viewport = constraints.biggest;
              if (_viewport != viewport || _content != contentSize) {
                _viewport = viewport;
                _content = contentSize;
                _fit = math.min(
                  1,
                  math.min(
                    viewport.width / contentSize.width,
                    viewport.height / contentSize.height,
                  ),
                );
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _reset();
                });
              }
              return ColoredBox(
                color: AppColors.surfaceFor(context),
                child: InteractiveViewer(
                  key: const ValueKey('bracket-overview-viewer'),
                  transformationController: _transform,
                  constrained: false,
                  alignment: Alignment.topLeft,
                  boundaryMargin: const EdgeInsets.all(160),
                  minScale: _fit,
                  maxScale: 4,
                  child: SizedBox(
                    width: contentSize.width,
                    height: contentSize.height,
                    child: Stack(
                      children: [
                        Positioned(
                          left: 24,
                          top: 20,
                          width: math.min(500, contentSize.width - 48),
                          child: Text(
                            heading,
                            style: nameStyle.copyWith(
                              fontSize: 16,
                              color: AppColors.accentFor(context),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _BracketLines([
                                ...layout.nodes.map((n) => n.rails),
                                ...layout.connections,
                              ], AppColors.mutedFor(context)),
                            ),
                          ),
                        ),
                        ...widget.detail.rounds.map(
                          (round) => Positioned(
                            left:
                                24 +
                                (round.number -
                                        widget.detail.rounds.first.number) *
                                    BracketOverviewLayout.step,
                            top: headingHeight + 44,
                            width: BracketOverviewLayout.width,
                            child: Text(
                              s.spectatorStage(round.title),
                              style: nameStyle,
                            ),
                          ),
                        ),
                        ...layout.nodes.map(
                          (node) => Positioned.fromRect(
                            rect: node.rect,
                            child: Semantics(
                              button: true,
                              label:
                                  '${node.pool.student?.name ?? s.freePlace}, ${node.pool.opponent?.name ?? s.freePlace}',
                              child: InkWell(
                                key: ValueKey('overview-fight-${node.pool.id}'),
                                onTap: () => widget.onOpenFight(node.pool),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    SizedBox(
                                      height: node.headerHeight,
                                      child: Text(
                                        [
                                          if (node.third) s.thirdPlace,
                                          node.pool.fightNumber ??
                                              '${s.fight} #${node.pool.position}',
                                        ].join(' · '),
                                        style: clubStyle,
                                      ),
                                    ),
                                    for (final (index, person) in [
                                      node.pool.student,
                                      node.pool.opponent,
                                    ].indexed)
                                      SizedBox(
                                        key: ValueKey(
                                          'overview-row-${node.pool.id}-$index',
                                        ),
                                        height: node.rowHeight,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 4,
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      person?.name ??
                                                          s.freePlace,
                                                      style: nameStyle,
                                                    ),
                                                    Text(
                                                      person?.club ?? '-',
                                                      style: clubStyle,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              if (person != null &&
                                                  node.pool.winnerId ==
                                                      person.id)
                                                const Icon(
                                                  Icons.emoji_events_outlined,
                                                  size: 18,
                                                  color: Color(0xFFB8860B),
                                                ),
                                              if (person != null &&
                                                  (index == 0
                                                      ? node.pool.studentAbsent
                                                      : node
                                                            .pool
                                                            .opponentAbsent))
                                                Tooltip(
                                                  message: s.absence,
                                                  child: const Icon(
                                                    Icons.block,
                                                    size: 16,
                                                    color: AppColors.red,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (widget.detail.podium.isNotEmpty)
                          Positioned(
                            left: 24,
                            top: layout.size.height,
                            width: contentSize.width - 48,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.results, style: nameStyle),
                                const SizedBox(height: 12),
                                ...widget.detail.podium.map(
                                  (p) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Text(
                                      '${p.place}. ${p.participant.name}',
                                      style: nameStyle,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: s.zoomOut,
              onPressed: () => _zoom(1 / 1.5),
              icon: const Icon(Icons.remove),
            ),
            IconButton(
              tooltip: s.fitBracket,
              onPressed: _reset,
              icon: const Icon(Icons.fit_screen),
            ),
            IconButton(
              tooltip: s.zoomIn,
              onPressed: () => _zoom(1.5),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ],
    );
  }
}

class _BracketLines extends CustomPainter {
  const _BracketLines(this.paths, this.color);
  final List<Path> paths;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25
      ..strokeJoin = StrokeJoin.miter
      ..strokeCap = StrokeCap.butt;
    for (final path in paths) {
      canvas.drawPath(path, pen);
    }
  }

  @override
  bool shouldRepaint(_BracketLines oldDelegate) =>
      oldDelegate.paths != paths || oldDelegate.color != color;
}
