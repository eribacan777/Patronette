import 'dart:math' as math;

import 'package:croi/drawing/layout.dart';
import 'package:croi/export/tiles.dart';
import 'package:croi/garments/catalog.dart';
import 'package:croi/garments/circle_skirt.dart';
import 'package:croi/garments/straight_skirt.dart';
import 'package:croi/geometry.dart';
import 'package:croi/models/measurements.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Rezerva de cusătură', () {
    final square = <Segment>[
      const LineSeg(Pt(0, 0), Pt(10, 0)),
      const LineSeg(Pt(10, 0), Pt(10, 10)),
      const LineSeg(Pt(10, 10), Pt(0, 10), EdgeKind.hem),
      const LineSeg(Pt(0, 10), Pt(0, 0), EdgeKind.fold),
    ];

    test('mută fiecare latură cu rezerva ei', () {
      final cut = offsetOutline(square, (k) => switch (k) {
            EdgeKind.seam => 1.0,
            EdgeKind.hem => 3.0,
            EdgeKind.fold => 0.0,
          });
      final b = Bounds.of(cut);
      expect(b.minX, closeTo(0, 1e-9)); // pe pliu: fără rezervă
      expect(b.minY, closeTo(-1, 1e-9));
      expect(b.maxX, closeTo(11, 1e-9));
      expect(b.maxY, closeTo(13, 1e-9)); // tiv de 3 cm
    });

    test('funcționează în ambele sensuri de parcurgere', () {
      final reversed = [
        for (final s in square.reversed)
          LineSeg((s as LineSeg).b, s.a, s.kind),
      ];
      final b = Bounds.of(offsetOutline(reversed, (_) => 1.0));
      expect(b.width, closeTo(12, 1e-9));
      expect(b.height, closeTo(12, 1e-9));
    });
  });

  group('Fustă cloș', () {
    for (final type in [1.0, 0.5]) {
      test('talia cusută are exact măsura taliei (tip $type)', () {
        const skirt = CircleSkirt();
        final draft = skirt.draft({'talie': 72}, {'tip': type, 'lungime': 50});
        final waistArc = draft.pieces.first.outline.last;
        // 2 piese pe pliu = 4 jumătăți de arc.
        expect(waistArc.length * 4, closeTo(72, 0.05));
      });
    }
  });

  group('Fustă dreaptă', () {
    test('talia minus pense = sfertul de talie', () {
      const skirt = StraightSkirt();
      final m = Map.of(kExampleMeasurements);
      final draft = skirt.draft(m, skirt.defaultOptions);
      final front = draft.pieces.first;
      final waistLen = front.outline.first.length;
      final darts = front.markings
          .fold<double>(0, (sum, d) => sum + d.first.distanceTo(d.last));
      expect(waistLen - darts, closeTo((m['talie']! + 1) / 4, 0.4));
    });

    test('lățimea la șold = sfertul de șold cu lărgime', () {
      const skirt = StraightSkirt();
      final draft = skirt.draft(kExampleMeasurements, {'largime': 4});
      final b = Bounds.of(draft.pieces.first.seamLine);
      expect(b.maxX, closeTo((kExampleMeasurements['sold']! + 4) / 4, 1e-6));
    });
  });

  test('mâneca tricoului se potrivește în răscroială', () {
    final tshirt = kGarments.firstWhere((g) => g.id == 'tricou');
    final draft = tshirt.draft(kExampleMeasurements, tshirt.defaultOptions);
    final armhole = draft.pieces.first.outline[2].length;
    final sleeveCap = draft.pieces[2].outline.first.length;
    expect(sleeveCap, closeTo(armhole, 0.1));
  });

  test('toate modelele dau contururi valide, și la măsuri extreme', () {
    final sets = [
      kExampleMeasurements,
      {for (final d in kMeasurements) d.key: d.min},
      {for (final d in kMeasurements) d.key: d.max},
    ];
    for (final g in kGarments) {
      for (final m in sets) {
        final draft = g.draft(m, g.defaultOptions);
        expect(draft.pieces, isNotEmpty, reason: g.name);
        for (final p in draft.pieces) {
          final cut = p.cutLine(seam: 1, hem: 2);
          for (final pt in cut) {
            expect(pt.x.isFinite && pt.y.isFinite, isTrue,
                reason: '${g.name} / ${p.name}');
          }
          // Linia de tăiere trebuie să fie mai mare decât cea de cusătură.
          expect(signedArea(cut).abs(), greaterThan(signedArea(p.seamLine).abs()),
              reason: '${g.name} / ${p.name}');
          // Conturul trebuie să fie închis.
          expect(p.outline.last.end.distanceTo(p.outline.first.start),
              lessThan(1e-6),
              reason: '${g.name} / ${p.name}');
        }
      }
    }
  });

  test('piesele nu se suprapun pe planșă și paginile se numără corect', () {
    for (final g in kGarments) {
      final draft = g.draft(kExampleMeasurements, g.defaultOptions);
      final layout = PatternLayout.build(draft.pieces, seam: 1, hem: 2);
      for (var i = 0; i < layout.placed.length; i++) {
        for (var j = i + 1; j < layout.placed.length; j++) {
          expect(layout.placed[i].bounds.intersects(layout.placed[j].bounds),
              isFalse,
              reason: g.name);
        }
      }
      final grid = TileGrid(layout);
      expect(grid.usedCount, inInclusiveRange(1, grid.rows * grid.cols));
      expect(math.max(grid.cols, grid.rows), lessThan(12), reason: g.name);
    }
  });
}
