import 'package:flutter/material.dart';

import '../data/profile_store.dart';
import '../drawing/layout.dart';
import '../drawing/layout_painter.dart';
import '../garments/catalog.dart';
import '../garments/garment.dart';
import '../models/profile.dart';
import '../theme.dart';
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
              for (var i = 0; i < kGarments.length; i++)
                _GarmentCard(
                    garment: kGarments[i], profile: profile, accent: Accent.of(i)),
            ],
          ),
        );
      },
    );
  }
}

class _GarmentCard extends StatelessWidget {
  const _GarmentCard(
      {required this.garment, required this.profile, required this.accent});

  final Garment garment;
  final Profile profile;
  final Accent accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final draft = garment.draft(profile.values, garment.defaultOptions);
    final layout = PatternLayout.build(draft.pieces, seam: 0, hem: 0);
    final dark = theme.brightness == Brightness.dark;
    return Card(
      clipBehavior: Clip.antiAlias,
      color: dark ? null : Color.alphaBlend(accent.light.withAlpha(110), Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: accent.strong.withAlpha(90)),
      ),
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
                  color: accent.light,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: CustomPaint(
                  painter: LayoutPainter(
                    layout: layout,
                    color: accent.strong,
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
                    Text(garment.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                            color: dark ? null : accent.strong,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(garment.description),
                    const SizedBox(height: 4),
                    const SizedBox(height: 4),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: accent.strong,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('${draft.pieces.length} piese',
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: Colors.white)),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: accent.strong),
            ],
          ),
        ),
      ),
    );
  }
}
