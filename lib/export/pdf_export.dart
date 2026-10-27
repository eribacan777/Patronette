import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../drawing/layout.dart';
import '../drawing/pattern_canvas.dart';
import '../format.dart';
import '../garments/garment.dart';
import '../geometry.dart';
import '../models/measurements.dart';
import '../models/pattern.dart';
import '../models/profile.dart';
import 'tiles.dart';

/// Desenează tiparul într-un PDF (implementarea `PatternCanvas` pentru PDF).
class PdfPatternCanvas implements PatternCanvas {
  PdfPatternCanvas(this.g, this.regular, this.bold, this.map, this.fix);

  final PdfGraphics g;
  final PdfFont regular;
  final PdfFont bold;

  /// Transformă centimetrii de pe planșă în puncte pe pagina PDF.
  final PdfPoint Function(Pt) map;

  /// Adaptează textul la font (vezi [stripDiacritics]).
  final String Function(String) fix;

  @override
  void polyline(List<Pt> pts,
      {bool closed = false,
      double width = 0.6,
      bool dashed = false,
      bool faint = false}) {
    if (pts.length < 2) return;
    g.setStrokeColor(faint ? PdfColors.grey400 : PdfColors.black);
    g.setLineWidth(width);
    if (dashed) g.setLineDashPattern([4, 3]);
    final first = map(pts.first);
    g.moveTo(first.x, first.y);
    for (final p in pts.skip(1)) {
      final q = map(p);
      g.lineTo(q.x, q.y);
    }
    if (closed) g.closePath();
    g.strokePath();
    if (dashed) g.setLineDashPattern([]);
  }

  @override
  void text(String s, Pt topLeft, {double size = 9, bool bold = false}) {
    final p = map(topLeft);
    g.setFillColor(PdfColors.black);
    // drawString primește linia de bază a textului, nu colțul de sus.
    g.drawString(bold ? this.bold : regular, size, fix(s), p.x, p.y - size * 0.85);
  }
}

class _Fonts {
  _Fonts(this.regular, this.bold, this.unicode);

  final pw.Font regular;
  final pw.Font bold;

  /// false = fonturile din aplicație lipsesc și folosim Helvetica,
  /// care nu are literele ă, ș, ț.
  final bool unicode;
}

Future<_Fonts> _loadFonts() async {
  try {
    final regular = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    final bold = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
    return _Fonts(pw.Font.ttf(regular), pw.Font.ttf(bold), true);
  } catch (_) {
    return _Fonts(pw.Font.helvetica(), pw.Font.helveticaBold(), false);
  }
}

/// Înlocuiește diacriticele pe care Helvetica nu le are.
String stripDiacritics(String s) {
  const map = {
    'ă': 'a', 'â': 'a', 'î': 'i', 'ș': 's', 'ş': 's', 'ț': 't', 'ţ': 't',
    'Ă': 'A', 'Â': 'A', 'Î': 'I', 'Ș': 'S', 'Ş': 'S', 'Ț': 'T', 'Ţ': 'T',
  };
  return s.split('').map((ch) => map[ch] ?? ch).join();
}

/// Construiește PDF-ul: o pagină de început cu instrucțiuni și harta
/// paginilor, apoi tiparul la scară reală, împărțit pe coli A4.
Future<Uint8List> buildPatternPdf({
  required Garment garment,
  required Draft draft,
  required Profile profile,
  required Map<String, double> options,
  required double seam,
  required double hem,
}) async {
  final fonts = await _loadFonts();
  String t(String s) => fonts.unicode ? s : stripDiacritics(s);

  final layout = PatternLayout.build(draft.pieces, seam: seam, hem: hem);
  final grid = TileGrid(layout);
  final footer = 'Patronette · ${garment.name} · ${profile.name}';
  const cm = PdfPageFormat.cm;
  const format = PdfPageFormat.a4;

  final doc = pw.Document(
    title: '${garment.name} – ${profile.name}',
    author: 'Patronette',
    creator: 'Patronette',
  );

  doc.addPage(pw.Page(
    pageFormat: format,
    margin: const pw.EdgeInsets.all(1.5 * cm),
    theme: pw.ThemeData.withFont(base: fonts.regular, bold: fonts.bold),
    build: (ctx) => _coverPage(ctx, t, fonts, garment, draft, profile, options,
        seam, hem, layout, grid),
  ));

  for (var r = 0; r < grid.rows; r++) {
    for (var c = 0; c < grid.cols; c++) {
      if (!grid.isUsed(r, c)) continue;
      doc.addPage(pw.Page(
        pageFormat: format,
        margin: pw.EdgeInsets.zero,
        build: (ctx) {
          final reg = fonts.regular.getFont(ctx);
          final bold = fonts.bold.getFont(ctx);
          return pw.CustomPaint(
            size: PdfPoint(format.width, format.height),
            painter: (g, size) => _paintTile(
                g, size, reg, bold, t, layout, grid, r, c, footer),
          );
        },
      ));
    }
  }
  return doc.save();
}

