import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/profile.dart';

/// Păstrează profilurile pe telefon, ca text JSON.
/// Ecranele ascultă de el și se redesenează când lista se schimbă.
class ProfileStore extends ChangeNotifier {
  static const _key = 'profiles';

  final List<Profile> _profiles = [];

  /// false până se termină prima încărcare.
  bool loaded = false;

  /// Mesajul de eroare, dacă profilurile nu au putut fi citite.
  String? loadError;

  List<Profile> get profiles => List.unmodifiable(_profiles);

  Profile? byId(String id) {
    for (final p in _profiles) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      _profiles.clear();
      if (raw != null) {
        final list = jsonDecode(raw) as List<dynamic>;
        _profiles.addAll(
            list.map((e) => Profile.fromJson(e as Map<String, dynamic>)));
      }
    } catch (e) {
      loadError = '$e';
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> save(Profile profile) async {
    final i = _profiles.indexWhere((p) => p.id == profile.id);
    if (i >= 0) {
      _profiles[i] = profile;
    } else {
      _profiles.add(profile);
    }
    await _persist();
  }

  Future<void> delete(String id) async {
    _profiles.removeWhere((p) => p.id == id);
    await _persist();
  }

  Future<void> _persist() async {
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(_profiles.map((p) => p.toJson()).toList()));
  }
}
