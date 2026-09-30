import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../l10n/app_locale.dart';
import 'feed_comments_sheet.dart';
import 'feed_media.dart';
import 'feed_models.dart';
import 'feed_reactions.dart';

class FeedPostScreen extends StatefulWidget {
  const FeedPostScreen({
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
  State<FeedPostScreen> createState() => _FeedPostScreenState();
}

class _FeedPostScreenState extends State<FeedPostScreen> {
  late FeedPost _post = widget.post;
  bool _busy = false;

  void _update(FeedPost post) {
    if (!mounted) return;
    setState(() => _post = post);
    widget.onPost(post);
  }

  Future<void> _react(String type) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final response = await widget.api.postJson(
        '/feed/${_post.id}/reaction',
        body: {'type': type},
      );
      _update(FeedPost.fromJson(response['post'] as Map<String, dynamic>));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.strings.feedPublication)),
    body: FeedCommentsSheet(
      api: widget.api,
      strings: widget.strings,
      post: _post,
      onPost: _update,
      fullPage: true,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FeedAvatar(name: _post.author, url: _post.avatarUrl),
              const SizedBox(width: 10),
              Expanded(child: Text(_post.author)),
            ],
          ),
          if (_post.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(_post.text),
            ),
          if (_post.attachment != null)
            FeedMedia(
              attachment: _post.attachment!,
              strings: widget.strings,
              fullSize: true,
            ),
          FeedReactions(
            strings: widget.strings,
            counts: _post.reactions,
            selected: _post.selectedReaction,
            enabled: !_busy,
            onSelect: _react,
          ),
        ],
      ),
    ),
  );
}
