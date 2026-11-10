import 'dart:math' as math;

import '../geometry.dart';
import '../models/pattern.dart';

/// O tăietură pe material: una sau două piese care ies dintr-o singură
/// tăietură prin ambele straturi ale materialului pliat.
class FabricCut {
  FabricCut({
    required this.piece,
    required this.shapes,
    required this.yields,
    required this.againstFold,
  }) : bounds = Bounds.of(shapes.expand((s) => s));

  final PatternPiece piece;

  /// Contururile de tăiere, deja mutate la locul lor pe material (cm).
  /// O piesă desfăcută din pliu are două contururi, în oglindă.
  final List<List<Pt>> shapes;
  final Bounds bounds;

  /// Câte bucăți rezultă din tăietura asta.
  final int yields;

  /// true = piesa stă lipită de îndoitura materialului.
  final bool againstFold;
}

/// Calculează de cât material e nevoie pentru un model.
///
/// Materialul se pliază în două pe lung, cu fața înăuntru: îndoitura e în
/// stânga (x = 0), marginile țesăturii în dreapta. Piesele stau cu firul
/// drept pe lungimea materialului și se așază automat cât mai strâns:
/// fiecare piesă coboară, ca la Tetris, până atinge piesele de dedesubt,
/// după forma ei reală, nu după dreptunghiul care o încadrează. Așa o
/// bandă poate intra în colțul gol de lângă un sfert de cerc.
class FabricPlan {
  FabricPlan._(this.fabricWidth, this.usableWidth, this.cuts, this.length, this.tooWide);

  /// Spațiul lăsat între piese, în cm.
  static const gap = 1.5;

  /// Marginea țesăturii (tivul fabricii), care nu se folosește.
  static const selvage = 1.5;

  /// În plus pentru intrarea la spălat și îndreptarea capătului.
  static const extra = 10.0;

  static const _cell = 0.5;

  factory FabricPlan.compute(
    List<PatternPiece> pieces, {
    required double fabricWidth,
    required double seam,
    required double hem,
  }) {
    final usable = fabricWidth / 2 - selvage;
    final cells = (usable / _cell).floor();
    final gapCells = (gap / _cell).ceil();

    final jobs = <_Job>[];
    for (final piece in pieces) {
      jobs.addAll(_jobsFor(piece, piece.cutLine(seam: seam, hem: hem), usable));
    }
    for (final job in jobs) {
      job.prepare(gapCells);
    }

    // Ordinea în care se pun piesele schimbă rezultatul, așa că încercăm
    // câteva ordini și o păstrăm pe cea care cere cel mai puțin material.
    int byArea(_Job a, _Job b) => b.area.compareTo(a.area);
    final fold = jobs.where((j) => j.againstFold).toList()..sort(byArea);
    final rest = jobs.where((j) => !j.againstFold).toList()..sort(byArea);
    final orders = <List<_Job>>[
      [...fold, ...rest], // întâi piesele de pe pliu, apoi restul, de la mare la mic
      [...rest, ...fold], // întâi restul (spre margine), apoi piesele de pe pliu
      [...jobs]..sort((a, b) => b.length.compareTo(a.length)), // de la cea mai lungă
    ];

    FabricPlan? best;
    for (final order in orders) {
      final plan = _pack(order, fabricWidth, usable, cells);
      if (best == null ||
          (plan.fits && !best.fits) ||
          (plan.fits == best.fits && plan.length < best.length - 1e-9)) {
        best = plan;
      }
    }
    return best!;
  }

