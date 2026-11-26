import 'package:flutter/material.dart';

import '../data/profile_store.dart';
import 'models.dart';
import 'post_actions.dart';
import 'post_card.dart';
import 'post_screen.dart';
import 'profile_screen.dart';
import 'save_sheet.dart';
import 'session.dart';
import 'community.dart';

/// O colecție: postările salvate în ea. Proprietara o poate redenumi, face
/// publică sau privată, ori șterge.
class CollectionScreen extends StatefulWidget {
  const CollectionScreen({
    super.key,
    required this.collectionId,
    required this.session,
    required this.store,
  });

  final int collectionId;
  final Session session;
  final ProfileStore store;

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  late final PostActions _actions = PostActions(widget.session);
  PostCollection? _collection;
  List<Post> _posts = [];
  String? _error;

  bool get _mine =>
      _collection != null && _collection!.owner.id == widget.session.user?.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final (c, posts) =
          await widget.session.api.collection(widget.collectionId);
      setState(() {
        _collection = c;
        _posts = posts;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  Future<void> _edit() async {
    final updated = await showDialog<PostCollection>(
      context: context,
      builder: (_) =>
          NewCollectionDialog(session: widget.session, existing: _collection),
    );
    if (updated != null) setState(() => _collection = updated);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Ștergi colecția „${_collection!.name}”?'),
        content:
            const Text('Postările rămân în comunitate; dispare doar colecția.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Renunță')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Șterge')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.session.api.deleteCollection(_collection!.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  void _replace(Post p) {
    final i = _posts.indexWhere((x) => x.id == p.id);
    if (i >= 0) setState(() => _posts[i] = p);
  }

  Future<void> _onAction(Post post, PostAction action) async {
    switch (action) {
      case PostAction.like:
        final u = await _actions.toggleLike(context, post);
        if (u != null) _replace(u);
      case PostAction.save:
        final u = await _actions.save(context, post);
        if (u != null) _load();
      case PostAction.comments:
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PostScreen(
              post: post, session: widget.session, store: widget.store),
        ));
        if (mounted) _load();
      case PostAction.openAuthor:
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ProfileScreen(
              userId: post.author.id,
              session: widget.session,
              store: widget.store),
        ));
      case PostAction.openPattern:
        await openSharedPattern(context, widget.store, post.pattern!);
      case PostAction.report:
        await _actions.report(context, post);
      case PostAction.block:
        if (await _actions.block(context, post)) _load();
      case PostAction.delete:
        if (await _actions.delete(context, post)) _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _collection;
    return Scaffold(
      appBar: AppBar(
        title: Text(c?.name ?? 'Colecție'),
        actions: [
          if (_mine)
            PopupMenuButton<String>(
              tooltip: 'Mai multe',
              onSelected: (v) => v == 'edit' ? _edit() : _delete(),
              itemBuilder: (_) => const [
                PopupMenuItem(
                    value: 'edit', child: Text('Redenumește / vizibilitate')),
                PopupMenuItem(value: 'delete', child: Text('Șterge colecția')),
              ],
            ),
        ],
      ),
      body: _error != null && c == null
          ? Center(
              child: Padding(
                  padding: const EdgeInsets.all(24), child: Text(_error!)))
          : c == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      ListTile(
                        leading: Icon(
                            c.isPublic ? Icons.public : Icons.lock_outline),
                        title: Text('${c.itemCount} '
                            '${c.itemCount == 1 ? 'postare salvată' : 'postări salvate'}'),
                        subtitle: Text(c.isPublic
                            ? 'Publică · colecția lui ${c.owner.displayName}'
                            : 'Privată · o vezi doar tu'),
                      ),
                      if (_posts.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            'Colecția e goală. Apasă semnul de salvare de pe o '
                            'postare ca s-o adaugi aici.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      for (final post in _posts)
                        PostCard(
                          post: post,
                          api: widget.session.api,
                          loggedIn: widget.session.loggedIn,
                          isMine: widget.session.user?.id == post.author.id,
                          onAction: (a) => _onAction(post, a),
                        ),
                    ],
                  ),
                ),
    );
  }
}
