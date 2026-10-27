import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../geometry.dart';
import 'layout.dart';
import 'pattern_canvas.dart';

/// Desenează tiparul pe ecran (implementarea `PatternCanvas` pentru Flutter).
class FlutterPatternCanvas implements PatternCanvas {
  FlutterPatternCanvas(this.canvas, this.pxPerCm, this.color);

  final Canvas canvas;
  final double pxPerCm;
  final Color color;

  Offset _o(Pt p) => Offset(p.x * pxPerCm, p.y * pxPerCm);

  /// Puncte tipografice → pixeli pe ecran, la scara curentă.
  double _px(double pt) => pt * 2.54 / 72 * pxPerCm;

  @override
  void polyline(List<Pt> pts,
      {bool closed = false,
      double width = 0.6,
      bool dashed = false,
      bool faint = false}) {
    if (pts.length < 2) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(_px(width), width >= 1 ? 1.2 : 0.7)
      ..color = faint ? color.withAlpha(60) : color;
    final offsets = [for (final p in pts) _o(p)];
    final path = dashed
        ? _dashed(offsets, closed, 0.3 * pxPerCm, 0.2 * pxPerCm)
        : (Path()..addPolygon(offsets, closed));
    canvas.drawPath(path, paint);
  }

  @override
  void text(String s, Pt topLeft, {double size = 9, bool bold = false}) {
    final painter = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontSize: _px(size),
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, _o(topLeft));
  }

  static Path _dashed(
      List<Offset> pts, bool closed, double dash, double gap) {
    final path = Path();
    final all = closed ? [...pts, pts.first] : pts;
    var drawing = true;
    var remaining = dash;
    for (var i = 0; i < all.length - 1; i++) {
      var a = all[i];
      final b = all[i + 1];
      var left = (b - a).distance;
      while (left > 1e-9) {
        final step = math.min(remaining, left);
        final p = Offset.lerp(a, b, step / left)!;
        if (drawing) {
          path
            ..moveTo(a.dx, a.dy)
            ..lineTo(p.dx, p.dy);
        }
        a = p;
        left -= step;
        remaining -= step;
        if (remaining <= 1e-9) {
          drawing = !drawing;
          remaining = drawing ? dash : gap;
        }
      }
    }
    return path;
  }
}

/// Afișează planșa cu piese, micșorată cât să încapă în spațiul disponibil.
class LayoutPainter extends CustomPainter {
  LayoutPainter({
    required this.layout,
    required this.color,
    this.footer = '',
    this.showText = true,
    this.showGrid = true,
  });

  final PatternLayout layout;
  final Color color;
  final String footer;
  final bool showText;
  final bool showGrid;

  @override
  void paint(Canvas canvas, Size size) {
    if (layout.width <= 0 || layout.height <= 0) return;
    final scale = math.min(size.width / layout.width, size.height / layout.height);
    canvas.save();
    canvas.translate((size.width - layout.width * scale) / 2,
        (size.height - layout.height * scale) / 2);

    final c = FlutterPatternCanvas(canvas, scale, color);
    if (showGrid) {
      // Caroiaj de 10 cm, ca reper de mărime.
      for (var x = 0.0; x <= layout.width; x += 10) {
        c.polyline([Pt(x, 0), Pt(x, layout.height)], width: 0.3, faint: true);
      }
      for (var y = 0.0; y <= layout.height; y += 10) {
        c.polyline([Pt(0, y), Pt(layout.width, y)], width: 0.3, faint: true);
      }
    }
    drawLayout(c, layout, footer: footer, showText: showText);
    canvas.restore();
  }

  @override
  bool shouldRepaint(LayoutPainter old) =>
      old.layout != layout || old.color != color || old.footer != footer;
}
