/// Datele comunității, așa cum vin de la server.
library;

class AppUser {
  const AppUser(
      {required this.id, required this.displayName, this.isAdmin = false});

  final int id;
  final String displayName;
  final bool isAdmin;

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as int,
        displayName: j['display_name'] as String,
        isAdmin: j['is_admin'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'display_name': displayName, 'is_admin': isAdmin};
}

/// Un tipar distribuit: doar modelul și setările, fără măsurile cuiva.
class SharedPattern {
  const SharedPattern({required this.garmentId, required this.options});

  final String garmentId;
  final Map<String, double> options;

  factory SharedPattern.fromJson(Map<String, dynamic> j) => SharedPattern(
        garmentId: j['garment_id'] as String,
        options: {
          for (final e in (j['options'] as Map<String, dynamic>).entries)
            e.key: (e.value as num).toDouble(),
        },
      );

  Map<String, dynamic> toJson() =>
      {'garment_id': garmentId, 'options': options};
}

class Post {
  const Post({
    required this.id,
    required this.author,
    required this.text,
    required this.linkUrl,
    required this.imageUrl,
    required this.pattern,
    required this.likeCount,
    required this.commentCount,
    required this.likedByMe,
    required this.canDelete,
    required this.hidden,
    required this.createdAt,
  });

  final int id;
  final AppUser author;
  final String text;
  final String? linkUrl;

  /// Calea pozei pe server (de exemplu `/posts/3/image`), sau null.
  final String? imageUrl;
  final SharedPattern? pattern;
  final int likeCount;
  final int commentCount;
  final bool likedByMe;
  final bool canDelete;
  final bool hidden;
  final DateTime createdAt;

  factory Post.fromJson(Map<String, dynamic> j) => Post(
        id: j['id'] as int,
        author: AppUser.fromJson(j['author'] as Map<String, dynamic>),
        text: j['text'] as String,
        linkUrl: j['link_url'] as String?,
        imageUrl: j['image_url'] as String?,
        pattern: j['pattern'] == null
            ? null
            : SharedPattern.fromJson(j['pattern'] as Map<String, dynamic>),
        likeCount: j['like_count'] as int,
        commentCount: j['comment_count'] as int,
        likedByMe: j['liked_by_me'] as bool,
        canDelete: j['can_delete'] as bool,
        hidden: j['hidden'] as bool? ?? false,
        createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
      );

  Post copyWith({bool? likedByMe, int? likeCount, int? commentCount}) => Post(
        id: id,
        author: author,
        text: text,
        linkUrl: linkUrl,
        imageUrl: imageUrl,
        pattern: pattern,
        likeCount: likeCount ?? this.likeCount,
        commentCount: commentCount ?? this.commentCount,
        likedByMe: likedByMe ?? this.likedByMe,
        canDelete: canDelete,
        hidden: hidden,
        createdAt: createdAt,
      );
}

class PostPage {
  const PostPage(this.posts, this.nextBeforeId);

  final List<Post> posts;
  final int? nextBeforeId;
}

class Comment {
  const Comment({
    required this.id,
    required this.author,
    required this.text,
    required this.createdAt,
    required this.canDelete,
  });

  final int id;
  final AppUser author;
  final String text;
  final DateTime createdAt;
  final bool canDelete;

  factory Comment.fromJson(Map<String, dynamic> j) => Comment(
        id: j['id'] as int,
        author: AppUser.fromJson(j['author'] as Map<String, dynamic>),
        text: j['text'] as String,
        createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
        canDelete: j['can_delete'] as bool,
      );
}

class ReportedPost {
  const ReportedPost(this.post, this.reportCount, this.reasons);

  final Post post;
  final int reportCount;
  final List<String> reasons;

  factory ReportedPost.fromJson(Map<String, dynamic> j) => ReportedPost(
        Post.fromJson(j['post'] as Map<String, dynamic>),
        j['report_count'] as int,
        [for (final r in j['reasons'] as List) r as String],
      );
}
