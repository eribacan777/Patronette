import '../fabric/fabric_plan.dart';
import '../format.dart';
import '../garments/garment.dart';
import '../garments/long_dress.dart';
import '../garments/trousers.dart';
import '../models/measurements.dart';
import 'sketches.dart';

/// Un pas din instrucțiunile de coasere.
class SewingStep {
  const SewingStep(this.title, this.text, [this.sketch]);

  final String title;
  final String text;
  final Sketch? sketch;
}

/// Tot ce trebuie ca să coși un model: cât de greu e, ce cumperi, ce faci.
class SewingGuide {
  const SewingGuide({
    required this.level,
    required this.time,
    required this.supplies,
    required this.steps,
  });

  /// „Începătoare”, „Ușor” sau „Mediu”.
  final String level;

  /// Timp aproximativ, pentru cine coase prima dată.
  final String time;
  final List<String> supplies;
  final List<SewingStep> steps;
}

/// Instrucțiunile pentru [garment], potrivite cu setările alese
/// (de exemplu, rochia din jerseu se coase altfel decât cea din in).
SewingGuide sewingGuide(
  Garment garment,
  Map<String, double> options,
  Measurements measurements, {
  FabricPlan? fabric,
}) {
  final supplies = <String>[
    if (fabric != null && fabric.fits)
      'Material: ${fmtCm(fabric.metersToBuy)} m, lat de ${fmtCm(fabric.fabricWidth)} cm',
    'Ață asortată, ace cu gămălie, foarfecă de croitorie, cretă sau creion '
        'care se șterge',
  ];
  double opt(String key) => garment.option(options, key);

  return switch (garment.id) {
    'fusta-dreapta' => _straightSkirt(supplies),
    'fusta-clos' => _circleSkirt(supplies),
    'tricou' => _tshirt(supplies),
    'corsaj' => _bodice(supplies),
    'rochie-lunga' => _longDress(supplies, opt('material') == LongDress.woven),
    'pantaloni' => _trousers(supplies,
        Trousers.elasticLength(garment.measure(measurements, 'talie'))),
    _ => SewingGuide(
        level: 'Mediu', time: '', supplies: supplies, steps: const []),
  };
}

// Pași care se repetă la mai multe modele.
const _finish = SewingStep(
  'Surfilează marginile',
  'Trece cu zigzag sau cu mașina overlock pe marginile care nu se ascund '
      'în tiv sau în cordon, ca materialul să nu se destrame.',
  Sketch.finishEdges,
);

SewingStep _press(String what) => SewingStep(
      'Calcă rezervele',
      'Calcă $what cu rezervele desfăcute, pe dos. Călcatul după fiecare '
          'cusătură face haina să arate cumpărată, nu făcută acasă.',
      Sketch.press,
    );

SewingGuide _straightSkirt(List<String> supplies) => SewingGuide(
      level: 'Ușor',
      time: '3–4 ore',
      supplies: [
        ...supplies,
        'Fermoar de 18 cm (obișnuit sau ascuns)',
        'Un nasture sau o capsă pentru cordon',
        'Întăritură termoadezivă (vlieselină) pentru cordon, opțional',
      ],
      steps: const [
        SewingStep(
          'Taie și marchează',
          'Taie fața pe pliu, două spate în oglindă și cordonul. Transferă '
              'pensele cu creta pe dosul materialului.',
        ),
        _finish,
        SewingStep(
          'Coase pensele',
          'Pliază fiecare pensă față pe față și coase de la talie spre vârf. '
              'Ultimul centimetru coase-l chiar pe muchie, ca vârful să nu facă '
              'bășică. Calcă pensele spre mijloc.',
          Sketch.dart,
        ),
        SewingStep(
          'Coase mijlocul spatelui',
          'Pune spatele față pe față și coase de jos în sus, dar oprește-te la '
              '18 cm sub talie: acolo intră fermoarul.',
          Sketch.seam,
        ),
        SewingStep(
          'Pune fermoarul',
          'Prinde fermoarul cu ace în deschidere, cu dinții la mijloc, și coase '
              'pe ambele părți cu piciorușul pentru fermoar.',
          Sketch.zipper,
        ),
        SewingStep(
          'Coase laturile',
          'Pune fața peste spate, față pe față, și coase cele două laturi de la '
              'talie până jos. Probează fusta înainte să mergi mai departe.',
          Sketch.seam,
        ),
        SewingStep(
          'Calcă rezervele',
          'Calcă laturile și mijlocul spatelui cu rezervele desfăcute.',
          Sketch.press,
        ),
        SewingStep(
          'Coase cordonul',
          'Calcă întăritura pe jumătate din cordon. Coase cordonul pe talie, față '
              'pe față, pliază-l pe linia din mijloc spre dos și prinde-l de mână '
              'sau cu o cusătură pe față, chiar în șanț.',
          Sketch.waistband,
        ),
        SewingStep(
          'Fă tivul',
          'Calcă marginea de jos în sus de două ori, ca rezerva să se ascundă, '
              'și coase la mașină sau de mână, cu împunsături mici.',
          Sketch.hem,
        ),
        SewingStep(
          'Nasturele și ultimul călcat',
          'Coase nasturele și butoniera (sau capsa) la capetele cordonului. '
              'Calcă toată fusta.',
          Sketch.buttonLoop,
        ),
      ],
    );

