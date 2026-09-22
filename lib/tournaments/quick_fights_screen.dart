import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../l10n/app_locale.dart';
import '../navigation/coach_bottom_nav.dart';
import 'tournament_models.dart';
import 'tournament_bracket_screen.dart';
import 'tournament_lists_screen.dart';

class QuickFightsScreen extends StatefulWidget {
  const QuickFightsScreen({
    super.key,
    required this.api,
    required this.strings,
  });
  final ApiClient api;
  final AppStrings strings;
  @override
  State<QuickFightsScreen> createState() => _QuickFightsScreenState();
}

class _QuickFightsScreenState extends State<QuickFightsScreen>
    with WidgetsBindingObserver {
  final _search = TextEditingController();
  Timer? _debounce, _refresh;
  bool _loading = false;
  String? _error, _tournament;
  int _page = 1, _last = 1, _request = 0;
  List<Map<String, dynamic>> _rows = [], _options = [];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _refresh = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_loading &&
          (WidgetsBinding.instance.lifecycleState ==
                  AppLifecycleState.resumed ||
              WidgetsBinding.instance.lifecycleState == null) &&
          ModalRoute.of(context)?.isCurrent == true) {
        _load(page: _page);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load(page: _page);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _refresh?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({int page = 1}) async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await widget.api.getJson(
        '/quick-fights',
        query: {
          'page': '$page',
          'search': _search.text.trim(),
          'tournament_id': ?_tournament,
        },
      );
      if (!mounted || request != _request) return;
      setState(() {
        _rows = (response['data'] as List)
            .whereType<Map<String, dynamic>>()
            .toList();
        _options = (response['tournaments'] as List)
            .whereType<Map<String, dynamic>>()
            .toList();
        if (!_options.any((o) => '${o['id']}' == _tournament)) {
          _tournament = null;
        }
        _page = page;
        _last = (response['meta']?['last_page'] as num?)?.toInt() ?? 1;
      });
    } catch (e) {
      if (mounted && request == _request) setState(() => _error = e.toString());
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _open(
    Map<String, dynamic> row, {
    int? round,
    int? poolId,
  }) async {
    final championship = Championship.fromJson({'id': row['championship_id']});
    final tournament = TournamentItem.fromJson({
      'id': row['tournament_id'],
      'championship_id': row['championship_id'],
      'name': row['tournament_name'],
    });
    final table = TournamentTableItem.fromJson({
      'id': row['list_id'],
      'name': row['list_name'],
      'generated': row['generated'],
    });
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => row['generated'] == true
            ? TournamentBracketScreen(
                strings: widget.strings,
                api: widget.api,
                championship: championship,
                tournament: tournament,
                table: table,
                initialRound: round,
                initialPoolId: poolId,
              )
            : TournamentListsScreen(
                strings: widget.strings,
                api: widget.api,
                championship: championship,
                tournament: tournament,
                list: table,
              ),
      ),
    );
    if (mounted) _load(page: _page);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          s.quickFights,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
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
            child: Column(
              children: [
                TextField(
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
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _tournament,
                  key: ValueKey(_tournament),
                  isExpanded: true,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: s.tournaments,
                  ),
                  items: [
                    DropdownMenuItem<String>(value: null, child: Text(s.all)),
                    ..._options.map(
                      (o) => DropdownMenuItem(
                        value: '${o['id']}',
                        child: Text(
                          o['name'].toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    _tournament = value;
                    _load();
                  },
                ),
              ],
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
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        s.noParticipants,
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  final row = _rows[index];
                  final path = (row['path'] as List<dynamic>? ?? [])
                      .whereType<Map<String, dynamic>>();
                  return InkWell(
                    onTap: () => _open(row),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row['name'].toString(),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            [
                              row['tournament_name'],
                              row['list_name'],
                              row['club'],
                            ].where((v) => v != null && v != '').join(' · '),
                            style: const TextStyle(fontSize: 11),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${s.tatami}: ${row['tatami'] ?? '—'}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          if (path.isEmpty)
                            Text(
                              s.notGenerated,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ...path.map(
                            (p) => InkWell(
                              onTap: () => _open(
                                row,
                                round: (p['round'] as num?)?.toInt(),
                                poolId: (p['id'] as num?)?.toInt(),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 5,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      p['status'] == 'won'
                                          ? Icons.emoji_events_outlined
                                          : p['status'] == 'absent'
                                          ? Icons.block
                                          : Icons.chevron_right,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        '${s.spectatorStage(p['stage']?.toString() ?? '')} · ${p['number'] ?? '—'} · ${s.fightPathStatus(p['status']?.toString() ?? '')}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: p['status'] == 'absent'
                                              ? Colors.red
                                              : null,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (row['current'] != null || row['next'] != null)
                            Text(
                              '${s.currentFight}: ${row['current']?['number'] ?? '—'} · ${s.nextFight}: ${row['next']?['number'] ?? '—'}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ),
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
              Text('$_page / $_last', style: const TextStyle(fontSize: 12)),
              IconButton(
                tooltip: s.nextPage,
                onPressed: !_loading && _page < _last
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
