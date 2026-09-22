import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../l10n/app_locale.dart';
import '../navigation/coach_bottom_nav.dart';
import '../students/student_profile_screen.dart';
import 'tournament_models.dart';
import 'tournament_bracket_screen.dart';

class TournamentListsScreen extends StatefulWidget {
  const TournamentListsScreen({
    super.key,
    required this.api,
    required this.strings,
    required this.championship,
    required this.tournament,
    this.list,
  });
  final ApiClient api;
  final AppStrings strings;
  final Championship championship;
  final TournamentItem tournament;
  final TournamentTableItem? list;
  @override
  State<TournamentListsScreen> createState() => _TournamentListsScreenState();
}

class _TournamentListsScreenState extends State<TournamentListsScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  var _page = 1, _lastPage = 1, _revision = 0;
  var _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = [];
  String get _path =>
      '/championships/${widget.championship.id}/tournaments/${widget.tournament.id}/lists${widget.list == null ? '' : '/${widget.list!.id}/members'}';
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({int page = 1}) async {
    final revision = ++_revision;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.api.getJson(
        _path,
        query: {'page': '$page', 'search': _search.text.trim()},
      );
      if (!mounted || revision != _revision) return;
      setState(() {
        _rows = (result['data'] as List)
            .whereType<Map<String, dynamic>>()
            .toList();
        _page = page;
        _lastPage = (result['meta']?['last_page'] as num?)?.toInt() ?? 1;
      });
    } catch (e) {
      if (mounted && revision == _revision) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted && revision == _revision) setState(() => _loading = false);
    }
  }

  void _open(Map<String, dynamic> row) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => widget.list == null
            ? TournamentListsScreen(
                api: widget.api,
                strings: widget.strings,
                championship: widget.championship,
                tournament: widget.tournament,
                list: TournamentTableItem.fromJson(row),
              )
            : StudentProfileScreen(
                api: widget.api,
                strings: widget.strings,
                studentId: (row['student_id'] as num).toInt(),
                tournamentId: widget.tournament.id,
                championshipId: widget.championship.id,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          widget.list?.name ?? s.sourceLists,
          maxLines: 2,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        actions: [
          if (widget.list?.generated == true)
            IconButton(
              tooltip: s.bracket,
              icon: const Icon(Icons.account_tree_outlined, size: 20),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => TournamentBracketScreen(
                    strings: s,
                    api: widget.api,
                    championship: widget.championship,
                    tournament: widget.tournament,
                    table: widget.list!,
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: CoachBottomNav(
        strings: s,
        api: widget.api,
        active: null,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _search,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                hintText: s.search,
                prefixIcon: const Icon(Icons.search, size: 18),
              ),
              onChanged: (_) {
                _debounce?.cancel();
                _debounce = Timer(
                  const Duration(milliseconds: 300),
                  () => _load(),
                );
              },
            ),
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          if (_error != null)
            TextButton(onPressed: _load, child: Text('$_error · ${s.retry}')),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _rows.isEmpty && !_loading ? 1 : _rows.length,
                separatorBuilder: (_, index) => const Divider(height: 1),
                itemBuilder: (_, index) {
                  if (_rows.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        s.noParticipants,
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  final row = _rows[index];
                  final member = widget.list != null;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 5),
                    dense: true,
                    onTap: () => _open(row),
                    title: Text(
                      row['name']?.toString() ?? '',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      member
                          ? [
                              [
                                row['age'],
                                row['weight'] == null
                                    ? null
                                    : '${row['weight']} ${s.kg}',
                                s.rankValue(row['rang']?.toString()),
                              ].where((v) => v != null).join(' · '),
                              [
                                row['club'],
                                row['coach_name'],
                              ].where((v) => v != null && v != '').join(' · '),
                              if (row['group_id'] != null)
                                '${s.team} ${row['group_number']}',
                            ].join('\n')
                          : '${s.participants}: ${row['students_count']} · ${row['generated'] == true ? s.bracket : s.notGenerated}',
                      style: const TextStyle(fontSize: 11, height: 1.5),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                  );
                },
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: s.previousPage,
                onPressed: !_loading && _page > 1
                    ? () => _load(page: _page - 1)
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text('$_page / $_lastPage', style: const TextStyle(fontSize: 12)),
              IconButton(
                tooltip: s.nextPage,
                onPressed: !_loading && _page < _lastPage
                    ? () => _load(page: _page + 1)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
