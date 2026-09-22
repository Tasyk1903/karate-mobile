import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../l10n/app_locale.dart';
import '../l10n/staff_strings.dart';
import '../media/protected_video_player.dart';
import 'staff_widgets.dart';

class MasterReviewScreen extends StatefulWidget {
  const MasterReviewScreen({
    super.key,
    required this.api,
    required this.strings,
    required this.workId,
  });
  final ApiClient api;
  final AppStrings strings;
  final int workId;
  @override
  State<MasterReviewScreen> createState() => _MasterReviewScreenState();
}

class _MasterReviewScreenState extends State<MasterReviewScreen> {
  final _fields = {
    for (final key in [
      'description',
      'point',
      'detail_point',
      'recommendation',
    ])
      key: TextEditingController(),
  };
  Map<String, dynamic>? _work;
  String? _error;
  bool _loading = true, _busy = false, _dirty = false, _saved = false;
  String get _path => '/master/works/${widget.workId}';
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  void _receive(Map<String, dynamic> work) {
    _work = work;
    for (final field in _fields.entries) {
      field.value.text = work['review'][field.key]?.toString() ?? '';
    }
    _dirty = false;
    _error = null;
  }

  Future<void> _load() async {
    if (_dirty &&
        !await staffConfirm(
          context,
          widget.strings,
          widget.strings.unsavedQuestion,
        )) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.api.getJson(_path);
      if (mounted) {
        setState(() {
          _receive(result['data'] as Map<String, dynamic>);
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = staffError(error, widget.strings);
        });
      }
    }
  }

  Future<void> _save(bool reviewed) async {
    if (_busy || _work == null) return;
    final reopen = _work!['is_review'] == true && !reviewed;
    if (reopen &&
        !await staffConfirm(
          context,
          widget.strings,
          widget.strings.reopenQuestion,
        )) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.api.postJson(
        _path,
        body: {
          'revision': _work!['revision'],
          'is_review': reviewed,
          'confirmed': reopen,
          for (final field in _fields.entries)
            field.key: field.value.text.trim(),
        },
      );
      if (mounted) {
        setState(() {
          _receive(result['data'] as Map<String, dynamic>);
          _busy = false;
          _saved = true;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = staffError(error, widget.strings);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    return PopScope(
      canPop: !_busy && !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop &&
            !_busy &&
            await staffConfirm(context, s, s.unsavedQuestion) &&
            context.mounted) {
          setState(() => _dirty = false);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) Navigator.pop(context);
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Text(s.masterReviews, style: const TextStyle(fontSize: 16)),
          actions: [
            IconButton(
              tooltip: s.refreshRecord,
              onPressed: _busy ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _work == null
            ? StaffError(
                error: _error ?? s.requestFailed,
                retry: _load,
                strings: s,
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    _work!['title'] ?? '',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    [
                      _work!['coach'],
                      _work!['club'],
                      _work!['rank'],
                    ].where((v) => v != null && v != '').join(' · '),
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _work!['category'] ?? '',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  StaffMark(reviewed: _work!['is_review'] == true, strings: s),
                  const SizedBox(height: 16),
                  if (_work!['video_url'] != null)
                    ProtectedVideoPlayer(
                      key: ValueKey(_work!['video_url']),
                      api: widget.api,
                      url: _work!['video_url'] as String,
                      strings: s,
                    )
                  else
                    Text(s.videoUnavailable),
                  for (final field in _fields.entries)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: TextField(
                        controller: field.value,
                        enabled: !_busy,
                        minLines: field.key.contains('point') ? 1 : 3,
                        maxLines: field.key.contains('point') ? 2 : 8,
                        maxLength: field.key.contains('point') ? 100 : 10000,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          labelText: s.staffField(field.key),
                          alignLabelWithHint: true,
                        ),
                        onChanged: (_) => setState(() {
                          _dirty = true;
                          _saved = false;
                        }),
                      ),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  if (_saved)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        s.savedScore,
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _save(true),
                    icon: const Icon(Icons.check, size: 18),
                    label: Text(
                      _busy
                          ? s.saving
                          : _work!['is_review'] == true
                          ? s.save
                          : s.publishReview,
                    ),
                  ),
                  TextButton(
                    onPressed: _busy ? null : () => _save(false),
                    child: Text(
                      _work!['is_review'] == true
                          ? s.reopenReview
                          : s.saveDraft,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
