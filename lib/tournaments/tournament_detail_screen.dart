import 'tournament_lists_screen.dart';

import 'package:flutter/material.dart';

import 'kata_video_upload_sheet.dart';
import 'kata_payments_panel.dart';

import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../account/payment_offer_dialog.dart';
import '../l10n/app_locale.dart';
import '../students/student_profile_screen.dart';
import '../theme/app_colors.dart';
import 'tournament_bracket_screen.dart';
import 'tournament_models.dart';
import 'tournament_student_picker.dart';
import '../files/download_helper.dart';

enum TournamentDetailTab { participants, coaches, tables }

class TournamentDetailScreen extends StatefulWidget {
  const TournamentDetailScreen({
    super.key,
    required this.strings,
    required this.api,
    required this.championship,
    required this.item,
  });

  final AppStrings strings;
  final ApiClient api;
  final Championship championship;
  final TournamentItem item;

  @override
  State<TournamentDetailScreen> createState() => _TournamentDetailScreenState();
}

class _TournamentDetailScreenState extends State<TournamentDetailScreen> {
  final _payments = GlobalKey<KataPaymentsPanelState>();
  final _scroll = ScrollController();
  final _search = TextEditingController();
  var _tab = TournamentDetailTab.participants;
  var _detailLoading = true;
  var _listLoading = true;
  var _loadingMore = false;
  var _page = 1;
  int _listRequest = 0;
  var _lastPage = 1;
  TournamentDetail? _detail;
  String? _detailError;
  var _participants = <TournamentParticipant>[];
  var _coaches = <TournamentCoach>[];
  var _tables = <TournamentTableItem>[];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadDetail();
    _loadList(reset: true);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  String get _basePath =>
      '/championships/${widget.championship.id}/tournaments/${widget.item.id}';

