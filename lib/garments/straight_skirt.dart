import 'dart:math' as math;

import '../geometry.dart';
import '../models/measurements.dart';
import '../models/pattern.dart';
import 'common.dart';
import 'garment.dart';

/// Fustă dreaptă cu pense, cordon și fermoar la mijlocul spatelui.
///
/// Fiecare piesă reprezintă un sfert din fustă: de la mijlocul feței (sau
/// al spatelui) până la cusătura laterală.
class StraightSkirt extends Garment {
  const StraightSkirt();

  @override
  String get id => 'fusta-dreapta';
  @override
  String get name => 'Fustă dreaptă';
  @override
  String get description =>
      'Fustă clasică, cu pense în talie, cordon și fermoar la spate.';

  @override
  List<String> get measurementKeys => const ['talie', 'sold', 'inaltimeSold'];

  @override
  List<GarmentOption> get options => const [
        GarmentOption(
            key: 'lungime',
            label: 'Lungimea fustei',
            min: 40,
            max: 110,
            step: 1,
            defaultValue: 60),
        GarmentOption(
            key: 'largime',
            label: 'Lărgime în plus la șold',
            min: 2,
            max: 8,
            step: 0.5,
            defaultValue: 4),
      ];

  @override
  Draft draft(Measurements m, Map<String, double> o) {
    final waist = measure(m, 'talie');
    final hipBody = measure(m, 'sold');
    final hip = math.max(hipBody, waist);
    final hipDepth = measure(m, 'inaltimeSold');
    final length = math.max(option(o, 'lungime'), hipDepth + 10);

    // Sferturile: șoldul cu lărgimea aleasă, talia cu 1 cm lejeritate.
    final hipQuarter = (hip + option(o, 'largime')) / 4;
    final waistQuarter = (waist + 1) / 4;

    return Draft(
      pieces: [
        _panel(true, hipQuarter, waistQuarter, hipDepth, length),
        _panel(false, hipQuarter, waistQuarter, hipDepth, length),
        waistband(waist),
      ],
      notes: [
        'Lasă deschis 18 cm la mijlocul spatelui pentru fermoar.',
        if (hipBody < waist)
          'Talia este mai mare decât șoldul, așa că fusta va cădea drept, '
              'fără pense.',
      ],
    );
  }

  PatternPiece _panel(bool front, double hipQuarter, double waistQuarter,
      double hipDepth, double length) {
    // Diferența talie–șold se strânge parțial din lateral, restul din pense.
    final diff = hipQuarter - waistQuarter;
    final side = math.min(diff, 2.5);
    final dartTotal = diff - side;

    // Talia urcă puțin în lateral, iar la spate coboară 1 cm la mijloc.
    final rise = math.min(1.0, side * 0.6);
    final centerY = front ? 0.0 : 1.0;
    final waistSide = Pt(hipQuarter - side, -rise);

    final waistCurve = CubicSeg(
      Pt(0, centerY),
      Pt(waistSide.x * 0.4, centerY),
      Pt(waistSide.x * 0.8, centerY + (waistSide.y - centerY) * 0.4),
      waistSide,
    );
    final outline = <Segment>[
      waistCurve,
      CubicSeg(
        waistSide,
        Pt(waistSide.x + side * 0.5, waistSide.y + hipDepth * 0.3),
        Pt(hipQuarter, hipDepth * 0.55),
        Pt(hipQuarter, hipDepth),
      ),
      LineSeg(Pt(hipQuarter, hipDepth), Pt(hipQuarter, length)),
      LineSeg(Pt(hipQuarter, length), Pt(0, length), EdgeKind.hem),
      LineSeg(Pt(0, length), Pt(0, centerY),
          front ? EdgeKind.fold : EdgeKind.seam),
    ];

    // Peste 3,5 cm, o singură pensă ar fi prea adâncă: o împărțim în două.
    final count = dartTotal > 3.5 ? 2 : (dartTotal > 0.3 ? 1 : 0);
    final waistPts = waistCurve.sample();
    final darts = <List<Pt>>[
      for (var i = 0; i < count; i++)
        dart(
          waistPts,
          count == 1 ? waistSide.x * 0.55 : waistSide.x * (i == 0 ? 0.4 : 0.7),
          dartTotal / count,
          (front ? 9.0 : 13.0) - i * 1.5,
        ),
    ];

    return PatternPiece(
      name: front ? 'Față' : 'Spate',
      cutInfo: front ? 'Taie 1 pe pliu' : 'Taie 2 (în oglindă)',
      outline: outline,
      markings: darts,
      grainFrom: Pt(hipQuarter * 0.2, hipDepth + 4),
      grainTo: Pt(hipQuarter * 0.2, length - 5),
      labelAt: Pt(hipQuarter * 0.3, hipDepth + 6),
    );
  }
}
