import 'dart:math' as math;

/// Un punct pe tipar, în centimetri.
/// Axa x merge spre dreapta, axa y în jos, ca pe o foaie de hârtie.
class Pt {
  const Pt(this.x, this.y);

  final double x;
  final double y;

  Pt operator +(Pt o) => Pt(x + o.x, y + o.y);
  Pt operator -(Pt o) => Pt(x - o.x, y - o.y);
  Pt operator *(double k) => Pt(x * k, y * k);

  double get length => math.sqrt(x * x + y * y);
  double distanceTo(Pt o) => (this - o).length;

  Pt get unit {
    final l = length;
    return l == 0 ? this : Pt(x / l, y / l);
  }

  /// Produsul vectorial în plan; semnul arată de ce parte e [o].
  double cross(Pt o) => x * o.y - y * o.x;

  @override
  String toString() => 'Pt(${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)})';
}

/// Ce fel de margine este o bucată din conturul unei piese.
/// De asta depinde câtă rezervă de cusătură primește.
enum EdgeKind {
  /// Cusătură obișnuită.
  seam,

  /// Tiv (marginea de jos a hainei).
  hem,

  /// Pliul materialului: piesa se taie pe îndoitură, fără rezervă.
  fold,
}

/// O bucată din conturul unei piese: linie dreaptă, curbă sau arc.
abstract class Segment {
  const Segment(this.kind);

  final EdgeKind kind;

  Pt get start;
  Pt get end;

  /// Puncte de-a lungul segmentului, inclusiv cele două capete.
  List<Pt> sample();

  double get length => polylineLength(sample());
}

class LineSeg extends Segment {
  const LineSeg(this.a, this.b, [EdgeKind kind = EdgeKind.seam]) : super(kind);

  final Pt a;
  final Pt b;

  @override
  Pt get start => a;
  @override
  Pt get end => b;

  @override
  List<Pt> sample() => [a, b];
}

/// Curbă Bézier cubică: pleacă din [a] spre [c1], ajunge în [b] dinspre [c2].
class CubicSeg extends Segment {
  const CubicSeg(this.a, this.c1, this.c2, this.b,
      [EdgeKind kind = EdgeKind.seam])
      : super(kind);

  final Pt a;
  final Pt c1;
  final Pt c2;
  final Pt b;

  @override
  Pt get start => a;
  @override
  Pt get end => b;

  Pt pointAt(double t) {
    final u = 1 - t;
    return a * (u * u * u) +
        c1 * (3 * u * u * t) +
        c2 * (3 * u * t * t) +
        b * (t * t * t);
  }

  @override
  List<Pt> sample() => [for (var i = 0; i <= 40; i++) pointAt(i / 40)];
}

/// Arc de cerc. Unghiurile (în radiani) se măsoară de la axa y, în jos,
/// spre axa x: unghiul 0 cade pe verticală, π/2 pe orizontală.
class ArcSeg extends Segment {
  const ArcSeg(this.center, this.radius, this.fromAngle, this.toAngle,
      [EdgeKind kind = EdgeKind.seam])
      : super(kind);

  final Pt center;
  final double radius;
  final double fromAngle;
  final double toAngle;

  Pt pointAt(double angle) => Pt(center.x + radius * math.sin(angle),
      center.y + radius * math.cos(angle));

  @override
  Pt get start => pointAt(fromAngle);
  @override
  Pt get end => pointAt(toAngle);

  @override
  List<Pt> sample() {
    // Aproximativ un punct la fiecare centimetru de arc.
    final n = math.max(8, (radius * (toAngle - fromAngle).abs()).ceil());
    return [
      for (var i = 0; i <= n; i++)
        pointAt(fromAngle + (toAngle - fromAngle) * i / n)
    ];
  }
}

/// Dreptunghiul care încadrează un set de puncte.
class Bounds {
  const Bounds(this.minX, this.minY, this.maxX, this.maxY);

  factory Bounds.of(Iterable<Pt> pts) {
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (final p in pts) {
      minX = math.min(minX, p.x);
      minY = math.min(minY, p.y);
      maxX = math.max(maxX, p.x);
      maxY = math.max(maxY, p.y);
    }
    return Bounds(minX, minY, maxX, maxY);
  }

  final double minX;
  final double minY;
  final double maxX;
  final double maxY;

  double get width => maxX - minX;
  double get height => maxY - minY;

  bool intersects(Bounds o) =>
      minX < o.maxX && o.minX < maxX && minY < o.maxY && o.minY < maxY;

