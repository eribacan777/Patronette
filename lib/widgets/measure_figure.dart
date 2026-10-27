import 'package:flutter/material.dart';

/// Siluetă simplă pe care se evidențiază locul unde se ia o măsură.
class MeasureFigure extends StatelessWidget {
  const MeasureFigure({super.key, required this.highlight});

  /// Cheia măsurii evidențiate (vezi `kMeasurements`).
  final String highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CustomPaint(
      painter: _FigurePainter(
        highlight: highlight,
        body: scheme.surfaceContainerHighest,
        outline: scheme.outline,
        accent: scheme.primary,
      ),
    );
  }
}

class _FigurePainter extends CustomPainter {
  _FigurePainter({
    required this.highlight,
    required this.body,
    required this.outline,
    required this.accent,
  });

  final String highlight;
  final Color body;
  final Color outline;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    // Desenul e gândit pe o grilă de 120 × 220 și apoi scalat.
    final s = (size.width / 120 < size.height / 220)
        ? size.width / 120
        : size.height / 220;
    canvas.translate((size.width - 120 * s) / 2, (size.height - 220 * s) / 2);
    canvas.scale(s);

    final fill = Paint()..color = body;
    final stroke = Paint()
      ..color = outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final figure = Path()
      ..addOval(Rect.fromCircle(center: const Offset(60, 20), radius: 13))
      ..addRect(const Rect.fromLTRB(54, 32, 66, 44))
      // trunchi: umeri, bust, talie, șold
      ..moveTo(28, 48)
      ..lineTo(92, 48)
      ..lineTo(90, 72)
      ..quadraticBezierTo(82, 88, 84, 100)
      ..quadraticBezierTo(94, 112, 92, 128)
      ..lineTo(28, 128)
      ..quadraticBezierTo(26, 112, 36, 100)
      ..quadraticBezierTo(38, 88, 30, 72)
      ..close()
      // brațe
      ..addPath(_limb(const Offset(28, 50), const Offset(14, 130), 10), Offset.zero)
      ..addPath(_limb(const Offset(92, 50), const Offset(106, 130), 10), Offset.zero)
      // picioare
      ..addPath(_limb(const Offset(44, 126), const Offset(44, 212), 16), Offset.zero)
      ..addPath(_limb(const Offset(76, 126), const Offset(76, 212), 16), Offset.zero);
    canvas.drawPath(figure, fill);
    canvas.drawPath(figure, stroke);

    final mark = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    void band(double y, double x1, double x2) {
      canvas.drawOval(
          Rect.fromLTRB(x1 - 2, y - 4, x2 + 2, y + 4), mark);
    }

    switch (highlight) {
      case 'bust':
        band(70, 30, 90);
      case 'talie':
        band(100, 36, 84);
      case 'sold':
        band(122, 26, 94);
      case 'gat':
        band(41, 53, 67);
      case 'umeri':
        canvas.drawLine(const Offset(28, 48), const Offset(92, 48), mark);
      case 'brat':
        canvas.drawLine(const Offset(18, 70), const Offset(30, 72), mark);
      case 'spate':
        canvas.drawLine(const Offset(60, 44), const Offset(60, 100), mark);
      case 'inaltimeSold':
        canvas.drawLine(const Offset(100, 100), const Offset(100, 122), mark);
        canvas.drawLine(const Offset(95, 100), const Offset(105, 100), mark);
        canvas.drawLine(const Offset(95, 122), const Offset(105, 122), mark);
    }
  }

  /// Un membru: o bandă de lățime [w] între două puncte.
  static Path _limb(Offset a, Offset b, double w) {
    final d = b - a;
    final n = Offset(-d.dy, d.dx) / d.distance * (w / 2);
    return Path()
      ..moveTo(a.dx + n.dx, a.dy + n.dy)
      ..lineTo(b.dx + n.dx, b.dy + n.dy)
      ..lineTo(b.dx - n.dx, b.dy - n.dy)
      ..lineTo(a.dx - n.dx, a.dy - n.dy)
      ..close();
  }

  @override
  bool shouldRepaint(_FigurePainter old) =>
      old.highlight != highlight || old.accent != accent;
}
