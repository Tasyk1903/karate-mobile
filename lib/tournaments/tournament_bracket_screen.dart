import 'kata_video_upload_sheet.dart';
import '../media/protected_video_player.dart';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../l10n/app_locale.dart';
import '../theme/app_colors.dart';
import 'tournament_models.dart';
import 'bracket_overview.dart';

class TournamentBracketScreen extends StatefulWidget {
  const TournamentBracketScreen({
    super.key,
    this.initialRound,
    this.initialPoolId,
    required this.strings,
    required this.api,
    required this.championship,
    required this.tournament,
    required this.table,
  });

  final int? initialRound, initialPoolId;
  final AppStrings strings;
  final ApiClient api;
  final Championship championship;
  final TournamentItem tournament;
  final TournamentTableItem table;

  @override
  State<TournamentBracketScreen> createState() =>
      _TournamentBracketScreenState();
}

class _TournamentBracketScreenState extends State<TournamentBracketScreen> {
  final _pageController = PageController();
  final _focusKey = GlobalKey();
  var _loading = true;
  var _page = 0;
  var _overview = false;
  TournamentBracketDetail? _detail;

  String get _path =>
      '/championships/${widget.championship.id}/tournaments/${widget.tournament.id}/lists/${widget.table.id}/bracket';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final response = await widget.api.getJson(_path);
      if (!mounted) return;
      setState(() {
        _detail = TournamentBracketDetail.fromJson(response);
        final index =
            _detail!.thirdPlace?.id == widget.initialPoolId &&
                widget.initialPoolId != null
            ? _detail!.rounds.length - 1
            : _detail!.rounds.indexWhere(
                (r) =>
                    r.pools.any((p) => p.id == widget.initialPoolId) ||
                    r.number == widget.initialRound,
              );
        _page = index < 0 ? 0 : index;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pageController.hasClients) {
          _pageController.jumpToPage(_page);
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final target = _focusKey.currentContext;
          if (mounted && target != null) {
            Scrollable.ensureVisible(target, alignment: 0.15);
          }
        });
      });
    } catch (error) {
      if (mounted) _message(error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;

    return Scaffold(
      backgroundColor: AppColors.pageFor(context),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              AppColors.backgroundImage(context),
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: ColoredBox(color: AppColors.backgroundOverlay(context)),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 16, 22, 10),
                  child: _Header(
                    title: detail?.kind == 'kata'
                        ? widget.strings.tables
                        : widget.strings.pools,
                  ),
                ),
                if (detail != null &&
                    detail.kind != 'kata' &&
                    !detail.isRoundRobin &&
                    detail.rounds.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: SegmentedButton<bool>(
                      segments: [
                        ButtonSegment(
                          value: false,
                          icon: const Icon(
                            Icons.view_carousel_outlined,
                            size: 18,
                          ),
                          label: Text(widget.strings.bracketRounds),
                        ),
                        ButtonSegment(
                          value: true,
                          icon: const Icon(
                            Icons.account_tree_outlined,
                            size: 18,
                          ),
                          label: Text(widget.strings.bracketOverview),
                        ),
                      ],
                      selected: {_overview},
                      showSelectedIcon: false,
                      onSelectionChanged: (values) {
                        setState(() => _overview = values.single);
                        if (!_overview) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted && _pageController.hasClients) {
                              _pageController.jumpToPage(_page);
                            }
                          });
                        }
                      },
                    ),
                  ),
                Expanded(
                  child: _loading || detail == null
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.red,
                          ),
                        )
                      : _overview &&
                            detail.kind != 'kata' &&
                            !detail.isRoundRobin
                      ? BracketOverview(
                          detail: detail,
                          strings: widget.strings,
                          heading:
                              '${widget.championship.name}\n${widget.tournament.name}',
                          onOpenFight: (pool) => showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => SafeArea(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(16),
                                child: _FightCard(
                                  pool: pool,
                                  strings: widget.strings,
                                ),
                              ),
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          color: AppColors.red,
                          onRefresh: _load,
                          child: detail.kind == 'kata'
                              ? _KataTableView(
                                  focusId: widget.initialPoolId,
                                  focusKey: _focusKey,
                                  detail: detail,
                                  strings: widget.strings,
                                  onUpdateFinalVideo: _updateFinalVideo,
                                  onOpenVideo: _openVideo,
                                )
                              : _BracketView(
                                  focusId: widget.initialPoolId,
                                  focusKey: _focusKey,
                                  detail: detail,
                                  strings: widget.strings,
                                  pageController: _pageController,
                                  page: _page,
                                  onPageChanged: (value) =>
                                      setState(() => _page = value),
                                ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _openVideo(TournamentKataRow row) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                row.name,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                [
                  if (row.members.isNotEmpty) row.memberDetails else row.club,
                  if (row.members.isEmpty) row.coachName,
                  row.categoryName ?? '',
                ].where((s) => s.isNotEmpty).join('\n'),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              if (row.videoUrl != null && row.videoUploaded)
                ProtectedVideoPlayer(
                  api: widget.api,
                  url: row.videoUrl!,
                  strings: widget.strings,
                )
              else
                Text(
                  row.videoUploaded
                      ? widget.strings.videoPrivate
                      : widget.strings.videoNotUploaded,
                  style: const TextStyle(fontSize: 12),
                ),
              if (row.canUpdateFinalVideo)
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _updateFinalVideo(row);
                  },
                  icon: const Icon(Icons.upload_file, size: 18),
                  label: Text(
                    row.videoUploaded
                        ? widget.strings.changeFinalVideo
                        : widget.strings.uploadFinalVideo,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateFinalVideo(TournamentKataRow row) async {
    final categories = _detail?.educationCategories ?? [];
    if (categories.isEmpty) {
      _message(widget.strings.chooseCategory);
      return;
    }

    final saved = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => KataVideoUploadSheet(
        api: widget.api,
        strings: widget.strings,
        path:
            '/championships/${widget.championship.id}/tournaments/${widget.tournament.id}/kata-pools/${row.id}/final-video',
        title: row.videoUploaded
            ? widget.strings.changeFinalVideo
            : widget.strings.uploadFinalVideo,
        name: row.name,
        categories: categories,
        categoryId: row.categoryId,
        categoryField: 'category_id',
        submitLabel: widget.strings.save,
      ),
    );

    if (saved != null) {
      await _load();
      if (mounted) _message(widget.strings.finalVideoUpdated);
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CircleButton(
          icon: Icons.arrow_back_rounded,
          onTap: () => Navigator.of(context).pop(),
        ),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.inkFor(context),
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 44),
      ],
    );
  }
}

