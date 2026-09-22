import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../l10n/app_locale.dart';
import '../navigation/coach_bottom_nav.dart';
import '../notifications/notifications_screen.dart';
import '../notifications/notification_button.dart';
import '../theme/app_colors.dart';
import 'examination_detail_screen.dart';
import 'examination_models.dart';

class ExaminationsScreen extends StatefulWidget {
  const ExaminationsScreen({
    super.key,
    required this.strings,
    required this.api,
  });

  final AppStrings strings;
  final ApiClient api;

  @override
  State<ExaminationsScreen> createState() => _ExaminationsScreenState();
}

class _ExaminationsScreenState extends State<ExaminationsScreen> {
  final _searchController = TextEditingController();
  var _exams = <MobileExamination>[];
  var _cities = <String>[];
  var _receivings = <String>[];
  var _isLoading = true;
  var _searchVisible = false;
  String? _selectedCity;
  String? _selectedReceiving;
  DateTimeRange? _selectedDateRange;
  var _page = 1;
  var _requestGeneration = 0;
  var _lastPage = 1;
  var _total = 0;

  @override
  void initState() {
    super.initState();
    _loadExams();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadExams({int page = 1}) async {
    setState(() => _isLoading = true);

    final request = ++_requestGeneration;
    try {
      final response = await widget.api.getJson(
        '/examinations',
        query: {
          'page': '$page',
          'per_page': '10',
          if (_searchController.text.trim().isNotEmpty)
            'search': _searchController.text.trim(),
          if (_selectedCity != null) 'city': _selectedCity,
          if (_selectedReceiving != null) 'receiving': _selectedReceiving,
          if (_selectedDateRange != null)
            'date_from': _dateQuery(_selectedDateRange!.start),
          if (_selectedDateRange != null)
            'date_to': _dateQuery(_selectedDateRange!.end),
        },
      );
      final data = response['data'] as List<dynamic>? ?? [];
      final meta = response['meta'] as Map<String, dynamic>? ?? {};
      final filters = response['filters'] as Map<String, dynamic>? ?? {};

      if (!mounted || request != _requestGeneration) return;
      setState(() {
        _exams = data
            .whereType<Map<String, dynamic>>()
            .map(MobileExamination.fromJson)
            .toList();
        _page = (meta['current_page'] as num?)?.toInt() ?? page;
        _lastPage = (meta['last_page'] as num?)?.toInt() ?? 1;
        _total = (meta['total'] as num?)?.toInt() ?? _exams.length;
        _cities = (filters['cities'] as List<dynamic>? ?? [])
            .map((item) => item.toString())
            .where((item) => item.isNotEmpty)
            .toList();
        _receivings = (filters['receiving'] as List<dynamic>? ?? [])
            .map((item) => item.toString())
            .where((item) => item.isNotEmpty)
            .toList();
      });
    } catch (error) {
      if (mounted && request == _requestGeneration) {
        _showMessage(error.toString());
      }
    } finally {
      if (mounted && request == _requestGeneration) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _openExam(MobileExamination exam) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ExaminationDetailScreen(
          strings: widget.strings,
          api: widget.api,
          examinationId: exam.id,
        ),
      ),
    );
  }

