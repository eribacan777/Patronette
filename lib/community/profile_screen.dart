import 'package:flutter/material.dart';

import '../data/profile_store.dart';
import '../theme.dart';
import 'admin_screen.dart';
import 'avatar.dart';
import 'collection_screen.dart';
import 'edit_profile_screen.dart';
import 'models.dart';
import 'post_actions.dart';
import 'post_screen.dart';
import 'save_sheet.dart';
import 'session.dart';

/// Profilul unei persoane, ca pe Instagram: poză, cifre, descriere, butonul
/// de urmărire și, dedesubt, grila cu postări sau colecțiile publice.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.userId,
    required this.session,
    required this.store,
  });

  final int userId;
  final Session session;
  final ProfileStore store;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

enum _Tab { posts, collections }

class _ProfileScreenState extends State<ProfileScreen> {
  late final PostActions _actions = PostActions(widget.session);
  UserProfile? _profile;
  final List<Post> _posts = [];
  int? _nextBeforeId;
  List<PostCollection>? _collections;
  _Tab _tab = _Tab.posts;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = widget.session.api;
    try {
      final results = await Future.wait([
        api.profile(widget.userId),
        api.userPosts(widget.userId),
        api.userCollections(widget.userId),
      ]);
      final page = results[1] as PostPage;
      setState(() {
        _profile = results[0] as UserProfile;
        _posts
          ..clear()
          ..addAll(page.posts);
        _nextBeforeId = page.nextBeforeId;
        _collections = results[2] as List<PostCollection>;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  Future<void> _morePosts() async {
    final before = _nextBeforeId;
    if (before == null || _busy) return;
    setState(() => _busy = true);
    try {
      final page =
          await widget.session.api.userPosts(widget.userId, beforeId: before);
      setState(() {
        _posts.addAll(page.posts);
        _nextBeforeId = page.nextBeforeId;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleFollow() async {
    final p = _profile!;
    if (!await _actions.ensureLoggedIn(context)) return;
    setState(() => _busy = true);
    try {
      final updated = p.followedByMe
          ? await widget.session.api.unfollow(p.id)
          : await widget.session.api.follow(p.id);
      setState(() => _profile = updated);
    } catch (e) {
      _snack('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unblock() async {
    try {
      await widget.session.api.unblock(_profile!.id);
      await _load();
    } catch (e) {
      _snack('$e');
    }
  }

  Future<void> _edit() async {
    final updated =
        await Navigator.of(context).push<UserProfile>(MaterialPageRoute(
      builder: (_) =>
          EditProfileScreen(session: widget.session, profile: _profile!),
    ));
    if (updated != null) setState(() => _profile = updated);
  }

  Future<void> _newCollection() async {
    final c = await showDialog<PostCollection>(
      context: context,
      builder: (_) => NewCollectionDialog(session: widget.session),
    );
    if (c != null) setState(() => _collections = [...?_collections, c]);
  }

  void _snack(String s) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
    }
  }

  Future<void> _openPost(Post post) async {
    await Navigator.of(context).push<Post?>(MaterialPageRoute(
      builder: (_) =>
          PostScreen(post: post, session: widget.session, store: widget.store),
    ));
    if (mounted) _load();
  }

  Future<void> _openCollection(PostCollection c) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CollectionScreen(
          collectionId: c.id, session: widget.session, store: widget.store),
    ));
    if (mounted) _load();
  }

  Future<void> _openPeople(bool followers) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => FollowListScreen(
        userId: widget.userId,
        followers: followers,
        session: widget.session,
        store: widget.store,
      ),
    ));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final p = _profile;
    final isAdmin = widget.session.user?.isAdmin ?? false;
    return Scaffold(
      appBar: AppBar(
        title: Text(p?.displayName ?? 'Profil'),
        actions: [
          if (p != null && p.isMe)
            PopupMenuButton<String>(
              tooltip: 'Mai multe',
              onSelected: (v) async {
                if (v == 'edit') _edit();
                if (v == 'admin') {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => AdminScreen(session: widget.session)));
                }
                if (v == 'logout') {
                  await widget.session.logout();
                  if (context.mounted) Navigator.of(context).pop();
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'edit', child: Text('Editează profilul')),
                if (isAdmin)
                  const PopupMenuItem(
                      value: 'admin', child: Text('Postări raportate')),
                const PopupMenuItem(
                    value: 'logout', child: Text('Deconectează-te')),
              ],
            ),
        ],
      ),
      body: _error != null && p == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(
                      onPressed: _load, child: const Text('Încearcă din nou')),
                ]),
              ),
            )
          : p == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(child: _header(context, p)),
                      if (_tab == _Tab.posts)
                        ..._postGrid(context)
                      else
                        ..._collectionGrid(context, p),
                    ],
                  ),
                ),
    );
  }

  Widget _header(BuildContext context, UserProfile p) {
    final theme = Theme.of(context);
    Widget stat(int n, String label, VoidCallback? onTap) => Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(children: [
                Text('$n',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
                Text(label, style: theme.textTheme.bodySmall),
              ]),
            ),
          ),
        );

    final Widget action;
    if (p.isMe) {
      action = OutlinedButton(
          onPressed: _edit, child: const Text('Editează profilul'));
    } else if (p.blockedByMe) {
      action =
          OutlinedButton(onPressed: _unblock, child: const Text('Deblochează'));
    } else if (p.followedByMe) {
      action = FilledButton.tonal(
          onPressed: _busy ? null : _toggleFollow,
          child: const Text('Urmărești'));
    } else {
      action = FilledButton(
          onPressed: _busy ? null : _toggleFollow,
          child: const Text('Urmărește'));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            UserAvatar(user: p.asUser, api: widget.session.api, radius: 42),
            const SizedBox(width: 16),
            stat(p.postCount, 'postări', null),
            stat(p.followerCount, 'urmăritori', () => _openPeople(true)),
            stat(p.followingCount, 'urmăriri', () => _openPeople(false)),
          ]),
          const SizedBox(height: 12),
          Text(p.displayName,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          if (p.bio.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(p.bio),
          ],
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: action),
          const SizedBox(height: 12),
          SegmentedButton<_Tab>(
            segments: const [
              ButtonSegment(
                  value: _Tab.posts,
                  icon: Icon(Icons.grid_on),
                  label: Text('Postări')),
              ButtonSegment(
                  value: _Tab.collections,
                  icon: Icon(Icons.bookmarks_outlined),
                  label: Text('Colecții')),
            ],
            selected: {_tab},
            onSelectionChanged: (s) => setState(() => _tab = s.first),
          ),
        ],
      ),
    );
  }

  List<Widget> _postGrid(BuildContext context) {
    if (_profile!.blockedByMe) {
      return [
        const _Empty('Ai blocat-o. Deblocheaz-o ca să-i vezi postările.')
      ];
    }
    if (_posts.isEmpty) return [const _Empty('Încă nicio postare.')];
    return [
      SliverPadding(
        padding: const EdgeInsets.all(2),
        sliver: SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, mainAxisSpacing: 2, crossAxisSpacing: 2),
          itemCount: _posts.length,
          itemBuilder: (context, i) {
            final post = _posts[i];
            return _PostTile(
              post: post,
              imageUrl: post.imageUrl == null
                  ? null
                  : widget.session.api.imageUrl(post.imageUrl!),
              onTap: () => _openPost(post),
            );
          },
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: _nextBeforeId == null
              ? const SizedBox.shrink()
              : TextButton(
                  onPressed: _busy ? null : _morePosts,
                  child: const Text('Mai multe postări'),
                ),
        ),
      ),
    ];
  }

  List<Widget> _collectionGrid(BuildContext context, UserProfile p) {
    final list = _collections ?? const [];
    final tiles = <Widget>[
      if (p.isMe)
        _CollectionTile(
          title: 'Colecție nouă',
          subtitle: 'Salvează idei',
          icon: Icons.add,
          onTap: _newCollection,
        ),
      for (final c in list)
        _CollectionTile(
          title: c.name,
          subtitle: '${c.itemCount} ${c.itemCount == 1 ? 'postare' : 'postări'}'
              '${c.isPublic ? '' : ' · privată'}',
          imageUrl: c.coverUrl == null
              ? null
              : widget.session.api.imageUrl(c.coverUrl!),
          icon: c.isPublic ? Icons.bookmarks_outlined : Icons.lock_outline,
          onTap: () => _openCollection(c),
        ),
    ];
    if (tiles.isEmpty) return [const _Empty('Nicio colecție publică.')];
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        sliver: SliverGrid.count(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.82,
          children: tiles,
        ),
      ),
    ];
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Text(text, textAlign: TextAlign.center),
        ),
      );
}

