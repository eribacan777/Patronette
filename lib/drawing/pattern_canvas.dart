import '../format.dart';
import '../geometry.dart';
import 'layout.dart';

/// O „foaie” pe care se poate desena tiparul, în centimetri.
///
/// Există două implementări: una pentru ecranul telefonului și una pentru
/// PDF. Astfel tiparul se desenează o singură dată, cu același cod.
abstract class PatternCanvas {
  /// [width] este grosimea liniei, în puncte tipografice (1 pt ≈ 0,35 mm).
  void polyline(List<Pt> pts,
      {bool closed = false,
      double width = 0.6,
      bool dashed = false,
      bool faint = false});

  /// [topLeft] este colțul din stânga sus al textului; [size] este în puncte.
  void text(String s, Pt topLeft, {double size = 9, bool bold = false});
}

/// Desenează toate piesele: linii de tăiere și cusătură, pense, fir, text.
void drawLayout(PatternCanvas c, PatternLayout layout,
    {String footer = '', bool showText = true}) {
  for (final p in layout.placed) {
    _drawPiece(c, layout, p, footer, showText);
  }
}

void _drawPiece(PatternCanvas c, PatternLayout layout, PlacedPiece p,
    String footer, bool showText) {
  final piece = p.piece;
  if (layout.hasAllowance) {
    // Linia continuă: pe aici se taie. Linia punctată: pe aici se coase.
    c.polyline(p.cutLine, closed: true, width: 1.2);
    c.polyline(p.seamLine, closed: true, width: 0.5, dashed: true);
  } else {
    c.polyline(p.seamLine, closed: true, width: 1.2);
  }

  for (final m in piece.markings) {
    c.polyline([for (final pt in m) p.map(pt)], width: 0.7);
  }

  _grainLine(c, p.map(piece.grainFrom), p.map(piece.grainTo));

  final area = signedArea(p.seamLine);
  for (final edge in piece.foldEdges) {
    _foldMark(c, p.map(edge.start), p.map(edge.end), area, showText);
  }

  if (!showText) return;
  var at = p.map(piece.labelAt);
  void line(String s, double size, {bool bold = false}) {
    c.text(s, at, size: size, bold: bold);
    at = at + Pt(0, size * 0.0353 * 1.4); // puncte → cm, cu spațiu între rânduri
  }

  line(piece.name, 14, bold: true);
  line(piece.cutInfo, 11);
  if (footer.isNotEmpty) line(footer, 8);
  if (layout.hasAllowance) {
    line(
        'Rezervă inclusă: ${fmtCm(layout.seam)} cm, tiv ${fmtCm(layout.hem)} cm',
        8);
  } else {
    line('Fără rezervă de cusătură: adaug-o la tăiere', 8);
  }
}

/// Săgeata firului drept: se așază paralel cu marginea țesăturii.
void _grainLine(PatternCanvas c, Pt a, Pt b) {
  final u = (b - a).unit;
  final v = Pt(-u.y, u.x);
  c.polyline([a, b], width: 0.8);
  c.polyline([b - u * 0.8 + v * 0.35, b, b - u * 0.8 - v * 0.35], width: 0.8);
  c.polyline([a + u * 0.8 + v * 0.35, a, a + u * 0.8 - v * 0.35], width: 0.8);
}

/// Semnul „pe pliu”: o paranteză cu săgeți spre marginea de pe îndoitură.
void _foldMark(PatternCanvas c, Pt start, Pt end, double area, bool showText) {
  final e = (end - start).unit;
  final inward = outwardNormal(e, area) * -1;
  final len = start.distanceTo(end);
  final a = start + e * (len * 0.2);
  final b = start + e * (len * 0.8);
  const depth = 1.5;
  c.polyline([a, a + inward * depth, b + inward * depth, b], width: 0.7);
  for (final tip in [a + inward * 0.15, b + inward * 0.15]) {
    c.polyline(
        [tip + inward * 0.6 + e * 0.3, tip, tip + inward * 0.6 - e * 0.3],
        width: 0.7);
  }
  if (showText) {
    final mid = start + e * (len * 0.5) + inward * (depth + 0.4);
    c.text('PE PLIU', mid, size: 9, bold: true);
  }
}