  Bounds shift(Pt d) => Bounds(minX + d.x, minY + d.y, maxX + d.x, maxY + d.y);
}

double polylineLength(List<Pt> pts) {
  var sum = 0.0;
  for (var i = 0; i < pts.length - 1; i++) {
    sum += pts[i].distanceTo(pts[i + 1]);
  }
  return sum;
}

/// Aria cu semn a unui poligon închis. Semnul arată sensul de parcurgere.
double signedArea(List<Pt> pts) {
  var sum = 0.0;
  for (var i = 0; i < pts.length; i++) {
    final a = pts[i], b = pts[(i + 1) % pts.length];
    sum += a.x * b.y - b.x * a.y;
  }
  return sum / 2;
}

/// Normala exterioară a direcției [e] pentru un poligon cu aria cu semn [area].
Pt outwardNormal(Pt e, double area) =>
    area > 0 ? Pt(e.y, -e.x) : Pt(-e.y, e.x);

/// Înălțimea (y) unei linii frânte în dreptul coordonatei [x].
double yAtX(List<Pt> pts, double x) {
  for (var i = 0; i < pts.length - 1; i++) {
    final a = pts[i], b = pts[i + 1];
    final lo = math.min(a.x, b.x), hi = math.max(a.x, b.x);
    if (x >= lo && x <= hi) {
      if (hi - lo < 1e-9) return a.y;
      return a.y + (b.y - a.y) * (x - a.x) / (b.x - a.x);
    }
  }
  // În afara liniei: luăm capătul cel mai apropiat.
  return (x - pts.first.x).abs() < (x - pts.last.x).abs()
      ? pts.first.y
      : pts.last.y;
}

/// Transformă conturul într-un poligon (linia de cusătură).
List<Pt> flattenOutline(List<Segment> outline) =>
    _flatten(outline, (_) => 0).$1;

(List<Pt>, List<double>) _flatten(
    List<Segment> outline, double Function(EdgeKind) allowance) {
  final pts = <Pt>[];
  // dist[i] = rezerva muchiei care pleacă din pts[i] spre pts[i + 1].
  final dist = <double>[];
  for (final seg in outline) {
    final s = seg.sample();
    final d = allowance(seg.kind);
    // Ultimul punct al segmentului este primul punct al următorului.
    for (var i = 0; i < s.length - 1; i++) {
      if (pts.isNotEmpty && pts.last.distanceTo(s[i]) < 1e-6) {
        dist[dist.length - 1] = d;
        continue;
      }
      pts.add(s[i]);
      dist.add(d);
    }
  }
  if (pts.length > 1 && pts.last.distanceTo(pts.first) < 1e-6) {
    pts.removeLast();
    dist.removeLast();
  }
  return (pts, dist);
}

/// Linia de tăiere: conturul împins în afară, fiecare muchie cu rezerva ei.
///
/// Fiecare muchie a poligonului se mută paralel spre exterior cu rezerva
/// ei, iar colțurile noi sunt intersecțiile muchiilor vecine mutate.
List<Pt> offsetOutline(
    List<Segment> outline, double Function(EdgeKind) allowance) {
  final (pts, dist) = _flatten(outline, allowance);
  final n = pts.length;
  final area = signedArea(pts);

  Pt dir(int i) => (pts[(i + 1) % n] - pts[i]).unit;

  final out = <Pt>[];
  for (var i = 0; i < n; i++) {
    final prev = (i - 1 + n) % n;
    final e1 = dir(prev), e2 = dir(i);
    final d1 = dist[prev], d2 = dist[i];
    final p = pts[i];
    // Câte un punct pe fiecare dintre cele două muchii mutate.
    final a = p + outwardNormal(e1, area) * d1;
    final b = p + outwardNormal(e2, area) * d2;

    final den = e1.cross(e2);
    if (den.abs() < 1e-9) {
      // Muchii paralele: nu au intersecție, păstrăm ambele puncte.
      out.add(a);
      if (a.distanceTo(b) > 1e-6) out.add(b);
      continue;
    }
    final t = (b - a).cross(e2) / den;
    final q = a + e1 * t;
    // La colțuri foarte ascuțite intersecția fuge departe: le teșim.
    final limit = 3 * math.max(math.max(d1, d2), 0.05);
    if (q.distanceTo(p) > limit) {
      out.add(a);
      out.add(b);
    } else {
      out.add(q);
    }
  }
  return out;
}