  static FabricPlan _pack(
      List<_Job> jobs, double fabricWidth, double usable, int cells) {
    final heights = List<double>.filled(cells, 0);
    final cuts = <FabricCut>[];
    final tooWide = <String>{};

    for (final job in jobs) {
      _Spot? best;
      for (var v = 0; v < job.variants.length; v++) {
        final shapes = job.variants[v];
        final b = job.bounds[v];
        final profile = job.profiles[v];
        if (profile.real > cells) continue;
        final lastX = job.againstFold ? 0 : cells - profile.real;
        // Piesele de pe pliu stau la stânga; restul preferă marginea din
        // dreapta, ca să lase îndoitura liberă.
        for (var i = 0; i <= lastX; i++) {
          final x = job.againstFold ? i : lastX - i;
          // Cât de jos poate coborî piesa până atinge ce e dedesubt.
          var y = 0.0;
          for (var c = 0; c < profile.width && x + c < cells; c++) {
            y = math.max(y, heights[x + c] - profile.top[c]);
          }
          final spot = _Spot(shapes, b, profile, x, y);
          if (best == null || spot.end < best.end - 1e-9) best = spot;
        }
      }

      if (best == null) {
        // Nu încape pe lățimea materialului pliat: o punem sub tot restul,
        // ca să știm totuși cât material ar lua.
        tooWide.add(job.piece.name);
        final shapes = job.variants.first;
        final b = job.bounds.first;
        final y = heights.fold<double>(0, math.max);
        best = _Spot(shapes, b, _Profile.box(cells, b.height), 0, y);
      }

      final pr = best.profile;
      for (var c = 0; c < pr.width && best.x + c < cells; c++) {
        heights[best.x + c] =
            math.max(heights[best.x + c], best.y + pr.bottom[c] + gap);
      }
      final shift = Pt(best.x * _cell - best.bounds.minX, best.y - best.bounds.minY);
      cuts.add(FabricCut(
        piece: job.piece,
        shapes: [for (final s in best.shapes) [for (final p in s) p + shift]],
        yields: job.yields,
        againstFold: job.againstFold,
      ));
    }

    final top = cuts.fold<double>(0, (m, c) => math.max(m, c.bounds.maxY));
    return FabricPlan._(fabricWidth, usable, cuts, top, tooWide.toList());
  }

  /// Lățimea întreagă a materialului, în cm.
  final double fabricWidth;

  /// Lățimea folosibilă pe materialul pliat, în cm.
  final double usableWidth;

  final List<FabricCut> cuts;

  /// Lungimea de material ocupată de piese, în cm.
  final double length;

  /// Piesele care nu încap pe lățimea materialului pliat.
  final List<String> tooWide;

  bool get fits => tooWide.isEmpty;

  /// Cât material să cumperi, în metri, rotunjit în sus la 10 cm.
  double get metersToBuy => ((length + extra) / 10).ceil() / 10;

  static List<_Job> _jobsFor(PatternPiece piece, List<Pt> cut, double usable) {
    // Benzile au firul pe lățime: le întoarcem, ca firul să fie pe lungime.
    final grain = piece.grainTo - piece.grainFrom;
    final shape = grain.x.abs() > grain.y.abs() ? _swap(cut) : cut;
    // Fiecare piesă poate fi întoarsă și cu capul în jos: firul drept
    // rămâne pe lungimea materialului.
    final variants = [
      [shape],
      [_flip(shape)],
      if (piece.canRotate) ...[[_swap(shape)], [_flip(_swap(shape))]],
    ];

    if (piece.onFold) {
      // Pe pliu, fiecare tăietură dă o piesă. Dacă trebuie două, e mai
      // economic să desfacem piesa în oglindă și s-o tăiem prin ambele
      // straturi oriunde pe material, când încape.
      final mirrored = [for (final p in shape) Pt(-p.x, p.y)];
      final unfoldedWidth = 2 * Bounds.of(shape).maxX;
      final onFold = [[shape], [_flip(shape)]];
      if (piece.copies >= 2 && unfoldedWidth <= usable) {
        return [
          for (var i = 0; i < piece.copies ~/ 2; i++)
            _Job(piece, [[shape, mirrored], [_flip(shape), _flip(mirrored)]], 2, false),
          if (piece.copies.isOdd) _Job(piece, onFold, 1, true),
        ];
      }
      return [for (var i = 0; i < piece.copies; i++) _Job(piece, onFold, 1, true)];
    }

    // Materialul e dublu: o tăietură dă două piese în oglindă.
    final jobs = <_Job>[];
    for (var left = piece.copies; left > 0; left -= 2) {
      jobs.add(_Job(piece, variants, math.min(left, 2), false));
    }
    return jobs;
  }

