import 'dart:math' as math;

import '../drawing/layout.dart';
import '../geometry.dart';

/// Împarte planșa în pagini A4. Fiecare pagină are 1 cm margine albă,
/// deci pe ea încape o bucată de 19 × 27,7 cm din tipar.
class TileGrid {
  TileGrid(this.layout)
      : cols = math.max(1, (layout.width / tileW).ceil()),
        rows = math.max(1, (layout.height / tileH).ceil());

  static const margin = 1.0;
  static const pageW = 21.0;
  static const pageH = 29.7;
  static const tileW = pageW - 2 * margin;
  static const tileH = pageH - 2 * margin;

  final PatternLayout layout;
  final int cols;
  final int rows;

  Bounds tile(int row, int col) =>
      Bounds(col * tileW, row * tileH, (col + 1) * tileW, (row + 1) * tileH);

  /// Paginile pe care nu cade nicio piesă nu se mai printează.
  bool isUsed(int row, int col) =>
      layout.placed.any((p) => p.bounds.intersects(tile(row, col)));

  int get usedCount {
    var n = 0;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (isUsed(r, c)) n++;
      }
    }
    return n;
  }

  /// Rândurile sunt litere, coloanele cifre: A1, A2, B1...
  static String label(int row, int col) =>
      '${String.fromCharCode(65 + row)}${col + 1}';
}
