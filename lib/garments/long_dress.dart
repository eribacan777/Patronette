import 'dart:math' as math;

import '../format.dart';
import '../geometry.dart';
import '../models/measurements.dart';
import '../models/pattern.dart';
import 'common.dart';
import 'garment.dart';

/// Rochie lungă, evazată, cu mâneci lungi. Fără pense și fără fermoar:
/// se îmbracă pe cap și se strânge în talie cu un cordon de legat.
///
/// Corpul e un tricou prelungit: aceeași răscroială și aceeași mânecă
/// potrivită automat, apoi laturile coboară până la șold și se lărgesc
/// spre tiv.
///
/// Coordonatele pornesc din punctul cel mai înalt al umărului, de lângă gât
/// (y = 0), iar x = 0 este mijlocul feței sau al spatelui.
class LongDress extends Garment {
  const LongDress();

  /// Valorile opțiunii „material”.
  static const elastic = 0.0;
  static const woven = 1.0;

  @override
  String get id => 'rochie-lunga';
  @override
  String get name => 'Rochie lungă';
  @override
  String get description =>
      'Rochie lungă evazată, cu mâneci lungi și cordon în talie. Fără pense '
      'și fără fermoar, se îmbracă pe cap.';

  @override
  List<String> get measurementKeys => const [
        'bust',
        'sold',
        'inaltimeSold',
        'gat',
        'umeri',
        'brat',
        'spate',
        'talie'
      ];

  @override
  // Fără `const`: o hartă constantă nu poate avea chei de tip double.
  List<GarmentOption> get options => [
        GarmentOption(
          key: 'material',
          label: 'Material',
          min: elastic,
          max: woven,
          step: 1,
          defaultValue: woven,
          choices: {
            woven: 'Neelastic (vâscoză, in)',
            elastic: 'Elastic (jerseu)'
          },
        ),
        const GarmentOption(
            key: 'lungime',
            label: 'Lungimea rochiei, de la umăr',
            min: 100,
            max: 150,
            step: 1,
            defaultValue: 125),
        const GarmentOption(
            key: 'maneca',
            label: 'Lungimea mânecii',
            min: 45,
            max: 70,
            step: 1,
            defaultValue: 58),
        GarmentOption(
          key: 'evazare',
          label: 'Cât de evazată',
          min: 0.08,
          max: 0.22,
          step: 0.07,
          defaultValue: 0.15,
          choices: {0.08: 'Puțin', 0.15: 'Evazată', 0.22: 'Foarte evazată'},
        ),
        const GarmentOption(
            key: 'largime',
            label: 'Lărgime în plus la bust',
            min: 4,
            max: 16,
            step: 1,
            defaultValue: 8),
      ];