SewingGuide _circleSkirt(List<String> supplies) => SewingGuide(
      level: 'Ușor',
      time: '3 ore',
      supplies: [
        ...supplies,
        'Fermoar de 18 cm',
        'Un nasture sau o capsă pentru cordon',
      ],
      steps: [
        _finish,
        const SewingStep(
          'Coase o latură',
          'Pune cele două piese față pe față și coase o latură de sus până jos.',
          Sketch.seam,
        ),
        const SewingStep(
          'A doua latură, cu loc de fermoar',
          'Coase și cealaltă latură, dar lasă sus 18 cm deschiși pentru fermoar.',
          Sketch.seam,
        ),
        const SewingStep(
          'Pune fermoarul',
          'Prinde fermoarul cu ace în deschidere și coase-l pe ambele părți.',
          Sketch.zipper,
        ),
        const SewingStep(
          'Coase cordonul',
          'Talia fustei cloș e tăiată în curbă și se lungește ușor: tighelește '
              'întâi la 0,5 cm de margine, ca să nu se deformeze. Apoi coase '
              'cordonul față pe față, pliază-l spre dos și prinde-l.',
          Sketch.waistband,
        ),
        const SewingStep(
          'Las-o să atârne o zi',
          'Agață fusta pe un umeraș 24 de ore înainte de tiv. Părțile tăiate pe '
              'diagonală se lungesc; apoi egalizezi tivul după cel mai scurt '
              'punct, măsurând de la podea.',
        ),
        const SewingStep(
          'Tiv îngust',
          'Pe o margine rotundă, un tiv lat face cute. Pliază de două ori câte '
              '0,5 cm și coase aproape de margine.',
          Sketch.hem,
        ),
        _press('fusta, mai ales tivul'),
      ],
    );

SewingGuide _tshirt(List<String> supplies) => SewingGuide(
      level: 'Ușor',
      time: '2 ore',
      supplies: [
        ...supplies.map((s) => s.startsWith('Material')
            ? '$s, din tricot elastic (jerseu, bumbac cu elastan)'
            : s),
        'Ac pentru tricot (cu vârf rotunjit) la mașina de cusut',
      ],
      steps: const [
        SewingStep(
          'Alege cusătura potrivită',
          'Tricotul se întinde, așa că o cusătură dreaptă s-ar rupe. Folosește un '
              'zigzag îngust (lățime 1, lungime 2,5) sau mașina overlock.',
        ),
        SewingStep(
          'Coase umerii',
          'Pune fața peste spate, față pe față, și coase umerii.',
          Sketch.seam,
        ),
        SewingStep(
          'Bentița de la gât',
          'Coase capetele bentiței ca să faci un cerc și pliaz-o pe lung. Împarte '
              'în patru și bentița, și decolteul, cu ace. Prinde-le potrivind '
              'semnele și coase întinzând ușor bentița, nu decolteul.',
          Sketch.neckband,
        ),
        SewingStep(
          'Prinde mânecile',
          'Potrivește mijlocul capului de mânecă cu cusătura umărului și '
              'capetele cu subrațul. Prinde cu ace des și coase.',
          Sketch.setSleeve,
        ),
        SewingStep(
          'Laterala și mâneca, dintr-o cusătură',
          'Întoarce tricoul pe dos și coase de la tivul mânecii, prin subraț, '
              'până la tivul de jos. La fel pe partea cealaltă.',
          Sketch.sideSeam,
        ),
        SewingStep(
          'Tivurile',
          'Pliază 2 cm la mâneci și jos și coase cu ac dublu sau cu zigzag, ca '
              'tivul să se poată întinde.',
          Sketch.hem,
        ),
        SewingStep(
          'Calcă',
          'Calcă la temperatura scrisă pe eticheta materialului, mai ales bentița.',
          Sketch.press,
        ),
      ],
    );