/// O postare în grila profilului: poza, sau textul pe fundal colorat.
class _PostTile extends StatelessWidget {
  const _PostTile(
      {required this.post, required this.imageUrl, required this.onTap});

  final Post post;
  final String? imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Accent.of(post.id);
    return InkWell(
      onTap: onTap,
      child: imageUrl != null
          ? Image.network(imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: accent.light))
          : Container(
              color: accent.light,
              padding: const EdgeInsets.all(8),
              alignment: Alignment.center,
              child: Text(post.text,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12, color: PatronetteColors.ink)),
            ),
    );
  }
}

class _CollectionTile extends StatelessWidget {
  const _CollectionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.imageUrl,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                color: theme.colorScheme.primaryContainer,
                child: imageUrl != null
                    ? Image.network(imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(icon, size: 40))
                    : Icon(icon, size: 40, color: theme.colorScheme.primary),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          Text(subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// Lista de urmăritori sau de persoane urmărite.
class FollowListScreen extends StatefulWidget {
  const FollowListScreen({
    super.key,
    required this.userId,
    required this.followers,
    required this.session,
    required this.store,
  });

  final int userId;
  final bool followers;
  final Session session;
  final ProfileStore store;

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  List<AppUser>? _people;
  String? _error;

  @override
  void initState() {
    super.initState();
    final api = widget.session.api;
    (widget.followers
            ? api.followers(widget.userId)
            : api.following(widget.userId))
        .then((p) => setState(() => _people = p))
        .catchError((Object e) => setState(() => _error = '$e'));
  }

  @override
  Widget build(BuildContext context) {
    final people = _people;
    return Scaffold(
      appBar: AppBar(title: Text(widget.followers ? 'Urmăritori' : 'Urmăriri')),
      body: _error != null
          ? Center(child: Text(_error!))
          : people == null
              ? const Center(child: CircularProgressIndicator())
              : people.isEmpty
                  ? Center(
                      child: Text(widget.followers
                          ? 'Încă nu o urmărește nimeni.'
                          : 'Încă nu urmărește pe nimeni.'))
                  : ListView(
                      children: [
                        for (final u in people)
                          ListTile(
                            leading:
                                UserAvatar(user: u, api: widget.session.api),
                            title: Text(u.displayName),
                            onTap: () =>
                                Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => ProfileScreen(
                                  userId: u.id,
                                  session: widget.session,
                                  store: widget.store),
                            )),
                          ),
                      ],
                    ),
    );
  }
}
