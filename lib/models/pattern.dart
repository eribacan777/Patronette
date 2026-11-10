import '../geometry.dart';

/// O piesă de tipar (de exemplu „Față” sau „Mânecă”), în centimetri.
class PatternPiece {
  PatternPiece({
    required this.name,
    required this.cutInfo,
    required this.outline,
    required this.grainFrom,
    required this.grainTo,
    required this.labelAt,
    this.markings = const [],
    this.copies = 1,
    this.canRotate = false,
  });

  final String name;

  /// Câte bucăți se taie și cum, de exemplu „Taie 1 pe pliu”.
  final String cutInfo;

  /// Conturul închis al piesei, pe linia de cusătură.
  final List<Segment> outline;

  /// Linii desenate în interior: pense, linii de pliere.
  final List<List<Pt>> markings;

  /// Capetele săgeții care arată direcția firului drept al materialului.
  final Pt grainFrom;
  final Pt grainTo;

  /// Colțul din stânga sus al textului scris pe piesă.
  final Pt labelAt;

  /// Câte bucăți din piesa asta se taie din material.
  final int copies;

  /// true = piesa se poate întoarce pe material (benzi, cordoane);
  /// celelalte stau cu firul drept pe lungimea materialului.
  final bool canRotate;

  List<Pt> get seamLine => flattenOutline(outline);

  List<Pt> cutLine({required double seam, required double hem}) {
    if (seam == 0 && hem == 0) return seamLine;
    return offsetOutline(
      outline,
      (kind) => switch (kind) {
        EdgeKind.seam => seam,
        EdgeKind.hem => hem,
        EdgeKind.fold => 0.0,
      },
    );
  }

  Iterable<Segment> get foldEdges =>
      outline.where((s) => s.kind == EdgeKind.fold);

  bool get onFold => foldEdges.isNotEmpty;
}

/// Rezultatul generării: piesele unui model, plus observații pentru utilizator.
class Draft {
  const Draft({required this.pieces, this.notes = const []});

  final List<PatternPiece> pieces;
  final List<String> notes;
}
