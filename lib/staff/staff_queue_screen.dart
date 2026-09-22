import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../l10n/app_locale.dart';
import '../l10n/staff_strings.dart';
import '../navigation/coach_bottom_nav.dart';
import 'judge_table_screen.dart';
import 'master_review_screen.dart';
import 'staff_widgets.dart';

class StaffQueueScreen extends StatefulWidget {
  const StaffQueueScreen({
    super.key,
    required this.api,
    required this.strings,
    this.picker = false,
  });
  final ApiClient api;
  final AppStrings strings;
  final bool picker;
  @override
  State<StaffQueueScreen> createState() => _StaffQueueScreenState();
}

class _StaffQueueScreenState extends State<StaffQueueScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  List<Map<String, dynamic>> _rows = [];
  int _page = 0, _last = 1, _version = 0;
  bool _loading = false;
  String? _error;
  String _status = 'all', _sort = 'tatami';
  Map<String, dynamic>? _tournament;
  @override
  void initState() {
    super.initState();
    if (widget.api.isMaster) _sort = 'id';
    _load(reset: true);
    _scroll.addListener(_more);
  }

  void _more() {
    if (_scroll.position.extentAfter < 250 &&
        !_loading &&
        _error == null &&
        _page < _last) {
      _load();
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (!reset && (_loading || _page >= _last)) return;
    final version = ++_version;
    final page = reset ? 1 : _page + 1;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _rows = [];
        _page = 0;
      }
    });
    try {
      final result = await widget.api.getJson(
        widget.picker
            ? '/judge/tournaments'
            : widget.api.isJudge
            ? '/judge/tables'
            : '/master/works',
        query: {
          'page': '$page',
          'search': _search.text.trim(),
          if (!widget.picker) 'sort': _sort,
          if (!widget.api.isJudge) 'status': _status,
          if (!widget.picker && _tournament != null)
            'tournament_id': '${_tournament!['id']}',
        },
      );
      if (!mounted || version != _version) return;
      setState(() {
        _rows = {
          for (final row in [
            ..._rows,
            ...(result['data'] as List).cast<Map<String, dynamic>>(),
          ])
            row['id']: row,
        }.values.toList();
        _page = page;
        _last = (result['meta']['last_page'] as num).toInt();
        _loading = false;
      });
    } catch (error) {
      if (mounted && version == _version) {
        setState(() {
          _error = staffError(error, widget.strings);
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        actions: [
          if (widget.api.isMaster)
            PopupMenuButton<String>(
              tooltip: s.sortDefault,
              icon: const Icon(Icons.sort),
              onSelected: (value) {
                _sort = value;
                _load(reset: true);
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'id', child: Text(s.sortDefault)),
                PopupMenuItem(value: 'name', child: Text(s.sortStudentName)),
              ],
            ),
        ],
        title: Text(
          widget.picker
              ? s.tournaments
              : widget.api.isJudge
              ? s.judging
              : s.masterReviews,
          maxLines: 1,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      bottomNavigationBar: widget.picker
          ? null
          : CoachBottomNav(
              api: widget.api,
              strings: s,
              active: widget.api.isJudge
                  ? CoachNavItem.judging
                  : CoachNavItem.reviews,
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _search,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                labelText: s.search,
                prefixIcon: const Icon(Icons.search, size: 20),
              ),
              onChanged: (_) {
                ++_version;
                _debounce?.cancel();
                _debounce = Timer(
                  const Duration(milliseconds: 300),
                  () => _load(reset: true),
                );
              },
            ),
          ),
          if (!widget.picker && widget.api.isJudge)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.filter_alt_outlined, size: 18),
                      label: Text(
                        _tournament?['title'] ?? s.allTournaments,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: () async {
                        final selected =
                            await Navigator.push<Map<String, dynamic>>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StaffQueueScreen(
                                  api: widget.api,
                                  strings: s,
                                  picker: true,
                                ),
                              ),
                            );
                        if (mounted && selected != null) {
                          _tournament = selected;
                          _load(reset: true);
                        }
                      },
                    ),
                  ),
                  if (_tournament != null)
                    IconButton(
                      tooltip: s.allTournaments,
                      icon: const Icon(Icons.filter_alt_off_outlined),
                      onPressed: () {
                        _tournament = null;
                        _load(reset: true);
                      },
                    ),
                  PopupMenuButton<String>(
                    tooltip: _sort == 'tatami' ? s.sortTatami : s.sortDefault,
                    icon: const Icon(Icons.sort),
                    onSelected: (v) {
                      _sort = v;
                      _load(reset: true);
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'tatami', child: Text(s.sortTatami)),
                      PopupMenuItem(value: 'id', child: Text(s.sortDefault)),
                    ],
                  ),
                ],
              ),
            ),
          if (!widget.api.isJudge)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  segments: [
                    ButtonSegment(value: 'all', label: Text(s.allWorks)),
                    ButtonSegment(
                      value: 'pending',
                      label: Text(s.pendingWorks),
                    ),
                    ButtonSegment(
                      value: 'reviewed',
                      label: Text(s.reviewedWorks),
                    ),
                  ],
                  selected: {_status},
                  showSelectedIcon: false,
                  onSelectionChanged: (v) {
                    _status = v.single;
                    _load(reset: true);
                  },
                ),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _load(reset: true),
              child: ListView.separated(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _rows.length + 1,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  if (index == _rows.length) {
                    if (_loading) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (_error != null) {
                      return StaffError(
                        error: _error!,
                        retry: () => _load(reset: _page == 0),
                        strings: s,
                      );
                    }
                    if (_rows.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(s.emptyStaffList),
                      );
                    }
                    if (_page < _last) {
                      return TextButton(
                        onPressed: _load,
                        child: Text(s.loadMore),
                      );
                    }
                    return const SizedBox(height: 16);
                  }
                  final row = _rows[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 4,
                    ),
                    title: Text(
                      row['title'] ?? '',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            [
                              if (widget.api.isJudge) ...[
                                row['championship'],
                                row['tournament'],
                                row['date'],
                                row['tatami'] == null
                                    ? null
                                    : '${s.tatami} ${row['tatami']}',
                              ] else ...[
                                row['category'],
                                row['club'],
                                row['rank'],
                              ],
                            ].where((v) => v != null && v != '').join(' · '),
                            style: const TextStyle(fontSize: 12),
                          ),
                          if (!widget.api.isJudge) ...[
                            const SizedBox(height: 5),
                            StaffMark(
                              reviewed: row['is_review'] == true,
                              strings: s,
                            ),
                            if (row['is_review'] == true)
                              for (final field in ['point', 'detail_point'])
                                if (row[field] != null && row[field] != '')
                                  Text(
                                    '${s.staffField(field)}: ${row[field]}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                          ],
                        ],
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () async {
                      if (widget.picker) {
                        Navigator.pop(context, row);
                        return;
                      }
                      await Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => widget.api.isJudge
                              ? JudgeTableScreen(
                                  api: widget.api,
                                  strings: s,
                                  listId: row['id'] as int,
                                )
                              : MasterReviewScreen(
                                  api: widget.api,
                                  strings: s,
                                  workId: row['id'] as int,
                                ),
                        ),
                      );
                      if (mounted) _load(reset: true);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
