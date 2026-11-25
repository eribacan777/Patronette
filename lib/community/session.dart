import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'models.dart';

/// Cine e conectată în comunitate. Tokenul se păstrează pe telefon, ca să nu
/// fie nevoie de login la fiecare deschidere.
class Session extends ChangeNotifier {
  Session(this.api) {
    api.onUnauthorized = _expired;
  }

  final CommunityApi api;
  AppUser? _user;

  static const _tokenKey = 'community_token';
  static const _userKey = 'community_user';
  // Pe ce server s-a făcut login-ul: un token de pe serverul local nu e
  // valabil pe cel din cloud.
  static const _serverKey = 'community_server';

  AppUser? get user => _user;
  bool get loggedIn => _user != null;

  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      final user = prefs.getString(_userKey);
      if (token == null || user == null) return;
      if (prefs.getString(_serverKey) != api.baseUrl) {
        await _forget();
        return;
      }
      api.token = token;
      _user = AppUser.fromJson(jsonDecode(user) as Map<String, dynamic>);
      notifyListeners();
    } catch (_) {
      // O sesiune stricată înseamnă doar că trebuie făcut login din nou.
    }
  }

  Future<void> _save(String token, AppUser user) async {
    api.token = token;
    _user = user;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
    await prefs.setString(_serverKey, api.baseUrl);
  }

  Future<void> login(String email, String password) async {
    final (token, user) = await api.login(email, password);
    await _save(token, user);
  }

  Future<void> register(String email, String password, String name) async {
    final (token, user) = await api.register(email, password, name);
    await _save(token, user);
  }

  Future<void> loginWithGoogle(String idToken) async {
    final (token, user) = await api.loginWithGoogle(idToken);
    await _save(token, user);
  }

  Future<void> logout() async {
    api.token = null;
    _user = null;
    notifyListeners();
    await _forget();
  }

  /// Serverul a respins tokenul: deconectare, fără să mai fie nevoie de un
  /// buton apăsat de utilizatoare.
  void _expired() {
    if (_user == null) return;
    logout();
  }

  Future<void> _forget() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_userKey);
      await prefs.remove(_serverKey);
    } catch (_) {}
  }
}
