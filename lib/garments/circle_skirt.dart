import 'dart:math' as math;

import '../format.dart';
import '../geometry.dart';
import '../models/measurements.dart';
import '../models/pattern.dart';
import 'common.dart';
import 'garment.dart';

/// Fustă cloș: un inel de cerc (întreg sau jumătate) tăiat din patru sferturi.
///
/// Talia este cercul mic: raza lui se alege astfel încât lungimea
/// cercului să fie egală cu talia. Tivul este cercul mare.
class CircleSkirt extends Garment {
  const CircleSkirt();

  @override
  String get id => 'fusta-clos';
  @override
  String get name => 'Fustă cloș';
  @override
  String get description =>
      'Fustă evazată dintr-un cerc sau semicerc. Fără pense, ușor de cusut.';

  @override
  List<String> get measurementKeys => const ['talie'];

  @override
  // Fără `const`: o hartă constantă nu poate avea chei de tip double.
  List<GarmentOption> get options => [
        GarmentOption(
          key: 'tip',
          label: 'Cât de evazată',
          min: 0.5,
          max: 1,
          step: 0.5,
          defaultValue: 1,
          choices: {1: 'Cerc întreg', 0.5: 'Semicerc'},
        ),
        const GarmentOption(
            key: 'lungime',
            label: 'Lungimea fustei',
            min: 30,
            max: 100,
            step: 1,
            defaultValue: 55),
      ];

  @override
  Draft draft(Measurements m, Map<String, double> o) {
    final waist = measure(m, 'talie');
    final fraction = option(o, 'tip'); // 1 = cerc întreg, 0,5 = semicerc
    final length = option(o, 'lungime');

    // Lungimea cercului = 2πr, deci raza = talie / 2π
    // (pentru semicerc, talia ocupă doar jumătate de cerc).
    final r = waist / (2 * math.pi * fraction);
    final bigR = r + length;
    // Fiecare piesă e un sfert din fustă: 90° la cerc întreg, 45° la semicerc.
    final angle = math.pi * fraction / 2;

    const center = Pt(0, 0);
    final hemArc = ArcSeg(center, bigR, 0, angle, EdgeKind.hem);
    final waistArc = ArcSeg(center, r, angle, 0);
    final outline = <Segment>[
      LineSeg(Pt(0, r), Pt(0, bigR), EdgeKind.fold),
      hemArc,
      LineSeg(hemArc.end, waistArc.start),
      waistArc,
    ];

    final labelPoint =
        ArcSeg(center, r + length * 0.3, 0, angle).pointAt(angle * 0.3);

    final piece = PatternPiece(
      name: 'Fustă (față și spate)',
      cutInfo: 'Taie 2 pe pliu',
      outline: outline,
      grainFrom: Pt(2.5, r + 4),
      grainTo: Pt(2.5, bigR - 6),
      labelAt: labelPoint,
    );

    String cm(double v) => fmtCm(double.parse(v.toStringAsFixed(1)));
    return Draft(
      pieces: [piece, waistband(waist)],
      notes: [
        'Raza taliei: ${cm(r)} cm. Raza tivului: ${cm(bigR)} cm.',
        'Lasă fusta să atârne o zi înainte de tiv: pe porțiunile oblice '
            'materialul se lungește.',
        'Fermoarul se coase în cusătura laterală.',
        if (bigR > 72)
          'Piesa are peste 72 cm: pe un material de 150 cm pliat în două '
              's-ar putea să nu încapă.',
      ],
    );
  }
}
