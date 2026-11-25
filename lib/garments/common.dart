import 'dart:math' as math;

import '../geometry.dart';
import '../models/pattern.dart';

/// Pensă: două linii care pleacă din talie și se unesc în vârf.
/// [length] pozitiv = vârful în jos (fuste), negativ = în sus (corsaje).
List<Pt> dart(List<Pt> waist, double x, double width, double length) {
  final left = x - width / 2, right = x + width / 2;
  return [
    Pt(left, yAtX(waist, left)),
    Pt(x, yAtX(waist, x) + length),
    Pt(right, yAtX(waist, right)),
  ];
}

/// Piesă dreptunghiulară (cordon, bentiță), pliată pe lung la jumătate.
PatternPiece foldedStrip({
  required String name,
  required String cutInfo,
  required double length,
  required double width,
}) {
  final outline = <Segment>[
    LineSeg(const Pt(0, 0), Pt(length, 0)),
    LineSeg(Pt(length, 0), Pt(length, width)),
    LineSeg(Pt(length, width), Pt(0, width)),
    LineSeg(Pt(0, width), const Pt(0, 0)),
  ];
  return PatternPiece(
    name: name,
    cutInfo: cutInfo,
    outline: outline,
    markings: [
      [Pt(0, width / 2), Pt(length, width / 2)],
    ],
    grainFrom: Pt(length * 0.55, width * 0.75),
    grainTo: Pt(length * 0.9, width * 0.75),
    labelAt: const Pt(1.5, 0.5),
    canRotate: true,
  );
}

/// Cordon de talie: lungimea taliei + 1 cm lejeritate + 3 cm pentru suprapunere.
PatternPiece waistband(double waist) => foldedStrip(
      name: 'Cordon',
      cutInfo: 'Taie 1 · se pliază pe linia din mijloc',
      length: waist + 1 + 3,
      width: 8,
    );

/// Mânecă tăiată pe pliu, potrivită cu răscroiala. Înălțimea capului se caută automat astfel încât
/// jumătatea lui să aibă exact lungimea unei răscroieli.
({PatternPiece piece, double capLength, bool tooWide}) fittedSleeve({
  required double arm,
  required double ease,
  required double armholeLength,
  required double length,
  double minHemHalf = 9,
}) {
  final halfWidth = (arm + ease * 0.6) / 2;

  CubicSeg cap(double height) => CubicSeg(
        const Pt(0, 0),
        Pt(halfWidth * 0.45, 0),
        Pt(halfWidth * 0.6, height),
        Pt(halfWidth, height),
      );

  // Căutare binară: un cap mai înalt are o curbă mai lungă.
  var lo = 1.0, hi = 30.0;
  for (var i = 0; i < 40; i++) {
    final mid = (lo + hi) / 2;
    if (cap(mid).length < armholeLength) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  final capHeight = (lo + hi) / 2;
  final capSeg = cap(capHeight);
  final tooWide = capSeg.length < armholeLength - 0.5;

  final sleeveLength = math.max(length, capHeight + 3);
  // Mâneca se îngustează spre încheietură.
  final hemHalf = math.max(halfWidth - (sleeveLength - capHeight) * 0.12,
      math.max(halfWidth * 0.55, minHemHalf));
  final hemX = math.min(hemHalf, halfWidth);

  final piece = PatternPiece(
    name: 'Mânecă',
    cutInfo: 'Taie 2 pe pliu',
    copies: 2,
    outline: [
      capSeg,
      LineSeg(Pt(halfWidth, capHeight), Pt(hemX, sleeveLength)),
      LineSeg(Pt(hemX, sleeveLength), Pt(0, sleeveLength), EdgeKind.hem),
      LineSeg(Pt(0, sleeveLength), const Pt(0, 0), EdgeKind.fold),
    ],
    grainFrom: Pt(hemX * 0.8, capHeight + 0.5),
    grainTo: Pt(hemX * 0.8, sleeveLength - 1),
    labelAt: Pt(1.5, capHeight + 0.5),
  );
  return (piece: piece, capLength: capSeg.length, tooWide: tooWide);
}
