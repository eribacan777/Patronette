/// Datele comunității, așa cum vin de la server.
library;

class AppUser {
  const AppUser({
    required this.id,
    required this.displayName,
    this.isAdmin = false,
    this.avatarUrl,
  });

  final int id;
  final String displayName;
  final bool isAdmin;

  /// Calea pozei de profil pe server, sau null.
  final String? avatarUrl;

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as int,
        displayName: j['display_name'] as String,
        isAdmin: j['is_admin'] as bool? ?? false,
        avatarUrl: j['avatar_url'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'display_name': displayName,
        'is_admin': isAdmin,
        'avatar_url': avatarUrl,
      };

  AppUser copyWith(
          {String? displayName, String? avatarUrl, bool clearAvatar = false}) =>
      AppUser(
        id: id,
        displayName: displayName ?? this.displayName,
        isAdmin: isAdmin,
        avatarUrl: clearAvatar ? null : (avatarUrl ?? this.avatarUrl),
      );
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
    this.savedByMe = false,
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

  /// Salvată în cel puțin una dintre colecțiile mele.
  final bool savedByMe;
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
        savedByMe: j['saved_by_me'] as bool? ?? false,
        canDelete: j['can_delete'] as bool,
        hidden: j['hidden'] as bool? ?? false,
        createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
      );

  Post copyWith({
    bool? likedByMe,
    int? likeCount,
    int? commentCount,
    bool? savedByMe,
  }) =>
      Post(
        id: id,
        author: author,
        text: text,
        linkUrl: linkUrl,
        imageUrl: imageUrl,
        pattern: pattern,
        likeCount: likeCount ?? this.likeCount,
        commentCount: commentCount ?? this.commentCount,
        likedByMe: likedByMe ?? this.likedByMe,
        savedByMe: savedByMe ?? this.savedByMe,
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

/// Profilul public al unei persoane, ca pe Instagram.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    required this.bio,
    required this.avatarUrl,
    required this.postCount,
    required this.followerCount,
    required this.followingCount,
    required this.followedByMe,
    required this.blockedByMe,
    required this.isMe,
  });

  final int id;
  final String displayName;
  final String bio;
  final String? avatarUrl;
  final int postCount;
  final int followerCount;
  final int followingCount;
  final bool followedByMe;
  final bool blockedByMe;
  final bool isMe;

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        id: j['id'] as int,
        displayName: j['display_name'] as String,
        bio: j['bio'] as String? ?? '',
        avatarUrl: j['avatar_url'] as String?,
        postCount: j['post_count'] as int,
        followerCount: j['follower_count'] as int,
        followingCount: j['following_count'] as int,
        followedByMe: j['followed_by_me'] as bool,
        blockedByMe: j['blocked_by_me'] as bool,
        isMe: j['is_me'] as bool,
      );

  AppUser get asUser =>
      AppUser(id: id, displayName: displayName, avatarUrl: avatarUrl);
}

/// O colecție de postări salvate, ca un board pe Pinterest.
class PostCollection {
  const PostCollection({
    required this.id,
    required this.owner,
    required this.name,
    required this.isPublic,
    required this.itemCount,
    required this.coverUrl,
    this.containsPost,
  });

  final int id;
  final AppUser owner;
  final String name;
  final bool isPublic;
  final int itemCount;
  final String? coverUrl;

  /// Doar când lista a fost cerută pentru o anumită postare.
  final bool? containsPost;

  factory PostCollection.fromJson(Map<String, dynamic> j) => PostCollection(
        id: j['id'] as int,
        owner: AppUser.fromJson(j['owner'] as Map<String, dynamic>),
        name: j['name'] as String,
        isPublic: j['is_public'] as bool,
        itemCount: j['item_count'] as int,
        coverUrl: j['cover_url'] as String?,
        containsPost: j['contains_post'] as bool?,
      );
}
