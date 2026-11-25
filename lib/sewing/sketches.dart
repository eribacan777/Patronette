import 'dart:math' as math;

import '../drawing/pattern_canvas.dart';
import '../geometry.dart';

/// Desenele simple care însoțesc pașii de coasere. Fiecare arată o singură
/// operație, cu linia punctată acolo unde se coase.
enum Sketch {
  finishEdges,
  seam,
  press,
  dart,
  zipper,
  waistband,
  hem,
  elasticCasing,
  setSleeve,
  sideSeam,
  neckband,
  crotchSeam,
  buttonLoop,
  belt,
}

/// Lățimea și înălțimea cutiei în care se desenează o schiță (unități
/// oarecare; ecranul și PDF-ul le scalează).
const sketchWidth = 10.0;
const sketchHeight = 6.0;

void drawSketch(PatternCanvas c, Sketch s) {
  switch (s) {
    case Sketch.finishEdges:
      _finishEdges(c);
    case Sketch.seam:
      _seam(c);
    case Sketch.press:
      _press(c);
    case Sketch.dart:
      _dart(c);
    case Sketch.zipper:
      _zipper(c);
    case Sketch.waistband:
      _waistband(c);
    case Sketch.hem:
      _hem(c);
    case Sketch.elasticCasing:
      _elasticCasing(c);
    case Sketch.setSleeve:
      _setSleeve(c);
    case Sketch.sideSeam:
      _sideSeam(c);
    case Sketch.neckband:
      _neckband(c);
    case Sketch.crotchSeam:
      _crotchSeam(c);
    case Sketch.buttonLoop:
      _buttonLoop(c);
    case Sketch.belt:
      _belt(c);
  }
}

// ------------------------------------------------------------------ ajutoare

List<Pt> _rect(double x, double y, double w, double h) =>
    [Pt(x, y), Pt(x + w, y), Pt(x + w, y + h), Pt(x, y + h)];

/// Curbă Bézier cubică, transformată în linie frântă.
List<Pt> _curve(Pt a, Pt b, Pt c, Pt d) => CubicSeg(a, b, c, d).sample();

List<Pt> _circle(Pt center, double r, [int n = 28]) => [
      for (var i = 0; i <= n; i++)
        Pt(center.x + r * math.cos(2 * math.pi * i / n),
            center.y + r * math.sin(2 * math.pi * i / n)),
    ];

/// Săgeată de la [a] la [b].
void _arrow(PatternCanvas c, Pt a, Pt b) {
  final u = (b - a).unit;
  final v = Pt(-u.y, u.x);
  c.polyline([a, b], width: 0.8);
  c.polyline([b - u * 0.45 + v * 0.3, b, b - u * 0.45 - v * 0.3], width: 0.8);
}

/// Linie zigzag (surfilare) între două puncte.
List<Pt> _zigzag(Pt a, Pt b, double amp, int teeth) {
  final u = (b - a).unit;
  final v = Pt(-u.y, u.x);
  final len = (b - a).length;
  return [
    for (var i = 0; i <= teeth * 2; i++)
      a + u * (len * i / (teeth * 2)) + v * (i.isEven ? 0 : amp),
  ];
}

/// Ac cu gămălie: o linie cu un cerculeț la capăt.
void _pin(PatternCanvas c, Pt head, Pt tip) {
  c.polyline([head, tip], width: 0.6);
  c.polyline(_circle(head, 0.18, 10), width: 0.6);
}

// ------------------------------------------------------------------ schițe

void _finishEdges(PatternCanvas c) {
  c.polyline(_rect(1.5, 0.8, 6.5, 4.4), closed: true, width: 1);
  c.polyline(_zigzag(const Pt(7.7, 0.8), const Pt(7.7, 5.2), 0.3, 9),
      width: 0.7);
  _arrow(c, const Pt(9.6, 4.6), const Pt(8.4, 3.4));
}

