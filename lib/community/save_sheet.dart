import 'package:flutter/material.dart';

import 'models.dart';
import 'session.dart';

/// Fereastra „Salvează în colecție”, ca pe Pinterest: bifezi colecțiile în
/// care vrei postarea sau faci una nouă. Întoarce dacă postarea a rămas
/// salvată undeva.
Future<bool?> showSaveSheet(BuildContext context, Session session, Post post) =>
    showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _SaveSheet(session: session, post: post),
    );

class _SaveSheet extends StatefulWidget {
  const _SaveSheet({required this.session, required this.post});

  final Session session;
  final Post post;

  @override
  State<_SaveSheet> createState() => _SaveSheetState();
}

class _SaveSheetState extends State<_SaveSheet> {
  List<PostCollection>? _collections;
  final Set<int> _inside = {};
  final Set<int> _busy = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list =
          await widget.session.api.myCollections(postId: widget.post.id);
      setState(() {
        _collections = list;
        _inside
          ..clear()
          ..addAll(list.where((c) => c.containsPost ?? false).map((c) => c.id));
      });
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  Future<void> _toggle(PostCollection c) async {
    final api = widget.session.api;
    final add = !_inside.contains(c.id);
    setState(() {
      _busy.add(c.id);
      add ? _inside.add(c.id) : _inside.remove(c.id);
    });
    try {
      add
          ? await api.savePost(c.id, widget.post.id)
          : await api.unsavePost(c.id, widget.post.id);
    } catch (e) {
      // Nu a mers: punem bifa înapoi cum era.
      setState(() => add ? _inside.remove(c.id) : _inside.add(c.id));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(c.id));
    }
  }

  Future<void> _create() async {
    final created = await showDialog<PostCollection>(
      context: context,
      builder: (_) => NewCollectionDialog(session: widget.session),
    );
    if (created == null) return;
    setState(() => _collections = [...?_collections, created]);
    await _toggle(created);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final list = _collections;
    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_inside.isNotEmpty);
      },
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text('Salvează în colecție',
                    style: theme.textTheme.titleLarge),
              ),
              if (_error != null)
                Padding(padding: const EdgeInsets.all(20), child: Text(_error!))
              else if (list == null)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      if (list.isEmpty)
                        const Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          child:
                              Text('Încă nu ai colecții. Fă prima, de exemplu '
                                  '„Rochii de vară” sau „Trucuri de cusut”.'),
                        ),
                      for (final c in list)
                        CheckboxListTile(
                          value: _inside.contains(c.id),
                          onChanged:
                              _busy.contains(c.id) ? null : (_) => _toggle(c),
                          title: Text(c.name),
                          subtitle: Text(c.isPublic ? 'Publică' : 'Privată'),
                          secondary: Icon(
                              c.isPublic ? Icons.public : Icons.lock_outline),
                        ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: list == null ? null : _create,
                        icon: const Icon(Icons.add),
                        label: const Text('Colecție nouă'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () =>
                            Navigator.of(context).pop(_inside.isNotEmpty),
                        child: const Text('Gata'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialogul pentru o colecție nouă: nume și dacă e publică.
class NewCollectionDialog extends StatefulWidget {
  const NewCollectionDialog({super.key, required this.session, this.existing});

  final Session session;

  /// Dacă e dată, dialogul o modifică în loc să facă una nouă.
  final PostCollection? existing;

  @override
  State<NewCollectionDialog> createState() => _NewCollectionDialogState();
}

class _NewCollectionDialogState extends State<NewCollectionDialog> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late bool _public = widget.existing?.isPublic ?? false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Dă un nume colecției');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final api = widget.session.api;
      final c = widget.existing == null
          ? await api.createCollection(name, isPublic: _public)
          : await api.updateCollection(widget.existing!.id,
              name: name, isPublic: _public);
      if (mounted) Navigator.of(context).pop(c);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title:
          Text(widget.existing == null ? 'Colecție nouă' : 'Modifică colecția'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            maxLength: 60,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: 'Nume', errorText: _error),
            onSubmitted: (_) => _save(),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _public,
            onChanged: (v) => setState(() => _public = v),
            title: const Text('Publică'),
            subtitle: Text(_public
                ? 'Apare pe profilul tău și o poate vedea oricine'
                : 'O vezi doar tu'),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Renunță')),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(widget.existing == null ? 'Creează' : 'Salvează'),
        ),
      ],
    );
  }
}
