import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../l10n/app_locale.dart';
import '../l10n/staff_strings.dart';
import '../media/protected_video_player.dart';
import '../navigation/coach_bottom_nav.dart';
import 'staff_widgets.dart';

class JudgeTableScreen extends StatefulWidget {
  const JudgeTableScreen({
    super.key,
    required this.api,
    required this.strings,
    required this.listId,
  });
  final ApiClient api;
  final AppStrings strings;
  final int listId;
  @override
  State<JudgeTableScreen> createState() => _JudgeTableScreenState();
}

class _JudgeTableScreenState extends State<JudgeTableScreen> {
  Map<String, dynamic>? _table;
  List<Map<String, dynamic>> _rows = [];
  String _round = 'pre';
  String? _field, _reason, _error;
  bool _loading = false, _canScore = false;
  int _page = 0, _last = 1, _version = 0;
  final _scroll = ScrollController();
  String get _path => '/judge/tables/${widget.listId}';
  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
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
        _canScore = false;
      }
    });
    try {
      final result = await widget.api.getJson(
        _path,
        query: {'round': _round, 'page': '$page'},
      );
      if (!mounted || version != _version) return;
      setState(() {
        _table = result['table'] as Map<String, dynamic>;
        _field = result['field'] as String?;
        _canScore = result['can_score'] == true;
        _reason = result['reason'] as String?;
        _rows.addAll((result['data'] as List).cast<Map<String, dynamic>>());
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

  Future<void> _score(Map<String, dynamic> row) async {
    final s = widget.strings;
    final input = TextEditingController(text: row['score']?.toString() ?? '');
    var original = row['score']?.toString();
    final field = _field;
    bool busy = false, changed = false;
    String? error;
    final route = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialog) => StatefulBuilder(
        builder: (context, update) => PopScope(
          canPop: !busy,
          child: AlertDialog(
            title: Text(s.ownScore, style: const TextStyle(fontSize: 16)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (row['students'] as List).map((v) => v['name']).join(', '),
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: input,
                    enabled: !busy,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: s.ownScore,
                      suffixIcon: IconButton(
                        tooltip: s.delete,
                        onPressed: busy ? null : input.clear,
                        icon: const Icon(Icons.backspace_outlined, size: 18),
                      ),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(error!, style: const TextStyle(fontSize: 13)),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () async {
                              update(() => busy = true);
                              try {
                                final result = await widget.api.getJson(
                                  '$_path/scores/${row['id']}',
                                );
                                if (dialog.mounted) {
                                  update(() {
                                    original = result['score']?.toString();
                                    error = '${s.ownScore}: ${original ?? '—'}';
                                  });
                                }
                              } catch (failure) {
                                if (dialog.mounted) {
                                  update(() => error = staffError(failure, s));
                                }
                              }
                              if (dialog.mounted) update(() => busy = false);
                            },
                      child: Text(s.refreshRecord),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(dialog),
                child: Text(s.cancel),
              ),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        final text = input.text.trim().replaceAll(',', '.');
                        final value = double.tryParse(text);
                        if (text.isNotEmpty &&
                            (value == null ||
                                !value.isFinite ||
                                value < 0 ||
                                value > 10 ||
                                (value * 10 - (value * 10).round()).abs() >
                                    .000001)) {
                          update(() => error = s.scoreRange);
                          return;
                        }
                        update(() {
                          busy = true;
                          error = null;
                        });
                        try {
                          await widget.api.postJson(
                            '$_path/scores/${row['id']}',
                            body: {
                              'field': field,
                              'value': text.isEmpty ? null : text,
                              'original_value': original,
                            },
                          );
                          changed = true;
                          if (mounted) {
                            setState(
                              () => row['score'] = text.isEmpty ? null : text,
                            );
                          }
                          if (dialog.mounted) Navigator.pop(dialog);
                        } catch (failure) {
                          if (dialog.mounted) {
                            update(() {
                              busy = false;
                              error =
                                  failure is ApiException &&
                                      failure.statusCode == 409
                                  ? s.scoreConflict
                                  : staffError(failure, s);
                            });
                          }
                        }
                      },
                child: Text(busy ? s.saving : s.save),
              ),
            ],
          ),
        ),
      ),
    );
    await Navigator.of(context).push(route);
    await route.completed;
    input.dispose();
    if (mounted && changed) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.savedScore)));
    }
  }

  Future<void> _participant(Map<String, dynamic> student) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      student['name'] ?? '',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: widget.strings.close,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(
                [
                  student['coach'],
                  student['club'],
                  student['rank'],
                ].where((v) => v != null && v != '').join(' · '),
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              Text(
                student['category'] ?? '',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              if (student['video_url'] != null)
                ProtectedVideoPlayer(
                  api: widget.api,
                  url: student['video_url'] as String,
                  strings: widget.strings,
                )
              else
                Text(widget.strings.videoUnavailable),
            ],
          ),
        ),
      );
  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          _table?['title'] ?? s.judging,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ),
      bottomNavigationBar: CoachBottomNav(
        api: widget.api,
        strings: s,
        active: CoachNavItem.judging,
      ),
      body: Column(
        children: [
          if (_table != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text(
                [
                  _table!['championship'],
                  _table!['tournament'],
                ].where((v) => v != null).join(' · '),
                style: const TextStyle(fontSize: 12),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'pre', label: Text(s.preliminaryRound)),
                  ButtonSegment(value: 'final', label: Text(s.finalRound)),
                ],
                selected: {_round},
                showSelectedIcon: false,
                onSelectionChanged: (v) {
                  _round = v.single;
                  if (_scroll.hasClients) _scroll.jumpTo(0);
                  _load(reset: true);
                },
              ),
            ),
          ),
          if (_reason != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(_reason!, style: const TextStyle(fontSize: 12)),
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
                    return const SizedBox(height: 20);
                  }
                  final row = _rows[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '#${row['number'] ?? index + 1}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _canScore ? () => _score(row) : null,
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              label: Text(
                                '${s.ownScore}: ${row['score'] ?? '—'}',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                        for (final student
                            in (row['students'] as List)
                                .cast<Map<String, dynamic>>())
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              student['name'] ?? '',
                              style: const TextStyle(fontSize: 14),
                            ),
                            subtitle: Text(
                              [
                                student['club'],
                                student['rank'],
                              ].where((v) => v != null).join(' · '),
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: student['video_url'] == null
                                ? null
                                : const Icon(
                                    Icons.play_circle_outline,
                                    size: 20,
                                  ),
                            onTap: () => _participant(student),
                          ),
                      ],
                    ),
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
