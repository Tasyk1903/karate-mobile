import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../feed/feed_models.dart';
import '../navigation/coach_route_observer.dart';
import 'feed_comments_sheet.dart';
import 'feed_composer_sheet.dart';
import 'feed_settings_sheet.dart';
import 'feed_reactions.dart';
import 'feed_media.dart';
import 'feed_post_screen.dart';
import 'feed_attachment_button.dart';
import '../l10n/app_locale.dart';
import '../navigation/coach_bottom_nav.dart';
import '../notifications/notification_button.dart';
import '../theme/app_colors.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({
    super.key,
    required this.strings,
    required this.api,
    required this.email,
    required this.onLogout,
    this.onlyMine = false,
  });

  final AppStrings strings;
  final ApiClient api;
  final String? email;
  final Future<void> Function() onLogout;
  final bool onlyMine;

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen>
    with WidgetsBindingObserver, RouteAware {
  final _composerController = TextEditingController();
  final _scroll = ScrollController();
  int _page = 0, _lastPage = 1, _generation = 0;
  bool _loadingMore = false, _publishing = false;
  final _reacting = <int>{};
  bool? _ticker;
  bool _openingPost = false;
  bool _skipActivationRefresh = false;
  String? _error;
  var _selectedAudience = FeedAudience.all;
  var _isLoading = true;

  var _posts = <FeedPost>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(() {
      if (_scroll.hasClients && _scroll.position.extentAfter < 350) {
        _loadFeed(more: true);
      }
    });
    _loadFeed();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) coachRouteObserver.subscribe(this, route);
    final enabled = TickerMode.valuesOf(context).enabled;
    if (_ticker == false && enabled) {
      if (_skipActivationRefresh) {
        _skipActivationRefresh = false;
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_openingPost) _loadFeed(preserve: true);
        });
      }
    }
    _ticker = enabled;
  }

  @override
  void didPopNext() {
    if (_ticker != false && !_openingPost) _loadFeed(preserve: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _ticker != false &&
        !_openingPost) {
      _loadFeed(preserve: true);
    }
  }

  @override
  void dispose() {
    _composerController.dispose();
    _generation++;
    coachRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _scroll.dispose();
    super.dispose();
  }

  List<FeedPost> get _visiblePosts => _posts;

  String get _feedScope => widget.onlyMine ? 'mine' : _selectedAudience.name;

  Future<void> _loadFeed({bool more = false, bool preserve = false}) async {
    if (preserve && (_isLoading || _loadingMore)) return;
    preserve = preserve && _posts.isNotEmpty;
    if (!mounted ||
        more && (_isLoading || _loadingMore || _page >= _lastPage)) {
      return;
    }
    final generation = ++_generation;
    final page = more ? _page + 1 : 1;
    setState(() {
      _error = null;
      if (more) {
        _loadingMore = true;
      } else if (!preserve) {
        _isLoading = true;
        _posts = [];
      }
    });
    try {
      final response = await widget.api.getJson(
        '/feed',
        query: {'scope': _feedScope, 'page': '$page', 'per_page': '10'},
      );
      if (!mounted || generation != _generation) return;
      final data = (response['data'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(FeedPost.fromJson);
      final meta = response['meta'] as Map<String, dynamic>? ?? {};
      setState(() {
        final items = {for (final post in _posts) post.id: post};
        for (final post in data) {
          if (!preserve || items.containsKey(post.id)) items[post.id] = post;
        }
        _posts = items.values.toList();
        if (!preserve) _page = page;
        _lastPage = (meta['last_page'] as num?)?.toInt() ?? page;
      });
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() {
          _isLoading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _openSettings() async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          FeedSettingsSheet(api: widget.api, strings: widget.strings),
    );
    if (changed == true && mounted) await _loadFeed();
  }

  void _replacePost(FeedPost post) {
    if (!mounted) return;
    final index = _posts.indexWhere((item) => item.id == post.id);
    setState(() {
      if (index == -1) {
        return;
      } else {
        _posts[index] = post;
      }
    });
  }

  Future<void> _publishQuickPost() async {
    if (_publishing) return;
    final text = _composerController.text.trim();
    if (text.isEmpty) {
      _showMessage(widget.strings.emptyPost);
      return;
    }

    setState(() => _publishing = true);
    try {
      await widget.api.postMultipart('/feed', fields: {'text': text});
      if (!mounted) return;
      _composerController.clear();
      await _loadFeed();
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  Future<void> _openComposer({
    FeedPost? post,
    FeedAttachmentType? attachmentType,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => FeedComposerSheet(
        api: widget.api,
        strings: widget.strings,
        post: post,
        initialText: post == null ? _composerController.text : null,
        initialType: attachmentType,
        onSaved: (saved) async {
          if (!mounted) return;
          if (post == null) {
            _composerController.clear();
            await _loadFeed();
          } else {
            _replacePost(saved);
          }
        },
      ),
    );
  }

  Future<void> _toggleReaction(FeedPost post, String type) async {
    if (!_reacting.add(post.id)) return;
    try {
      final response = await widget.api.postJson(
        '/feed/${post.id}/reaction',
        body: {'type': type},
      );
      _replacePost(FeedPost.fromJson(response['post'] as Map<String, dynamic>));
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      _reacting.remove(post.id);
    }
  }

  Future<void> _deletePost(FeedPost post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(widget.strings.feedRemoveQuestion),
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
    if (confirmed != true || !mounted) return;
    try {
      await widget.api.deleteJson('/feed/${post.id}');
      if (mounted) {
        setState(() => _posts.removeWhere((item) => item.id == post.id));
      }
    } catch (error) {
      _showMessage(error.toString());
    }
  }

  Future<void> _openComments(FeedPost post) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => FeedCommentsSheet(
        api: widget.api,
        strings: widget.strings,
        post: post,
        onPost: _replacePost,
      ),
    );
  }

  Future<void> _openPost(FeedPost post) async {
    _openingPost = true;
    _skipActivationRefresh = true;
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => FeedPostScreen(
            api: widget.api,
            strings: widget.strings,
            post: post,
            onPost: _replacePost,
          ),
        ),
      );
    } finally {
      _openingPost = false;
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(AppColors.backgroundImage(context), fit: BoxFit.cover),
          Container(color: AppColors.backgroundOverlay(context)),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _loadFeed,
              child: CustomScrollView(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.onlyMine)
                            Row(
                              children: [
                                const BackButton(),
                                Expanded(
                                  child: Text(
                                    widget.strings.myPosts,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else
                            _FeedHeader(
                              strings: widget.strings,
                              api: widget.api,
                              onLogout: widget.onLogout,
                              onSettings: _openSettings,
                            ),
                          const SizedBox(height: 22),
                          if (!widget.onlyMine)
                            _AudienceTabs(
                              student: widget.api.isStudent,
                              strings: widget.strings,
                              selected: _selectedAudience,
                              onChanged: (value) {
                                setState(() => _selectedAudience = value);
                                _loadFeed();
                              },
                            ),
                          const SizedBox(height: 16),
                          _PostComposer(
                            strings: widget.strings,
                            controller: _composerController,
                            onPublish: _publishQuickPost,
                            onOpenComposer: _openComposer,
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    sliver: _isLoading
                        ? const SliverToBoxAdapter(
                            child: Center(
                              child: Padding(
                                padding: EdgeInsets.all(32),
                                child: CircularProgressIndicator(
                                  color: AppColors.red,
                                ),
                              ),
                            ),
                          )
                        : SliverList.separated(
                            itemCount: _visiblePosts.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 16),
                            itemBuilder: (context, index) {
                              final post = _visiblePosts[index];
                              return FeedPostCard(
                                key: ValueKey(post.id),
                                strings: widget.strings,
                                post: post,
                                onEdit: () => _openComposer(post: post),
                                onDelete: () => _deletePost(post),
                                onComments: () => _openComments(post),
                                onOpen: () => _openPost(post),
                                onReaction: (type) =>
                                    _toggleReaction(post, type),
                              );
                            },
                          ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          if (_error != null) ...[
                            Text(_error!),
                            TextButton(
                              onPressed: () =>
                                  _loadFeed(more: _posts.isNotEmpty),
                              child: Text(widget.strings.retry),
                            ),
                          ] else if (!_isLoading && _posts.isEmpty)
                            Text(widget.strings.feedNoPosts),
                          if (_loadingMore)
                            const CircularProgressIndicator()
                          else if (!_isLoading &&
                              _page < _lastPage &&
                              _error == null)
                            TextButton(
                              onPressed: () => _loadFeed(more: true),
                              child: Text(widget.strings.moreRecords),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: widget.onlyMine
          ? null
          : CoachBottomNav(
              strings: widget.strings,
              api: widget.api,
              active: CoachNavItem.feed,
            ),
    );
  }
}

class _FeedHeader extends StatelessWidget {
  const _FeedHeader({
    required this.strings,
    required this.api,
    required this.onLogout,
    required this.onSettings,
  });

  final AppStrings strings;
  final ApiClient api;
  final VoidCallback onSettings;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            strings.participantsFeed,
            style: TextStyle(
              color: AppColors.inkFor(context),
              fontSize: 20,
              height: 1.05,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        NotificationButton(api: api, strings: strings),
        const SizedBox(width: 12),
        _RoundIconButton(icon: Icons.tune_rounded, onTap: onSettings),
      ],
    );
  }
}

class _AudienceTabs extends StatelessWidget {
  const _AudienceTabs({
    this.student = false,
    required this.strings,
    required this.selected,
    required this.onChanged,
  });

  final AppStrings strings;
  final FeedAudience selected;
  final bool student;
  final ValueChanged<FeedAudience> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = [
      (FeedAudience.all, strings.all),
      if (!student) (FeedAudience.students, strings.myStudents),
      if (!student) (FeedAudience.coaches, strings.coaches),
      (FeedAudience.organization, strings.organization),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (final item in items) ...[
            _AudienceChip(
              label: item.$2,
              active: selected == item.$1,
              onTap: () => onChanged(item.$1),
            ),
            const SizedBox(width: 12),
          ],
        ],
      ),
    );
  }
}

