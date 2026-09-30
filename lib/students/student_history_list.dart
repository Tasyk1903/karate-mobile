import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../l10n/app_locale.dart';
import 'student_models.dart';

class StudentHistoryList extends StatefulWidget {
  const StudentHistoryList({
    super.key,
    required this.api,
    required this.strings,
    required this.studentId,
    required this.kind,
  });
  final ApiClient api;
  final AppStrings strings;
  final int studentId;
  final String kind;
  @override
  State<StudentHistoryList> createState() => _StudentHistoryListState();
}

class _StudentHistoryListState extends State<StudentHistoryList> {
  final _rows = <Map<String, dynamic>>[];
  int _page = 0, _last = 1;
  bool _loading = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await widget.api.getJson(
        '/students/${widget.studentId}/${widget.kind == 'categories' ? 'categories' : 'history'}',
        query: {'kind': widget.kind, 'page': '${_page + 1}'},
      );
      if (!mounted) return;
      setState(() {
        _rows.addAll((response['data'] as List).cast<Map<String, dynamic>>());
        _page = response['meta']['current_page'] as int;
        _last = response['meta']['last_page'] as int;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final row in _rows) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: _entry(row),
          ),
          const Divider(height: 1),
        ],
        if (!_loading && _rows.isEmpty && _error == null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              widget.kind == 'wins' || widget.kind == 'losses'
                  ? s.noFightRecords
                  : '—',
              textAlign: TextAlign.center,
            ),
          ),
        if (_error != null) Text(_error!),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (!_loading && _page < _last)
          TextButton(
            onPressed: _load,
            child: Text(_error == null ? s.moreRecords : s.retry),
          ),
      ],
    );
  }

  Widget _entry(Map<String, dynamic> row) {
    final s = widget.strings;
    final lines = <String>[];
    String name;
    if (widget.kind == 'categories') {
      name = row['name'].toString();
      lines.add((row['categories'] as List? ?? []).join('\n'));
    } else if (widget.kind == 'tournaments') {
      final t = StudentTournament.fromJson(row);
      name = t.name;
      lines.add('${t.date} · ${t.type}');
      lines.add('${s.wins}: ${t.wins} · ${s.losses}: ${t.losses}');
    } else {
      final f = StudentFightRecord.fromJson(row);
      final club = row['opponent']?['club']?.toString();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                widget.kind == 'wins'
                    ? Icons.emoji_events_outlined
                    : Icons.sports_martial_arts,
                size: 20,
                color: widget.kind == 'wins'
                    ? Colors.green
                    : Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  f.opponentName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            f.tournamentName,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(f.pool, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 8),
          Text(
            '${s.coach}: ${f.opponentCoach}',
            style: const TextStyle(fontSize: 12),
          ),
          if (club != null && club.isNotEmpty)
            Text('${s.club}: $club', style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              Text(
                '${s.age}: ${f.opponentAge}',
                style: const TextStyle(fontSize: 12),
              ),
              Text(f.fightDate, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        for (final line in lines.where((e) => e.isNotEmpty))
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(line, style: const TextStyle(fontSize: 12)),
          ),
      ],
    );
  }
}

void showStudentHistory(
  BuildContext context,
  ApiClient api,
  AppStrings strings,
  int studentId,
  String kind,
  String title,
) {
  if (kind == 'wins' || kind == 'losses') {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StudentFightHistoryScreen(
          api: api,
          strings: strings,
          studentId: studentId,
          initialKind: kind,
        ),
      ),
    );
    return;
  }
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .72,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            StudentHistoryList(
              api: api,
              strings: strings,
              studentId: studentId,
              kind: kind,
            ),
          ],
        ),
      ),
    ),
  );
}

class StudentFightHistoryScreen extends StatefulWidget {
  const StudentFightHistoryScreen({
    super.key,
    required this.api,
    required this.strings,
    required this.studentId,
    required this.initialKind,
  });
  final ApiClient api;
  final AppStrings strings;
  final int studentId;
  final String initialKind;
  @override
  State<StudentFightHistoryScreen> createState() =>
      _StudentFightHistoryScreenState();
}

class _StudentFightHistoryScreenState extends State<StudentFightHistoryScreen> {
  late String _kind = widget.initialKind;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.strings.record,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
    ),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'wins',
                    label: Text(widget.strings.wins),
                  ),
                  ButtonSegment(
                    value: 'losses',
                    label: Text(widget.strings.losses),
                  ),
                ],
                selected: {_kind},
                showSelectedIcon: false,
                onSelectionChanged: (values) =>
                    setState(() => _kind = values.single),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              key: ValueKey(_kind),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                StudentHistoryList(
                  key: ValueKey(_kind),
                  api: widget.api,
                  strings: widget.strings,
                  studentId: widget.studentId,
                  kind: _kind,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
