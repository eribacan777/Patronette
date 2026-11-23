import 'dart:convert';

import 'package:croi/data/profile_store.dart';
import 'package:croi/garments/catalog.dart';
import 'package:croi/garments/circle_skirt.dart';
import 'package:croi/garments/straight_skirt.dart';
import 'package:croi/export/pdf_export.dart';
import 'package:croi/models/profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> ana() => {
      'id': '1',
      'name': 'Ana',
      'values': {'talie': 70, 'sold': 96},
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Salvarea profilurilor', () {
    test('un text stricat nu se pierde la salvarea unui profil nou', () async {
      const corrupt = '[{"id": "1", "name": "Ana"'; // tăiat la jumătate
      SharedPreferences.setMockInitialValues({'profiles': corrupt});
      final store = ProfileStore();
      await store.load();

      expect(store.loadError, isNotNull);
      expect(store.canSave, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ProfileStore.backupKey), corrupt);

      await store.save(Profile(id: '2', name: 'Ioana', values: {'talie': 66}));
      expect(prefs.getString(ProfileStore.backupKey), corrupt);
      expect(store.profiles.map((p) => p.name), ['Ioana']);
    });

    test('un profil stricat nu le strică pe celelalte', () async {
      final raw = jsonEncode([
        ana(),
        {'id': '2', 'name': 'Fără măsuri'}, // lipsește „values”
      ]);
      SharedPreferences.setMockInitialValues({'profiles': raw});
      final store = ProfileStore();
      await store.load();

      expect(store.profiles.map((p) => p.name), ['Ana']);
      expect(store.loadError, contains('Un profil'));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ProfileStore.backupKey), raw);
    });

    test('o a doua eroare nu suprascrie copia de siguranță', () async {
      SharedPreferences.setMockInitialValues(
          {'profiles': 'nou stricat', ProfileStore.backupKey: 'vechi'});
      await ProfileStore().load();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ProfileStore.backupKey), 'vechi');
      expect(
          prefs.getKeys().where((k) => k.startsWith('${ProfileStore.backupKey}_')),
          hasLength(1));
    });

    test('profilurile bune se citesc fără avertizare', () async {
      SharedPreferences.setMockInitialValues({'profiles': jsonEncode([ana()])});
      final store = ProfileStore();
      await store.load();
      expect(store.loadError, isNull);
      expect(store.profiles.single.values['sold'], 96);
    });
  });

  group('Măsuri lipsă', () {
    final profile = Profile.fromJson(ana()); // doar talie și șold

    test('fiecare model spune ce măsuri îi lipsesc', () {
      expect(const CircleSkirt().missingMeasurements(profile.values), isEmpty);
      expect(const StraightSkirt().missingMeasurements(profile.values),
          ['inaltimeSold']);
      final tshirt = kGarments.firstWhere((g) => g.id == 'tricou');
      expect(tshirt.missingMeasurements(profile.values),
          ['bust', 'gat', 'umeri', 'brat']);
    });

    test('PDF-ul nu se face cu măsuri inventate', () async {
      const g = StraightSkirt();
      expect(
        buildPatternPdf(
          garment: g,
          draft: g.draft(profile.values, g.defaultOptions),
          profile: profile,
          options: g.defaultOptions,
          seam: 1,
          hem: 2,
        ),
        throwsArgumentError,
      );
    });
  });
}
