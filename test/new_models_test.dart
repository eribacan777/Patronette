import 'package:croi/fabric/fabric_plan.dart';
import 'package:croi/garments/long_dress.dart';
import 'package:croi/garments/trousers.dart';
import 'package:croi/geometry.dart';
import 'package:croi/models/measurements.dart';
import 'package:croi/models/pattern.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lungimea conturului dintre două puncte ale piesei (segmentele dintre ele).
double edgeLength(PatternPiece p, int from, int to) => [
      for (var i = from; i <= to; i++) p.outline[i].length,
    ].fold(0.0, (a, b) => a + b);

void main() {
  final m = kExampleMeasurements;

  group('Rochie lungă', () {
    const dress = LongDress();

    test('mâneca lungă se potrivește în răscroială', () {
      final d = dress.draft(m, dress.defaultOptions);
      final armhole = d.pieces[0].outline[2].length;
      final sleeve = d.pieces[2];
      expect(sleeve.outline.first.length, closeTo(armhole, 0.1));
      expect(Bounds.of(sleeve.seamLine).height, closeTo(58, 1e-6));
    });

    test('la șold e cu cel puțin 6 cm mai largă decât corpul', () {
      final d = dress.draft(m, dress.defaultOptions);
      final front = d.pieces[0];
      final hipY = m['spate']! + m['inaltimeSold']!;
      final widthAtHip = yAtXInverse(front.seamLine, hipY);
      expect(widthAtHip * 4, greaterThanOrEqualTo(m['sold']! + 6 - 1e-6));
    });

    test('din material neelastic spatele are cusătură, din jerseu e pe pliu', () {
      final woven = dress.draft(m, dress.defaultOptions);
      final knit = dress.draft(
          m, {...dress.defaultOptions, 'material': LongDress.elastic});
      expect(woven.pieces[1].onFold, isFalse);
      expect(woven.pieces[1].copies, 2);
      expect(knit.pieces[1].onFold, isTrue);
      expect(knit.pieces[3].name, 'Bentiță gât');
      expect(woven.pieces[3].name, 'Bie gât');
    });

    test('mâna trece prin manșetă (cel puțin 22 cm la neelastic)', () {
      final d = dress.draft(m, dress.defaultOptions);
      final sleeve = d.pieces[2];
      final hem = sleeve.outline.firstWhere((s) => s.kind == EdgeKind.hem);
      expect(hem.length * 2, greaterThanOrEqualTo(22 - 1e-6));
    });

    test('cantitatea de material e realistă', () {
      final d = dress.draft(m, dress.defaultOptions);
      final plan = FabricPlan.compute(d.pieces, fabricWidth: 150, seam: 1, hem: 2);
      expect(plan.fits, isTrue);
      expect(plan.metersToBuy, inInclusiveRange(2.2, 3.5));
    });
  });

  group('Pantaloni', () {
    const trousers = Trousers();

    test('talia de sus trece peste șold', () {
      final d = trousers.draft(m, trousers.defaultOptions);
      final top = d.pieces[0].outline[0].length + d.pieces[1].outline[0].length;
      // Patru piese: două fețe și două spate.
      expect(top * 2, greaterThanOrEqualTo(m['sold']! + 4));
    });

    test('lungimea e cea a piciorului, minus scurtarea aleasă', () {
      final full = trousers.draft(m, trousers.defaultOptions);
      final cropped =
          trousers.draft(m, {...trousers.defaultOptions, 'scurtare': 20});
      expect(Bounds.of(full.pieces[0].seamLine).maxY, closeTo(m['lungimePicior']!, 1e-6));
      expect(Bounds.of(cropped.pieces[0].seamLine).maxY,
          closeTo(m['lungimePicior']! - 20, 1e-6));
    });

    test('cusăturile laterale și interioare au aproape aceeași lungime', () {
      final d = trousers.draft(m, trousers.defaultOptions);
      final front = d.pieces[0], back = d.pieces[1];
      // Lateral: segmentele 1–3 (sus → genunchi) + 4 (genunchi → tiv).
      expect(edgeLength(back, 1, 3), closeTo(edgeLength(front, 1, 3), 1.0));
      // Interior: 5 (tiv → genunchi) + 6 (genunchi → crăcană). Spatele e
      // puțin mai scurt și se întinde la cusut.
      final inFront = edgeLength(front, 5, 6), inBack = edgeLength(back, 5, 6);
      expect(inBack, lessThanOrEqualTo(inFront + 1e-6));
      expect(inFront - inBack, lessThan(2));
    });

    test('lățimea la tiv urmează opțiunea aleasă', () {
      final d = trousers.draft(m, {...trousers.defaultOptions, 'tiv': 50});
      final hems = d.pieces
          .map((p) => p.outline.firstWhere((s) => s.kind == EdgeKind.hem).length);
      expect(hems.fold(0.0, (a, b) => a + b), closeTo(50, 1e-6));
    });

    test('cantitatea de material e realistă', () {
      final d = trousers.draft(m, trousers.defaultOptions);
      final plan = FabricPlan.compute(d.pieces, fabricWidth: 150, seam: 1, hem: 2);
      expect(plan.fits, isTrue);
      expect(plan.metersToBuy, inInclusiveRange(1.0, 1.8));
    });
  });
}

/// Cât de lată e piesa (x maxim) la înălțimea [y], pe conturul ei.
double yAtXInverse(List<Pt> poly, double y) {
  var best = 0.0;
  for (var i = 0; i < poly.length; i++) {
    final a = poly[i], b = poly[(i + 1) % poly.length];
    if ((a.y - y) * (b.y - y) <= 0 && a.y != b.y) {
      final x = a.x + (b.x - a.x) * (y - a.y) / (b.y - a.y);
      if (x > best) best = x;
    }
  }
  return best;
}
