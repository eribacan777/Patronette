/// Măsurile corpului, în centimetri, după cheie (de exemplu 'talie' → 70).
typedef Measurements = Map<String, double>;

/// Descrierea unei măsuri: cum se numește, cum se ia, ce valori sunt obișnuite.
class MeasurementDef {
  const MeasurementDef({
    required this.key,
    required this.label,
    required this.howTo,
    required this.min,
    required this.max,
    required this.example,
  });

  final String key;
  final String label;
  final String howTo;

  /// Interval obișnuit pentru adulți; în afara lui afișăm o avertizare.
  final double min;
  final double max;

  /// Valoare tipică (aproximativ mărimea 38), folosită ca exemplu.
  final double example;
}

const kMeasurements = <MeasurementDef>[
  MeasurementDef(
    key: 'bust',
    label: 'Bust / piept',
    howTo: 'Treci banda pe sub brațe, peste partea cea mai plină a bustului, '
        'paralel cu podeaua.',
    min: 70,
    max: 150,
    example: 88,
  ),
  MeasurementDef(
    key: 'talie',
    label: 'Talie',
    howTo: 'Leagă o sfoară în jurul taliei: se așază singură în locul cel mai '
        'subțire. Măsoară acolo, fără să strângi.',
    min: 55,
    max: 140,
    example: 70,
  ),
  MeasurementDef(
    key: 'sold',
    label: 'Șold',
    howTo: 'Măsoară în jurul celei mai pline părți a șoldurilor și a feselor, '
        'cu picioarele apropiate.',
    min: 75,
    max: 160,
    example: 96,
  ),
  MeasurementDef(
    key: 'inaltimeSold',
    label: 'Distanța talie–șold',
    howTo: 'Pe lateral, de la sfoara din talie în jos, până la linia cea mai '
        'plină a șoldului.',
    min: 14,
    max: 28,
    example: 20,
  ),
  MeasurementDef(
    key: 'gat',
    label: 'Circumferința gâtului',
    howTo: 'La baza gâtului, acolo unde stă un colier, fără să strângi.',
    min: 30,
    max: 50,
    example: 36,
  ),
  MeasurementDef(
    key: 'umeri',
    label: 'Lățimea umerilor',
    howTo: 'Pe spate, de la capătul unui umăr până la capătul celuilalt '
        '(osul de la vârful umărului).',
    min: 30,
    max: 55,
    example: 39,
  ),
  MeasurementDef(
    key: 'brat',
    label: 'Circumferința brațului',
    howTo: 'În jurul celei mai groase părți a brațului, sub umăr, '
        'cu brațul relaxat.',
    min: 20,
    max: 50,
    example: 27,
  ),
  MeasurementDef(
    key: 'spate',
    label: 'Lungimea taliei pe spate',
    howTo: 'De la osul proeminent de la baza gâtului, pe mijlocul spatelui, '
        'în jos până la sfoara din talie.',
    min: 34,
    max: 50,
    example: 40,
  ),
];

MeasurementDef measurementDef(String key) =>
    kMeasurements.firstWhere((d) => d.key == key);

/// Măsuri tipice, folosite în teste și ca exemplu.
final Measurements kExampleMeasurements = {
  for (final d in kMeasurements) d.key: d.example,
};
