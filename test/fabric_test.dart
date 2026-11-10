import 'package:croi/fabric/fabric_plan.dart';
import 'package:croi/garments/catalog.dart';
import 'package:croi/garments/circle_skirt.dart';
import 'package:croi/geometry.dart';
import 'package:croi/models/measurements.dart';
import 'package:flutter_test/flutter_test.dart';

FabricPlan planFor(String id, double width, {Map<String, double>? options}) {
  final g = kGarments.firstWhere((g) => g.id == id);
  final draft = g.draft(kExampleMeasurements, options ?? g.defaultOptions);
  return FabricPlan.compute(draft.pieces, fabricWidth: width, seam: 1, hem: 2);
}

/// Puncte la fiecare centimetru pe conturul unei forme.
List<Pt> densify(List<Pt> shape) => [
      for (var i = 0; i < shape.length; i++)
        for (var k = 0; k < 4; k++)
          Pt(shape[i].x + (shape[(i + 1) % shape.length].x - shape[i].x) * k / 4,
              shape[i].y + (shape[(i + 1) % shape.length].y - shape[i].y) * k / 4),
    ];

/// Punct în interiorul poligonului (metoda razei), cu o mică toleranță.
bool inside(Pt p, List<Pt> poly) {
  var hit = false;
  for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    final a = poly[i], b = poly[j];
    if ((a.y > p.y) != (b.y > p.y) &&
        p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x - 0.05) {
      hit = !hit;
    }
  }
  return hit;
}

void main() {
  test('se taie fiecare piesă de câte ori trebuie', () {
    for (final g in kGarments) {
      final draft = g.draft(kExampleMeasurements, g.defaultOptions);
      final plan = FabricPlan.compute(draft.pieces, fabricWidth: 150, seam: 1, hem: 2);
      for (final piece in draft.pieces) {
        final made = plan.cuts
            .where((c) => c.piece == piece)
            .fold<int>(0, (sum, c) => sum + c.yields);
        expect(made, piece.copies, reason: '${g.name} / ${piece.name}');
      }
    }
  });

  test('piesele nu se suprapun și stau pe material', () {
    for (final g in kGarments) {
      for (final width in [110.0, 140.0, 150.0]) {
        final plan = planFor(g.id, width);
        if (!plan.fits) continue;
        for (final c in plan.cuts) {
          expect(c.bounds.minX, greaterThanOrEqualTo(-1e-6), reason: g.name);
          expect(c.bounds.maxX, lessThanOrEqualTo(plan.usableWidth + 1e-6), reason: g.name);
        }
        // Piesele se pot îmbuca (o bandă în colțul unui sfert de cerc),
        // deci verificăm formele reale: niciun punct de pe conturul unei
        // piese nu are voie să cadă în interiorul alteia.
        for (var i = 0; i < plan.cuts.length; i++) {
          for (var j = 0; j < plan.cuts.length; j++) {
            if (i == j) continue;
            for (final shape in plan.cuts[i].shapes) {
              for (final p in densify(shape)) {
                for (final other in plan.cuts[j].shapes) {
                  expect(inside(p, other), isFalse,
                      reason: '${g.name} $width: ${plan.cuts[i].piece.name} / ${plan.cuts[j].piece.name}');
                }
              }
            }
          }
        }
      }
    }
  });

  test('piesele pe pliu stau lipite de îndoitură', () {
    final plan = planFor('fusta-dreapta', 150);
    final front = plan.cuts.firstWhere((c) => c.piece.name == 'Față');
    expect(front.againstFold, isTrue);
    expect(front.bounds.minX, closeTo(0, 1e-6));
  });

  test('cantitățile sunt realiste', () {
    // Valori obișnuite din croitorie, pentru mărimea 38 la 150 cm lățime.
    expect(planFor('fusta-dreapta', 150).metersToBuy, inInclusiveRange(0.6, 1.3));
    expect(planFor('tricou', 150).metersToBuy, inInclusiveRange(0.8, 1.9));
    expect(planFor('corsaj', 150).metersToBuy, inInclusiveRange(0.4, 1.0));
  });

  test('un material mai îngust nu cere mai puțin material', () {
    for (final g in kGarments) {
      expect(planFor(g.id, 110).length,
          greaterThanOrEqualTo(planFor(g.id, 150).length - 1e-6), reason: g.name);
    }
  });

  test('fusta cloș prea lungă nu încape pe material îngust', () {
    const skirt = CircleSkirt();
    final draft = skirt.draft(kExampleMeasurements, {'tip': 1, 'lungime': 80});
    final plan = FabricPlan.compute(draft.pieces, fabricWidth: 110, seam: 1, hem: 2);
    expect(plan.fits, isFalse);
    expect(plan.tooWide, contains('Fustă (față și spate)'));
  });

  test('metrii se rotunjesc în sus la 10 cm', () {
    final plan = planFor('fusta-dreapta', 150);
    final m = plan.metersToBuy;
    expect((m * 10).roundToDouble(), closeTo(m * 10, 1e-9));
    expect(m * 100, greaterThanOrEqualTo(plan.length + FabricPlan.extra - 1e-6));
    // Afișare: un singur desen al lungimii, fără valori ciudate.
    expect(Bounds.of(plan.cuts.expand((c) => c.shapes.expand((s) => s))).maxY,
        closeTo(plan.length, 1e-6));
  });
}