  bool _exporting = false;
  Future<void> _exportLists(String format) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      List<int> bytes;
      if (_detail?.exportFormats.isNotEmpty == true) {
        final type = ['excel', 'pdf'].contains(format)
            ? 'lists-$format'
            : format;
        var task =
            (await widget.api.postJson(
                  '$_basePath/exports',
                  body: {'format': type},
                ))['task']
                as Map<String, dynamic>;
        final id = task['id'];
        for (
          var attempt = 0;
          ['queued', 'processing'].contains(task['status']) && attempt < 300;
          attempt++
        ) {
          await Future<void>.delayed(const Duration(seconds: 2));
          if (!mounted) return;
          task =
              (await widget.api.getJson('/tasks/$id'))['task']
                  as Map<String, dynamic>;
        }
        if (task['status'] != 'ready') {
          throw Exception(widget.strings.exportNotReady);
        }
        bytes = await widget.api.getBytes('/tasks/$id/file');
      } else {
        bytes = await widget.api.getBytes('$_basePath/lists/export/$format');
      }
      final file = await DownloadHelper.saveBytes(
        bytes: bytes,
        fileName:
            'tournament-${widget.item.id}-${['excel', 'pdf'].contains(format) ? 'lists' : format}.${format == 'excel' ? 'xlsx' : 'pdf'}',
      );
      await DownloadHelper.share(file);
    } catch (error) {
      if (mounted) _message(error.toString());
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _loadDetail({bool silent = false}) async {
    setState(() {
      _detailLoading = !silent;
      _detailError = null;
    });
    try {
      final response = await widget.api.getJson(_basePath);
      if (!mounted) return;
      setState(() {
        _detail = TournamentDetail.fromJson(
          response['tournament'] as Map<String, dynamic>? ?? {},
        );
      });
    } catch (error) {
      if (mounted) setState(() => _detailError = error.toString());
    } finally {
      if (mounted) setState(() => _detailLoading = false);
    }
  }

  Future<void> _loadList({required bool reset}) async {
    if (reset) {
      _page = 1;
      setState(() => _listLoading = true);
    } else {
      if (_listLoading || _loadingMore || _page >= _lastPage) {
        return;
      }
      setState(() => _loadingMore = true);
      _page += 1;
    }

    final request = ++_listRequest;
    final tab = _tab;
    try {
      final endpoint = switch (tab) {
        TournamentDetailTab.participants => 'students',
        TournamentDetailTab.coaches => 'coaches',
        TournamentDetailTab.tables => 'lists',
      };
      final response = await widget.api.getJson(
        '$_basePath/$endpoint',
        query: {
          'page': _page.toString(),
          'per_page': '10',
          if (tab == TournamentDetailTab.tables) 'generated': '1',
          if (_search.text.trim().isNotEmpty) 'search': _search.text.trim(),
        },
      );

      if (!mounted || request != _listRequest) return;
      setState(() {
        if (tab == TournamentDetailTab.participants) {
          final loaded = (response['data'] as List<dynamic>? ?? [])
              .whereType<Map<String, dynamic>>()
              .map(TournamentParticipant.fromJson)
              .toList();
          _participants = reset ? loaded : [..._participants, ...loaded];
        } else if (tab == TournamentDetailTab.coaches) {
          final loaded = (response['data'] as List<dynamic>? ?? [])
              .whereType<Map<String, dynamic>>()
              .map(TournamentCoach.fromJson)
              .toList();
          _coaches = reset ? loaded : [..._coaches, ...loaded];
        } else {
          final loaded = (response['data'] as List<dynamic>? ?? [])
              .whereType<Map<String, dynamic>>()
              .map(TournamentTableItem.fromJson)
              .toList();
          _tables = reset ? loaded : [..._tables, ...loaded];
        }
        final meta = response['meta'] as Map<String, dynamic>? ?? {};
        _lastPage = (meta['last_page'] as num?)?.toInt() ?? 1;
      });
    } catch (error) {
      if (mounted && request == _listRequest) {
        if (!reset) _page -= 1;
        _message(error.toString());
      }
    } finally {
      if (mounted && request == _listRequest) {
        setState(() {
          _listLoading = false;
          _loadingMore = false;
        });
      }
    }
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 220) {
      _loadList(reset: false);
    }
  }

  void _changeTab(TournamentDetailTab tab) {
    if (_tab == tab) return;
    setState(() {
      _tab = tab;
      _search.clear();
      _participants = [];
      _coaches = [];
      _tables = [];
    });
    _loadList(reset: true);
  }

  final _detachingIds = <int>{};

  Future<void> _detach(TournamentParticipant participant) async {
    if (!_detachingIds.add(participant.pivotId)) return;
    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(widget.strings.detachQuestion),
          content: Text(widget.strings.detachText),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(widget.strings.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(widget.strings.detach),
            ),
          ],
        ),
      );
      if (confirm != true) return;

      try {
        await widget.api.deleteJson(
          '$_basePath/students/${participant.pivotId}',
        );
        await _loadList(reset: true);
      } catch (error) {
        if (mounted) _message(error.toString());
      }
    } finally {
      _detachingIds.remove(participant.pivotId);
    }
  }

  Future<void> _openAttachSheet() async {
    if (_detail?.requiresOnlineKataPayment == true) {
      try {
        await _openOnlineKataAttachSheet();
      } catch (error) {
        if (mounted) _message(error.toString());
      }
      return;
    }

    if (widget.api.isStudent) {
      await _selfEnrollment();
      return;
    }

    final success = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => TournamentStudentPicker(
        api: widget.api,
        strings: widget.strings,
        path: _basePath,
        submit: (students) async {
          final response = await widget.api.postJson(
            '$_basePath/students',
            body: {'student_ids': students.map((s) => s.id).toList()},
          );
          if ((response['attached'] as List<dynamic>? ?? []).isEmpty) {
            throw Exception(widget.strings.noAttachOptions);
          }
        },
      ),
    );
    if (success == true && mounted) {
      await _loadDetail();
      await _loadList(reset: true);
    }
  }

  Future<void> _openOnlineKataAttachSheet() async {
    TournamentAttachStudent? selected;
    if (widget.api.isStudent) {
      if (!await acceptPaymentOffer(context, widget.api, widget.strings)) {
        return;
      }
      final response = await widget.api.getJson(
        '/students/${widget.api.accountId}',
      );
      final student = response['student'] as Map<String, dynamic>;
      selected = TournamentAttachStudent.fromJson({
        ...student,
        'name': student['full_name'],
      });
    } else {
      await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (_) => TournamentStudentPicker(
          api: widget.api,
          strings: widget.strings,
          path: _basePath,
          single: true,
          submit: (students) async {
            selected = students.single;
          },
        ),
      );
    }
    if (!mounted || selected == null) return;
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => KataVideoUploadSheet(
        api: widget.api,
        strings: widget.strings,
        path: '$_basePath/students/online-kata',
        title: widget.strings.onlineKataApplication,
        name: selected!.name,
        categories: _detail?.educationCategories ?? [],
        categoryField: 'online_kata_first_round_category_id',
        fields: {'student_id': selected!.id.toString()},
        submitLabel:
            '${widget.strings.continueToPayment} · ${_detail?.onlineKataPriceLabel ?? ""}',
      ),
    );
    if (!mounted) return;
    await _payments.currentState?.refresh();
    if (result != null) {
      final payment = result['payment'] as Map<String, dynamic>? ?? {};
      final url = Uri.tryParse(payment['payment_url']?.toString() ?? '');
      if (url != null && url.scheme == 'https') {
        try {
          if (!await launchUrl(url, mode: LaunchMode.externalApplication) &&
              mounted) {
            _message(widget.strings.paymentOpenFailed);
          }
        } catch (_) {
          if (mounted) _message(widget.strings.paymentOpenFailed);
        }
      }
      if (mounted) {
        await _loadDetail();
        await _loadList(reset: true);
      }
    }
  }

  bool _selfBusy = false;

  Future<void> _selfEnrollment({int? membershipId}) async {
    if (_selfBusy) return;
    setState(() => _selfBusy = true);
    try {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            membershipId == null
                ? widget.strings.joinTournamentConfirm
                : widget.strings.detachQuestion,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(widget.strings.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                membershipId == null
                    ? widget.strings.joinExam
                    : widget.strings.detach,
              ),
            ),
          ],
        ),
      );
      if (accepted != true) return;
      if (membershipId == null) {
        await widget.api.postJson('$_basePath/self', body: {});
      } else {
        await widget.api.deleteJson('$_basePath/self/$membershipId');
      }
      if (mounted) {
        await _loadDetail();
        await _loadList(reset: true);
      }
    } catch (error) {
      if (mounted) _message(error.toString());
    } finally {
      if (mounted) setState(() => _selfBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final tableTitle = detail?.type == 'kumite'
        ? widget.strings.pools
        : widget.strings.tables;

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
            child: RefreshIndicator(
              color: AppColors.red,
              onRefresh: () async {
                await _loadDetail();
                await _loadList(reset: true);
              },
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 120),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _Header(title: widget.strings.tournaments),
                      ),
                      if (_exporting)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      PopupMenuButton<String>(
                        tooltip: widget.strings.more,
                        icon: const Icon(Icons.more_horiz, size: 22),
                        onSelected: (value) async {
                          if (value == 'lists') {
                            Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => TournamentListsScreen(
                                  api: widget.api,
                                  strings: widget.strings,
                                  championship: widget.championship,
                                  tournament: widget.item,
                                ),
                              ),
                            );
                          } else {
                            await _exportLists(value);
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'lists',
                            child: Text(widget.strings.sourceLists),
                          ),
                          PopupMenuItem(
                            value: 'excel',
                            child: Text(widget.strings.listsExcel),
                          ),
                          PopupMenuItem(
                            value: 'pdf',
                            child: Text(widget.strings.listsPdf),
                          ),
                          if (_detail?.exportFormats.contains('kata-tables') ==
                              true)
                            PopupMenuItem(
                              value: 'kata-tables',
                              child: Text('${widget.strings.tables} PDF'),
                            ),
                          if (_detail?.exportFormats.contains('brackets') ==
                              true)
                            PopupMenuItem(
                              value: 'brackets',
                              child: Text('${widget.strings.pools} PDF'),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (_detailError != null) ...[
                    Text(_detailError!, style: const TextStyle(fontSize: 12)),
                    TextButton(
                      onPressed: _loadDetail,
                      child: Text(widget.strings.retry),
                    ),
                  ] else if (_detailLoading || detail == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 120),
                      child: Center(
                        child: CircularProgressIndicator(color: AppColors.red),
                      ),
                    )
                  else ...[
                    if (detail.requiresOnlineKataPayment)
                      KataPaymentsPanel(
                        key: _payments,
                        api: widget.api,
                        strings: widget.strings,
                        tournamentId: widget.item.id,
                        onFulfilled: () async {
                          await _loadDetail(silent: true);
                          await _loadList(reset: true);
                        },
                      ),
                    _HeroCard(
                      detail: detail,
                      strings: widget.strings,
                      api: widget.api,
                    ),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        if (detail.ageRange.isNotEmpty)
                          Text(
                            '${widget.strings.age}: ${detail.ageRange}',
                            style: const TextStyle(fontSize: 11),
                          ),
                        if (detail.tatami.isNotEmpty)
                          Text(
                            '${widget.strings.tatami}: ${detail.tatami}',
                            style: const TextStyle(fontSize: 11),
                          ),
                        if (detail.rankGroup.isNotEmpty)
                          Text(
                            detail.rankGroup == 'junior'
                                ? widget.strings.juniorRankGroup
                                : widget.strings.seniorRankGroup,
                            style: const TextStyle(fontSize: 11),
                          ),
                      ],
                    ),
                    if (detail.chiefJudge.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${widget.strings.chiefJudge}: ${detail.chiefJudge}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    if (detail.chiefSecretary.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '${widget.strings.chiefSecretary}: ${detail.chiefSecretary}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    Wrap(
                      spacing: 8,
                      children: detail.documents
                          .map(
                            (document) => TextButton.icon(
                              icon: const Icon(
                                Icons.description_outlined,
                                size: 16,
                              ),
                              label: Text(
                                document.key == 'regulation_document'
                                    ? widget.strings.regulationDocument
                                    : widget.strings.applicationDocument,
                                style: const TextStyle(fontSize: 12),
                              ),
                              onPressed: () async {
                                try {
                                  final bytes = await widget.api.getBytes(
                                    document.url,
                                  );
                                  final file = await DownloadHelper.saveBytes(
                                    bytes: bytes,
                                    fileName: document.name,
                                  );
                                  await DownloadHelper.share(file);
                                } catch (error) {
                                  if (mounted) _message(error.toString());
                                }
                              },
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 18),
                    _Tabs(
                      tab: _tab,
                      tableTitle: tableTitle,
                      strings: widget.strings,
                      onChanged: _changeTab,
                    ),
                    const SizedBox(height: 18),
                    if (widget.api.isStudent)
                      for (final membership in detail.selfMemberships)
                        ListTile(
                          dense: true,
                          title: Text(
                            membership['name']?.toString() ?? '',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: membership['can_detach'] == true
                              ? IconButton(
                                  tooltip: widget.strings.detach,
                                  icon: const Icon(Icons.link_off, size: 20),
                                  onPressed: _selfBusy
                                      ? null
                                      : () => _selfEnrollment(
                                          membershipId:
                                              (membership['id'] as num).toInt(),
                                        ),
                                )
                              : null,
                        ),
                    _ContentCard(
                      title: switch (_tab) {
                        TournamentDetailTab.participants =>
                          widget.strings.participants,
                        TournamentDetailTab.coaches => widget.strings.coaches,
                        TournamentDetailTab.tables => tableTitle,
                      },
                      action:
                          _tab == TournamentDetailTab.participants &&
                              (_detail?.canAttachStudents ?? false)
                          ? _AttachButton(
                              text: widget.api.isStudent
                                  ? widget.strings.joinExam
                                  : widget.strings.attach,
                              onPressed: _openAttachSheet,
                            )
                          : null,
                      child: _body(tableTitle),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(String tableTitle) {
    if (_listLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 42),
        child: Center(child: CircularProgressIndicator(color: AppColors.red)),
      );
    }

    final hint = switch (_tab) {
      TournamentDetailTab.participants => widget.strings.searchParticipant,
      TournamentDetailTab.coaches => widget.strings.searchCoach,
      TournamentDetailTab.tables => widget.strings.searchPool,
    };

    final items = switch (_tab) {
      TournamentDetailTab.participants => _participants.length,
      TournamentDetailTab.coaches => _coaches.length,
      TournamentDetailTab.tables => _tables.length,
    };

    return Column(
      children: [
        _SearchField(
          controller: _search,
          hint: hint,
          onChanged: (_) => _loadList(reset: true),
        ),
        const SizedBox(height: 12),
        if (items == 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 34),
            child: Text(
              _tab == TournamentDetailTab.participants
                  ? widget.strings.noParticipants
                  : widget.strings.noTournaments,
              style: TextStyle(
                color: AppColors.mutedFor(context),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        else if (_tab == TournamentDetailTab.participants)
          ..._participants.map(
            (item) => _ParticipantRow(
              participant: item,
              strings: widget.strings,
              api: widget.api,
              onProfile: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => StudentProfileScreen(
                    strings: widget.strings,
                    api: widget.api,
                    studentId: item.id,
                    tournamentId: widget.item.id,
                    championshipId: widget.championship.id,
                  ),
                ),
              ),
              onDetach: item.canDetach ? () => _detach(item) : null,
            ),
          )
        else if (_tab == TournamentDetailTab.coaches)
          ..._coaches.map(
            (item) => _CoachRow(
              coach: item,
              strings: widget.strings,
              api: widget.api,
            ),
          )
        else
          ..._tables.map(
            (item) => _TableRowItem(
              item: item,
              tableTitle: tableTitle,
              strings: widget.strings,
              onOpen: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => TournamentBracketScreen(
                    strings: widget.strings,
                    api: widget.api,
                    championship: widget.championship,
                    tournament: widget.item,
                    table: item,
                  ),
                ),
              ),
            ),
          ),
        if (_loadingMore)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: CircularProgressIndicator(color: AppColors.red),
          ),
      ],
    );
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
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
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 46),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.detail,
    required this.strings,
    required this.api,
  });

  final TournamentDetail detail;
  final AppStrings strings;
  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(context),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 74,
              height: 90,
              child: detail.cover == null
                  ? ColoredBox(
                      color: const Color(0xFFFFEAEA),
                      child: Icon(
                        detail.type == 'kata'
                            ? Icons.self_improvement_rounded
                            : Icons.sports_martial_arts_rounded,
                        color: AppColors.accentFor(context),
                        size: 30,
                      ),
                    )
                  : Image.network(
                      api.publicUrl(detail.cover!),
                      fit: BoxFit.cover,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.name,
                  style: TextStyle(
                    color: AppColors.inkFor(context),
                    fontSize: 13,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  detail.championshipName,
                  style: TextStyle(
                    color: AppColors.mutedFor(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 15,
                      color: AppColors.mutedFor(context),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      detail.dateLabel,
                      style: TextStyle(
                        color: AppColors.mutedFor(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _StatusPill(
                      text: detail.status == 'active'
                          ? strings.active
                          : strings.completed,
                    ),
                    _TournamentInfoChip(
                      icon: Icons.sports_martial_arts_rounded,
                      text: detail.type == 'kata'
                          ? strings.kata
                          : strings.kumite,
                    ),
                    if ((detail.region ?? '').isNotEmpty)
                      _TournamentInfoChip(
                        icon: Icons.location_on_outlined,
                        text: detail.region!,
                      ),
                    if ((detail.scale ?? '').isNotEmpty)
                      _TournamentInfoChip(
                        icon: Icons.workspace_premium_outlined,
                        text: detail.scale!,
                      ),
                    if (detail.dateFinishLabel.isNotEmpty)
                      _TournamentInfoChip(
                        icon: Icons.event_available_outlined,
                        text: detail.dateFinishLabel,
                      ),
                    if (detail.priceLabel.isNotEmpty)
                      _TournamentInfoChip(
                        icon: Icons.payments_outlined,
                        text: detail.priceLabel,
                      ),
                  ],
                ),
                if ((detail.address ?? '').isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    detail.address!,
                    style: TextStyle(
                      color: AppColors.mutedFor(context),
                      fontSize: 11,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (detail.dateCommissionLabel.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    '${strings.commissionDate}: ${detail.dateCommissionLabel}',
                    style: TextStyle(
                      color: AppColors.mutedFor(context),
                      fontSize: 10.5,
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

class _TournamentInfoChip extends StatelessWidget {
  const _TournamentInfoChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(context),
        border: Border.all(color: AppColors.borderFor(context)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.mutedFor(context)),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.mutedFor(context),
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.tab,
    required this.tableTitle,
    required this.strings,
    required this.onChanged,
  });

  final TournamentDetailTab tab;
  final String tableTitle;
  final AppStrings strings;
  final ValueChanged<TournamentDetailTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: _cardDecoration(context, radius: 20),
      child: Row(
        children: [
          _TabButton(
            text: strings.participants,
            active: tab == TournamentDetailTab.participants,
            onTap: () => onChanged(TournamentDetailTab.participants),
          ),
          _TabButton(
            text: strings.coaches,
            active: tab == TournamentDetailTab.coaches,
            onTap: () => onChanged(TournamentDetailTab.coaches),
          ),
          _TabButton(
            text: tableTitle,
            active: tab == TournamentDetailTab.tables,
            onTap: () => onChanged(TournamentDetailTab.tables),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.text,
    required this.active,
    required this.onTap,
  });

  final String text;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              text,
              style: TextStyle(
                color: active
                    ? AppColors.accentFor(context)
                    : AppColors.mutedFor(context),
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 9),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: active ? 96 : 0,
              height: 3,
              decoration: BoxDecoration(
                color: AppColors.red,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContentCard extends StatelessWidget {
  const _ContentCard({required this.title, required this.child, this.action});

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: AppColors.inkFor(context),
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              ?action,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _AttachButton extends StatelessWidget {
  const _AttachButton({required this.text, required this.onPressed});

  final String text;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.person_add_alt_1_rounded, size: 15),
      label: Text(text),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.red,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(0, 34),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _ParticipantRow extends StatelessWidget {
  const _ParticipantRow({
    required this.participant,
    required this.strings,
    required this.api,
    required this.onProfile,
    required this.onDetach,
  });

  final TournamentParticipant participant;
  final AppStrings strings;
  final ApiClient api;
  final VoidCallback onProfile;
  final VoidCallback? onDetach;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onProfile,
      borderRadius: BorderRadius.circular(14),
      child: _SeparatedRow(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Avatar(url: participant.avatar, size: 52, api: api),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    participant.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.inkFor(context),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (participant.age != null) '${participant.age}',
                      if ((participant.weight ?? '').isNotEmpty)
                        '${participant.weight} ${strings.kg}',
                      if ((participant.rang ?? '').isNotEmpty)
                        strings.rankValue(participant.rang),
                    ].join('  •  '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.mutedFor(context),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${strings.coach}: ${participant.coachName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.mutedFor(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: [
                      _OkPill(
                        text: strings.documentsOkShort,
                        ok: participant.documentsOk,
                        icon: Icons.description_rounded,
                      ),
                      if (participant.showVideoStatus)
                        _OkPill(
                          text: participant.videoOk
                              ? strings.firstVideoReady
                              : strings.firstVideoMissing,
                          ok: participant.videoOk,
                          icon: Icons.videocam_rounded,
                        ),
                      if (participant.showVideoStatus &&
                          participant.finalVideoRequired)
                        _OkPill(
                          text: participant.finalVideoUploaded
                              ? strings.finalVideoReady
                              : strings.finalVideoMissing,
                          ok: participant.finalVideoUploaded,
                          icon: Icons.videocam_rounded,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (onDetach != null)
              TextButton.icon(
                onPressed: onDetach,
                icon: const Icon(Icons.link_off_rounded, size: 14),
                label: Text(strings.detach),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.red,
                  textStyle: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 5,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              )
            else
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.mutedFor(context),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

class _CoachRow extends StatelessWidget {
  const _CoachRow({
    required this.coach,
    required this.strings,
    required this.api,
  });

  final TournamentCoach coach;
  final AppStrings strings;
  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    return _SeparatedRow(
      child: Row(
        children: [
          _Avatar(url: coach.avatar, size: 52, api: api),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  coach.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.inkFor(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  coach.club,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.mutedFor(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${coach.studentsCount} ${strings.students.toLowerCase()}',
                  style: TextStyle(
                    color: AppColors.mutedFor(context),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
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

class _TableRowItem extends StatelessWidget {
  const _TableRowItem({
    required this.item,
    required this.tableTitle,
    required this.strings,
    required this.onOpen,
  });

  final TournamentTableItem item;
  final String tableTitle;
  final AppStrings strings;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(14),
      child: _SeparatedRow(
        child: Row(
          children: [
            Icon(
              Icons.drag_indicator_rounded,
              color: AppColors.mutedFor(context),
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.inkFor(context),
                      fontSize: 13.5,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${item.studentsCount} ${strings.participants.toLowerCase()}',
                    style: TextStyle(
                      color: AppColors.mutedFor(context),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${item.completionPercent}%',
              style: TextStyle(
                color: AppColors.mutedFor(context),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.mutedFor(context),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded, size: 23),
        filled: true,
        fillColor: AppColors.surfaceFor(context),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.borderFor(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.borderFor(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.red),
        ),
      ),
    );
  }
}

class _SeparatedRow extends StatelessWidget {
  const _SeparatedRow({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderFor(context))),
      ),
      child: child,
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.size, required this.api});

  final String? url;
  final double size;
  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: url == null
            ? ColoredBox(
                color: AppColors.surfaceFor(context),
                child: Icon(
                  Icons.person_rounded,
                  color: AppColors.mutedFor(context),
                  size: 30,
                ),
              )
            : Image.network(api.publicUrl(url!), fit: BoxFit.cover),
      ),
    );
  }
}

class _OkPill extends StatelessWidget {
  const _OkPill({required this.text, required this.ok, required this.icon});

  final String text;
  final bool ok;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: ok ? const Color(0xFFE9FAF0) : const Color(0xFFFFEFEF),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: ok ? const Color(0xFFC5EFD5) : const Color(0xFFF7C7C7),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: ok ? const Color(0xFF14975A) : AppColors.red,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: ok ? const Color(0xFF14975A) : AppColors.red,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
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
        width: 46,
        height: 46,
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
        child: Icon(icon, color: AppColors.inkFor(context), size: 24),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF8EF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFC3EFD3)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF14975A),
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
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
