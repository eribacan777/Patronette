import 'package:flutter/material.dart';

import '../data/profile_store.dart';
import 'community.dart';
import 'models.dart';
import 'post_actions.dart';
import 'post_card.dart';
import 'session.dart';

/// O postare cu toate comentariile ei. Întoarce postarea actualizată (sau
/// null dacă a fost ștearsă), ca lista să se poată actualiza.
class PostScreen extends StatefulWidget {
  const PostScreen(
      {super.key,
      required this.post,
      required this.session,
      required this.store});

  final Post post;
  final Session session;
  final ProfileStore store;

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  late final PostActions _actions = PostActions(widget.session);
  late Post _post = widget.post;
  final _input = TextEditingController();
  List<Comment>? _comments;
  String? _error;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final comments = await widget.session.api.comments(_post.id);
      setState(() {
        _comments = comments;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    if (!await _actions.ensureLoggedIn(context)) return;
    setState(() => _sending = true);
    try {
      final c = await widget.session.api.addComment(_post.id, text);
      _input.clear();
      setState(() {
        _comments = [...?_comments, c];
        _post = _post.copyWith(commentCount: _post.commentCount + 1);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _deleteComment(Comment c) async {
    try {
      await widget.session.api.deleteComment(c.id);
      setState(() {
        _comments = _comments!.where((x) => x.id != c.id).toList();
        _post = _post.copyWith(commentCount: _post.commentCount - 1);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _onAction(PostAction action) async {
    final nav = Navigator.of(context);
    switch (action) {
      case PostAction.like:
        final updated = await _actions.toggleLike(context, _post);
        if (updated != null) setState(() => _post = updated);
      case PostAction.comments:
        break;
      case PostAction.openPattern:
        await openSharedPattern(context, widget.store, _post.pattern!);
      case PostAction.report:
        if (await _actions.report(context, _post)) nav.pop(null);
      case PostAction.block:
        if (await _actions.block(context, _post)) nav.pop(null);
      case PostAction.delete:
        if (await _actions.delete(context, _post)) nav.pop(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope<Post?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_post);
      },
      child: Scaffold(
        appBar: AppBar(title: Text('Postarea lui ${_post.author.displayName}')),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  PostCard(
                    post: _post,
                    api: widget.session.api,
                    loggedIn: widget.session.loggedIn,
                    isMine: widget.session.user?.id == _post.author.id,
                    onAction: _onAction,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child:
                        Text('Comentarii', style: theme.textTheme.titleMedium),
                  ),
                  if (_error != null)
                    ListTile(
                      title: Text(_error!),
                      trailing: TextButton(
                          onPressed: _load, child: const Text('Reîncearcă')),
                    )
                  else if (_comments == null)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_comments!.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Niciun comentariu încă. Scrie tu primul!'),
                    )
                  else
                    for (final c in _comments!)
                      ListTile(
                        title: Text(c.author.displayName,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(c.text),
                        isThreeLine: c.text.length > 40,
                        trailing: c.canDelete
                            ? IconButton(
                                tooltip: 'Șterge comentariul',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _deleteComment(c),
                              )
                            : Text(timeAgo(c.createdAt),
                                style: theme.textTheme.bodySmall),
                      ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        maxLength: 1000,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                            hintText: 'Scrie un comentariu…', counterText: ''),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Trimite',
                      onPressed: _sending ? null : _send,
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