void _paintTile(
  PdfGraphics g,
  PdfPoint size,
  PdfFont reg,
  PdfFont bold,
  String Function(String) t,
  PatternLayout layout,
  TileGrid grid,
  int row,
  int col,
  String footer,
) {
  const cm = PdfPageFormat.cm;
  const m = TileGrid.margin;
  const tw = TileGrid.tileW, th = TileGrid.tileH;
  final h = size.y;
  final label = TileGrid.label(row, col);

  // Originea PDF-ului este jos-stânga, iar pe planșă sus-stânga.
  PdfPoint map(Pt p) => PdfPoint(
      (m + p.x - col * tw) * cm, h - (m + p.y - row * th) * cm);

  // Eticheta mare, gri, în fundal: ajută la lipirea paginilor.
  g.setFillColor(PdfColors.grey200);
  g.drawString(bold, 90, label, (m + tw / 2 - 2.2) * cm, h / 2 - 30);

  g.saveContext();
  g.drawRect(m * cm, h - (m + th) * cm, tw * cm, th * cm);
  g.clipPath();
  drawLayout(PdfPatternCanvas(g, reg, bold, map, t), layout, footer: footer);
  g.restoreContext();

  // Chenarul: pe el se taie marginea albă.
  g.setStrokeColor(PdfColors.grey600);
  g.setLineWidth(0.5);
  g.drawRect(m * cm, h - (m + th) * cm, tw * cm, th * cm);
  g.strokePath();

  // Romburi la mijlocul fiecărei laturi, de potrivit cu pagina vecină.
  final left = m * cm, right = (m + tw) * cm;
  final top = h - m * cm, bottom = h - (m + th) * cm;
  final midX = (left + right) / 2, midY = (top + bottom) / 2;
  for (final p in [
    PdfPoint(midX, top),
    PdfPoint(midX, bottom),
    PdfPoint(left, midY),
    PdfPoint(right, midY),
  ]) {
    const d = 0.25 * cm;
    g.setFillColor(PdfColors.grey700);
    g.moveTo(p.x, p.y + d);
    g.lineTo(p.x + d, p.y);
    g.lineTo(p.x, p.y - d);
    g.lineTo(p.x - d, p.y);
    g.closePath();
    g.fillPath();
  }

  g.setFillColor(PdfColors.grey800);
  g.drawString(reg, 8, t('$footer · pagina $label'), left, top + 0.35 * cm);
  g.drawString(
      reg,
      8,
      t('Rândul ${label[0]}, coloana ${col + 1}. Taie marginea albă de-a lungul '
          'chenarului și potrivește romburile cu paginile vecine.'),
      left,
      bottom - 0.6 * cm);
}

