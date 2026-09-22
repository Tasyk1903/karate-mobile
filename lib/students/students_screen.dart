import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../l10n/app_locale.dart';
import '../navigation/coach_bottom_nav.dart';
import '../notifications/notifications_screen.dart';
import '../notifications/notification_button.dart';
import '../theme/app_colors.dart';
import 'student_models.dart';
import 'student_invitations_screen.dart';
import 'student_history_list.dart';
import 'student_profile_screen.dart';

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key, required this.strings, required this.api});

  final AppStrings strings;
  final ApiClient api;

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _searchDebounce;
  var _searchVisible = false;
  String? _ageGroup;
  String? _rang;
  String? _gender;
  String? _tournamentStatus;
  var _students = <CoachStudent>[];
  var _isLoading = true;
  var _isLoadingMore = false;
  var _page = 1;
  var _requestGeneration = 0;
  var _lastPage = 1;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadMoreOnScroll);
    _loadStudents();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStudents({int page = 1, bool append = false}) async {
    if (append) {
      if (_isLoadingMore || _isLoading || page > _lastPage) return;
      setState(() => _isLoadingMore = true);
    } else {
      setState(() => _isLoading = true);
    }

    final request = ++_requestGeneration;
    try {
      final response = await widget.api.getJson(
        '/students',
        query: {
          'scope': 'mine',
          'page': '$page',
          'per_page': '10',
          if (_searchController.text.trim().isNotEmpty)
            'search': _searchController.text.trim(),
          'age_group': ?_ageGroup,
          'rang': ?_rang,
          'gender': ?_gender,
          'tournament_status': ?_tournamentStatus,
        },
      );

      final data = response['data'] as List<dynamic>? ?? [];
      final meta = response['meta'] as Map<String, dynamic>? ?? {};

      if (!mounted || request != _requestGeneration) return;
      setState(() {
        final nextStudents = data
            .whereType<Map<String, dynamic>>()
            .map(CoachStudent.fromJson)
            .toList();
        _students = append ? [..._students, ...nextStudents] : nextStudents;
        _page = (meta['current_page'] as num?)?.toInt() ?? page;
        _lastPage = (meta['last_page'] as num?)?.toInt() ?? 1;
      });
    } catch (error) {
      if (mounted && request == _requestGeneration) {
        _showMessage(error.toString());
      }
    } finally {
      if (mounted && request == _requestGeneration) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  void _toggleSearch() {
    setState(() => _searchVisible = !_searchVisible);
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 260),
      () => _loadStudents(),
    );
  }

  Future<void> _openFilter(
    String title,
    List<_FilterOption> options,
    ValueChanged<String?> onSelected,
  ) async {
    final value = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.surfaceFor(context),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              18,
              0,
              18,
              18 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.62,
              ),
              child: ListView(
                shrinkWrap: true,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: AppColors.inkFor(context),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...options.map(
                    (option) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        option.label,
                        style: TextStyle(
                          color: AppColors.inkFor(context),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onTap: () => Navigator.of(context).pop(option.value),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    onSelected(value);
    await _loadStudents();
  }

  void _loadMoreOnScroll() {
    if (!_scrollController.hasClients || _page >= _lastPage) return;

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 220) {
      _loadStudents(page: _page + 1, append: true);
    }
  }

  Future<void> _openStudent(CoachStudent student) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StudentProfileScreen(
          strings: widget.strings,
          api: widget.api,
          studentId: student.id,
        ),
      ),
    );
    if (mounted) await _loadStudents();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;

    return Scaffold(
      resizeToAvoidBottomInset: false,
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
            child: RefreshIndicator(
              color: AppColors.red,
              onRefresh: () => _loadStudents(),
              child: ListView(
                controller: _scrollController,
                padding: EdgeInsets.fromLTRB(
                  24,
                  18,
                  24,
                  24 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                children: [
                  _Header(
                    api: widget.api,
                    strings: strings,
                    searchVisible: _searchVisible,
                    onInvite: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => StudentInvitationsScreen(
                          api: widget.api,
                          strings: strings,
                        ),
                      ),
                    ),
                    onSearch: _toggleSearch,
                    onNotifications: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => NotificationsScreen(
                            strings: strings,
                            api: widget.api,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  _SearchAndFilters(
                    strings: strings,
                    controller: _searchController,
                    searchVisible: _searchVisible,
                    ageGroup: _ageGroup,
                    rang: _rang,
                    gender: _gender,
                    tournamentStatus: _tournamentStatus,
                    onChanged: _onSearchChanged,
                    onAge: () => _openFilter(strings.age, [
                      _FilterOption(strings.allAges, null),
                      _FilterOption('7-9', '7_9'),
                      _FilterOption('10-11', '10_11'),
                      _FilterOption('12-13', '12_13'),
                      _FilterOption(strings.from14, '14_plus'),
                    ], (value) => setState(() => _ageGroup = value)),
                    onBelt: () => _openFilter(strings.belt, [
                      _FilterOption(strings.allBelts, null),
                      for (final rank in [
                        '10 кю',
                        '9 кю',
                        '8 кю',
                        '7 кю',
                        '6 кю',
                        '5 кю',
                        '4 кю',
                        '3 кю',
                        '2 кю',
                        '1 кю',
                        '1 дан',
                      ])
                        _FilterOption(rank, widget.strings.rankValue(rank)),
                    ], (value) => setState(() => _rang = value)),
                    onGender: () => _openFilter(strings.gender, [
                      _FilterOption(strings.bothGenders, null),
                      _FilterOption(strings.male, 'male'),
                      _FilterOption(strings.female, 'female'),
                    ], (value) => setState(() => _gender = value)),
                    onTournaments: () => _openFilter(strings.tournaments, [
                      _FilterOption(strings.allTournaments, null),
                      _FilterOption(strings.withActiveTournament, 'active'),
                      _FilterOption(
                        strings.withoutActiveTournament,
                        'without_active',
                      ),
                    ], (value) => setState(() => _tournamentStatus = value)),
                  ),
                  const SizedBox(height: 16),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Center(
                        child: CircularProgressIndicator(color: AppColors.red),
                      ),
                    )
                  else if (_students.isEmpty)
                    _EmptyState(strings: strings)
                  else
                    ..._students.map(
                      (student) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _StudentCard(
                          strings: strings,
                          student: student,
                          onTap: () => _openStudent(student),
                          onCategories: () => showStudentHistory(
                            context,
                            widget.api,
                            strings,
                            student.id,
                            'categories',
                            strings.activeCategories,
                          ),
                        ),
                      ),
                    ),
                  if (_isLoadingMore)
                    const Padding(
                      padding: EdgeInsets.only(top: 10, bottom: 10),
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
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.api,
    required this.strings,
    required this.searchVisible,
    required this.onSearch,
    required this.onNotifications,
    required this.onInvite,
  });

  final AppStrings strings;
  final bool searchVisible;
  final VoidCallback onSearch;
  final VoidCallback onNotifications;
  final VoidCallback onInvite;

  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            strings.students,
            style: TextStyle(
              color: AppColors.inkFor(context),
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ),
        IconButton(
          tooltip: strings.inviteStudent,
          onPressed: onInvite,
          icon: const Icon(Icons.person_add_alt_1_outlined),
        ),
        _RoundIconButton(
          icon: searchVisible ? Icons.close_rounded : Icons.search_rounded,
          onTap: onSearch,
        ),
        const SizedBox(width: 12),
        NotificationButton(api: api, strings: strings, onOpen: onNotifications),
      ],
    );
  }
}