SewingGuide _bodice(List<String> supplies) => SewingGuide(
      level: 'Ușor',
      time: '1–2 ore',
      supplies: [
        'Pânză ieftină pentru probă (nesă, pânză de bumbac)',
        'Ață de o culoare care se vede, ace, foarfecă, cretă',
        'Un marker, ca să notezi modificările',
      ],
      steps: const [
        SewingStep(
          'Ce este corsajul de bază',
          'Corsajul de bază nu e o haină de purtat, ci o probă. Îl coși repede '
              'din pânză ieftină ca să verifici că tiparul se potrivește, apoi '
              'pornești de la el pentru bluze și rochii.',
        ),
        SewingStep(
          'Coase pensele',
          'Coase pensele de talie de la talie spre vârf. Nu e nevoie să surfilezi.',
          Sketch.dart,
        ),
        SewingStep(
          'Coase umerii și laturile',
          'Pune fața peste spate, față pe față, și coase umerii, apoi laturile. '
              'Folosește o cusătură lungă, ca să o poți desface ușor.',
          Sketch.seam,
        ),
        SewingStep(
          'Probează',
          'Îmbracă proba pe dos și închide spatele cu ace. Verifică: linia taliei '
              'stă pe talie? Pensele se termină sub bust? Umerii nu trag?',
        ),
        SewingStep(
          'Notează și corectează',
          'Marchează direct pe probă ce trebuie mutat sau strâns, apoi '
              'transferă modificările pe tiparul de hârtie.',
        ),
      ],
    );

