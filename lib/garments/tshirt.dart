import 'dart:math' as math;

import '../format.dart';
import '../geometry.dart';
import '../models/measurements.dart';
import '../models/pattern.dart';
import 'common.dart';
import 'garment.dart';

/// Tricou lejer, cu mânecă scurtă sau lungă, din material elastic.
///
/// Coordonatele pornesc din punctul cel mai înalt al umărului, de lângă gât
/// (y = 0), iar x = 0 este mijlocul feței sau al spatelui (pe pliu).
class TShirt extends Garment {
  const TShirt();

  @override
  String get id => 'tricou';
  @override
  String get name => 'Tricou';
  @override
  String get description =>
      'Tricou lejer din tricot, cu mânecă scurtă sau lungă și bentiță la gât.';

  @override
  List<String> get measurementKeys => const ['bust', 'gat', 'umeri', 'brat'];

  @override
  List<GarmentOption> get options => const [
        GarmentOption(
            key: 'lungime',
            label: 'Lungimea tricoului',
            min: 50,
            max: 90,
            step: 1,
            defaultValue: 66),
        GarmentOption(
            key: 'maneca',
            label: 'Lungimea mânecii',
            min: 10,
            max: 65,
            step: 1,
            defaultValue: 20),
        GarmentOption(
            key: 'largime',
            label: 'Lărgime în plus la bust',
            min: 4,
            max: 20,
            step: 1,
            defaultValue: 10),
      ];

  @override
  Draft draft(Measurements m, Map<String, double> o) {
    final bust = measure(m, 'bust');
    final neck = measure(m, 'gat');
    final shoulders = measure(m, 'umeri');
    final arm = measure(m, 'brat');
    final ease = option(o, 'largime');

    final halfWidth = (bust + ease) / 4;
    final neckWidth = neck / 6 + 1;
    final armholeDepth = bust / 6 + 8;
    final length = math.max(option(o, 'lungime'), armholeDepth + 10);
    // Umărul coboară 4,5 cm de la gât până la capătul lui.
    final shoulderX =
        math.max(math.min(shoulders / 2, halfWidth - 2), neckWidth + 4);
    final shoulderPoint = Pt(shoulderX, 4.5);
    final underarm = Pt(halfWidth, armholeDepth);

    // Răscroiala: coboară aproape vertical, apoi se rotunjește spre subraț.
    final armhole = CubicSeg(
      shoulderPoint,
      Pt(shoulderX - 0.3, 4.5 + (armholeDepth - 4.5) * 0.5),
      Pt(shoulderX + (halfWidth - shoulderX) * 0.25, armholeDepth),
      underarm,
    );

    CubicSeg neckline(double depth) => CubicSeg(
          Pt(0, depth),
          Pt(neckWidth * 0.55, depth),
          Pt(neckWidth, depth * 0.55),
          Pt(neckWidth, 0),
        );
    final frontNeck = neckline(neck / 6 + 2);
    final backNeck = neckline(2);

    PatternPiece body(bool front) {
      final neckSeg = front ? frontNeck : backNeck;
      return PatternPiece(
        name: front ? 'Față' : 'Spate',
        cutInfo: 'Taie 1 pe pliu',
        outline: [
          neckSeg,
          LineSeg(Pt(neckWidth, 0), shoulderPoint),
          armhole,
          LineSeg(underarm, Pt(halfWidth, length)),
          LineSeg(Pt(halfWidth, length), Pt(0, length), EdgeKind.hem),
          LineSeg(Pt(0, length), neckSeg.start, EdgeKind.fold),
        ],
        grainFrom: Pt(halfWidth * 0.25, armholeDepth + 2),
        grainTo: Pt(halfWidth * 0.25, length - 5),
        labelAt: Pt(halfWidth * 0.35, armholeDepth + 4),
      );
    }

    final sleeve = fittedSleeve(
        arm: arm,
        ease: ease,
        armholeLength: armhole.length,
        length: option(o, 'maneca'));

    // Bentița e cu 15% mai scurtă decât decolteul, ca să stea întinsă.
    final neckOpening = 2 * (frontNeck.length + backNeck.length);
    final band = foldedStrip(
      name: 'Bentiță gât',
      cutInfo: 'Taie 1 din material elastic',
      length: neckOpening * 0.85,
      width: 5,
    );

    String cm(double v) => fmtCm(double.parse(v.toStringAsFixed(1)));
    return Draft(
      pieces: [body(true), body(false), sleeve.piece, band],
      notes: [
        'Capul mânecii: ${cm(sleeve.capLength * 2)} cm; '
            'răscroiala față + spate: ${cm(armhole.length * 2)} cm.',
        if (sleeve.tooWide)
          'Brațul este lat față de răscroială. Mărește lărgimea la bust '
              'ca mâneca să se potrivească.',
      ],
    );
  }
}
