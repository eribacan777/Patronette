import 'package:flutter/material.dart';

import 'api.dart';
import 'login_screen.dart';
import 'models.dart';
import 'save_sheet.dart';
import 'session.dart';

/// Acțiunile pe o postare, folosite și în listă, și în pagina postării.
class PostActions {
  PostActions(this.session);

  final Session session;
  CommunityApi get api => session.api;

  void _error(BuildContext context, Object e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
  }

  /// Cere login dacă e nevoie. Întoarce true dacă utilizatoarea e conectată.
  Future<bool> ensureLoggedIn(BuildContext context) async {
    if (session.loggedIn) return true;
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => LoginScreen(session: session)));
    return session.loggedIn;
  }

  /// Salvează postarea în colecții. Întoarce postarea actualizată, sau null
  /// dacă nu s-a schimbat nimic.
  Future<Post?> save(BuildContext context, Post post) async {
    if (!await ensureLoggedIn(context) || !context.mounted) return null;
    final saved = await showSaveSheet(context, session, post);
    if (saved == null || saved == post.savedByMe) return null;
    return post.copyWith(savedByMe: saved);
  }

  /// Apreciază sau retrage aprecierea. Întoarce postarea actualizată, sau
  /// null dacă nu s-a schimbat nimic.
  Future<Post?> toggleLike(BuildContext context, Post post) async {
    if (!await ensureLoggedIn(context)) return null;
    final liked = !post.likedByMe;
    try {
      liked ? await api.like(post.id) : await api.unlike(post.id);
      return post.copyWith(
          likedByMe: liked, likeCount: post.likeCount + (liked ? 1 : -1));
    } catch (e) {
      if (context.mounted) _error(context, e);
      return null;
    }
  }

  Future<bool> report(BuildContext context, Post post) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Raportează postarea'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 300,
          decoration: const InputDecoration(
              hintText:
                  'De ce? De exemplu: reclamă, jignire, conținut nepotrivit'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Renunță')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Trimite'),
          ),
        ],
      ),
    );
    if (reason == null || !context.mounted) return false;
    if (reason.length < 3) {
      _error(context, 'Scrie pe scurt motivul (cel puțin 3 litere).');
      return false;
    }
    try {
      await api.report(post.id, reason);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Mulțumim! Administratoarele vor verifica postarea.')));
      }
      return true;
    } catch (e) {
      if (context.mounted) _error(context, e);
      return false;
    }
  }

  Future<bool> block(BuildContext context, Post post) async {
    final ok = await _confirm(
      context,
      'O blochezi pe ${post.author.displayName}?',
      'Nu îi vei mai vedea postările și comentariile.',
      'Blochează',
    );
    if (!ok || !context.mounted) return false;
    try {
      await api.block(post.author.id);
      return true;
    } catch (e) {
      if (context.mounted) _error(context, e);
      return false;
    }
  }

  Future<bool> delete(BuildContext context, Post post) async {
    final ok = await _confirm(context, 'Ștergi postarea?',
        'Postarea și comentariile ei dispar definitiv.', 'Șterge');
    if (!ok || !context.mounted) return false;
    try {
      await api.deletePost(post.id);
      return true;
    } catch (e) {
      if (context.mounted) _error(context, e);
      return false;
    }
  }

  static Future<bool> _confirm(
      BuildContext context, String title, String body, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Renunță')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true), child: Text(action)),
        ],
      ),
    );
    return ok == true;
  }
}
