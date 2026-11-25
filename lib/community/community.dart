import 'package:flutter/material.dart';

import '../data/profile_store.dart';
import '../garments/catalog.dart';
import '../models/measurements.dart';
import '../models/profile.dart';
import '../screens/pattern_screen.dart';
import '../screens/profile_edit_screen.dart';
import 'api.dart';
import 'models.dart';
import 'session.dart';

/// Sesiunea comunității, una pentru toată aplicația. Se creează la prima
/// folosire; `main` o restaurează la pornire.
final Session communitySession = Session(CommunityApi());

/// Data unei postări, pe înțelesul oricui: „acum 5 min”, „ieri”, „3 mar.”.
String timeAgo(DateTime t, {DateTime? now}) {
  final d = (now ?? DateTime.now()).difference(t);
  if (d.inMinutes < 1) return 'chiar acum';
  if (d.inMinutes < 60) return 'acum ${d.inMinutes} min';
  if (d.inHours < 24) {
    return d.inHours == 1 ? 'acum o oră' : 'acum ${d.inHours} ore';
  }
  if (d.inDays == 1) return 'ieri';
  if (d.inDays < 7) return 'acum ${d.inDays} zile';
  const months = [
    'ian.',
    'feb.',
    'mar.',
    'apr.',
    'mai',
    'iun.',
    'iul.',
    'aug.',
    'sept.',
    'oct.',
    'nov.',
    'dec.'
  ];
  final sameYear = t.year == (now ?? DateTime.now()).year;
  return '${t.day} ${months[t.month - 1]}${sameYear ? '' : ' ${t.year}'}';
}

/// Deschide un tipar distribuit pe măsurile unui profil ales de utilizatoare.
Future<void> openSharedPattern(
    BuildContext context, ProfileStore store, SharedPattern pattern) async {
  final messenger = ScaffoldMessenger.of(context);
  final matches = kGarments.where((g) => g.id == pattern.garmentId);
  if (matches.isEmpty) {
    messenger.showSnackBar(const SnackBar(
        content: Text(
            'Modelul acesta nu există în versiunea ta. Actualizează aplicația.')));
    return;
  }
  final garment = matches.first;
  if (store.profiles.isEmpty) {
    messenger.showSnackBar(const SnackBar(
        content: Text(
            'Adaugă întâi un profil cu măsurile tale, din ecranul de start.')));
    return;
  }

  final chosen = store.profiles.length == 1
      ? store.profiles.first
      : await showModalBottomSheet<Profile>(
          context: context,
          showDragHandle: true,
          builder: (ctx) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                const ListTile(title: Text('Pe măsurile cui deschid tiparul?')),
                for (final p in store.profiles)
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text(p.name),
                    onTap: () => Navigator.pop(ctx, p),
                  ),
              ],
            ),
          ),
        );
  if (chosen == null || !context.mounted) return;

  var profile = chosen;
  final missing = garment.missingMeasurements(profile.values);
  if (missing.isNotEmpty) {
    final labels =
        missing.map((k) => measurementDef(k).label.toLowerCase()).join(', ');
    messenger.showSnackBar(
        SnackBar(content: Text('Pentru acest model mai trebuie: $labels.')));
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProfileEditScreen(
          store: store, profile: profile, neededKeys: missing.toSet()),
    ));
    final updated = store.byId(profile.id);
    if (updated == null ||
        garment.missingMeasurements(updated.values).isNotEmpty) {
      return;
    }
    profile = updated;
  }
  if (!context.mounted) return;
  await Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => PatternScreen(
        garment: garment, profile: profile, initialOptions: pattern.options),
  ));
}