class _AudienceChip extends StatelessWidget {
  const _AudienceChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: active ? AppColors.red : AppColors.surfaceFor(context),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: (active ? AppColors.red : Colors.black).withValues(
                alpha: active ? 0.20 : 0.06,
              ),
              blurRadius: active ? 24 : 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : AppColors.inkFor(context),
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _PostComposer extends StatelessWidget {
  const _PostComposer({
    required this.strings,
    required this.controller,
    required this.onPublish,
    required this.onOpenComposer,
  });

  final AppStrings strings;
  final TextEditingController controller;
  final VoidCallback onPublish;
  final Future<void> Function({
    FeedPost? post,
    FeedAttachmentType? attachmentType,
  })
  onOpenComposer;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Avatar(label: 'В', size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: strings.shareNews,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: const EdgeInsets.only(top: 10),
                  ),
                ),
              ),
            ],
          ),
          Divider(height: 22, color: AppColors.borderFor(context)),
          Row(
            children: [
              FeedAttachmentButton(
                strings: strings,
                onSelected: (type) => onOpenComposer(attachmentType: type),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: onPublish,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      strings.publish,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class FeedPostCard extends StatelessWidget {
  const FeedPostCard({
    super.key,
    required this.strings,
    required this.post,
    required this.onEdit,
    required this.onDelete,
    required this.onComments,
    required this.onReaction,
    this.onOpen,
  });
  final AppStrings strings;
  final FeedPost post;
  final VoidCallback onEdit, onDelete, onComments;
  final ValueChanged<String> onReaction;
  final VoidCallback? onOpen;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(8),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FeedAvatar(name: post.author, url: post.avatarUrl),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.author,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${post.createdAt.day.toString().padLeft(2, '0')}.${post.createdAt.month.toString().padLeft(2, '0')}.${post.createdAt.year}',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.mutedFor(context),
                      ),
                    ),
                  ],
                ),
              ),
              if (post.isMine)
                PopupMenuButton<String>(
                  tooltip: strings.more,
                  icon: const Icon(Icons.more_horiz, size: 20),
                  onSelected: (value) {
                    if (value == 'edit') {
                      onEdit();
                    } else {
                      onDelete();
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'edit', child: Text(strings.edit)),
                    PopupMenuItem(value: 'delete', child: Text(strings.delete)),
                  ],
                ),
            ],
          ),
          if (post.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                post.text,
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
            ),
          if (post.attachment != null)
            FeedMedia(
              attachment: post.attachment!,
              strings: strings,
              onOpen: onOpen,
            ),
          const Divider(height: 18),
          FeedReactions(
            strings: strings,
            counts: post.reactions,
            selected: post.selectedReaction,
            onSelect: onReaction,
          ),
          TextButton.icon(
            onPressed: onComments,
            icon: const Icon(Icons.mode_comment_outlined, size: 18),
            label: Text(
              '${strings.comments} · ${post.commentTotal}',
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.label, required this.size});

  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.red.withValues(alpha: 0.10),
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: AppColors.accentFor(context),
          fontWeight: FontWeight.w900,
          fontSize: size * 0.36,
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: onTap,
          icon: Icon(icon, color: AppColors.inkFor(context)),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.surfaceFor(context),
            fixedSize: const Size(54, 54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            shadowColor: Colors.black.withValues(alpha: 0.10),
            elevation: 8,
          ),
        ),
      ],
    );
  }
}

BoxDecoration _cardDecoration(BuildContext context) {
  return BoxDecoration(
    color: AppColors.surfaceFor(context),
    borderRadius: BorderRadius.circular(24),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.07),
        blurRadius: 28,
        offset: const Offset(0, 14),
      ),
    ],
  );
}
