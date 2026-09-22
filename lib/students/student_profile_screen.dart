import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../l10n/app_locale.dart';
import '../theme/app_colors.dart';
import 'student_edit_screen.dart';
import 'student_join_coach_screen.dart';
import 'student_models.dart';
import 'student_actions.dart';
import 'student_history_list.dart';
import '../navigation/coach_bottom_nav.dart';

enum StudentProfileTab { rating, documents, tournaments }

class StudentProfileScreen extends StatefulWidget {
  const StudentProfileScreen({
    super.key,
    required this.strings,
    required this.api,
    required this.studentId,
    this.tournamentId,
    this.championshipId,
    this.ownProfile = false,
    this.active = true,
  });

  final AppStrings strings;
  final ApiClient api;
  final int studentId;
  final int? tournamentId, championshipId;
  final bool ownProfile;
  final bool active;

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen>
    with WidgetsBindingObserver {
  var _isLoading = true;
  String? _error;
  bool _publicOnly = false, _detaching = false;
  var _tab = StudentProfileTab.rating;
  StudentDetail? _student;
  StudentRatingCard? _kumite;
  StudentRatingCard? _kata;
  StudentRecord? _record;
  var _documents = <StudentDocument>[];
  var _documentFields = <StudentDocumentField>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadProfile();
  }

