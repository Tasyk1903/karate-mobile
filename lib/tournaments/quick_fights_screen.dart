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
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              decoration:
                                  path.any((p) => p['status'] == 'absent')
                                  ? TextDecoration.lineThrough
                                  : null,
                              decorationColor: Theme.of(context)
                                  .colorScheme
                                  .error,
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
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: path
                                .map(
                                  (p) => _FightStep(
                                    data: p,
                                    strings: s,
                                    onTap: () => _open(
                                      row,
                                      round: (p['round'] as num?)?.toInt(),
                                      poolId: (p['id'] as num?)?.toInt(),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 10),
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

class _FightStep extends StatelessWidget {
  const _FightStep({
    required this.data,
    required this.strings,
    required this.onTap,
  });
  final Map<String, dynamic> data;
  final AppStrings strings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = data['status']?.toString() ?? '';
    final past = ['won', 'lost', 'absent', 'scored'].contains(status);
    final failed = ['lost', 'absent'].contains(status);
    final scheme = Theme.of(context).colorScheme;
    final color = failed
        ? scheme.error
        : past
        ? scheme.onSurfaceVariant
        : scheme.onSurface;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 96, maxWidth: 155),
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.spectatorStage(data['stage']?.toString() ?? ''),
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (data['side'] != null) ...[
                      Tooltip(
                        message: data['side'] == 'red'
                            ? strings.redSide
                            : strings.whiteSide,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: data['side'] == 'red'
                                ? const Color(0xFFBC2831)
                                : Colors.white,
                            border: Border.all(color: Colors.grey),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        '${strings.fightNumberLabel} ${data['number'] ?? '—'}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: color,
                          decoration: past ? TextDecoration.lineThrough : null,
                          fontStyle: status == 'possible'
                              ? FontStyle.italic
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  strings.fightPathStatus(status),
                  style: TextStyle(fontSize: 10, color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
