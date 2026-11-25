import 'package:flutter/material.dart';

import 'models.dart';
import 'session.dart';

/// Panoul administratoarelor: postările raportate, cu motivele.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key, required this.session});

  final Session session;

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<ReportedPost>? _reports;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await widget.session.api.reportedPosts();
      setState(() {
        _reports = r;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  Future<void> _decide(ReportedPost r, {required bool hide}) async {
    try {
      hide
          ? await widget.session.api.hidePost(r.post.id)
          : await widget.session.api.restorePost(r.post.id);
      setState(() => _reports!.remove(r));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Widget body;
    if (_error != null) {
      body = Center(child: Text(_error!));
    } else if (_reports == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_reports!.isEmpty) {
      body = const Center(
          child: Text('Nicio postare raportată. Totul e în regulă!'));
    } else {
      body = ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final r in _reports!)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        '${r.post.author.displayName} · ${r.reportCount} raportări',
                        style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Text(r.post.text,
                        maxLines: 6, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    for (final reason in r.reasons)
                      Text('• $reason',
                          style: TextStyle(color: theme.colorScheme.error)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => _decide(r, hide: false),
                          child: const Text('E în regulă'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () => _decide(r, hide: true),
                          child: const Text('Ascunde'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Postări raportate')),
      body: RefreshIndicator(onRefresh: _load, child: body),
    );
  }
}