void _seam(PatternCanvas c) {
  // Două piese puse față pe față, puțin decalate ca să se vadă amândouă.
  c.polyline(_rect(1.6, 1.2, 6.8, 4.2), closed: true, width: 0.6, faint: true);
  c.polyline(_rect(1.2, 0.8, 6.8, 4.2), closed: true, width: 1);
  c.polyline([const Pt(7.0, 0.8), const Pt(7.0, 5.0)],
      width: 0.8, dashed: true);
  _pin(c, const Pt(4.2, 1.8), const Pt(6.4, 1.8));
  _pin(c, const Pt(4.2, 4.0), const Pt(6.4, 4.0));
  _arrow(c, const Pt(7.0, 0.1), const Pt(7.0, 1.4));
}

void _press(PatternCanvas c) {
  // Secțiune: cusătura jos, rezervele deschise în lateral, fierul deasupra.
  c.polyline([const Pt(1, 4.6), const Pt(4.85, 4.6), const Pt(4.85, 5.6)],
      width: 1);
  c.polyline([const Pt(9, 4.6), const Pt(5.15, 4.6), const Pt(5.15, 5.6)],
      width: 1);
  c.polyline(
    [
      const Pt(3, 3.6),
      const Pt(7.6, 3.6),
      const Pt(7.6, 2.6),
      const Pt(4.4, 2.0),
      const Pt(3, 3.6)
    ],
    closed: true,
    width: 1,
  );
  c.polyline([const Pt(5.2, 2.15), const Pt(5.6, 1.0), const Pt(7.0, 1.0)],
      width: 0.8);
  _arrow(c, const Pt(2.2, 4.2), const Pt(1.2, 4.2));
  _arrow(c, const Pt(7.8, 4.2), const Pt(8.8, 4.2));
}

void _dart(PatternCanvas c) {
  c.polyline([const Pt(0.8, 0.8), const Pt(9.2, 0.8)], width: 1);
  c.polyline([const Pt(4.0, 0.8), const Pt(5.0, 5.0), const Pt(6.0, 0.8)],
      width: 0.6, faint: true);
  // Pensa pliată: se coase de la talie spre vârf.
  c.polyline([const Pt(5.0, 0.8), const Pt(5.0, 5.0)], width: 0.6);
  c.polyline([const Pt(5.9, 0.8), const Pt(5.0, 5.0)],
      width: 0.8, dashed: true);
  _arrow(c, const Pt(6.8, 1.3), const Pt(6.0, 4.5));
}

void _zipper(PatternCanvas c) {
  c.polyline(_rect(1.2, 0.6, 3.5, 4.8), closed: true, width: 1);
  c.polyline(_rect(5.3, 0.6, 3.5, 4.8), closed: true, width: 1);
  c.polyline(_rect(4.55, 0.6, 0.9, 4.2), closed: true, width: 0.6);
  c.polyline(_zigzag(const Pt(5.0, 0.7), const Pt(5.0, 4.6), 0.18, 14),
      width: 0.5);
  c.polyline(_rect(4.75, 0.9, 0.5, 0.6), closed: true, width: 0.6);
  c.polyline([
    const Pt(4.2, 0.6),
    const Pt(4.2, 5.0),
    const Pt(5.8, 5.0),
    const Pt(5.8, 0.6)
  ], width: 0.8, dashed: true);
}

void _waistband(PatternCanvas c) {
  c.polyline([const Pt(1, 2.2), const Pt(9, 2.2), const Pt(9.4, 5.6)],
      width: 1);
  c.polyline([const Pt(1, 2.2), const Pt(0.6, 5.6)], width: 1);
  c.polyline(_rect(1, 0.6, 8, 1.6), closed: true, width: 1);
  c.polyline([const Pt(1, 1.4), const Pt(9, 1.4)], width: 0.5, faint: true);
  c.polyline([const Pt(1, 2.0), const Pt(9, 2.0)], width: 0.8, dashed: true);
}

