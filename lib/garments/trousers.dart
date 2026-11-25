import 'dart:math' as math;

import '../format.dart';
import '../geometry.dart';
import '../models/measurements.dart';
import '../models/pattern.dart';
import 'garment.dart';

/// Pantaloni cu talie pe elastic, fără fermoar și fără pense: cel mai
/// simplu model de pantaloni de cusut.
///
/// Fiecare picior are o față și un spate. Partea de sus se pliază peste
/// elastic, ca un tunel, așa că talia de sus e la fel de largă ca șoldul
/// și pantalonii trec peste el.
///
/// Coordonatele: y = 0 este linia taliei (unde se pliază tunelul), iar
/// x = 0 este vârful dintre picioare (punctul de la crăcană).
class Trousers extends Garment {
  const Trousers();

  /// Cât se pliază sus pentru tunel: elastic de 2,5 cm + 1,5 cm joc.
  static const casing = 4.0;

  @override
  String get id => 'pantaloni';
  @override
  String get name => 'Pantaloni';
  @override
  String get description =>
      'Pantaloni comozi cu talie pe elastic, fără fermoar și fără pense. '
      'Drepți sau evazați.';

  @override
  List<String> get measurementKeys =>
      const ['talie', 'sold', 'inaltimeSold', 'inaltimeSezut', 'lungimePicior'];

  @override
  List<GarmentOption> get options => const [
        GarmentOption(
            key: 'scurtare',
            label: 'Mai scurți decât glezna cu',
            min: 0,
            max: 50,
            step: 1,
            defaultValue: 0),
        GarmentOption(
            key: 'tiv',
            label: 'Lățimea piciorului la tiv (circumferință)',
            min: 34,
            max: 70,
            step: 1,
            defaultValue: 44),
        GarmentOption(
            key: 'largime',
            label: 'Lărgime în plus la șold',
            min: 4,
            max: 16,
            step: 1,
            defaultValue: 8),
      ];

  @override
  Draft draft(Measurements m, Map<String, double> o) {
    final waist = measure(m, 'talie');
    final hipBody = measure(m, 'sold');
    final hipY = measure(m, 'inaltimeSold');
    final seat = measure(m, 'inaltimeSezut');
    final leg = measure(m, 'lungimePicior');

    // Talia trebuie să treacă peste șold, deci lucrăm cu cea mai mare dintre ele.
    final hip = math.max(hipBody, waist) + option(o, 'largime');
    // Crăcana coboară 1,5 cm sub înălțimea de șezut, ca să nu tragă.
    final crotchY = math.max(seat + 1.5, hipY + 4);
    final length = math.max(leg - option(o, 'scurtare'), crotchY + 15);
    final kneeY = crotchY + (length - crotchY) / 2 - 4;
    final hemQuarter = option(o, 'tiv') / 4;

    final front = _leg(
      front: true,
      width: hip / 4 - 1,
      extension: hip / 16,
      hipY: hipY,
      crotchY: crotchY,
      kneeY: kneeY,
      length: length,
      hemHalf: hemQuarter - 1,
    );
    final back = _leg(
      front: false,
      width: hip / 4 + 1,
      extension: hip / 10,
      hipY: hipY,
      crotchY: crotchY + 1,
      kneeY: kneeY,
      length: length,
      hemHalf: hemQuarter + 1,
    );

    // Elasticul e cu 8% mai scurt decât talia, ca să țină pantalonii sus.
    final elastic = double.parse((waist * 0.92).toStringAsFixed(0));
    return Draft(
      pieces: [front, back],
      notes: [
        'Elastic lat de 2,5 cm, lung de ${fmtCm(elastic)} cm, cusut în cerc.',
        'Coase întâi fiecare picior: cusătura laterală și cea interioară. '
            'Apoi întoarce un picior pe față, bagă-l în celălalt și coase '
            'cusătura din mijloc dintr-o singură trecere.',
        'Cusătura interioară de la spate e puțin mai scurtă: întinde-o ușor '
            'când o coși, ca să se potrivească.',
        'Sus, pliază tunelul pe linie, coase-l lăsând 5 cm deschiși, trage '
            'elasticul prin el și închide deschiderea.',
      ],
    );
  }

  /// O jumătate de picior (față sau spate). La spate, mijlocul se ridică
  /// și se înclină puțin, ca să fie loc de șezut.
  PatternPiece _leg({
    required bool front,
    required double width,
    required double extension,
    required double hipY,
    required double crotchY,
    required double kneeY,
    required double length,
    required double hemHalf,
  }) {
    final rise = front ? 0.0 : 2.5; // cât urcă talia la mijlocul spatelui
    final tilt = front ? 0.0 : 1.5; // cât se înclină mijlocul spatelui

    final centerTop = Pt(extension + tilt, -casing - rise);
    final sideTop = Pt(extension + width + tilt, -casing);
    final sideHip = Pt(extension + width, hipY);
    final centerHip = Pt(extension, hipY);
    final crotch = Pt(0, crotchY);

    // Dunga piciorului: la mijlocul lățimii, la nivelul crăcanei.
    final crease = (extension + width) / 2;
    final kneeHalf = hemHalf + 1.5;
    final kneeOut = Pt(crease + kneeHalf, kneeY);
    final kneeIn = Pt(crease - kneeHalf, kneeY);
    final hemOut = Pt(crease + hemHalf, length);
    final hemIn = Pt(crease - hemHalf, length);

    final outline = <Segment>[
      LineSeg(centerTop, sideTop),
      LineSeg(sideTop, sideHip),
      CubicSeg(
        sideHip,
        Pt(sideHip.x, hipY + (kneeY - hipY) * 0.35),
        Pt(kneeOut.x, kneeY - (kneeY - hipY) * 0.35),
        kneeOut,
      ),
      LineSeg(kneeOut, hemOut),
      LineSeg(hemOut, hemIn, EdgeKind.hem),
      LineSeg(hemIn, kneeIn),
      // Cusătura interioară se arcuiește ușor spre crăcană.
      CubicSeg(
        kneeIn,
        Pt(kneeIn.x, kneeY - (kneeY - crotchY) * 0.45),
        Pt(kneeIn.x * 0.25, crotchY + (kneeY - crotchY) * 0.15),
        crotch,
      ),
      // Curba crăcanei, de la vârf până la linia șoldului.
      CubicSeg(
        crotch,
        Pt(extension * 0.55, crotchY),
        Pt(extension, math.max(hipY, crotchY - extension * 0.7)),
        centerHip,
      ),
      LineSeg(centerHip, centerTop),
    ];

    // Linia pe care se pliază tunelul, paralelă cu marginea de sus.
    final t = (hipY + rise) / (hipY + casing + rise);
    final foldCenter = Pt(extension + tilt * t, -rise);

    return PatternPiece(
      name: front ? 'Față' : 'Spate',
      cutInfo: 'Taie 2 (în oglindă)',
      copies: 2,
      outline: outline,
      markings: [
        [foldCenter, Pt(sideTop.x - tilt * 0.05, 0)],
      ],
      grainFrom: Pt(crease, crotchY + 3),
      grainTo: Pt(crease, length - 5),
      labelAt: Pt(extension + 1.5, 1.5),
    );
  }
}
