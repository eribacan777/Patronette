import 'package:croi/drawing/pattern_canvas.dart';
import 'package:croi/fabric/fabric_plan.dart';
import 'package:croi/garments/catalog.dart';
import 'package:croi/garments/long_dress.dart';
import 'package:croi/garments/straight_skirt.dart';
import 'package:croi/garments/trousers.dart';
import 'package:croi/geometry.dart';
import 'package:croi/models/measurements.dart';
import 'package:croi/sewing/guides.dart';
import 'package:croi/sewing/sewing_screen.dart';
import 'package:croi/sewing/sketches.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// O „foaie” care doar ține minte ce s-a desenat.
class _Recorder implements PatternCanvas {
  final points = <Pt>[];
  int lines = 0;

  @override
  void polyline(List<Pt> pts,
      {bool closed = false, double width = 0.6, bool dashed = false, bool faint = false}) {
    lines++;
    points.addAll(pts);
  }

  @override
  void text(String s, Pt topLeft, {double size = 9, bool bold = false}) {}
}

void main() {
  final m = kExampleMeasurements;

  test('fiecare model are instrucțiuni complete', () {
    for (final g in kGarments) {
      final guide = sewingGuide(g, g.defaultOptions, m);
      expect(guide.steps.length, greaterThanOrEqualTo(5), reason: g.name);
      expect(guide.supplies, isNotEmpty, reason: g.name);
      expect(guide.level, isNotEmpty, reason: g.name);
      for (final s in guide.steps) {
        expect(s.title.trim(), isNotEmpty, reason: g.name);
        expect(s.text.length, greaterThan(20), reason: '${g.name}: ${s.title}');
      }
    }
  });

  test('fiecare schiță se desenează în interiorul cutiei ei', () {
    for (final s in Sketch.values) {
      final r = _Recorder();
      drawSketch(r, s);
      expect(r.lines, greaterThan(0), reason: s.name);
      for (final p in r.points) {
        expect(p.x, inInclusiveRange(0, sketchWidth), reason: s.name);
        expect(p.y, inInclusiveRange(0, sketchHeight), reason: s.name);
      }
    }
  });

  test('rochia: pașii depind de material', () {
    const dress = LongDress();
    final woven = sewingGuide(dress, dress.defaultOptions, m);
    final knit =
        sewingGuide(dress, {...dress.defaultOptions, 'material': LongDress.elastic}, m);
    final wovenText = woven.steps.map((s) => s.title).join(' ');
    final knitText = knit.steps.map((s) => s.title).join(' ');
    expect(wovenText, contains('Bie'));
    expect(wovenText, contains('nasturele'));
    expect(knitText, contains('Bentița'));
    expect(knitText, isNot(contains('nasturele')));
    expect(knit.supplies.join(), contains('tricot'));
  });

  test('pantalonii: elasticul din listă e cel de pe tipar', () {
    const trousers = Trousers();
    final guide = sewingGuide(trousers, trousers.defaultOptions, m);
    final elastic = Trousers.elasticLength(m['talie']!);
    expect(guide.supplies.join(), contains('lung de ${elastic.toStringAsFixed(0)} cm'));
    final notes = trousers.draft(m, trousers.defaultOptions).notes.join();
    expect(notes, contains('lung de ${elastic.toStringAsFixed(0)} cm'));
  });

  test('materialul de cumpărat apare în listă', () {
    const skirt = StraightSkirt();
    final plan = FabricPlan.compute(skirt.draft(m, skirt.defaultOptions).pieces,
        fabricWidth: 150, seam: 1, hem: 2);
    final guide = sewingGuide(skirt, skirt.defaultOptions, m, fabric: plan);
    expect(guide.supplies.first, startsWith('Material: '));
    expect(guide.supplies.join(), contains('Fermoar de 18 cm'));
  });

  testWidgets('pașii se bifează și rămân bifați', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    const trousers = Trousers();
    final guide = sewingGuide(trousers, trousers.defaultOptions, m);
    Widget screen() => MaterialApp(
          home: SewingScreen(garmentId: 'pantaloni', garmentName: 'Pantaloni', guide: guide),
        );

    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    expect(find.text('0 din ${guide.steps.length} pași'), findsOneWidget);
    expect(find.byType(SketchView), findsWidgets);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(find.text('1 din ${guide.steps.length} pași'), findsOneWidget);

    // Altă deschidere a ecranului: bifa e tot acolo.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    expect(find.text('1 din ${guide.steps.length} pași'), findsOneWidget);
  });
}