  @override
  void didUpdateWidget(covariant StudentProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ownProfile &&
        widget.active &&
        !oldWidget.active &&
        !_isLoading) {
      _loadProfile();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        widget.ownProfile &&
        widget.active &&
        !_isLoading &&
        ModalRoute.of(context)?.isCurrent == true) {
      _loadProfile();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      Map<String, dynamic> response;
      try {
        response = await widget.api.getJson('/students/${widget.studentId}');
      } on ApiException catch (e) {
        if (e.statusCode != 403 ||
            widget.tournamentId == null ||
            widget.championshipId == null) {
          rethrow;
        }
        response = await widget.api.getJson(
          '/students/${widget.studentId}/public',
          query: {
            'tournament_id': '${widget.tournamentId}',
            'championship_id': '${widget.championshipId}',
          },
        );
      }
      final rating = response['rating'] as Map<String, dynamic>? ?? {};
      final docs = response['documents'] as Map<String, dynamic>? ?? {};

      if (!mounted) return;
      setState(() {
        _publicOnly = response['public_only'] == true;
        _student = StudentDetail.fromJson(
          response['student'] as Map<String, dynamic>? ?? {},
        );
        _kumite = StudentRatingCard.fromJson(
          rating['kumite'] as Map<String, dynamic>?,
        );
        _kata = StudentRatingCard.fromJson(
          rating['kata'] as Map<String, dynamic>?,
        );
        _record = StudentRecord.fromJson(
          rating['record'] as Map<String, dynamic>?,
        );
        _documents = (docs['items'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(StudentDocument.fromJson)
            .toList();
        _documentFields = (docs['fields'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(StudentDocumentField.fromJson)
            .toList();
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _student = null;
          _documents = [];
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _detach() async {
    if (_detaching) return;
    setState(() => _detaching = true);
    try {
      if (!await confirmStudentAction(
        context,
        widget.strings,
        widget.strings.detachStudentConfirm,
        widget.strings.detachStudent,
      )) {
        return;
      }
      if (!mounted) return;
      await widget.api.postJson(
        '/students/${widget.studentId}/detach',
        body: {'confirmed': true},
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _showMessage(e.toString());
    } finally {
      if (mounted) setState(() => _detaching = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    final student = _student;

    return Scaffold(
      bottomNavigationBar: widget.ownProfile
          ? CoachBottomNav(
              strings: strings,
              api: widget.api,
              active: CoachNavItem.profile,
            )
          : null,
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
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.red),
                  )
                : student == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error ?? '—', textAlign: TextAlign.center),
                      TextButton(
                        onPressed: _loadProfile,
                        child: Text(strings.retry),
                      ),
                      if (!widget.ownProfile)
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back),
                        ),
                    ],
                  )
                : RefreshIndicator(
                    color: AppColors.red,
                    onRefresh: _loadProfile,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                      children: [
                        _TopBar(
                          ownProfile: widget.ownProfile,
                          strings: strings,
                          onDetach: student.canEdit('detach') && !_detaching
                              ? _detach
                              : null,
                          onEdit: !student.canEdit('edit')
                              ? null
                              : () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => StudentEditScreen(
                                        strings: strings,
                                        api: widget.api,
                                        student: student,
                                        documents: _documents,
                                        onPreview: (doc) =>
                                            _openDocumentPreview(
                                              context,
                                              strings,
                                              doc,
                                              widget.api,
                                            ),
                                      ),
                                    ),
                                  );
                                  if (context.mounted) {
                                    await _loadProfile();
                                  }
                                },
                        ),
                        const SizedBox(height: 18),
                        _ProfileHero(strings: strings, student: student),
                        if (widget.ownProfile &&
                            widget.api.isStudent &&
                            student.canEdit('join_coach')) ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.person_add_alt_1, size: 18),
                            label: Text(
                              strings.joinCoach,
                              textAlign: TextAlign.center,
                            ),
                            onPressed: () async {
                              final joined = await Navigator.of(context)
                                  .push<bool>(
                                    MaterialPageRoute(
                                      builder: (_) => StudentJoinCoachScreen(
                                        api: widget.api,
                                        strings: strings,
                                      ),
                                    ),
                                  );
                              if (!mounted) return;
                              await _loadProfile();
                              if (joined == true && mounted) {
                                _showMessage(strings.coachJoined);
                              }
                            },
                          ),
                        ],
                        const SizedBox(height: 18),
                        if (!_publicOnly) ...[
                          _Tabs(
                            strings: strings,
                            tab: _tab,
                            onChanged: (tab) => setState(() => _tab = tab),
                          ),
                          const SizedBox(height: 18),
                          if (_tab == StudentProfileTab.rating)
                            _RatingTab(
                              strings: strings,
                              kumite: _kumite!,
                              kata: _kata!,
                              record: _record!,
                              api: widget.api,
                              studentId: widget.studentId,
                            )
                          else if (_tab == StudentProfileTab.documents)
                            _DocumentsTab(
                              api: widget.api,
                              strings: strings,
                              documents: _documents,
                              fields: _documentFields,
                            )
                          else
                            StudentHistoryList(
                              api: widget.api,
                              strings: strings,
                              studentId: widget.studentId,
                              kind: 'tournaments',
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
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.strings,
    this.onEdit,
    this.onDetach,
    this.ownProfile = false,
  });

  final AppStrings strings;
  final VoidCallback? onEdit, onDetach;
  final bool ownProfile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (ownProfile)
          const SizedBox(width: 48)
        else
          _CircleButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.of(context).pop(),
          ),
        Expanded(
          child: Text(
            ownProfile ? strings.profile : strings.studentProfile,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.inkFor(context),
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (onDetach != null)
          IconButton(
            tooltip: strings.detachStudent,
            onPressed: onDetach,
            icon: const Icon(Icons.person_remove_outlined, size: 20),
          ),
        if (onEdit != null)
          _CircleButton(icon: Icons.edit_rounded, onTap: onEdit!),
      ],
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.strings, required this.student});

  final AppStrings strings;
  final StudentDetail student;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(26),
        boxShadow: _softShadow,
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(url: student.avatarUrl, size: 88),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.fullName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.inkFor(context),
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _InfoLine(
                      assetPath: 'assets/images/club-icon.png',
                      text: '${strings.club}: ${student.club}',
                    ),
                    const SizedBox(height: 5),
                    _InfoLine(
                      assetPath: 'assets/images/coach-icon.png',
                      text: '${strings.coach}: ${student.coachName}',
                    ),
                    const SizedBox(height: 8),
                    _BeltProgress(belt: student.belt),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          strings.rankValue(student.rang),
                          style: TextStyle(
                            color: AppColors.inkFor(context),
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: student.belt.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: student.belt.accent.withValues(
                                alpha: 0.35,
                              ),
                            ),
                          ),
                          child: Text(
                            _beltLabel(strings, student.belt.labelKey),
                            style: TextStyle(
                              color:
                                  student.belt.accent.computeLuminance() > 0.65
                                  ? const Color(0xFF9A6A00)
                                  : student.belt.accent,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final compactTileWidth = (constraints.maxWidth - 24) / 5;

              return Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _FactTile(
                    width: compactTileWidth,
                    assetPath: 'assets/images/age-icon.png',
                    value: student.ageLabel,
                  ),
                  _FactTile(
                    width: compactTileWidth,
                    assetPath: 'assets/images/gender-icon.png',
                    value: student.genderLabel,
                  ),
                  _FactTile(
                    width: compactTileWidth,
                    assetPath: 'assets/images/birth-date-icon.png',
                    value: student.birthday,
                  ),
                  _FactTile(
                    width: compactTileWidth,
                    assetPath: 'assets/images/weight-icon.png',
                    value: student.weight == '—'
                        ? '—'
                        : '${student.weight} ${strings.kg}',
                  ),
                  _FactTile(
                    width: compactTileWidth,
                    assetPath: 'assets/images/height-icon.png',
                    value: student.height == '—'
                        ? '—'
                        : '${student.height} ${strings.cm}',
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.strings,
    required this.tab,
    required this.onChanged,
  });

  final AppStrings strings;
  final StudentProfileTab tab;
  final ValueChanged<StudentProfileTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(18),
        boxShadow: _softShadow,
      ),
      child: Row(
        children: [
          _TabButton(
            label: strings.rating,
            active: tab == StudentProfileTab.rating,
            onTap: () => onChanged(StudentProfileTab.rating),
          ),
          _TabButton(
            label: strings.documents,
            active: tab == StudentProfileTab.documents,
            onTap: () => onChanged(StudentProfileTab.documents),
          ),
          _TabButton(
            label: strings.tournaments,
            active: tab == StudentProfileTab.tournaments,
            onTap: () => onChanged(StudentProfileTab.tournaments),
          ),
        ],
      ),
    );
  }
}

