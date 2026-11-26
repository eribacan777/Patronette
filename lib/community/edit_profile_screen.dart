import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'avatar.dart';
import 'models.dart';
import 'session.dart';

/// Editarea profilului: poză, nume și descriere. Întoarce profilul nou.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen(
      {super.key, required this.session, required this.profile});

  final Session session;
  final UserProfile profile;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.profile.displayName);
  late final _bio = TextEditingController(text: widget.profile.bio);
  late UserProfile _profile = widget.profile;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  void _snack(Object s) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$s')));
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(
          source: source, maxWidth: 1200, maxHeight: 1200, imageQuality: 85);
      if (file == null) return;
      setState(() => _busy = true);
      final updated = await widget.session.api
          .setAvatar(await file.readAsBytes(), file.name);
      setState(() => _profile = updated);
      await widget.session.updateUser(updated.asUser);
    } catch (e) {
      _snack(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removePhoto() async {
    setState(() => _busy = true);
    try {
      final updated = await widget.session.api.deleteAvatar();
      setState(() => _profile = updated);
      await widget.session.updateUser(updated.asUser);
    } catch (e) {
      _snack(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _photoMenu() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Alege din galerie'),
            onTap: () => Navigator.pop(ctx, 'gallery'),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Fă o poză'),
            onTap: () => Navigator.pop(ctx, 'camera'),
          ),
          if (_profile.avatarUrl != null)
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Scoate poza'),
              onTap: () => Navigator.pop(ctx, 'remove'),
            ),
        ]),
      ),
    );
    switch (choice) {
      case 'gallery':
        await _pickPhoto(ImageSource.gallery);
      case 'camera':
        await _pickPhoto(ImageSource.camera);
      case 'remove':
        await _removePhoto();
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final updated = await widget.session.api
          .updateMe(displayName: _name.text.trim(), bio: _bio.text.trim());
      await widget.session.updateUser(updated.asUser);
      if (mounted) Navigator.of(context).pop(updated);
    } catch (e) {
      _snack(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<UserProfile>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        // Poza se salvează imediat: întoarcem profilul nou și fără „Salvează”.
        if (!didPop) Navigator.of(context).pop(_profile);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Editează profilul'),
          actions: [
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: _busy ? null : _save,
              child: const Text('Salvează'),
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: Stack(
                  children: [
                    UserAvatar(
                        user: _profile.asUser,
                        api: widget.session.api,
                        radius: 56),
                    if (_busy)
                      const Positioned.fill(
                          child: Center(child: CircularProgressIndicator())),
                  ],
                ),
              ),
              Center(
                child: TextButton(
                  onPressed: _busy ? null : _photoMenu,
                  child: const Text('Schimbă poza de profil'),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                maxLength: 40,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nume'),
                validator: (v) => (v ?? '').trim().length < 2
                    ? 'Cel puțin 2 caractere'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bio,
                maxLength: 300,
                minLines: 3,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Despre tine',
                  hintText:
                      'De exemplu: cos de doi ani, îmi plac rochiile de in.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
