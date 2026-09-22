import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../l10n/app_locale.dart';
import '../navigation/coach_bottom_nav.dart';
import 'education_video_screen.dart';
import 'education_work_editor.dart';

class EducationScreen extends StatefulWidget {
  const EducationScreen({
    super.key,
    required this.api,
    required this.strings,
    this.section,
    this.category,
    this.title,
  });
  final ApiClient api;
  final AppStrings strings;
  final String? section, title;
  final int? category;

  @override
  State<EducationScreen> createState() => _EducationScreenState();
}

class _EducationScreenState extends State<EducationScreen> {
  final _scroll = ScrollController();
  final _search = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _rows = [];
  bool _loading = false;
  String? _error;
  int _page = 0, _lastPage = 1, _version = 0;
  bool get _root => widget.section == null;
  bool get _works => widget.section == 'works';
  String get _path => _root
      ? '/education'
      : _works
      ? '/education/works'
      : '/education/catalog/${widget.section}${widget.category == null ? '' : '/${widget.category}'}';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 180) _load();
    });
    _load(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (!reset && (_loading || _error != null || _page >= _lastPage)) return;
    final version = ++_version;
    final page = reset ? 1 : _page + 1;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _rows = [];
        _page = 0;
        _lastPage = 1;
      }
    });
    try {
      final result = await widget.api.getJson(
        _path,
        query: {
          if (!_root) 'page': '$page',
          if (!_root) 'search': _search.text.trim(),
        },
      );
      if (!mounted || version != _version) return;
      final rows = (result['data'] as List).cast<Map<String, dynamic>>();
      final meta = result['meta'] as Map<String, dynamic>? ?? {};
      setState(() {
        _rows = {
          for (final row in [..._rows, ...rows]) row['id']: row,
        }.values.toList();
        _page = page;
        _lastPage = (meta['last_page'] as num?)?.toInt() ?? 1;
        _loading = false;
      });
    } catch (_) {
      if (mounted && version == _version) {
        setState(() {
          _loading = false;
          _error = widget.strings.educationLoadFailed;
        });
      }
    }
  }

  Future<void> _open(Map<String, dynamic> row) async {
    final Widget screen;
    if (_root || (!_works && widget.category == null)) {
      screen = EducationScreen(
        api: widget.api,
        strings: widget.strings,
        section: _root ? row['id'] as String : widget.section,
        category: _root ? null : (row['id'] as num).toInt(),
        title: _root ? null : row['title'] as String,
      );
    } else {
      screen = EducationVideoScreen(
        api: widget.api,
        strings: widget.strings,
        video: row,
        workId: _works ? (row['id'] as num).toInt() : null,
      );
    }
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => screen));
    if (mounted) _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    final title =
        widget.title ??
        (_root
            ? s.education
            : s.educationSection(
                widget.section!,
                ownWorks: widget.api.isStudent,
              ));
    return Scaffold(
      appBar: AppBar(
        actions: [
          if (_works && widget.api.isStudent)
            IconButton(
              tooltip: s.newEducationWork,
              icon: const Icon(Icons.add),
              onPressed: () async {
                if (await editEducationWork(context, widget.api, s) &&
                    mounted) {
                  _load(reset: true);
                }
              },
            ),
        ],
        centerTitle: true,
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      bottomNavigationBar: CoachBottomNav(
        api: widget.api,
        strings: s,
        active: null,
      ),
      body: Column(
        children: [
          if (!_root)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _search,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: s.search,
                  prefixIcon: const Icon(Icons.search, size: 20),
                ),
                onChanged: (_) {
                  _debounce?.cancel();
                  ++_version;
                  _debounce = Timer(
                    const Duration(milliseconds: 300),
                    () => _load(reset: true),
                  );
                },
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _load(reset: true),
              child: ListView.separated(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
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
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Text(_error!, style: const TextStyle(fontSize: 13)),
                            TextButton(
                              onPressed: () {
                                _error = null;
                                _load(reset: _page == 0);
                              },
                              child: Text(s.retry),
                            ),
                          ],
                        ),
                      );
                    }
                    if (_rows.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(s.educationEmpty),
                      );
                    }
                    if (_page < _lastPage) {
                      return TextButton(
                        onPressed: () => _load(),
                        child: Text(s.loadMore),
                      );
                    }
                    return const SizedBox.shrink();
                  }
                  final row = _rows[index];
                  return InkWell(
                    onTap: () => _open(row),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (_root)
                            Padding(
                              padding: const EdgeInsets.only(right: 14),
                              child: Icon(
                                row['id'] == 'works'
                                    ? Icons.assignment_outlined
                                    : Icons.video_library_outlined,
                                size: 24,
                              ),
                            )
                          else if (!_works && widget.category != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: _Cover(
                                api: widget.api,
                                url: row['poster_url'] as String?,
                              ),
                            ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _root
                                      ? s.educationSection(
                                          row['id'] as String,
                                          ownWorks: widget.api.isStudent,
                                        )
                                      : row['title'] as String,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (_works) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    [row['category'], row['rank'], row['club']]
                                        .where((v) => v != null && v != '')
                                        .join(' · '),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(height: 5),
                                  EducationReviewStatus(
                                    reviewed: row['is_review'] == true,
                                    paid:
                                        !widget.api.isStudent ||
                                        row['is_payment'] == true,
                                    strings: s,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Icon(Icons.chevron_right, size: 20),
                          ),
                        ],
                      ),
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

class _Cover extends StatelessWidget {
  const _Cover({required this.api, this.url});
  final ApiClient api;
  final String? url;
  @override
  Widget build(BuildContext context) {
    final headers = url == null ? <String, String>{} : api.mediaHeaders(url!);
    final fallback = ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(child: Icon(Icons.play_circle_outline, size: 28)),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 96,
        height: 60,
        child: url == null || headers.isEmpty
            ? fallback
            : Image.network(
                api.publicUrl(url!),
                headers: headers,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : fallback,
              ),
      ),
    );
  }
}