  @override
  Draft draft(Measurements m, Map<String, double> o) {
    final bust = measure(m, 'bust');
    final hip = measure(m, 'sold');
    final hipDepth = measure(m, 'inaltimeSold');
    final neck = measure(m, 'gat');
    final shoulders = measure(m, 'umeri');
    final arm = measure(m, 'brat');
    final backLength = measure(m, 'spate');
    final waist = measure(m, 'talie');
    final ease = option(o, 'largime');
    final isWoven = option(o, 'material') == woven;

    final halfWidth = (bust + ease) / 4;
    // Decolteu puțin mai larg decât la tricou, ca rochia să treacă peste cap.
    final neckWidth = neck / 6 + 2;
    final armholeDepth = bust / 6 + 9;
    final waistY = backLength;
    final hipY = waistY + hipDepth;
    final length = math.max(option(o, 'lungime'), hipY + 25);

    // La șold, rochia trebuie să fie cu cel puțin 6 cm mai largă decât corpul.
    final hipHalf = math.max(halfWidth, (hip + 6) / 4);
    final hemHalf = hipHalf + (length - hipY) * option(o, 'evazare');
    // Tivul urcă puțin spre lateral, ca să cadă drept când rochia se
    // lărgește.
    final hemRise = (hemHalf - hipHalf) * 0.2;

    final shoulderX =
        math.max(math.min(shoulders / 2, halfWidth - 2), neckWidth + 4);
    final shoulderPoint = Pt(shoulderX, 4.5);
    final underarm = Pt(halfWidth, armholeDepth);
    final hipPoint = Pt(hipHalf, hipY);
    final hemSide = Pt(hemHalf, length - hemRise);
    // Unde taie linia taliei cusătura laterală (subraț → șold).
    final sideAtWaist = halfWidth +
        (hipHalf - halfWidth) *
            ((waistY - armholeDepth) / (hipY - armholeDepth)).clamp(0.0, 1.0);

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
    final frontNeck = neckline(neck / 6 + 3);
    final backNeck = neckline(2);

    PatternPiece body(bool front) {
      final neckSeg = front ? frontNeck : backNeck;
      // Din material neelastic, spatele are cusătură la mijloc, ca să rămână
      // sus o deschidere pentru cap.
      final centerSeam = !front && isWoven;
      return PatternPiece(
        name: front ? 'Față' : 'Spate',
        cutInfo: centerSeam ? 'Taie 2 (în oglindă)' : 'Taie 1 pe pliu',
        copies: centerSeam ? 2 : 1,
        outline: [
          neckSeg,
          LineSeg(Pt(neckWidth, 0), shoulderPoint),
          armhole,
          LineSeg(underarm, hipPoint),
          LineSeg(hipPoint, hemSide),
          CubicSeg(
            hemSide,
            Pt(hemHalf * 0.66, length),
            Pt(hemHalf * 0.33, length),
            Pt(0, length),
            EdgeKind.hem,
          ),
          LineSeg(Pt(0, length), neckSeg.start,
              centerSeam ? EdgeKind.seam : EdgeKind.fold),
        ],
        markings: [
          // Linia taliei, unde se leagă cordonul.
          [Pt(0, waistY), Pt(sideAtWaist, waistY)],
        ],
        grainFrom: Pt(halfWidth * 0.3, armholeDepth + 4),
        grainTo: Pt(halfWidth * 0.3, length - 10),
        labelAt: Pt(halfWidth * 0.4, armholeDepth + 6),
      );
    }

    final sleeve = fittedSleeve(
      arm: arm,
      ease: ease,
      armholeLength: armhole.length,
      length: option(o, 'maneca'),
      // Mâna trebuie să treacă prin manșetă: 22 cm la material neelastic.
      minHemHalf: isWoven ? 11 : 9.5,
    );

    final neckOpening = 2 * (frontNeck.length + backNeck.length);
    final neckFinish = isWoven
        ? foldedStrip(
            name: 'Bie gât',
            cutInfo: 'Taie 1 pe diagonala materialului',
            length: neckOpening + 2,
            width: 4,
          )
        : foldedStrip(
            name: 'Bentiță gât',
            cutInfo: 'Taie 1 din material elastic',
            length: neckOpening * 0.85,
            width: 5,
          );

    final belt = foldedStrip(
      name: 'Cordon de legat',
      cutInfo: 'Taie 1 · se pliază pe linia din mijloc',
      length: waist + 90,
      width: 7,
    );

    String cm(double v) => fmtCm(double.parse(v.toStringAsFixed(1)));
    return Draft(
      pieces: [body(true), body(false), sleeve.piece, neckFinish, belt],
      notes: [
        if (isWoven)
          'Coase spatele la mijloc, dar lasă sus o deschidere de 12 cm și '
              'încheie-o cu un nasture și o buclă.',
        if (!isWoven)
          'Coase cu cusătură elastică (zigzag) sau la mașina overlock.',
        'Capul mânecii: ${cm(sleeve.capLength * 2)} cm; '
            'răscroiala față + spate: ${cm(armhole.length * 2)} cm.',
        'Linia din talie arată unde se leagă cordonul.',
        if (sleeve.tooWide)
          'Brațul este lat față de răscroială. Mărește lărgimea la bust '
              'ca mâneca să se potrivească.',
      ],
    );
  }
}