class _BracketView extends StatelessWidget {
  const _BracketView({
    this.focusId,
    this.focusKey,
    required this.detail,
    required this.strings,
    required this.pageController,
    required this.page,
    required this.onPageChanged,
  });

  final TournamentBracketDetail detail;
  final AppStrings strings;
  final int? focusId;
  final GlobalKey? focusKey;
  final PageController pageController;
  final int page;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    if (detail.rounds.isEmpty) {
      return _EmptyState(title: detail.title, strings: strings);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        children: [
          _TitleCard(
            title: detail.title,
            subtitle: detail.tatami,
            strings: strings,
          ),
          const SizedBox(height: 12),
          _RoundStatus(
            strings: strings,
            round: detail.rounds[page],
            page: page,
            total: detail.rounds.length,
            onPrevious: page == 0
                ? null
                : () => pageController.previousPage(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                  ),
            onNext: page == detail.rounds.length - 1
                ? null
                : () => pageController.nextPage(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                  ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: PageView.builder(
              controller: pageController,
              onPageChanged: onPageChanged,
              itemCount: detail.rounds.length,
              itemBuilder: (context, index) {
                final round = detail.rounds[index];
                final isLast = index == detail.rounds.length - 1;

                return ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    ...round.pools.map(
                      (pool) => _FightCard(
                        key: pool.id == focusId ? focusKey : null,
                        pool: pool,
                        strings: strings,
                      ),
                    ),
                    if (detail.isRoundRobin && detail.podium.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _PodiumCard(podium: detail.podium, strings: strings),
                    ],
                    if (isLast && detail.thirdPlace != null) ...[
                      const SizedBox(height: 12),
                      _ThirdPlaceCard(
                        key: detail.thirdPlace!.id == focusId ? focusKey : null,
                        pool: detail.thirdPlace!,
                        strings: strings,
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _KataTableView extends StatelessWidget {
  const _KataTableView({
    this.focusId,
    this.focusKey,
    required this.detail,
    required this.strings,
    required this.onUpdateFinalVideo,
    required this.onOpenVideo,
  });

  final TournamentBracketDetail detail;
  final AppStrings strings;
  final int? focusId;
  final GlobalKey? focusKey;
  final ValueChanged<TournamentKataRow> onUpdateFinalVideo;
  final ValueChanged<TournamentKataRow> onOpenVideo;

  @override
  Widget build(BuildContext context) {
    final rounds = detail.kataRounds.where((round) => round.rows.isNotEmpty);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 120),
      child: Column(
        children: [
          _TitleCard(
            title: detail.title,
            subtitle: detail.tatami,
            strings: strings,
          ),
          const SizedBox(height: 12),
          ...rounds.map(
            (round) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: _cardDecoration(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.spectatorStage(round.title),
                    style: TextStyle(
                      color: AppColors.inkFor(context),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...round.rows.map(
                    (row) => _KataRowItem(
                      key: row.id == focusId ? focusKey : null,
                      row: row,
                      strings: strings,
                      isOnlineKata: detail.isOnlineKata,
                      onOpenVideo: () => onOpenVideo(row),
                      onUpdateFinalVideo: row.canUpdateFinalVideo
                          ? () => onUpdateFinalVideo(row)
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _KataResultsCard(detail: detail, strings: strings),
        ],
      ),
    );
  }
}

class _TitleCard extends StatelessWidget {
  const _TitleCard({
    required this.title,
    required this.subtitle,
    required this.strings,
  });

  final String title;
  final String? subtitle;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(context),
      child: Row(
        children: [
          Icon(
            Icons.emoji_events_rounded,
            color: AppColors.accentFor(context),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.inkFor(context),
                    fontSize: 14.5,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if ((subtitle ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${strings.tatami} $subtitle',
                    style: TextStyle(
                      color: AppColors.mutedFor(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundStatus extends StatelessWidget {
  const _RoundStatus({
    required this.strings,
    required this.round,
    required this.page,
    required this.total,
    required this.onPrevious,
    required this.onNext,
  });

  final AppStrings strings;
  final TournamentBracketRound round;
  final int page;
  final int total;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: _cardDecoration(context, radius: 16),
      child: Row(
        children: [
          _RoundArrow(icon: Icons.chevron_left_rounded, onTap: onPrevious),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  strings.spectatorStage(round.title),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.inkFor(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var index = 0; index < total; index++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: index == page ? 16 : 5,
                        height: 5,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: index == page
                              ? AppColors.red
                              : AppColors.borderFor(context),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${page + 1}/$total',
            style: TextStyle(
              color: AppColors.mutedFor(context),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 8),
          _RoundArrow(icon: Icons.chevron_right_rounded, onTap: onNext),
        ],
      ),
    );
  }
}

class _RoundArrow extends StatelessWidget {
  const _RoundArrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: onTap == null
              ? AppColors.page
              : AppColors.red.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: 20,
          color: onTap == null
              ? AppColors.mutedFor(context).withValues(alpha: 0.45)
              : AppColors.red,
        ),
      ),
    );
  }
}

class _BracketRail extends StatelessWidget {
  const _BracketRail();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: 2,
              decoration: BoxDecoration(
                color: AppColors.borderFor(context),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: AppColors.red.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.red.withValues(alpha: 0.35)),
            ),
          ),
          Expanded(
            child: Container(
              width: 2,
              decoration: BoxDecoration(
                color: AppColors.borderFor(context),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FightCard extends StatelessWidget {
  const _FightCard({super.key, required this.pool, required this.strings});

  final TournamentBracketPool pool;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(9),
      decoration: _cardDecoration(context, radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${strings.fight} #${pool.position == 0 ? pool.id : pool.position}',
                style: TextStyle(
                  color: AppColors.mutedFor(context),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              if ((pool.fightNumber ?? '').isNotEmpty)
                _SmallPill(text: pool.fightNumber!),
            ],
          ),
          const SizedBox(height: 7),
          IntrinsicHeight(
            child: Row(
              children: [
                const _BracketRail(),
                const SizedBox(width: 7),
                Expanded(
                  child: Column(
                    children: [
                      _ParticipantLine(
                        participant: pool.student,
                        strings: strings,
                        winner: pool.student?.id == pool.winnerId,
                        absent: pool.studentAbsent,
                        wazari: pool.studentWazari,
                        ippon: pool.studentIppon,
                      ),
                      const SizedBox(height: 5),
                      _ParticipantLine(
                        participant: pool.opponent,
                        strings: strings,
                        winner: pool.opponent?.id == pool.winnerId,
                        absent: pool.opponentAbsent,
                        wazari: pool.opponentWazari,
                        ippon: pool.opponentIppon,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThirdPlaceCard extends StatelessWidget {
  const _ThirdPlaceCard({super.key, required this.pool, required this.strings});

  final TournamentBracketPool pool;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.thirdPlace,
          style: TextStyle(
            color: AppColors.inkFor(context),
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        _FightCard(pool: pool, strings: strings),
      ],
    );
  }
}

class _ParticipantLine extends StatelessWidget {
  const _ParticipantLine({
    required this.participant,
    required this.strings,
    required this.winner,
    required this.absent,
    this.wazari = 0,
    this.ippon = false,
  });

  final TournamentBracketParticipant? participant;
  final AppStrings strings;
  final bool winner;
  final bool absent;
  final int wazari;
  final bool ippon;

  @override
  Widget build(BuildContext context) {
    final name = participant?.name.isNotEmpty == true
        ? participant!.name
        : strings.freePlace;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: winner
            ? Colors.green.withValues(alpha: .12)
            : AppColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: absent
              ? const Color(0xFFF3B8B8)
              : winner
              ? const Color(0xFF9BE5BB)
              : AppColors.borderFor(context),
        ),
      ),
      child: Row(
        children: [
          if (participant?.avatar != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ClipOval(
                child: Image.network(
                  participant!.avatar!,
                  width: 28,
                  height: 28,
                  fit: BoxFit.cover,
                  errorBuilder: (_, error, stack) =>
                      const Icon(Icons.person_outline, size: 28),
                ),
              ),
            ),
          Icon(
            absent
                ? Icons.block_rounded
                : winner
                ? Icons.emoji_events_rounded
                : Icons.radio_button_unchecked_rounded,
            color: absent
                ? AppColors.red
                : winner
                ? const Color(0xFFDA9900)
                : AppColors.mutedFor(context).withValues(alpha: 0.45),
            size: 15,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (absent || wazari > 0 || ippon)
                  Text(
                    absent
                        ? strings.absence
                        : '${strings.wazari}: $wazari · ${strings.ippon}: ${ippon ? 1 : 0}',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.mutedFor(context),
                    ),
                  ),
                Text(
                  name,
                  style: TextStyle(
                    color: AppColors.inkFor(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  participant?.club?.isNotEmpty == true
                      ? participant!.club!
                      : '-',
                  style: TextStyle(
                    color: AppColors.mutedFor(context),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PodiumCard extends StatelessWidget {
  const _PodiumCard({required this.podium, required this.strings});

  final List<TournamentPodiumPlace> podium;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(context),
      child: Column(
        children: podium
            .map(
              (place) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.emoji_events_rounded,
                      color: place.place == 1
                          ? const Color(0xFFE3A500)
                          : place.place == 2
                          ? const Color(0xFF9BA4AF)
                          : const Color(0xFFC56C2E),
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${place.place} ${strings.placeNumber}',
                      style: TextStyle(
                        color: AppColors.mutedFor(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        place.participant.name,
                        style: TextStyle(
                          color: AppColors.inkFor(context),
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _KataRowItem extends StatelessWidget {
  const _KataRowItem({
    super.key,
    required this.row,
    required this.strings,
    required this.isOnlineKata,
    required this.onUpdateFinalVideo,
    required this.onOpenVideo,
  });

  final TournamentKataRow row;
  final AppStrings strings;
  final bool isOnlineKata;
  final VoidCallback? onUpdateFinalVideo;
  final VoidCallback onOpenVideo;

  @override
  Widget build(BuildContext context) {
    final meta = row.members.isNotEmpty
        ? row.memberDetails
        : [
            if (row.club.isNotEmpty) row.club,
            if (row.coachName.isNotEmpty) row.coachName,
          ].join(' · ');
    final category = row.categoryName ?? '';

    return InkWell(
      onTap: isOnlineKata ? onOpenVideo : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.borderFor(context)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceFor(context),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: AppColors.borderFor(context)),
                  ),
                  child: Text(
                    row.participantNumber ?? '-',
                    style: TextStyle(
                      color: AppColors.mutedFor(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.members.isEmpty ? row.name : strings.team,
                        style: TextStyle(
                          color: AppColors.inkFor(context),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          meta,
                          style: TextStyle(
                            color: AppColors.mutedFor(context),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      if (category.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          category,
                          style: TextStyle(
                            color: AppColors.mutedFor(context),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (row.winnerPlace != null)
                      Icon(
                        Icons.emoji_events_rounded,
                        color: _placeColor(row.winnerPlace!),
                        size: 18,
                      ),
                    Text(
                      row.totalScore ?? '-',
                      style: TextStyle(
                        color: AppColors.accentFor(context),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      row.rank == null
                          ? strings.totalScore
                          : '${strings.rank} #${row.rank}',
                      style: TextStyle(
                        color: AppColors.mutedFor(context),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                _SmallPill(
                  text: '${strings.referee} ${row.refereeScore ?? '-'}',
                ),
                _SmallPill(text: '1 ${row.judge1Score ?? '-'}'),
                _SmallPill(text: '2 ${row.judge2Score ?? '-'}'),
                _SmallPill(text: '3 ${row.judge3Score ?? '-'}'),
                _SmallPill(text: '4 ${row.judge4Score ?? '-'}'),
                if (row.minScore != null)
                  _SmallPill(text: '${strings.minScore} ${row.minScore}'),
                if (row.maxScore != null)
                  _SmallPill(text: '${strings.maxScore} ${row.maxScore}'),
              ],
            ),
            if (isOnlineKata || onUpdateFinalVideo != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  _VideoStatusPill(
                    uploaded: row.videoUploaded,
                    strings: strings,
                  ),
                  if (onUpdateFinalVideo != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onUpdateFinalVideo,
                        icon: const Icon(Icons.video_call_rounded, size: 16),
                        label: Text(
                          row.videoUploaded
                              ? strings.changeFinalVideo
                              : strings.uploadFinalVideo,
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.red,
                          side: const BorderSide(color: Color(0xFFF3B8B8)),
                          minimumSize: const Size(0, 34),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          textStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _placeColor(int place) {
    return place == 1
        ? const Color(0xFFE3A500)
        : place == 2
        ? const Color(0xFF9BA4AF)
        : const Color(0xFFC56C2E);
  }
}

class _VideoStatusPill extends StatelessWidget {
  const _VideoStatusPill({required this.uploaded, required this.strings});

  final bool uploaded;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final color = uploaded ? const Color(0xFF169B53) : AppColors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            uploaded ? Icons.check_circle_rounded : Icons.error_rounded,
            color: color,
            size: 13,
          ),
          const SizedBox(width: 4),
          Text(
            uploaded ? strings.videoUploaded : strings.videoNotUploaded,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _KataResultsCard extends StatelessWidget {
  const _KataResultsCard({required this.detail, required this.strings});

  final TournamentBracketDetail detail;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final rows =
        detail.kataRounds
            .expand((round) => round.rows)
            .where((row) => row.winnerPlace != null)
            .toList()
          ..sort((a, b) => a.winnerPlace!.compareTo(b.winnerPlace!));

    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.results,
            style: TextStyle(
              color: AppColors.inkFor(context),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Icon(
                    Icons.emoji_events_rounded,
                    color: row.winnerPlace == 1
                        ? const Color(0xFFE3A500)
                        : row.winnerPlace == 2
                        ? const Color(0xFF9BA4AF)
                        : const Color(0xFFC56C2E),
                    size: 17,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${row.winnerPlace} ${strings.placeNumber} · ${row.name}',
                      style: TextStyle(
                        color: AppColors.inkFor(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    row.totalScore ?? '-',
                    style: TextStyle(
                      color: AppColors.accentFor(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallPill extends StatelessWidget {
  const _SmallPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.borderFor(context)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: AppColors.inkFor(context),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.strings});

  final String title;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 120),
      children: [
        _TitleCard(title: title, subtitle: null, strings: strings),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: _cardDecoration(context),
          child: Text(
            strings.noGeneratedData,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.mutedFor(context),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.surfaceFor(context),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(icon, color: AppColors.inkFor(context), size: 23),
      ),
    );
  }
}

BoxDecoration _cardDecoration(BuildContext context, {double radius = 22}) {
  return BoxDecoration(
    color: AppColors.surfaceFor(context),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: AppColors.borderFor(context)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.05),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ],
  );
}