SewingGuide _longDress(List<String> supplies, bool woven) => SewingGuide(
      level: 'Mediu',
      time: woven ? '5–6 ore' : '4 ore',
      supplies: [
        ...supplies,
        if (woven) ...[
          'Bie de 2 cm pentru gât (sau fâșia tăiată din material, din tipar)',
          'Un nasture mic și un fir de elastic subțire pentru buclă',
        ] else
          'Ac pentru tricot (cu vârf rotunjit) la mașina de cusut',
      ],
      steps: [
        if (woven) ...[
          _finish,
          const SewingStep(
            'Coase mijlocul spatelui',
            'Pune cele două spate față pe față și coase de jos în sus, dar lasă '
                'sus 12 cm deschiși: pe acolo trece capul. Calcă rezervele '
                'desfăcute și tighelește-le pe marginea deschiderii.',
            Sketch.seam,
          ),
        ] else
          const SewingStep(
            'Alege cusătura potrivită',
            'Pe jerseu folosește un zigzag îngust sau mașina overlock, ca '
                'cusăturile să se poată întinde.',
          ),
        const SewingStep(
          'Coase umerii',
          'Pune fața peste spate, față pe față, și coase umerii.',
          Sketch.seam,
        ),
        if (woven) ...[
          const SewingStep(
            'Bie la gât',
            'Coase biea pe decolteu, față pe față, la 0,6 cm de margine. Taie '
                'mici crestături în rezervă pe curbă, întoarce biea pe dos, calc-o '
                'și tighelește-o.',
            Sketch.neckband,
          ),
          const SewingStep(
            'Bucla și nasturele',
            'Fă o buclă din elastic subțire sus, pe o parte a deschiderii, și '
                'coase nasturele pe partea cealaltă.',
            Sketch.buttonLoop,
          ),
        ] else
          const SewingStep(
            'Bentița de la gât',
            'Coase bentița în cerc, pliaz-o pe lung, împarte-o în patru ca și '
                'decolteul și coase-o întinzând ușor bentița.',
            Sketch.neckband,
          ),
        const SewingStep(
          'Prinde mânecile',
          'Potrivește mijlocul capului de mânecă cu cusătura umărului. Prinde cu '
              'ace des, mai ales pe curba de sus, și coase.',
          Sketch.setSleeve,
        ),
        const SewingStep(
          'Laterala și mâneca, dintr-o cusătură',
          'Întoarce rochia pe dos și coase de la tivul mânecii, prin subraț, '
              'până la tivul rochiei. Probează și verifică lungimea.',
          Sketch.sideSeam,
        ),
        const SewingStep(
          'Las-o să atârne o zi',
          'Rochia evazată are părți tăiate pe diagonală care se lungesc. Agaț-o '
              '24 de ore pe umeraș, apoi egalizează tivul măsurând de la podea.',
        ),
        SewingStep(
          'Tivurile',
          woven
              ? 'Tiv îngust jos (de două ori câte 0,5 cm), pentru că marginea e '
                  'rotundă. La mâneci pliază de două ori câte 1,5 cm.'
              : 'Pliază 2 cm la mâneci și jos și coase cu ac dublu sau zigzag.',
          Sketch.hem,
        ),
        const SewingStep(
          'Cordonul de legat',
          'Pliază cordonul pe lung, față pe față, și coase de jur împrejur, dar '
              'lasă 10 cm deschiși la mijloc. Întoarce-l pe față prin deschidere, '
              'calcă-l și închide deschiderea cu câteva împunsături.',
          Sketch.belt,
        ),
      ],
    );

SewingGuide _trousers(List<String> supplies, double elastic) => SewingGuide(
      level: 'Începătoare',
      time: '2–3 ore',
      supplies: [
        ...supplies,
        'Elastic lat de 2,5 cm, lung de ${fmtCm(elastic)} cm '
            '(plus 2 cm pentru suprapunere)',
        'Un ac de siguranță mare, ca să tragi elasticul',
      ],
      steps: [
        _finish,
        const SewingStep(
          'Coase laturile',
          'La fiecare picior, pune fața peste spate, față pe față, și coase '
              'laterala de sus până jos.',
          Sketch.seam,
        ),
        const SewingStep(
          'Coase cusătura interioară',
          'Tot la fiecare picior, coase cusătura dintre picioare, de la tiv până '
              'la crăcană. Spatele e puțin mai scurt: întinde-l ușor cât coși.',
          Sketch.seam,
        ),
        const SewingStep(
          'Cusătura din mijloc',
          'Întoarce un picior pe față și bagă-l în celălalt, care rămâne pe dos. '
              'Potrivește cusăturile interioare și coase curba din mijloc dintr-o '
              'singură trecere, de la talia din față până la talia din spate. Pe '
              'curbă coase de două ori, că acolo se întinde cel mai mult.',
          Sketch.crotchSeam,
        ),
        const SewingStep(
          'Tunelul pentru elastic',
          'Pliază marginea de sus 1 cm spre dos, apoi încă o dată pe linia '
              'marcată pe tipar. Coase aproape de margine, dar lasă 5 cm '
              'deschiși la spate.',
          Sketch.elasticCasing,
        ),
        const SewingStep(
          'Trage elasticul',
          'Prinde acul de siguranță de capătul elasticului și trage-l prin tunel. '
              'Suprapune capetele 2 cm, coase-le cu zigzag și închide deschiderea.',
          Sketch.elasticCasing,
        ),
        const SewingStep(
          'Tivul',
          'Probează lungimea, apoi pliază de două ori și coase tivul.',
          Sketch.hem,
        ),
        _press('cusăturile și tivul'),
      ],
    );