class _SearchAndFilters extends StatelessWidget {
  const _SearchAndFilters({
    required this.strings,
    required this.controller,
    required this.searchVisible,
    required this.ageGroup,
    required this.rang,
    required this.gender,
    required this.tournamentStatus,
    required this.onChanged,
    required this.onAge,
    required this.onBelt,
    required this.onGender,
    required this.onTournaments,
  });

  final AppStrings strings;
  final TextEditingController controller;
  final bool searchVisible;
  final String? ageGroup;
  final String? rang;
  final String? gender;
  final String? tournamentStatus;
  final ValueChanged<String> onChanged;
  final VoidCallback onAge;
  final VoidCallback onBelt;
  final VoidCallback onGender;
  final VoidCallback onTournaments;

  @override
  Widget build(BuildContext context) {
    final filters = Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _FilterChip(
                icon: Icons.calendar_month_outlined,
                label: _ageLabel(),
                active: ageGroup != null,
                onTap: onAge,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _FilterChip(
                assetPath: 'assets/images/belt-filter.png',
                label: rang == null ? strings.belt : strings.rankValue(rang),
                active: rang != null,
                onTap: onBelt,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _FilterChip(
                assetPath: 'assets/images/gender-filter.png',
                label: _genderLabel(),
                active: gender != null,
                onTap: onGender,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _FilterChip(
                icon: Icons.emoji_events_outlined,
                label: _tournamentLabel(),
                active: tournamentStatus != null,
                onTap: onTournaments,
              ),
            ),
          ],
        ),
      ],
    );

    return Column(
      children: [
        if (searchVisible) ...[
          TextField(
            controller: controller,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: strings.search,
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: AppColors.surfaceFor(context),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        filters,
      ],
    );
  }

  String _ageLabel() {
    return switch (ageGroup) {
      '7_9' => '7-9',
      '10_11' => '10-11',
      '12_13' => '12-13',
      '14_plus' => strings.from14,
      _ => strings.age,
    };
  }

  String _genderLabel() {
    return switch (gender) {
      'male' => strings.maleShort,
      'female' => strings.femaleShort,
      _ => strings.gender,
    };
  }

  String _tournamentLabel() {
    return switch (tournamentStatus) {
      'active' => strings.activeShort,
      'without_active' => strings.noActiveShort,
      _ => strings.tournaments,
    };
  }
}

