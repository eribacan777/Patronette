import '../models/measurements.dart';
import '../models/pattern.dart';

/// O setare a modelului pe care utilizatorul o poate schimba (de exemplu
/// lungimea fustei). Dacă are [choices], se alege dintr-o listă.
class GarmentOption {
  const GarmentOption({
    required this.key,
    required this.label,
    required this.min,
    required this.max,
    required this.step,
    required this.defaultValue,
    this.choices,
  });

  final String key;
  final String label;
  final double min;
  final double max;
  final double step;
  final double defaultValue;

  /// Variante cu nume, în loc de un glisor: valoare → etichetă.
  final Map<double, String>? choices;
}

/// Un model de haină: știe ce măsuri îi trebuie și cum se desenează.
///
/// Fiecare model este o „rețetă” parametrică: aceleași formule,
/// alte măsuri, alt tipar.
abstract class Garment {
  const Garment();

  String get id;
  String get name;
  String get description;

  /// Cheile măsurilor folosite (vezi `kMeasurements`).
  List<String> get measurementKeys;

  List<GarmentOption> get options;

  Draft draft(Measurements m, Map<String, double> options);

  Map<String, double> get defaultOptions =>
      {for (final o in options) o.key: o.defaultValue};

  /// Măsurile de care are nevoie modelul și care lipsesc din profil.
  /// Un tipar adevărat (ecran, PDF) se face doar când lista e goală.
  List<String> missingMeasurements(Measurements m) =>
      [for (final k in measurementKeys) if (m[k] == null) k];

  /// O măsură din profil. Dacă lipsește, folosim valoarea tipică, dar doar
  /// pentru miniaturi: înainte de tipar se verifică [missingMeasurements].
  double measure(Measurements m, String key) =>
      m[key] ?? measurementDef(key).example;

  double option(Map<String, double> o, String key) =>
      o[key] ?? options.firstWhere((x) => x.key == key).defaultValue;
}
