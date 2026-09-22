import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../l10n/app_locale.dart';
import 'feed_models.dart';
import 'feed_media.dart';
import 'feed_reactions.dart';

class FeedCommentsSheet extends StatefulWidget {
  const FeedCommentsSheet({
    super.key,
    required this.api,
    required this.strings,
    required this.post,
    required this.onPost,
  });
  final ApiClient api;
  final AppStrings strings;
  final FeedPost post;
  final ValueChanged<FeedPost> onPost;
  @override
  State<FeedCommentsSheet> createState() => _FeedCommentsSheetState();
}

class _FeedCommentsSheetState extends State<FeedCommentsSheet> {
  final _text = TextEditingController();
  final _comments = <FeedComment>[];
  final _replies = <int, List<FeedComment>>{};
  final _replyPages = <int, int>{}, _replyLast = <int, int>{};
  final _replyLoading = <int>{};
  int _page = 0, _last = 1;
  bool _loading = false, _busy = false;
  String? _error;
  FeedComment? _editing, _replying;
  bool get _working => _busy || _loading || _replyLoading.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false, int? parent}) async {
    if (_busy ||
        parent == null && _loading ||
        parent != null && _replyLoading.contains(parent)) {
      return;
    }
    final page = reset
        ? 1
        : (parent == null ? _page : _replyPages[parent] ?? 0) + 1;
    setState(() {
      _error = null;
      if (parent == null) {
        _loading = true;
      } else {
        _replyLoading.add(parent);
      }
    });
    try {
      final result = await widget.api.getJson(
        '/feed/${widget.post.id}/comments',
        query: {'page': '$page', if (parent != null) 'parent_id': '$parent'},
      );
      if (!mounted) return;
      final items = (result['data'] as List)
          .cast<Map<String, dynamic>>()
          .map(FeedComment.fromJson)
          .toList();
      setState(() {
        final list = parent == null
            ? _comments
            : _replies.putIfAbsent(parent, () => []);
        if (reset) list.clear();
        final merged = {for (final c in list) c.id: c};
        for (final item in items) {
          merged[item.id] = item;
        }
        list
          ..clear()
          ..addAll(merged.values)
          ..sort((a, b) => a.id.compareTo(b.id));
        final last = (result['meta']['last_page'] as num).toInt();
        if (parent == null) {
          _page = page;
          _last = last;
        } else {
          _replyPages[parent] = page;
          _replyLast[parent] = last;
        }
      });
      _updatePost(result);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() {
          if (parent == null) {
            _loading = false;
          } else {
            _replyLoading.remove(parent);
          }
        });
      }
    }
  }

  void _updatePost(Map<String, dynamic> data) {
    if (data['post'] is Map<String, dynamic>) {
      widget.onPost(FeedPost.fromJson(data['post'] as Map<String, dynamic>));
    }
  }

  Future<void> _mutate(
    Future<Map<String, dynamic>> Function() request, {
    FeedComment? remove,
  }) async {
    if (_working) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await request();
      if (!mounted) return;
      _updatePost(data);
      setState(() {
        if (remove != null) {
          _comments.removeWhere((c) => c.id == remove.id);
          for (final list in _replies.values) {
            list.removeWhere((c) => c.id == remove.id);
          }
          _replies.remove(remove.id);
        } else if (data['comment'] is Map<String, dynamic>) {
          final next = FeedComment.fromJson(
            data['comment'] as Map<String, dynamic>,
          );
          final list = next.parentId == null
              ? _comments
              : _replies.putIfAbsent(next.parentId!, () => []);
          final i = list.indexWhere((c) => c.id == next.id);
          if (i >= 0) {
            list[i] = next;
          } else {
            list.add(next);
            list.sort((a, b) => a.id.compareTo(b.id));
          }
        }
        if (data['parent'] is Map<String, dynamic>) {
          final parent = FeedComment.fromJson(
            data['parent'] as Map<String, dynamic>,
          );
          final i = _comments.indexWhere((c) => c.id == parent.id);
          if (i >= 0) _comments[i] = parent;
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (_text.text.trim().isEmpty || _working) return;
    final editing = _editing, replying = _replying;
    await _mutate(
      () => editing == null
          ? widget.api.postJson(
              '/feed/${widget.post.id}/comments',
              body: {
                'text': _text.text.trim(),
                if (replying != null) 'parent_id': replying.id,
              },
            )
          : widget.api.putJson(
              '/feed/comments/${editing.id}',
              body: {'text': _text.text.trim()},
            ),
    );
    if (!mounted || _error != null) return;
    setState(() {
      _editing = null;
      _replying = null;
      _text.clear();
    });
  }

  Future<void> _delete(FeedComment comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(widget.strings.feedRemoveQuestion),
        content: Text(
          comment.text,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(widget.strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(widget.strings.delete),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _mutate(
        () => widget.api.deleteJson('/feed/comments/${comment.id}'),
        remove: comment,
      );
      if (_error == null) await _load(reset: true);
    }
  }

  Widget _tile(FeedComment comment, {bool reply = false}) {
    final s = widget.strings;
    return Padding(
      padding: EdgeInsets.only(left: reply ? 20 : 0, top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FeedAvatar(
                name: comment.author,
                url: comment.avatarUrl,
                size: 28,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment.author,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(comment.text, style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              if (comment.isMine)
                PopupMenuButton<String>(
                  enabled: !_working,
                  tooltip: s.more,
                  icon: const Icon(Icons.more_horiz, size: 18),
                  onSelected: (value) {
                    if (value == 'delete') {
                      _delete(comment);
                    } else {
                      setState(() {
                        _editing = comment;
                        _replying = null;
                        _text.text = comment.text;
                      });
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'edit', child: Text(s.edit)),
                    PopupMenuItem(value: 'delete', child: Text(s.delete)),
                  ],
                ),
            ],
          ),
          FeedReactions(
            strings: s,
            counts: comment.reactions,
            selected: comment.selectedReaction,
            enabled: !_working,
            onSelect: (type) => _mutate(
              () => widget.api.postJson(
                '/feed/comments/${comment.id}/reaction',
                body: {'type': type},
              ),
            ),
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () => setState(() {
                    _replying = comment;
                    _editing = null;
                    _text.clear();
                  }),
            child: Text(s.reply, style: const TextStyle(fontSize: 11)),
          ),
          if (!reply) ...[
            for (final child in _replies[comment.id] ?? <FeedComment>[])
              _tile(child, reply: true),
            if (_replyLoading.contains(comment.id))
              const LinearProgressIndicator()
            else if (comment.repliesCount > 0 &&
                ((_replyPages[comment.id] ?? 0) <
                    (_replyLast[comment.id] ?? 1)))
              TextButton(
                onPressed: () => _load(parent: comment.id),
                child: Text('${s.feedReplies}: ${comment.repliesCount}'),
              ),
          ],
          const Divider(height: 1),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    return PopScope(
      canPop: !_busy,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.75,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      s.comments,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final comment in _comments) _tile(comment),
                        if (_loading)
                          const LinearProgressIndicator()
                        else if (_page < _last)
                          TextButton(
                            onPressed: () => _load(),
                            child: Text(s.moreRecords),
                          ),
                      ],
                    ),
                  ),
                  if (_error != null)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                        IconButton(
                          tooltip: s.retry,
                          onPressed: () => _load(reset: true),
                          icon: const Icon(Icons.refresh),
                        ),
                      ],
                    ),
                  if (_editing != null || _replying != null)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${_editing != null ? s.edit : s.reply}: ${(_editing ?? _replying)!.author}',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                        IconButton(
                          tooltip: s.cancel,
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                  _editing = null;
                                  _replying = null;
                                  _text.clear();
                                }),
                          icon: const Icon(Icons.close, size: 18),
                        ),
                      ],
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _text,
                          enabled: !_working,
                          minLines: 1,
                          maxLines: 3,
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(hintText: s.comments),
                        ),
                      ),
                      IconButton(
                        tooltip: s.send,
                        onPressed: _working ? null : _submit,
                        icon: _busy
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_outlined),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
