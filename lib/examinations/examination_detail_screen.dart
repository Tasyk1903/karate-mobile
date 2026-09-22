import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../files/download_helper.dart';
import '../l10n/app_locale.dart';
import '../navigation/coach_bottom_nav.dart';
import '../theme/app_colors.dart';
import '../students/student_actions.dart';
import 'examination_models.dart';
import '../tournaments/tournament_models.dart';
import '../tournaments/tournament_student_picker.dart';

class ExaminationDetailScreen extends StatefulWidget {
  const ExaminationDetailScreen({
    super.key,
    required this.strings,
    required this.api,
    required this.examinationId,
  });

  final AppStrings strings;
  final ApiClient api;
  final int examinationId;

  @override
  State<ExaminationDetailScreen> createState() =>
      _ExaminationDetailScreenState();
}

class _ExaminationDetailScreenState extends State<ExaminationDetailScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  MobileExamination? _exam;
  var _students = <ExaminationStudent>[];
  var _coaches = <ExaminationCoach>[];
  var _isLoading = true;
  var _isLoadingMore = false;
  int? _selectedCoachId;
  var _page = 1;
  var _lastPage = 1;
  var _total = 0;
  var _studentsGeneration = 0;
  String? _examError;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadMoreOnScroll);
    _loadAll();
  }

  @override
  void dispose() {
    _studentsGeneration++;
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadExam(), _loadStudents()]);
  }

  Future<void> _loadExam() async {
    setState(() => _examError = null);
    try {
      final response = await widget.api.getJson(
        '/examinations/${widget.examinationId}',
      );
      if (!mounted) return;
      setState(() {
        _exam = MobileExamination.fromJson(
          response['item'] as Map<String, dynamic>? ?? {},
        );
      });
    } catch (error) {
      if (mounted) setState(() => _examError = error.toString());
    }
  }

  Future<void> _loadStudents({int page = 1, bool append = false}) async {
    if (append) {
      if (_isLoadingMore || _isLoading || page > _lastPage) return;
      setState(() => _isLoadingMore = true);
    } else {
      setState(() => _isLoading = true);
    }

    final generation = ++_studentsGeneration;
    try {
      final response = await widget.api.getJson(
        '/examinations/${widget.examinationId}/students',
        query: {
          'page': '$page',
          'per_page': '10',
          if (_searchController.text.trim().isNotEmpty)
            'search': _searchController.text.trim(),
          if (_selectedCoachId != null) 'coach_id': '$_selectedCoachId',
        },
      );
      final data = response['data'] as List<dynamic>? ?? [];
      final meta = response['meta'] as Map<String, dynamic>? ?? {};
      final filters = response['filters'] as Map<String, dynamic>? ?? {};

      if (!mounted || generation != _studentsGeneration) return;
      setState(() {
        final nextStudents = data
            .whereType<Map<String, dynamic>>()
            .map(ExaminationStudent.fromJson)
            .toList();
        _students = append ? [..._students, ...nextStudents] : nextStudents;
        _page = (meta['current_page'] as num?)?.toInt() ?? page;
        _lastPage = (meta['last_page'] as num?)?.toInt() ?? 1;
        _total = (meta['total'] as num?)?.toInt() ?? _students.length;
        _coaches = (filters['coaches'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(ExaminationCoach.fromJson)
            .toList();
      });
    } catch (error) {
      if (mounted && generation == _studentsGeneration) {
        _showMessage(error.toString());
      }
    } finally {
      if (mounted && generation == _studentsGeneration) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  void _loadMoreOnScroll() {
    if (!_scrollController.hasClients || _page >= _lastPage) return;

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 220) {
      _loadStudents(page: _page + 1, append: true);
    }
  }

  final _detachingIds = <int>{};
  bool _selfBusy = false;

  Future<void> _attachSelf() async {
    if (_selfBusy) return;
    setState(() => _selfBusy = true);
    try {
      if (!await confirmStudentAction(
        context,
        widget.strings,
        widget.strings.joinExamConfirm,
        widget.strings.joinExam,
      )) {
        return;
      }
      await widget.api.postJson(
        '/examinations/${widget.examinationId}/self',
        body: {},
      );
      if (mounted) await _loadAll();
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _selfBusy = false);
    }
  }

  Future<void> _detach(ExaminationStudent student) async {
    if (!_detachingIds.add(student.id)) return;
    try {
      if (!await confirmStudentAction(
        context,
        widget.strings,
        widget.strings.detach,
        widget.strings.detach,
      )) {
        return;
      }
      try {
        await widget.api.deleteJson(
          '/examinations/${widget.examinationId}/students/${student.id}',
        );
        await _loadAll();
      } catch (error) {
        _showMessage(error.toString());
      }
    } finally {
      _detachingIds.remove(student.id);
    }
  }

  Future<void> _exportExcel() async {
    try {
      final bytes = await widget.api.getBytes(
        '/examinations/${widget.examinationId}/students/export',
        query: {if (_selectedCoachId != null) 'coach_id': '$_selectedCoachId'},
      );
      final file = await DownloadHelper.saveBytes(
        bytes: bytes,
        fileName: 'examination-${widget.examinationId}-students.xlsx',
      );
      await DownloadHelper.share(file);
      _showMessage('${widget.strings.fileSaved}: ${file.name}');
    } catch (error) {
      _showMessage(error.toString());
    }
  }

  Future<void> _openCoachFilter() async {
    final search = TextEditingController();
    var filtered = List<ExaminationCoach>.from(_coaches);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void filter(String value) {
              setSheetState(() {
                filtered = _coaches
                    .where(
                      (coach) => coach.fullName.toLowerCase().contains(
                        value.toLowerCase(),
                      ),
                    )
                    .toList();
              });
            }

            void choose(int? id) {
              Navigator.of(context).pop();
              setState(() => _selectedCoachId = id);
              _loadStudents();
            }

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.56,
              ),
              margin: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
              decoration: BoxDecoration(
                color: AppColors.surfaceFor(context),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.borderFor(context),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.strings.trainerFilter,
                    style: TextStyle(
                      color: AppColors.inkFor(context),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: search,
                    onChanged: filter,
                    decoration: InputDecoration(
                      hintText: widget.strings.search,
                      prefixIcon: const Icon(Icons.search_rounded),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        _CoachOptionTile(
                          title: widget.strings.all,
                          selected: _selectedCoachId == null,
                          onTap: () => choose(null),
                        ),
                        for (final coach in filtered)
                          _CoachOptionTile(
                            title: coach.fullName,
                            selected: _selectedCoachId == coach.id,
                            onTap: () => choose(coach.id),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openAttachSheet() async {
    final path = '/examinations/${widget.examinationId}';
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => TournamentStudentPicker(
        api: widget.api,
        strings: widget.strings,
        path: path,
        optionsPath: '$path/attach-options',
        parseStudent: (json) => TournamentAttachStudent.fromJson({
          ...json,
          'name': json['full_name'] ?? json['name'],
          'age': json['age_years'],
        }),
        submit: (students) async {
          final response = await widget.api.postJson(
            '$path/students',
            body: {'student_ids': students.map((s) => s.id).toList()},
          );
          if ((response['attached'] as List<dynamic>? ?? []).isEmpty) {
            throw Exception(widget.strings.examNoStudentsAttached);
          }
        },
      ),
    );
    if (changed == true && mounted) await _loadAll();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    final exam = _exam;

    return Scaffold(
      backgroundColor: AppColors.pageFor(context),
      bottomNavigationBar: CoachBottomNav(
        strings: strings,
        api: widget.api,
        active: null,
      ),
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
            child: _examError != null
                ? Column(
                    children: [
                      _TopBar(strings: strings),
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(20),
                                child: Text(
                                  _examError!,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              TextButton(
                                onPressed: _loadAll,
                                child: Text(strings.retry),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : exam == null
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.red),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: RefreshIndicator(
                          color: AppColors.red,
                          onRefresh: _loadAll,
                          child: ListView(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
                            children: [
                              _TopBar(strings: strings),
                              const SizedBox(height: 18),
                              _ExamInfo(strings: strings, exam: exam),
                              const SizedBox(height: 20),
                              _ParticipantsPanel(
                                strings: strings,
                                searchController: _searchController,
                                isLoading: _isLoading,
                                isLoadingMore: _isLoadingMore,
                                students: _students,
                                total: _total,
                                onSearch: (_) => _loadStudents(),
                                onAttach: widget.api.isStudent
                                    ? (exam.canAttachSelf && !_selfBusy
                                          ? _attachSelf
                                          : null)
                                    : _openAttachSheet,
                                self: widget.api.isStudent,
                                onExport: widget.api.isStudent
                                    ? null
                                    : _exportExcel,
                                onCoachFilter: _openCoachFilter,
                                onDetach: _detach,
                              ),
                            ],
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
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.strings});

  final AppStrings strings;

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
            strings.exam,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.inkFor(context),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }
}

class _ExamInfo extends StatelessWidget {
  const _ExamInfo({required this.strings, required this.exam});

  final AppStrings strings;
  final MobileExamination exam;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(24),
        boxShadow: _softShadow,
      ),
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.calendar_month_outlined,
            label: strings.examName,
            value: exam.name,
          ),
          Divider(height: 22, color: AppColors.borderFor(context)),
          _InfoRow(
            icon: Icons.location_on_outlined,
            label: strings.examPlace,
            value: exam.city,
          ),
          Divider(height: 22, color: AppColors.borderFor(context)),
          _InfoRow(
            icon: Icons.calendar_today_outlined,
            label: strings.date,
            value: exam.dateLabel,
          ),
          Divider(height: 22, color: AppColors.borderFor(context)),
          _InfoRow(
            icon: Icons.person_outline_rounded,
            label: strings.receiving,
            value: exam.receiving,
          ),
        ],
      ),
    );
  }
}

class _ParticipantsPanel extends StatelessWidget {
  const _ParticipantsPanel({
    required this.strings,
    required this.searchController,
    required this.isLoading,
    required this.isLoadingMore,
    required this.students,
    required this.total,
    required this.onSearch,
    required this.onAttach,
    required this.onExport,
    required this.onCoachFilter,
    required this.onDetach,
    this.self = false,
  });

  final AppStrings strings;
  final TextEditingController searchController;
  final bool isLoading;
  final bool isLoadingMore;
  final List<ExaminationStudent> students;
  final int total;
  final ValueChanged<String> onSearch;
  final VoidCallback? onAttach;
  final VoidCallback? onExport;
  final bool self;
  final VoidCallback onCoachFilter;
  final ValueChanged<ExaminationStudent> onDetach;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(24),
        boxShadow: _softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.students,
            style: TextStyle(
              color: AppColors.inkFor(context),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (onAttach != null)
                Expanded(
                  flex: 6,
                  child: ElevatedButton.icon(
                    onPressed: onAttach,
                    icon: const Icon(Icons.add_rounded, size: 17),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        self ? strings.joinExam : strings.attachStudent,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.red,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(38),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              if (onExport != null) const SizedBox(width: 12),
              if (onExport != null)
                Expanded(
                  flex: 5,
                  child: OutlinedButton.icon(
                    onPressed: onExport,
                    icon: const Icon(Icons.download_rounded, size: 17),
                    label: Text(strings.excel),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.mutedFor(context),
                      minimumSize: const Size.fromHeight(38),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                      side: BorderSide(color: AppColors.borderFor(context)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchController,
                  onChanged: onSearch,
                  decoration: InputDecoration(
                    hintText: strings.search,
                    prefixIcon: const Icon(Icons.search_rounded),
                    contentPadding: const EdgeInsets.symmetric(vertical: 7),
                    filled: true,
                    fillColor: AppColors.surfaceFor(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: AppColors.borderFor(context),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: AppColors.borderFor(context),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.borderFor(context)),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: IconButton(
                  onPressed: onCoachFilter,
                  icon: const Icon(Icons.tune_rounded),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: AppColors.red),
              ),
            )
          else if (students.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(child: Text(strings.noParticipants)),
            )
          else
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.borderFor(context)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Column(
                  children: [
                    for (final student in students)
                      _StudentRow(
                        student: student,
                        strings: strings,
                        onDetach: () => onDetach(student),
                      ),
                  ],
                ),
              ),
            ),
          if (!isLoading && students.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Center(
                child: Text(
                  '${strings.shown} ${students.length} ${strings.of} $total',
                  style: TextStyle(
                    color: AppColors.mutedFor(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          if (isLoadingMore)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.red,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({
    required this.student,
    required this.strings,
    required this.onDetach,
  });

  final ExaminationStudent student;
  final AppStrings strings;
  final VoidCallback onDetach;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderFor(context))),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFFE5E7EB),
            child: Icon(
              Icons.person_rounded,
              color: AppColors.mutedFor(context),
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.inkFor(context),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    student.age,
                    strings.rankValue(student.rang),
                  ].where((item) => item.isNotEmpty).join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.mutedFor(context),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (student.canDetach) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onDetach,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 34),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                strings.detach,
                style: TextStyle(
                  color: AppColors.accentFor(context),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CoachOptionTile extends StatelessWidget {
  const _CoachOptionTile({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        dense: true,
        onTap: onTap,
        title: Text(
          title,
          style: TextStyle(
            color: selected ? AppColors.red : AppColors.inkFor(context),
            fontWeight: FontWeight.w800,
          ),
        ),
        trailing: selected
            ? Icon(Icons.check_rounded, color: AppColors.accentFor(context))
            : null,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.inkFor(context), size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: AppColors.mutedFor(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                value,
                style: TextStyle(
                  color: AppColors.inkFor(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
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
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: AppColors.surfaceFor(context),
          shape: BoxShape.circle,
          boxShadow: _softShadow,
        ),
        child: Icon(icon, color: AppColors.inkFor(context), size: 24),
      ),
    );
  }
}

final _softShadow = [
  BoxShadow(
    color: Colors.black.withValues(alpha: 0.07),
    blurRadius: 24,
    offset: const Offset(0, 10),
  ),
];