void _hem(PatternCanvas c) {
  // Secțiune prin tiv: materialul se pliază de două ori în sus.
  c.polyline([const Pt(2, 0.6), const Pt(2, 5.2)], width: 1.2);
  c.polyline(
      _curve(const Pt(2, 5.2), const Pt(2, 5.7), const Pt(2.8, 5.7),
          const Pt(2.8, 5.2)),
      width: 1.2);
  c.polyline([const Pt(2.8, 5.2), const Pt(2.8, 3.0)], width: 1.2);
  c.polyline(
      _curve(const Pt(2.8, 3.0), const Pt(2.8, 2.6), const Pt(2.4, 2.6),
          const Pt(2.4, 3.0)),
      width: 1.2);
  c.polyline([const Pt(2.4, 3.0), const Pt(2.4, 4.4)], width: 1.2);
  c.polyline([const Pt(1.2, 3.4), const Pt(3.8, 3.4)],
      width: 0.8, dashed: true);
  // Vedere din față: linia tivului.
  c.polyline(_rect(5, 0.6, 4.2, 4.8), closed: true, width: 1);
  c.polyline([const Pt(5, 4.2), const Pt(9.2, 4.2)], width: 0.8, dashed: true);
}

void _elasticCasing(PatternCanvas c) {
  c.polyline(_rect(1, 1, 8, 4.4), closed: true, width: 1);
  c.polyline([const Pt(1, 2.4), const Pt(9, 2.4)], width: 0.8, dashed: true);
  c.polyline(_rect(1.6, 1.5, 6.4, 0.5), closed: true, width: 0.6, faint: true);
  // Acul de siguranță trage elasticul prin tunel.
  c.polyline([
    const Pt(8.0, 1.5),
    const Pt(9.2, 1.5),
    const Pt(9.4, 1.75),
    const Pt(9.2, 2.0),
    const Pt(8.0, 2.0)
  ], width: 0.7);
  _arrow(c, const Pt(6.2, 0.4), const Pt(8.6, 0.4));
  c.polyline([const Pt(6.6, 1.0), const Pt(7.6, 1.0)], width: 2);
}

void _setSleeve(PatternCanvas c) {
  // Răscroiala corpului și capul mânecii, potrivite cu acele.
  c.polyline(
      _curve(const Pt(2.6, 0.6), const Pt(2.5, 3.4), const Pt(3.6, 5.0),
          const Pt(5.6, 5.0)),
      width: 1);
  c.polyline(
      _curve(const Pt(2.9, 0.6), const Pt(6.0, 0.6), const Pt(7.0, 4.6),
          const Pt(9.4, 5.0)),
      width: 0.6,
      faint: true);
  c.polyline(
      _curve(const Pt(2.9, 0.9), const Pt(2.8, 3.4), const Pt(3.8, 4.7),
          const Pt(5.6, 4.7)),
      width: 0.8,
      dashed: true);
  _pin(c, const Pt(1.2, 1.4), const Pt(3.4, 1.0));
  _pin(c, const Pt(1.4, 3.6), const Pt(3.6, 3.0));
  _pin(c, const Pt(4.4, 5.8), const Pt(5.0, 4.4));
}

void _sideSeam(PatternCanvas c) {
  // Tricoul întors pe dos: o singură cusătură de la mânecă până jos.
  c.polyline([
    const Pt(3.6, 0.5),
    const Pt(1.0, 1.4),
    const Pt(0.4, 2.9),
    const Pt(2.4, 3.2),
    const Pt(2.8, 2.4),
    const Pt(2.8, 5.6),
    const Pt(7.2, 5.6),
    const Pt(7.2, 2.4),
    const Pt(7.6, 3.2),
    const Pt(9.6, 2.9),
    const Pt(9.0, 1.4),
    const Pt(6.4, 0.5),
  ], width: 1);
  c.polyline(
      _curve(const Pt(3.6, 0.5), const Pt(4.2, 1.2), const Pt(5.8, 1.2),
          const Pt(6.4, 0.5)),
      width: 1);
  c.polyline([const Pt(0.75, 2.75), const Pt(2.6, 2.7), const Pt(3.0, 5.6)],
      width: 0.8, dashed: true);
  c.polyline([const Pt(9.25, 2.75), const Pt(7.4, 2.7), const Pt(7.0, 5.6)],
      width: 0.8, dashed: true);
}

