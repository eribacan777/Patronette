import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../garments/catalog.dart';
import 'models.dart';
import 'session.dart';

/// Postare nouă: text, link opțional, poză opțională și, dacă vine din
/// ecranul tiparului, tiparul atașat.
class NewPostScreen extends StatefulWidget {
  const NewPostScreen({super.key, required this.session, this.pattern});

  final Session session;
  final SharedPattern? pattern;

  @override
  State<NewPostScreen> createState() => _NewPostScreenState();
}

class _NewPostScreenState extends State<NewPostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _text = TextEditingController();
  final _link = TextEditingController();
  late SharedPattern? _pattern = widget.pattern;
  Uint8List? _image;
  String? _imageName;
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      // Telefonul micșorează poza înainte de trimitere: încarcă mai repede.
      final file = await ImagePicker().pickImage(
          source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 85);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _image = bytes;
        _imageName = file.name;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Nu am putut deschide poza: $e')));
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final post = await widget.session.api.createPost(
        text: _text.text.trim(),
        linkUrl: _link.text.trim(),
        pattern: _pattern,
        imageBytes: _image,
        imageName: _imageName,
      );
      if (mounted) Navigator.of(context).pop(post);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final garment = _pattern == null
        ? null
        : kGarments.where((g) => g.id == _pattern!.garmentId).firstOrNull;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Postare nouă'),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Publică'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _text,
              autofocus: true,
              minLines: 4,
              maxLines: 12,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText:
                    'Un sfat, un truc, o întrebare sau povestea hainei tale…',
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Scrie ceva în postare' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _link,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Link (opțional)',
                hintText: 'https://…',
                prefixIcon: Icon(Icons.link),
              ),
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.isEmpty) return null;
                return RegExp(r'^https?://\S+\.\S+$').hasMatch(s)
                    ? null
                    : 'Link-ul trebuie să înceapă cu http:// sau https://';
              },
            ),
            const SizedBox(height: 16),
            if (_image != null)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.memory(_image!,
                        height: 240, width: double.infinity, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton.filled(
                      tooltip: 'Scoate poza',
                      onPressed: () => setState(() => _image = null),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Din galerie'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Fă o poză'),
                    ),
                  ),
                ],
              ),
            if (_pattern != null) ...[
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.content_cut),
                  title: Text(
                      'Tipar atașat: ${garment?.name ?? _pattern!.garmentId}'),
                  subtitle: const Text(
                      'Se distribuie modelul și setările, nu măsurile tale. Cine îl '
                      'deschide îl vede pe măsurile ei.'),
                  trailing: IconButton(
                    tooltip: 'Scoate tiparul',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _pattern = null),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Postările sunt publice. Fii prietenoasă: postările raportate de mai '
              'multe persoane sunt ascunse până le verifică o administratoare.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
