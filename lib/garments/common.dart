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
  );
}

/// Cordon de talie: lungimea taliei + 1 cm lejeritate + 3 cm pentru suprapunere.
PatternPiece waistband(double waist) => foldedStrip(
      name: 'Cordon',
      cutInfo: 'Taie 1 · se pliază pe linia din mijloc',
      length: waist + 1 + 3,
      width: 8,
    );
