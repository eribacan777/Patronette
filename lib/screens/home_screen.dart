import 'package:flutter/material.dart';

import '../data/profile_store.dart';
import '../models/profile.dart';
import '../theme.dart';
import 'garment_list_screen.dart';
import 'measure_guide_screen.dart';
import 'profile_edit_screen.dart';

/// Primul ecran: lista profilurilor de măsuri.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.store});

  final ProfileStore store;

  void _edit(BuildContext context, Profile? profile) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProfileEditScreen(store: store, profile: profile),
    ));
  }

  Future<void> _delete(BuildContext context, Profile profile) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ștergi profilul?'),
        content: Text('Măsurile pentru „${profile.name}” se vor pierde.'),
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
    if (ok == true) await store.delete(profile.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patronette'),
        actions: [
          IconButton(
            icon: const Icon(Icons.straighten),
            tooltip: 'Ghid de măsurare',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const MeasureGuideScreen())),
          ),
        ],
      ),
      // Pe ecranul gol există deja butonul mare din mijloc.
      floatingActionButton: ListenableBuilder(
        listenable: store,
        builder: (context, _) => store.profiles.isEmpty
            ? const SizedBox.shrink()
            : FloatingActionButton.extended(
                onPressed: () => _edit(context, null),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Profil nou'),
              ),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          if (!store.loaded) {
            return const Center(child: CircularProgressIndicator());
          }
          final profiles = store.profiles;
          if (store.loadError != null && profiles.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                    'Nu am putut citi profilurile salvate:\n${store.loadError}'),
              ),
            );
          }
          if (profiles.isEmpty) {
            return _Welcome(onStart: () => _edit(context, null));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              const _Banner(),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('Alege pentru cine croiești',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              for (final (i, p) in profiles.indexed)
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                        backgroundColor: Accent.of(i).strong,
                        foregroundColor: Colors.white,
                        child: Text(p.name.isEmpty
                            ? '?'
                            : p.name.characters.first.toUpperCase())),
                    title: Text(p.name),
                    subtitle: Text(_summary(p)),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) =>
                          GarmentListScreen(store: store, profileId: p.id),
                    )),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) =>
                          v == 'edit' ? _edit(context, p) : _delete(context, p),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Editează')),
                        PopupMenuItem(value: 'delete', child: Text('Șterge')),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  static String _summary(Profile p) {
    String v(String key) => p.values[key]?.toStringAsFixed(0) ?? '–';
    return 'Bust ${v('bust')} · Talie ${v('talie')} · Șold ${v('sold')}';
  }
}

/// Banda de sus cu fetița, pe fundal roz, deasupra listei de profiluri.
class _Banner extends StatelessWidget {
  const _Banner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [PatronetteColors.roseLight, PatronetteColors.honeyLight],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset('assets/logo/patronette.png', width: 84),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bine ai venit!',
                    style: theme.textTheme.titleLarge?.copyWith(
                        color: PatronetteColors.rose,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Tipare croite pe măsurile tale, gata de printat.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: PatronetteColors.ink)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget step(IconData icon, String text, Accent a) => ListTile(
          leading: CircleAvatar(
            backgroundColor: a.light,
            child: Icon(icon, color: a.strong),
          ),
          title: Text(text),
        );
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            children: [
              Image.asset('assets/logo/patronette.png', width: 160),
              const SizedBox(height: 16),
              Text('Tipare pe măsurile tale',
                  style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              step(Icons.straighten, '1. Ia-ți măsurile, după ghid', Accent.of(0)),
              step(Icons.checkroom, '2. Alege un model de haină', Accent.of(1)),
              step(Icons.print, '3. Printează tiparul la scară reală', Accent.of(2)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Adaugă primul profil'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
