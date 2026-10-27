import 'dart:math' as math;

import '../geometry.dart';
import '../models/pattern.dart';

/// O piesă așezată pe planșă: liniile ei sunt deja mutate la locul lor.
class PlacedPiece {
  PlacedPiece(this.piece, this.shift, this.seamLine, this.cutLine)
      : bounds = Bounds.of(cutLine);

  final PatternPiece piece;

  /// Cât s-a mutat piesa față de coordonatele ei originale.
  final Pt shift;
  final List<Pt> seamLine;
  final List<Pt> cutLine;
  final Bounds bounds;

  Pt map(Pt p) => p + shift;
}

/// Așază piesele pe rânduri, una lângă alta, ca pe o masă de croit.
class PatternLayout {
  PatternLayout._(this.placed, this.width, this.height, this.seam, this.hem);

  /// Spațiul dintre piese, în cm.
  static const gap = 3.0;

  factory PatternLayout.build(
    List<PatternPiece> pieces, {
    required double seam,
    required double hem,
    double maxRowWidth = 57,
  }) {
    final cuts = [for (final p in pieces) p.cutLine(seam: seam, hem: hem)];
    final boxes = [for (final c in cuts) Bounds.of(c)];
    final rowLimit = math.max(
        maxRowWidth, boxes.fold<double>(0, (w, b) => math.max(w, b.width)));

    final placed = <PlacedPiece>[];
    var x = gap, y = gap, rowHeight = 0.0, width = 0.0;
    for (var i = 0; i < pieces.length; i++) {
      final b = boxes[i];
      if (x > gap && x + b.width > rowLimit + gap) {
        // Nu mai încape pe rândul ăsta: trecem pe rândul următor.
        y += rowHeight + gap;
        x = gap;
        rowHeight = 0;
      }
      final shift = Pt(x - b.minX, y - b.minY);
      placed.add(PlacedPiece(
        pieces[i],
        shift,
        [for (final p in pieces[i].seamLine) p + shift],
        [for (final p in cuts[i]) p + shift],
      ));
      x += b.width + gap;
      rowHeight = math.max(rowHeight, b.height);
      width = math.max(width, x);
    }
    return PatternLayout._(placed, width, y + rowHeight + gap, seam, hem);
  }

  final List<PlacedPiece> placed;
  final double width;
  final double height;
  final double seam;
  final double hem;

  bool get hasAllowance => seam > 0 || hem > 0;
}
