enum FeedAudience { all, students, coaches, organization }

enum FeedAttachmentType { image, video }

class FeedAttachment {
  const FeedAttachment({
    required this.type,
    this.localPath,
    this.assetPath,
    this.remoteUrl,
  });

  factory FeedAttachment.fromJson(Map<String, dynamic> json) {
    final type = json['type']?.toString() == 'video'
        ? FeedAttachmentType.video
        : FeedAttachmentType.image;

    return FeedAttachment(type: type, remoteUrl: json['url']?.toString());
  }

  final FeedAttachmentType type;
  final String? localPath;
  final String? assetPath;
  final String? remoteUrl;
}

class FeedComment {
  FeedComment({
    required this.id,
    required this.author,
    required this.text,
    required this.createdAt,
    this.isMine = false,
    this.avatarUrl,
    this.parentId,
    this.repliesCount = 0,
    this.selectedReaction,
    List<FeedComment>? replies,
    Map<String, int>? reactions,
  }) : replies = replies ?? [],
       reactions = reactions ?? {};

  final int id;
  final String author;
  String text;
  final DateTime createdAt;
  final bool isMine;
  final String? avatarUrl;
  final int? parentId;
  final int repliesCount;
  final String? selectedReaction;
  final List<FeedComment> replies;
  final Map<String, int> reactions;

  factory FeedComment.fromJson(Map<String, dynamic> json) {
    final reactions = _asMap(json['reactions']);
    final counts = _asMap(reactions['counts']);

    return FeedComment(
      id: (json['id'] as num).toInt(),
      author: _asMap(json['author'])['name']?.toString() ?? '—',
      text: json['text']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      isMine: json['is_mine'] == true,
      avatarUrl: _asMap(json['author'])['avatar_url']?.toString(),
      parentId: (json['parent_id'] as num?)?.toInt(),
      repliesCount: (json['replies_count'] as num?)?.toInt() ?? 0,
      selectedReaction: reactions['selected']?.toString(),
      reactions: counts.map(
        (key, value) => MapEntry(key, (value as num).toInt()),
      ),
      replies: (json['replies'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(FeedComment.fromJson)
          .toList(),
    );
  }
}

class FeedPost {
  FeedPost({
    required this.id,
    required this.author,
    required this.scope,
    required this.text,
    required this.createdAt,
    this.isMine = false,
    this.avatarUrl,
    this.commentsCount,
    this.attachment,
    List<String>? tags,
    List<FeedComment>? comments,
    Map<String, int>? reactions,
    this.selectedReaction,
  }) : tags = tags ?? [],
       comments = comments ?? [],
       reactions = reactions ?? {};

  final int id;
  final String author;
  final FeedAudience scope;
  String text;
  final DateTime createdAt;
  final bool isMine;
  final String? avatarUrl;
  final int? commentsCount;
  FeedAttachment? attachment;
  final List<String> tags;
  final List<FeedComment> comments;
  final Map<String, int> reactions;
  String? selectedReaction;

  factory FeedPost.fromJson(Map<String, dynamic> json) {
    final reactions = _asMap(json['reactions']);
    final counts = _asMap(reactions['counts']);
    final attachment = _nullableMap(json['attachment']);

    return FeedPost(
      id: (json['id'] as num).toInt(),
      author: _asMap(json['author'])['name']?.toString() ?? '—',
      scope: _audienceFromApi(json['scope']?.toString()),
      text: json['text']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      isMine: json['is_mine'] == true,
      avatarUrl: _asMap(json['author'])['avatar_url']?.toString(),
      commentsCount: (json['comments_count'] as num?)?.toInt(),
      attachment: attachment == null
          ? null
          : FeedAttachment.fromJson(attachment),
      comments: (json['comments'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(FeedComment.fromJson)
          .toList(),
      reactions: counts.map(
        (key, value) => MapEntry(key, (value as num).toInt()),
      ),
      selectedReaction: reactions['selected']?.toString(),
    );
  }

  int get reactionTotal =>
      reactions.values.fold(0, (sum, value) => sum + value);
  int get commentTotal =>
      commentsCount ??
      comments.fold<int>(0, (sum, comment) => sum + 1 + comment.replies.length);
}

Map<String, dynamic> _asMap(Object? value) {
  return value is Map<String, dynamic> ? value : <String, dynamic>{};
}

Map<String, dynamic>? _nullableMap(Object? value) {
  return value is Map<String, dynamic> ? value : null;
}

FeedAudience _audienceFromApi(String? value) {
  return switch (value) {
    'organization' => FeedAudience.organization,
    'coaches' => FeedAudience.coaches,
    'students' => FeedAudience.students,
    _ => FeedAudience.all,
  };
}