class _RatingTab extends StatelessWidget {
  const _RatingTab({
    required this.strings,
    required this.kumite,
    required this.kata,
    required this.record,
    required this.api,
    required this.studentId,
  });

  final AppStrings strings;
  final StudentRatingCard kumite;
  final StudentRatingCard kata;
  final StudentRecord record;
  final ApiClient api;
  final int studentId;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _RatingCard(
          strings: strings,
          title: strings.kumite,
          assetPath: 'assets/images/student-kumite.png',
          tint: AppColors.red,
          rating: kumite,
        ),
        const SizedBox(height: 14),
        _RatingCard(
          strings: strings,
          title: strings.kata,
          assetPath: 'assets/images/student-kata.png',
          tint: const Color(0xFF1E67B1),
          rating: kata,
        ),
        const SizedBox(height: 14),
        _RecordCard(
          strings: strings,
          record: record,
          onWins: () => showStudentHistory(
            context,
            api,
            strings,
            studentId,
            'wins',
            strings.wins,
          ),
          onLosses: () => showStudentHistory(
            context,
            api,
            strings,
            studentId,
            'losses',
            strings.losses,
          ),
        ),
      ],
    );
  }
}

class _DocumentsTab extends StatelessWidget {
  const _DocumentsTab({
    required this.api,
    required this.strings,
    required this.documents,
    required this.fields,
  });

  final AppStrings strings;
  final List<StudentDocument> documents;
  final ApiClient api;
  final List<StudentDocumentField> fields;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (fields.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final field in fields)
                  _DocumentFieldChip(
                    label: _documentFieldLabel(strings, field.labelKey),
                    value: field.value,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Divider(height: 1, color: AppColors.borderFor(context)),
            const SizedBox(height: 14),
          ],
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final document in documents)
                _DocumentCard(strings: strings, document: document, api: api),
            ],
          ),
        ],
      ),
    );
  }
}

class _RatingCard extends StatelessWidget {
  const _RatingCard({
    required this.strings,
    required this.title,
    required this.assetPath,
    required this.tint,
    required this.rating,
  });