  static List<Pt> _swap(List<Pt> pts) => [for (final p in pts) Pt(p.y, p.x)];

  static List<Pt> _flip(List<Pt> pts) => [for (final p in pts) Pt(p.x, -p.y)];
}

class _Job {
  _Job(this.piece, this.variants, this.yields, this.againstFold) {
    final b = Bounds.of(variants.first.expand((s) => s));
    area = b.width * b.height;
    length = b.height;
  }

  final PatternPiece piece;

  /// Orientările posibile; fiecare e o listă de contururi.
  final List<List<List<Pt>>> variants;
  final int yields;
  final bool againstFold;
  late final double area;
  late final double length;

  /// Calculate o singură dată, pentru toate ordinile încercate.
  late final List<Bounds> bounds;
  late final List<_Profile> profiles;

  void prepare(int gapCells) {
    bounds = [for (final v in variants) Bounds.of(v.expand((s) => s))];
    profiles = [
      for (var i = 0; i < variants.length; i++) _Profile.of(variants[i], bounds[i], gapCells)
    ];
  }
}

class _Spot {
  _Spot(this.shapes, this.bounds, this.profile, this.x, this.y);

  final List<List<Pt>> shapes;
  final Bounds bounds;
  final _Profile profile;
  final int x;
  final double y;

  double get end => y + bounds.height;
}

/// Forma unei piese văzută pe coloane de câte 0,5 cm: pentru fiecare
/// coloană, unde începe piesa (sus) și unde se termină (jos), măsurat de la
/// marginea de sus a dreptunghiului ei. Coloanele din dreapta se lărgesc cu
/// spațiul dintre piese.
class _Profile {
  _Profile(this.top, this.bottom, this.real);

  factory _Profile.of(List<List<Pt>> shapes, Bounds b, int pad) {
    final n = (b.width / FabricPlan._cell).ceil().clamp(1, 100000);
    final top = List<double>.filled(n, double.infinity);
    final bottom = List<double>.filled(n, -double.infinity);
    void mark(Pt p) {
      final c = ((p.x - b.minX) / FabricPlan._cell).floor().clamp(0, n - 1);
      final y = p.y - b.minY;
      if (y < top[c]) top[c] = y;
      if (y > bottom[c]) bottom[c] = y;
    }

    // Puncte la fiecare 0,25 cm pe conturul piesei.
    for (final shape in shapes) {
      for (var i = 0; i < shape.length; i++) {
        final a = shape[i], z = shape[(i + 1) % shape.length];
        final steps = (a.distanceTo(z) / 0.25).ceil().clamp(1, 100000);
        for (var k = 0; k <= steps; k++) {
          mark(Pt(a.x + (z.x - a.x) * k / steps, a.y + (z.y - a.y) * k / steps));
        }
      }
    }
    // Coloană fără puncte (n-ar trebui să existe): o considerăm plină.
    for (var c = 0; c < n; c++) {
      if (top[c] == double.infinity) {
        top[c] = 0;
        bottom[c] = b.height;
      }
    }
    // Spațiul dintre piese, la dreapta: copiem ultima coloană.
    return _Profile(
      [...top, for (var i = 0; i < pad; i++) top.last],
      [...bottom, for (var i = 0; i < pad; i++) bottom.last],
      n,
    );
  }

  factory _Profile.box(int width, double height) =>
      _Profile(List.filled(width, 0), List.filled(width, height), width);

  final List<double> top;
  final List<double> bottom;

  /// Câte coloane ocupă piesa propriu-zisă, fără spațiul de la dreapta.
  final int real;

  int get width => top.length;
}
