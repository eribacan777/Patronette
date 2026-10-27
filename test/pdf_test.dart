import 'dart:io';

import 'package:croi/export/pdf_export.dart';
import 'package:croi/garments/catalog.dart';
import 'package:croi/models/measurements.dart';
import 'package:croi/models/profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fiecare model se exportă ca PDF', () async {
    final profile =
        Profile(id: '1', name: 'Ana', values: Map.of(kExampleMeasurements));
    final outDir = Directory('build/pdf_test')..createSync(recursive: true);
    for (final g in kGarments) {
      final options = g.defaultOptions;
      final bytes = await buildPatternPdf(
        garment: g,
        draft: g.draft(profile.values, options),
        profile: profile,
        options: options,
        seam: 1,
        hem: 2,
      );
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      // Le păstrăm, ca să poată fi deschise și verificate de mână.
      File('${outDir.path}/${g.id}.pdf').writeAsBytesSync(bytes);
    }
  });

  test('fără diacritice când lipsește fontul', () {
    expect(stripDiacritics('Fustă cloș, mânecă, țesătură'),
        'Fusta clos, maneca, tesatura');
  });
}