  final AppStrings strings;
  final String title;
  final String assetPath;
  final Color tint;
  final StudentRatingCard rating;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        children: [
          Row(
            children: [
              _AssetCircleIcon(path: assetPath, tint: tint),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: AppColors.inkFor(context),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${strings.rating} ${rating.year}',
                      style: _mutedStyle(context).copyWith(fontSize: 12),
                    ),
                    if (rating.subtitle != null)
                      Text(
                        rating.subtitle!,
                        style: _mutedStyle(context).copyWith(fontSize: 11),
                      ),
                  ],
                ),
              ),
              _BigMetric(value: rating.label, label: strings.position),
              const _Divider(height: 34),
              _BigMetric(value: '${rating.points}', label: strings.points),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: AppColors.borderFor(context)),
          const SizedBox(height: 12),
          Row(
            children: [
              _MedalMetric(
                assetPath: 'assets/images/medal-gold.png',
                label: strings.gold,
                value: rating.medals.gold,
              ),
              const _Divider(height: 34),
              _MedalMetric(
                assetPath: 'assets/images/medal-silver.png',
                label: strings.silver,
                value: rating.medals.silver,
              ),
              const _Divider(height: 34),
              _MedalMetric(
                assetPath: 'assets/images/medal-bronze.png',
                label: strings.bronze,
                value: rating.medals.bronze,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.strings,
    required this.record,
    required this.onWins,
    required this.onLosses,
  });

  final AppStrings strings;
  final StudentRecord record;
  final VoidCallback onWins;
  final VoidCallback onLosses;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const _AssetCircleIcon(
                path: 'assets/images/student-record.png',
                tint: Color(0xFF15935A),
                size: 36,
              ),
              const SizedBox(width: 10),
              Text(
                strings.record,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.inkFor(context),
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _RecordButton(
                  value: '${record.wins}',
                  label: strings.wins,
                  color: const Color(0xFF15935A),
                  onTap: onWins,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _RecordButton(
                  value: '${record.losses}',
                  label: strings.losses,
                  color: AppColors.red,
                  onTap: onLosses,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E67B1).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF1E67B1).withValues(alpha: 0.18),
                    ),
                  ),
                  child: _BigMetric(
                    value: '${record.total}',
                    label: strings.totalFights,
                    color: const Color(0xFF1E67B1),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecordButton extends StatelessWidget {
  const _RecordButton({
    required this.value,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String value;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: _BigMetric(value: value, label: label, color: color),
      ),
    );
  }
}

class _DocumentFieldChip extends StatelessWidget {
  const _DocumentFieldChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 138,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderFor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _mutedStyle(context).copyWith(fontSize: 10),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.inkFor(context),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.strings,
    required this.document,
    required this.api,
  });

  final ApiClient api;

  final AppStrings strings;
  final StudentDocument document;

  @override
  Widget build(BuildContext context) {
    final confirmed = document.ok;
    final statusColor = !document.included
        ? AppColors.mutedFor(context)
        : confirmed
        ? const Color(0xFF15935A)
        : AppColors.red;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: document.fileUrl == null
          ? null
          : () => _openDocumentPreview(context, strings, document, api),
      child: Container(
        width: 138,
        decoration: BoxDecoration(
          color: AppColors.surfaceFor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderFor(context)),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 96,
                width: double.infinity,
                color: Colors.white,
                child: document.fileUrl == null
                    ? Icon(
                        Icons.description_outlined,
                        color: AppColors.mutedFor(context),
                      )
                    : Image.network(
                        api.publicUrl(document.fileUrl!),
                        headers: api.mediaHeaders(document.fileUrl!),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.broken_image_outlined),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _documentLabel(strings, document.key),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.inkFor(context),
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (document.expiresAt != null)
              Text(
                document.expiresAt!,
                style: _mutedStyle(context).copyWith(fontSize: 10),
              ),
            const SizedBox(height: 5),
            Row(
              children: [
                Icon(
                  confirmed ? Icons.verified_rounded : Icons.error_outline,
                  size: 15,
                  color: statusColor,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    !document.included
                        ? strings.documentExcluded
                        : confirmed
                        ? strings.documentsOk
                        : strings.studentDocumentIssue(document.issueKey),
                    style: _mutedStyle(context).copyWith(fontSize: 10),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FactTile extends StatelessWidget {
  const _FactTile({required this.value, required this.width, this.assetPath});

  final String? assetPath;
  final double width;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppColors.borderFor(context)),
      ),
      child: Column(
        children: [
          if (assetPath != null)
            SizedBox(
              width: 18,
              height: 18,
              child: ClipRect(
                child: OverflowBox(
                  minWidth: 34,
                  minHeight: 34,
                  maxWidth: 34,
                  maxHeight: 34,
                  child: Image.asset(assetPath!, fit: BoxFit.contain),
                ),
              ),
            )
          else
            Icon(
              Icons.info_outline_rounded,
              color: AppColors.inkFor(context),
              size: 20,
            ),
          const SizedBox(height: 3),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: TextStyle(
                  color: AppColors.inkFor(context),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(22),
        boxShadow: _softShadow,
      ),
      child: child,
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.text, this.assetPath});

  final String? assetPath;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (assetPath != null)
          SizedBox(
            width: 18,
            height: 18,
            child: ClipRect(
              child: OverflowBox(
                minWidth: 38,
                minHeight: 38,
                maxWidth: 38,
                maxHeight: 38,
                child: Image.asset(assetPath!, fit: BoxFit.contain),
              ),
            ),
          )
        else
          Icon(
            Icons.info_outline_rounded,
            color: AppColors.mutedFor(context),
            size: 18,
          ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _mutedStyle(context).copyWith(fontSize: 14),
          ),
        ),
      ],
    );
  }
}