pw.Widget _coverPage(
  pw.Context ctx,
  String Function(String) t,
  _Fonts fonts,
  Garment garment,
  Draft draft,
  Profile profile,
  Map<String, double> options,
  double seam,
  double hem,
  PatternLayout layout,
  TileGrid grid,
) {
  const cm = PdfPageFormat.cm;
  final heading = pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold);
  const small = pw.TextStyle(fontSize: 9.5);

  final measurementLines = [
    for (final key in garment.measurementKeys)
      '${measurementDef(key).label}: ${fmtCm(garment.measure(profile.values, key))} cm',
  ];
  final optionLines = [
    for (final o in garment.options)
      '${o.label}: ${o.choices?[garment.option(options, o.key)] ?? '${fmtCm(garment.option(options, o.key))} cm'}',
    'Rezervă de cusătură: ${fmtCm(seam)} cm · tiv: ${fmtCm(hem)} cm',
  ];
  final steps = [
    'Printează la „Dimensiune reală” (100%), fără „Potrivire în pagină”.',
    'Măsoară pătratul de test: trebuie să aibă exact 5 × 5 cm.',
    'Taie marginea albă a paginilor de-a lungul chenarului și lipește-le cap '
        'la cap, în ordinea din hartă, potrivind romburile.',
    'Linia continuă este linia de tăiere, linia punctată este linia de cusătură.',
    'Taie din material câte bucăți scrie pe fiecare piesă. „Pe pliu” înseamnă '
        'că marginea aceea se așază pe îndoitura materialului.',
  ];

  pw.Widget lines(List<String> items) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          for (final s in items)
            pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 2),
                child: pw.Text(t(s), style: small)),
        ],
      );

  // Harta: toată planșa micșorată, cu paginile numerotate peste ea.
  final totalW = grid.cols * TileGrid.tileW;
  final totalH = grid.rows * TileGrid.tileH;
  final k = math.min(17 * cm / totalW, 7 * cm / totalH); // puncte per cm
  final mapSize = PdfPoint(totalW * k, totalH * k);
  final reg = fonts.regular.getFont(ctx);
  final bold = fonts.bold.getFont(ctx);

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(t('Patronette · ${garment.name}'),
          style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
      pw.Text(t('Tipar făcut pe măsurile pentru: ${profile.name}')),
      pw.SizedBox(height: 14),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(t('Măsuri folosite'), style: heading),
                lines(measurementLines),
                pw.SizedBox(height: 8),
                pw.Text(t('Setări'), style: heading),
                lines(optionLines),
                pw.SizedBox(height: 8),
                pw.Text(t('Piese'), style: heading),
                lines([for (final p in draft.pieces) '${p.name}: ${p.cutInfo}']),
              ],
            ),
          ),
          pw.SizedBox(width: 12),
          pw.Column(children: [
            pw.Container(
              width: 5 * cm,
              height: 5 * cm,
              decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.8)),
              alignment: pw.Alignment.center,
              child: pw.Text('5 × 5 cm', style: heading),
            ),
            pw.SizedBox(height: 4),
            pw.Text(t('Pătrat de test'), style: small),
          ]),
        ],
      ),
      pw.SizedBox(height: 12),
      pw.Text(t('Cum asamblezi tiparul'), style: heading),
      lines([for (var i = 0; i < steps.length; i++) '${i + 1}. ${steps[i]}']),
      if (draft.notes.isNotEmpty) ...[
        pw.SizedBox(height: 8),
        pw.Text(t('De reținut'), style: heading),
        lines([for (final n in draft.notes) '• $n']),
      ],
      pw.SizedBox(height: 12),
      pw.Text(
          t('Harta paginilor (${grid.usedCount} pagini de printat)'),
          style: heading),
      pw.SizedBox(height: 6),
      pw.CustomPaint(
        size: mapSize,
        painter: (g, size) {
          PdfPoint map(Pt p) => PdfPoint(p.x * k, size.y - p.y * k);
          drawLayout(
              PdfPatternCanvas(g, reg, bold, map, t), layout, showText: false);
          for (var r = 0; r < grid.rows; r++) {
            for (var c = 0; c < grid.cols; c++) {
              final b = grid.tile(r, c);
              final used = grid.isUsed(r, c);
              final p0 = map(Pt(b.minX, b.maxY));
              g.setStrokeColor(used ? PdfColors.blue700 : PdfColors.grey400);
              g.setLineWidth(used ? 0.8 : 0.4);
              if (!used) g.setLineDashPattern([2, 2]);
              g.drawRect(p0.x, p0.y, b.width * k, b.height * k);
              g.strokePath();
              if (!used) g.setLineDashPattern([]);
              if (used) {
                final center = map(Pt(b.minX + b.width / 2, b.minY + b.height / 2));
                g.setFillColor(PdfColors.blue700);
                g.drawString(bold, 10, TileGrid.label(r, c), center.x - 7, center.y - 4);
              }
            }
          }
        },
      ),
    ],
  );
}
