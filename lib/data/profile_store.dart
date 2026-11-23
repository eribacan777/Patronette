import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/profile.dart';

/// Păstrează profilurile pe telefon, ca text JSON.
/// Ecranele ascultă de el și se redesenează când lista se schimbă.
///
/// Dacă textul salvat nu poate fi citit (în întregime sau doar unele
/// profiluri), îl copiem neatins sub [backupKey] înainte de orice scriere,
/// ca o salvare nouă să nu șteargă datele vechi.
class ProfileStore extends ChangeNotifier {
  static const _key = 'profiles';
  static const backupKey = 'profiles_backup';

  final List<Profile> _profiles = [];

  /// false până se termină prima încărcare.
  bool loaded = false;

  /// Mesajul de eroare, dacă profilurile nu au putut fi citite.
  String? loadError;

  /// true = datele vechi nu au putut fi puse deoparte, așa că nu scriem
  /// nimic peste ele.
  bool _writeBlocked = false;

  /// false = salvarea este oprită, ca să nu se piardă datele vechi.
  bool get canSave => !_writeBlocked;

  List<Profile> get profiles => List.unmodifiable(_profiles);

  Profile? byId(String id) {
    for (final p in _profiles) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> load() async {
    _profiles.clear();
    loadError = null;
    _writeBlocked = false;
    String? raw;
    try {
      final prefs = await SharedPreferences.getInstance();
      raw = prefs.getString(_key);
      if (raw != null) {
        final (profiles, broken) = parse(raw);
        _profiles.addAll(profiles);
        if (broken > 0) {
          loadError = broken == 1
              ? 'Un profil salvat nu a putut fi citit.'
              : '$broken profiluri salvate nu au putut fi citite.';
          await _backup(prefs, raw);
        }
      }
    } catch (e) {
      loadError = 'Profilurile salvate nu au putut fi citite ($e).';
      _writeBlocked = true;
      if (raw != null) {
        try {
          await _backup(await SharedPreferences.getInstance(), raw);
          _writeBlocked = false;
        } catch (_) {}
      }
    }
    loaded = true;
    notifyListeners();
  }

  /// Citește lista de profiluri. Un profil stricat nu le strică pe celelalte:
  /// întoarce profilurile bune și câte nu au putut fi citite.
  /// Aruncă o eroare doar dacă textul nu este deloc o listă JSON.
  @visibleForTesting
  static (List<Profile>, int) parse(String raw) {
    final list = jsonDecode(raw) as List<dynamic>;
    final profiles = <Profile>[];
    var broken = 0;
    for (final e in list) {
      try {
        profiles.add(Profile.fromJson(e as Map<String, dynamic>));
      } catch (_) {
        broken++;
      }
    }
    return (profiles, broken);
  }

  /// Pune deoparte textul original, fără să suprascrie o copie mai veche.
  static Future<void> _backup(SharedPreferences prefs, String raw) async {
    if (prefs.getString(backupKey) == raw) return;
    final key = prefs.containsKey(backupKey)
        ? '${backupKey}_${DateTime.now().millisecondsSinceEpoch}'
        : backupKey;
    if (!await prefs.setString(key, raw)) {
      throw StateError('Copia de siguranță nu a putut fi scrisă.');
    }
  }

  /// Aruncă o eroare dacă profilul nu a putut fi scris pe telefon;
  /// lista din memorie rămâne atunci neschimbată.
  Future<void> save(Profile profile) async {
    final next = [..._profiles];
    final i = next.indexWhere((p) => p.id == profile.id);
    if (i >= 0) {
      next[i] = profile;
    } else {
      next.add(profile);
    }
    await _persist(next);
  }

  Future<void> delete(String id) async {
    await _persist(_profiles.where((p) => p.id != id).toList());
  }

  Future<void> _persist(List<Profile> next) async {
    if (_writeBlocked) {
      throw StateError('Profilurile vechi nu au putut fi puse deoparte, așa '
          'că nu salvez nimic peste ele.');
    }
    final prefs = await SharedPreferences.getInstance();
    final ok = await prefs.setString(
        _key, jsonEncode(next.map((p) => p.toJson()).toList()));
    if (!ok) throw StateError('Profilurile nu au putut fi salvate.');
    _profiles
      ..clear()
      ..addAll(next);
    notifyListeners();
  }
}
