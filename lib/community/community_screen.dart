import 'package:flutter/material.dart';

import '../data/profile_store.dart';
import 'admin_screen.dart';
import 'community.dart';
import 'login_screen.dart';
import 'models.dart';
import 'new_post_screen.dart';
import 'post_actions.dart';
import 'post_card.dart';
import 'post_screen.dart';
import 'session.dart';

/// Comunitatea: cele mai noi postări, cu încărcare pe pagini la derulare.
class CommunityScreen extends StatefulWidget {
  const CommunityScreen(
      {super.key, required this.store, required this.session});

  final ProfileStore store;
  final Session session;

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  late final PostActions _actions = PostActions(widget.session);
  final _scroll = ScrollController();
  final List<Post> _posts = [];
  int? _nextBeforeId;
  bool _loading = false;
  bool _done = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 600) _loadMore();
    });
    widget.session.addListener(_onSession);
    _refresh();
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSession);
    _scroll.dispose();
    super.dispose();
  }

  // După login sau logout se schimbă ce văd (aprecierile mele, blocările).
  void _onSession() => _refresh();

  Future<void> _refresh() async {
    _posts.clear();
    _nextBeforeId = null;
    _done = false;
    _error = null;
    await _loadMore(force: true);
  }

  Future<void> _loadMore({bool force = false}) async {
    if ((_loading || _done) && !force) return;
    setState(() => _loading = true);
    try {
      final page = await widget.session.api.feed(beforeId: _nextBeforeId);
      setState(() {
        _posts.addAll(page.posts);
        _nextBeforeId = page.nextBeforeId;
        _done = page.nextBeforeId == null;
      });
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _replace(Post updated) {
    final i = _posts.indexWhere((p) => p.id == updated.id);
    if (i >= 0) setState(() => _posts[i] = updated);
  }

  Future<void> _onAction(Post post, PostAction action) async {
    switch (action) {
      case PostAction.like:
        final updated = await _actions.toggleLike(context, post);
        if (updated != null) _replace(updated);
      case PostAction.comments:
        await _openPost(post);
      case PostAction.openPattern:
        await openSharedPattern(context, widget.store, post.pattern!);
      case PostAction.report:
        if (await _actions.report(context, post)) _refresh();
      case PostAction.block:
        if (await _actions.block(context, post)) _refresh();
      case PostAction.delete:
        if (await _actions.delete(context, post)) {
          setState(() => _posts.removeWhere((p) => p.id == post.id));
        }
    }
  }

  Future<void> _openPost(Post post) async {
    final result = await Navigator.of(context).push<Post?>(MaterialPageRoute(
      builder: (_) =>
          PostScreen(post: post, session: widget.session, store: widget.store),
    ));
    if (result == null) {
      // Postarea a fost ștearsă sau ascunsă din pagina ei.
      if (mounted) _refresh();
    } else {
      _replace(result);
    }
  }

  Future<void> _newPost() async {
    if (!await _actions.ensureLoggedIn(context) || !mounted) return;
    final created = await Navigator.of(context).push<Post>(MaterialPageRoute(
        builder: (_) => NewPostScreen(session: widget.session)));
    if (created != null) setState(() => _posts.insert(0, created));
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Text('Comunitate'),
          actions: [
            if (session.user?.isAdmin ?? false)
              IconButton(
                tooltip: 'Postări raportate',
                icon: const Icon(Icons.shield_outlined),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => AdminScreen(session: session))),
              ),
            if (session.loggedIn)
              PopupMenuButton<String>(
                tooltip: 'Contul meu',
                icon: const Icon(Icons.account_circle_outlined),
                onSelected: (_) => session.logout(),
                itemBuilder: (_) => [
                  PopupMenuItem(
                      enabled: false,
                      child: Text('Conectată: ${session.user!.displayName}')),
                  const PopupMenuItem(
                      value: 'logout', child: Text('Deconectează-te')),
                ],
              )
            else
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => LoginScreen(session: session))),
                child: const Text('Conectare'),
              ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _newPost,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Postează'),
        ),
        body: RefreshIndicator(onRefresh: _refresh, child: _body()),
      ),
    );
  }

  Widget _body() {
    if (_posts.isEmpty) {
      final Widget content;
      if (_loading) {
        content = const Center(child: CircularProgressIndicator());
      } else if (_error != null) {
        content = _Message(
          icon: Icons.cloud_off_outlined,
          text: _error!,
          action: FilledButton(
              onPressed: _refresh, child: const Text('Încearcă din nou')),
        );
      } else {
        content = const _Message(
          icon: Icons.forum_outlined,
          text:
              'Încă nu a postat nimeni. Fii prima: un sfat, un link sau un tipar!',
        );
      }
      // ListView ca să meargă „trage în jos ca să reîncarci” și pe ecranul gol.
      return ListView(children: [SizedBox(height: 420, child: content)]);
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.only(top: 6, bottom: 96),
      itemCount: _posts.length + 1,
      itemBuilder: (context, i) {
        if (i == _posts.length) {
          if (_error != null) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: TextButton(
                  onPressed: _loadMore, child: const Text('Încarcă mai multe')),
            );
          }
          return _done
              ? const SizedBox(height: 24)
              : const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
        }
        final post = _posts[i];
        return PostCard(
          post: post,
          api: widget.session.api,
          loggedIn: widget.session.loggedIn,
          isMine: widget.session.user?.id == post.author.id,
          onAction: (a) => _onAction(post, a),
        );
      },
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text(text, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}