void _neckband(PatternCanvas c) {
  c.polyline(
      _curve(const Pt(1, 1), const Pt(1.6, 5.2), const Pt(8.4, 5.2),
          const Pt(9, 1)),
      width: 1);
  c.polyline(
      _curve(const Pt(1.7, 0.9), const Pt(2.2, 4.3), const Pt(7.8, 4.3),
          const Pt(8.3, 0.9)),
      width: 1);
  c.polyline(
      _curve(const Pt(1.35, 0.95), const Pt(1.9, 4.75), const Pt(8.1, 4.75),
          const Pt(8.65, 0.95)),
      width: 0.8,
      dashed: true);
  // Semnele de sferturi: bentița se întinde egal pe fiecare sfert.
  for (final x in [3.0, 5.0, 7.0]) {
    final y = x == 5.0 ? 4.4 : 3.75;
    c.polyline([Pt(x, y - 0.35), Pt(x, y + 0.6)], width: 0.6);
  }
}

void _crotchSeam(PatternCanvas c) {
  // Un picior întors pe față, băgat în celălalt: se coase curba de la mijloc.
  c.polyline([const Pt(1.2, 0.6), const Pt(1.2, 5.6)], width: 1);
  c.polyline([const Pt(8.8, 0.6), const Pt(8.8, 5.6)], width: 1);
  c.polyline(
      _curve(const Pt(3.4, 0.6), const Pt(3.4, 4.0), const Pt(6.6, 4.0),
          const Pt(6.6, 0.6)),
      width: 1);
  c.polyline(
      _curve(const Pt(3.8, 0.6), const Pt(3.8, 3.5), const Pt(6.2, 3.5),
          const Pt(6.2, 0.6)),
      width: 0.8,
      dashed: true);
  c.polyline(
      _curve(const Pt(3.95, 0.6), const Pt(3.95, 3.3), const Pt(6.05, 3.3),
          const Pt(6.05, 0.6)),
      width: 0.8,
      dashed: true);
  c.polyline([const Pt(1.2, 0.6), const Pt(3.4, 0.6)], width: 1);
  c.polyline([const Pt(6.6, 0.6), const Pt(8.8, 0.6)], width: 1);
}

void _buttonLoop(PatternCanvas c) {
  c.polyline([const Pt(5, 0.6), const Pt(5, 3.4)], width: 1);
  c.polyline([const Pt(1, 0.6), const Pt(9, 0.6)], width: 1);
  c.polyline([const Pt(5, 3.4), const Pt(5, 5.6)], width: 0.8, dashed: true);
  // Bucla în dreapta, nasturele în stânga.
  c.polyline(
      _curve(const Pt(5.1, 1.0), const Pt(6.6, 0.9), const Pt(6.6, 2.1),
          const Pt(5.1, 2.0)),
      width: 1);
  c.polyline(_circle(const Pt(4.0, 1.5), 0.55), width: 1);
  c.polyline(_circle(const Pt(3.85, 1.4), 0.08, 6), width: 0.6);
  c.polyline(_circle(const Pt(4.15, 1.6), 0.08, 6), width: 0.6);
}

void _belt(PatternCanvas c) {
  c.polyline(_rect(0.6, 1.6, 8.8, 1.6), closed: true, width: 1);
  c.polyline([const Pt(0.9, 1.9), const Pt(9.1, 1.9), const Pt(9.1, 2.9)],
      width: 0.8, dashed: true);
  c.polyline([const Pt(0.9, 1.9), const Pt(0.9, 2.9), const Pt(3.6, 2.9)],
      width: 0.8, dashed: true);
  c.polyline([const Pt(6.0, 2.9), const Pt(9.1, 2.9)],
      width: 0.8, dashed: true);
  // Deschiderea prin care se întoarce cordonul pe față.
  _arrow(c, const Pt(4.8, 3.0), const Pt(4.8, 5.4));
}
