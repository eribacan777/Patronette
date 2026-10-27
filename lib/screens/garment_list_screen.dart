import 'package:flutter/material.dart';

import '../data/profile_store.dart';
import '../drawing/layout.dart';
import '../drawing/layout_painter.dart';
import '../garments/catalog.dart';
import '../garments/garment.dart';
import '../models/profile.dart';
import 'pattern_screen.dart';

/// Lista modelelor; fiecare are o miniatură desenată chiar pe măsurile profilului.
class GarmentListScreen extends StatelessWidget {
  const GarmentListScreen(
      {super.key, required this.store, required this.profileId});

  final ProfileStore store;
  final String profileId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final profile = store.byId(profileId);
        if (profile == null) {
          return const Scaffold(body: Center(child: Text('Profil șters.')));
        }
        return Scaffold(
          appBar: AppBar(title: Text('Modele pentru ${profile.name}')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final g in kGarments) _GarmentCard(garment: g, profile: profile),
            ],
          ),
        );
      },
    );
  }
}

class _GarmentCard extends StatelessWidget {
  const _GarmentCard({required this.garment, required this.profile});

  final Garment garment;
  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final draft = garment.draft(profile.values, garment.defaultOptions);
    final layout = PatternLayout.build(draft.pieces, seam: 0, hem: 0);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PatternScreen(garment: garment, profile: profile),
        )),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 96,
                height: 96,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: CustomPaint(
                  painter: LayoutPainter(
                    layout: layout,
                    color: theme.colorScheme.onSurfaceVariant,
                    showText: false,
                    showGrid: false,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(garment.name, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(garment.description),
                    const SizedBox(height: 4),
                    Text('${draft.pieces.length} piese',
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
