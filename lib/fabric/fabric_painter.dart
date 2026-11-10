import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../geometry.dart';
import 'fabric_plan.dart';

/// Desenează materialul pliat, cu piesele așezate pe el.
class FabricPainter extends CustomPainter {
  FabricPainter({required this.plan, required this.ink});

  final FabricPlan plan;
  final Color ink;

  static const _fills = [
    Color(0xFFF4C7CF), Color(0xFFD9E8DC), Color(0xFFE6DDF2),
    Color(0xFFF8E3B5), Color(0xFFCFE2EE), Color(0xFFF2D4C2),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // Materialul desenat: jumătate din lățime (e pliat), plus o margine.
    final fabricW = plan.fabricWidth / 2;
    final fabricH = math.max(plan.length + 6, 20.0);
    const pad = 20.0; // cm de spațiu pentru riglă și etichete
    final scale = math.min(size.width / (fabricW + pad * 2),
        size.height / (fabricH + pad * 2));
    canvas.save();
    canvas.translate((size.width - (fabricW + pad * 2) * scale) / 2 + pad * scale,
        (size.height - (fabricH + pad * 2) * scale) / 2 + pad * scale);

    Offset o(Pt p) => Offset(p.x * scale, p.y * scale);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..color = ink
      ..strokeWidth = 1.2;

    // Materialul.
    final fabric = Rect.fromLTWH(0, 0, fabricW * scale, fabricH * scale);
    canvas.drawRect(fabric, Paint()..color = const Color(0xFFFFF8F0));
    canvas.drawRect(fabric, line);
    // Tivul fabricii din dreapta, care nu se folosește.
    final selvageX = plan.usableWidth * scale;
    canvas.drawRect(
        Rect.fromLTRB(selvageX, 0, fabric.right, fabric.bottom),
        Paint()..color = ink.withAlpha(25));

    // Piesele.
    final colors = <String, Color>{};
    for (final cut in plan.cuts) {
      final fill = colors.putIfAbsent(
          cut.piece.name, () => _fills[colors.length % _fills.length]);
      for (final shape in cut.shapes) {
        final path = Path()..addPolygon([for (final p in shape) o(p)], true);
        canvas.drawPath(path, Paint()..color = fill);
        canvas.drawPath(path, line);
      }
      final c = cut.bounds;
      final label = cut.yields == 2 ? '${cut.piece.name}\n×2' : cut.piece.name;
      _text(canvas, label, o(Pt((c.minX + c.maxX) / 2, (c.minY + c.maxY) / 2)),
          math.max(9, 3.2 * scale), center: true);
    }

    // Îndoitura materialului, în stânga.
    final fold = Paint()
      ..color = const Color(0xFFC8553D)
      ..strokeWidth = 3;
    for (var y = 0.0; y < fabricH; y += 4) {
      canvas.drawLine(o(Pt(0, y)), o(Pt(0, math.min(y + 2.5, fabricH))), fold);
    }
    _text(canvas, 'pliu', o(Pt(0, -6)), math.max(10, 3.5 * scale), center: true);
    _text(canvas, 'margine', o(Pt(fabricW, -6)), math.max(10, 3.5 * scale), center: true);

    // Riglă în dreapta: o gradație la 10 cm, cifre la fiecare 50 cm.
    for (var y = 0.0; y <= fabricH; y += 10) {
      final big = y % 50 == 0;
      canvas.drawLine(o(Pt(fabricW, y)), o(Pt(fabricW + (big ? 4 : 2), y)), line);
      if (big) {
        _text(canvas, '${y.toInt()} cm', o(Pt(fabricW + 5, y - 1.5)),
            math.max(9, 3 * scale));
      }
    }
    canvas.restore();
  }

  void _text(Canvas canvas, String s, Offset at, double size, {bool center = false}) {
    final tp = TextPainter(
      text: TextSpan(
          text: s,
          style: TextStyle(fontSize: size, color: ink, fontWeight: FontWeight.w600)),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center ? at - Offset(tp.width / 2, tp.height / 2) : at);
  }

  @override
  bool shouldRepaint(FabricPainter old) => old.plan != plan || old.ink != ink;
}