class _BeltProgress extends StatelessWidget {
  const _BeltProgress({required this.belt});

  final StudentBelt belt;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: Stack(
        children: [
          Container(
            height: 8,
            color: belt.progress <= 0 ? const Color(0xFFE5E7EB) : belt.color,
          ),
          Positioned(
            right: 18,
            top: 0,
            bottom: 0,
            child: Container(width: 12, color: belt.accent),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.size});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.surfaceFor(context),
      backgroundImage: url == null ? null : NetworkImage(url!),
      child: url == null
          ? Icon(
              Icons.person_rounded,
              color: AppColors.mutedFor(context),
              size: size * 0.42,
            )
          : null,
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
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.surfaceFor(context),
          shape: BoxShape.circle,
          boxShadow: _softShadow,
        ),
        child: Icon(icon, color: AppColors.inkFor(context), size: 28),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.red : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : AppColors.mutedFor(context),
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _AssetCircleIcon extends StatelessWidget {
  const _AssetCircleIcon({
    required this.path,
    required this.tint,
    this.size = 46,
  });

  final String path;
  final Color tint;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      padding: EdgeInsets.all(size <= 40 ? 6 : 7),
      child: Image.asset(path, fit: BoxFit.contain),
    );
  }
}

class _BigMetric extends StatelessWidget {
  const _BigMetric({
    required this.value,
    required this.label,
    this.color = AppColors.red,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: _mutedStyle(context).copyWith(fontSize: 8.5),
          ),
        ],
      ),
    );
  }
}

class _MedalMetric extends StatelessWidget {
  const _MedalMetric({
    required this.assetPath,
    required this.label,
    required this.value,
  });

  final String assetPath;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(assetPath, width: 20, height: 20, fit: BoxFit.contain),
          const SizedBox(width: 5),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _mutedStyle(context).copyWith(fontSize: 11),
                ),
                Text(
                  '$value',
                  style: TextStyle(
                    color: AppColors.inkFor(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
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

class _Divider extends StatelessWidget {
  const _Divider({this.height = 54});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      color: AppColors.borderFor(context),
    );
  }
}

String _beltLabel(AppStrings strings, String key) {
  return switch (key) {
    'whiteBelt' => strings.whiteBelt,
    'orangeBelt' => strings.orangeBelt,
    'blueBelt' => strings.blueBelt,
    'yellowBelt' => strings.yellowBelt,
    'greenBelt' => strings.greenBelt,
    'brownBelt' => strings.brownBelt,
    'blackBelt' => strings.blackBelt,
    _ => strings.beltNotSet,
  };
}

String _documentLabel(AppStrings strings, String key) {
  return switch (key) {
    'insurance' => strings.insurance,
    'ikoCard' => strings.ikoCard,
    'certificate' => strings.certificate,
    'passport' => strings.passport,
    'brand' => strings.brand,
    _ => key,
  };
}

String _documentFieldLabel(AppStrings strings, String key) {
  return switch (key) {
    'brandNumber' => strings.brandNumber,
    'ikoNumber' => strings.ikoNumber,
    'certificateNumber' => strings.certificateNumber,
    'lastExamDate' => strings.lastExamDate,
    'lastExamCity' => strings.lastExamCity,
    'lastReceiving' => strings.lastReceiving,
    'insuranceCloseDate' => strings.medicalUntil,
    'includedInDocumentCheck' => strings.includedInDocumentCheck,
    _ => key,
  };
}

void _openDocumentPreview(
  BuildContext context,
  AppStrings strings,
  StudentDocument document,
  ApiClient api,
) {
  showDialog<void>(
    context: context,
    builder: (context) => Dialog.fullscreen(
      backgroundColor: Colors.black.withValues(alpha: 0.92),
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: Center(
                  child: Image.network(
                    api.publicUrl(document.fileUrl!),
                    headers: api.mediaHeaders(document.fileUrl!),
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white,
                      size: 46,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 18,
              top: 14,
              right: 76,
              child: Text(
                _documentLabel(strings, document.key),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Positioned(
              right: 14,
              top: 8,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

TextStyle _mutedStyle(BuildContext context) => TextStyle(
  color: AppColors.mutedFor(context),
  fontSize: 15,
  fontWeight: FontWeight.w600,
);

final _softShadow = [
  BoxShadow(
    color: Colors.black.withValues(alpha: 0.07),
    blurRadius: 24,
    offset: const Offset(0, 10),
  ),
];