  Future<void> _pickDateRange() async {
    final from = TextEditingController(
      text: _selectedDateRange == null
          ? ''
          : _dateLabel(_selectedDateRange!.start),
    );
    final to = TextEditingController(
      text: _selectedDateRange == null
          ? ''
          : _dateLabel(_selectedDateRange!.end),
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        decoration: BoxDecoration(
          color: AppColors.surfaceFor(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
              widget.strings.chooseDate,
              style: TextStyle(
                color: AppColors.inkFor(context),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: from,
                    keyboardType: TextInputType.datetime,
                    decoration: InputDecoration(
                      labelText: widget.strings.dateFrom,
                      hintText: '01.01.2026',
                      prefixIcon: const Icon(Icons.calendar_month_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: to,
                    keyboardType: TextInputType.datetime,
                    decoration: InputDecoration(
                      labelText: widget.strings.dateTo,
                      hintText: '31.12.2026',
                      prefixIcon: const Icon(Icons.calendar_today_outlined),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      setState(() => _selectedDateRange = null);
                      _loadExams();
                    },
                    child: Text(widget.strings.reset),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final start = _parseDate(from.text);
                      final end = _parseDate(to.text);
                      if (start == null || end == null) {
                        _showMessage(widget.strings.checkFields);
                        return;
                      }
                      Navigator.of(context).pop();
                      setState(
                        () => _selectedDateRange = DateTimeRange(
                          start: start,
                          end: end,
                        ),
                      );
                      _loadExams();
                    },
                    child: Text(widget.strings.apply),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickOption({
    required String title,
    required List<String> options,
    required String? selected,
    required ValueChanged<String?> onSelected,
  }) async {
    final search = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        var filtered = options;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            void filter(String value) {
              setSheetState(() {
                filtered = options
                    .where(
                      (option) =>
                          option.toLowerCase().contains(value.toLowerCase()),
                    )
                    .toList();
              });
            }

            void choose(String? value) {
              Navigator.of(context).pop();
              onSelected(value);
              _loadExams();
            }

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.62,
              ),
              margin: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
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
                    title,
                    style: TextStyle(
                      color: AppColors.inkFor(context),
                      fontSize: 18,
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
                        _OptionTile(
                          title: widget.strings.all,
                          selected: selected == null,
                          onTap: () => choose(null),
                        ),
                        for (final option in filtered)
                          _OptionTile(
                            title: option,
                            selected: selected == option,
                            onTap: () => choose(option),
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

  DateTime? _parseDate(String value) {
    final parts = value.trim().split('.');
    if (parts.length != 3) return null;

    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;

    final parsed = DateTime(year, month, day);
    if (parsed.day != day || parsed.month != month || parsed.year != year) {
      return null;
    }

    return parsed;
  }

  String _dateQuery(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _dateLabel(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }

  String get _dateFilterLabel {
    final range = _selectedDateRange;
    if (range == null) return widget.strings.date;

    return '${_dateLabel(range.start)} - ${_dateLabel(range.end)}';
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
              onRefresh: () => _loadExams(page: _page),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                children: [
                  _Header(
                    api: widget.api,
                    strings: strings,
                    searchVisible: _searchVisible,
                    onSearchToggle: () =>
                        setState(() => _searchVisible = !_searchVisible),
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
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: _searchVisible
                        ? Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: TextField(
                              controller: _searchController,
                              autofocus: true,
                              onChanged: (_) => _loadExams(),
                              decoration: InputDecoration(
                                hintText: strings.search,
                                prefixIcon: const Icon(Icons.search_rounded),
                                filled: true,
                                fillColor: AppColors.surfaceFor(context),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 11,
                                ),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _FilterChip(
                          icon: Icons.calendar_month_outlined,
                          label: _dateFilterLabel,
                          selected: _selectedDateRange != null,
                          onTap: _pickDateRange,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _FilterChip(
                          icon: Icons.location_on_outlined,
                          label: _selectedCity ?? strings.place,
                          selected: _selectedCity != null,
                          onTap: () => _pickOption(
                            title: strings.place,
                            options: _cities,
                            selected: _selectedCity,
                            onSelected: (value) =>
                                setState(() => _selectedCity = value),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _FilterChip(
                          icon: Icons.person_outline_rounded,
                          label: _selectedReceiving ?? strings.receiving,
                          selected: _selectedReceiving != null,
                          onTap: () => _pickOption(
                            title: strings.receiving,
                            options: _receivings,
                            selected: _selectedReceiving,
                            onSelected: (value) =>
                                setState(() => _selectedReceiving = value),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 90),
                      child: Center(
                        child: CircularProgressIndicator(color: AppColors.red),
                      ),
                    )
                  else if (_exams.isEmpty)
                    _EmptyState(text: strings.noExams)
                  else
                    ..._exams.map(
                      (exam) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ExamCard(
                          strings: strings,
                          exam: exam,
                          onTap: () => _openExam(exam),
                        ),
                      ),
                    ),
                  if (!_isLoading && _exams.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        '${strings.shown} ${_exams.length} ${strings.of} $_total',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.mutedFor(context),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  if (!_isLoading && _lastPage > 1)
                    _Pagination(
                      page: _page,
                      lastPage: _lastPage,
                      onPrevious: _page > 1
                          ? () => _loadExams(page: _page - 1)
                          : null,
                      onNext: _page < _lastPage
                          ? () => _loadExams(page: _page + 1)
                          : null,
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
    required this.onSearchToggle,
    required this.onNotifications,
  });

  final AppStrings strings;
  final bool searchVisible;
  final VoidCallback onSearchToggle;
  final VoidCallback onNotifications;

  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            strings.exams,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.inkFor(context),
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        _RoundIconButton(
          icon: searchVisible ? Icons.close_rounded : Icons.search_rounded,
          onTap: onSearchToggle,
        ),
        const SizedBox(width: 12),
        NotificationButton(api: api, strings: strings, onOpen: onNotifications),
      ],
    );
  }
}

class _ExamCard extends StatelessWidget {
  const _ExamCard({
    required this.strings,
    required this.exam,
    required this.onTap,
  });

  final AppStrings strings;
  final MobileExamination exam;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceFor(context),
          borderRadius: BorderRadius.circular(24),
          boxShadow: _softShadow,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exam.name,
                    style: TextStyle(
                      color: AppColors.inkFor(context),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _InfoLine(icon: Icons.location_on_outlined, text: exam.city),
                  const SizedBox(height: 10),
                  _InfoLine(
                    icon: Icons.calendar_month_outlined,
                    text: exam.dateLabel,
                  ),
                  const SizedBox(height: 10),
                  _InfoLine(
                    icon: Icons.person_outline_rounded,
                    text: exam.receiving,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.mutedFor(context),
              size: 30,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.inkFor(context), size: 19),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: AppColors.mutedFor(context),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.red.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: selected
                ? AppColors.red.withValues(alpha: 0.22)
                : AppColors.borderFor(context),
          ),
          boxShadow: _softShadow,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? AppColors.red : AppColors.inkFor(context),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? AppColors.red : AppColors.inkFor(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.mutedFor(context),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
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
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(22),
        boxShadow: _softShadow,
      ),
      child: Center(
        child: Text(
          text,
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

class _Pagination extends StatelessWidget {
  const _Pagination({
    required this.page,
    required this.lastPage,
    required this.onPrevious,
    required this.onNext,
  });

  final int page;
  final int lastPage;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton.filled(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left_rounded),
            style: IconButton.styleFrom(
              backgroundColor: onPrevious == null
                  ? AppColors.borderFor(context)
                  : AppColors.red,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Text(
              '$page / $lastPage',
              style: TextStyle(
                color: AppColors.inkFor(context),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          IconButton.filled(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right_rounded),
            style: IconButton.styleFrom(
              backgroundColor: onNext == null
                  ? AppColors.borderFor(context)
                  : AppColors.red,
            ),
          ),
        ],
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