class _StudentCard extends StatelessWidget {
  const _StudentCard({
    required this.strings,
    required this.student,
    required this.onTap,
    required this.onCategories,
  });

  final AppStrings strings;
  final CoachStudent student;
  final VoidCallback onTap;
  final VoidCallback onCategories;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceFor(context),
          borderRadius: BorderRadius.circular(18),
          boxShadow: _softShadow,
        ),
        child: Row(
          children: [
            _Avatar(url: student.avatarUrl, size: 70),
            const SizedBox(width: 13),
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
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      if (student.ageLabel.isNotEmpty) student.ageLabel,
                      if (student.genderLabel.isNotEmpty) student.genderLabel,
                      if (student.weight.isNotEmpty)
                        '${student.weight} ${strings.locale.isRu ? 'кг' : 'kg'}',
                    ].join('  •  '),
                    style: _mutedStyle(context),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${strings.club}: ${student.club}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _mutedStyle(context),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _MiniBelt(belt: student.belt),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_beltLabel(strings, student.belt.labelKey)} (${strings.rankValue(student.rang)})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _mutedStyle(context).copyWith(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(
                        student.activeTournaments > 0
                            ? Icons.emoji_events_outlined
                            : Icons.description_outlined,
                        color: student.activeTournaments > 0
                            ? AppColors.red
                            : AppColors.mutedFor(context),
                        size: 15,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          student.activeTournaments > 0
                              ? '${student.activeTournaments} ${student.activeTournaments == 1 ? strings.activeTournament : strings.activeTournaments}'
                              : student.documentsOk
                              ? strings.documentsOk
                              : [
                                  strings.medicalUntil,
                                  student.insuranceCloseDate,
                                ].whereType<String>().join(' '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _mutedStyle(context).copyWith(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (student.activeTournaments > 0)
              IconButton(
                tooltip: strings.activeCategories,
                onPressed: onCategories,
                icon: const Icon(Icons.list_alt_outlined, size: 20),
              ),
            Tooltip(
              waitDuration: Duration.zero,
              message: student.documentsOk
                  ? strings.documentsOk
                  : student.documentIssues
                        .map(strings.studentDocumentIssue)
                        .join('\n'),
              child: Icon(
                student.documentsOk
                    ? Icons.verified_outlined
                    : Icons.error_outline,
                color: student.documentsOk ? Colors.green : AppColors.red,
                size: 18,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.mutedFor(context),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
    this.icon,
    this.assetPath,
  });

  final IconData? icon;
  final String? assetPath;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: active
              ? AppColors.red.withValues(alpha: .12)
              : AppColors.surfaceFor(context),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: active
                ? AppColors.red.withValues(alpha: 0.18)
                : Colors.white,
          ),
          boxShadow: _softShadow,
        ),
        child: Row(
          children: [
            if (assetPath != null)
              Image.asset(
                assetPath!,
                width: 21,
                height: 21,
                fit: BoxFit.contain,
              )
            else if (icon != null)
              Icon(
                icon,
                size: 18,
                color: active ? AppColors.red : AppColors.inkFor(context),
              ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active ? AppColors.red : AppColors.inkFor(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const Spacer(),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.mutedFor(context),
              size: 15,
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterOption {
  _FilterOption(this.label, this.value);

  final String label;
  final String? value;
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 40),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(22),
        boxShadow: _softShadow,
      ),
      child: Center(
        child: Text(
          strings.noStudents,
          style: TextStyle(
            color: AppColors.mutedFor(context),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
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

class _MiniBelt extends StatelessWidget {
  const _MiniBelt({required this.belt});

  final StudentBelt belt;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 10,
      decoration: BoxDecoration(
        color: belt.color,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      alignment: Alignment.centerRight,
      child: FractionallySizedBox(
        widthFactor: 0.28,
        child: Container(
          decoration: BoxDecoration(
            color: belt.accent,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.surfaceFor(context),
          shape: BoxShape.circle,
          boxShadow: _softShadow,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [Icon(icon, color: AppColors.inkFor(context), size: 28)],
        ),
      ),
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
