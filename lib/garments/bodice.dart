import 'dart:math' as math;

import '../geometry.dart';
import '../models/measurements.dart';
import '../models/pattern.dart';
import 'common.dart';
import 'garment.dart';

/// Corsaj de bază simplificat (fără pensă de bust), până în talie.
/// Este punctul de plecare pentru bluze și rochii.
class BasicBodice extends Garment {
  const BasicBodice();

  @override
  String get id => 'corsaj';
  @override
  String get name => 'Corsaj de bază';
  @override
  String get description =>
      'Tipar de bază până în talie, cu pense. Punct de plecare pentru bluze '
      'și rochii.';

  @override
  List<String> get measurementKeys =>
      const ['bust', 'talie', 'gat', 'umeri', 'spate'];

  @override
  List<GarmentOption> get options => const [
        GarmentOption(
            key: 'largime',
            label: 'Lărgime în plus la bust',
            min: 4,
            max: 12,
            step: 1,
            defaultValue: 8),
      ];

  @override
  Draft draft(Measurements m, Map<String, double> o) {
    final bust = measure(m, 'bust');
    final waist = measure(m, 'talie');
    final neck = measure(m, 'gat');
    final shoulders = measure(m, 'umeri');

    final halfWidth = (bust + option(o, 'largime')) / 4;
    final waistQuarter = (waist + 3) / 4;
    final neckWidth = neck / 6 + 0.5;
    final armholeDepth = bust / 6 + 6;
    final waistY = math.max(measure(m, 'spate'), armholeDepth + 8);

    final shoulderX =
        math.max(math.min(shoulders / 2, halfWidth - 1.5), neckWidth + 4);
    final shoulderPoint = Pt(shoulderX, 4.5);
    final underarm = Pt(halfWidth, armholeDepth);
    final armhole = CubicSeg(
      shoulderPoint,
      Pt(shoulderX - 0.5, 4.5 + (armholeDepth - 4.5) * 0.5),
      Pt(shoulderX + (halfWidth - shoulderX) * 0.3, armholeDepth),
      underarm,
    );

    // Diferența bust–talie: 40% din lateral (cel mult 3 cm), restul din pensă.
    final diff = math.max(0.0, halfWidth - waistQuarter);
    final side = math.min(diff * 0.4, 3.0);
    final dartWidth = diff - side;

    PatternPiece piece(bool front) {
      final neckDepth = front ? neck / 6 + 1.5 : 2.0;
      // În față talia coboară 1,5 cm la mijloc, pentru volumul bustului.
      final centerWaistY = front ? waistY + 1.5 : waistY;
      final waistSide = Pt(halfWidth - side, waistY);

      final neckSeg = CubicSeg(
        Pt(0, neckDepth),
        Pt(neckWidth * 0.55, neckDepth),
        Pt(neckWidth, neckDepth * 0.55),
        Pt(neckWidth, 0),
      );
      final waistSeg = CubicSeg(
        waistSide,
        Pt(waistSide.x * 0.6, waistY + (centerWaistY - waistY) * 0.2),
        Pt(waistSide.x * 0.3, centerWaistY),
        Pt(0, centerWaistY),
      );
      final dartLength = waistY - armholeDepth - (front ? 2 : 1);

      return PatternPiece(
        name: front ? 'Corsaj față' : 'Corsaj spate',
        cutInfo: front ? 'Taie 1 pe pliu' : 'Taie 2 (în oglindă)',
        outline: [
          neckSeg,
          LineSeg(Pt(neckWidth, 0), shoulderPoint),
          armhole,
          LineSeg(underarm, waistSide),
          waistSeg,
          LineSeg(Pt(0, centerWaistY), Pt(0, neckDepth),
              front ? EdgeKind.fold : EdgeKind.seam),
        ],
        markings: [
          if (dartWidth > 0.3)
            dart(waistSeg.sample(), waistSide.x * 0.5, dartWidth, -dartLength),
        ],
        grainFrom: Pt(waistSide.x * 0.8, armholeDepth + 2),
        grainTo: Pt(waistSide.x * 0.8, waistY - 2),
        labelAt: Pt(1.5, neckDepth + 3),
      );
    }

    return Draft(
      pieces: [piece(true), piece(false)],
      notes: const [
        'Tipar de bază simplificat, fără pensă de bust. Coase întâi o probă '
            'din pânză ieftină și ajustează.',
        'Lasă deschis la mijlocul spatelui pentru fermoar.',
      ],
    );
  }
}
