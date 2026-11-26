import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'api.dart';
import 'session.dart';

/// ID-ul clientului OAuth de tip „Web application” din Google Cloud Console.
/// Același ID stă și pe server, în GOOGLE_CLIENT_IDS (Render), ca serverul să
/// accepte tokenurile emise pentru aplicația noastră.
/// Se poate da și la build: --dart-define=GOOGLE_WEB_CLIENT_ID=...
const googleWebClientId = String.fromEnvironment(
  'GOOGLE_WEB_CLIENT_ID',
  defaultValue: _configuredWebClientId,
);

/// Completat după crearea clientului în Google Cloud Console.
const _configuredWebClientId =
    '395548626613-o7q110b37mvm4somdl14ac6ircdgghjc.apps.googleusercontent.com';

/// Butonul „Continuă cu Google” apare pe Android și iOS. Pe web, Google
/// cere butonul lui propriu, desenat de biblioteca lui.
bool get googleSignInSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

bool _initialized = false;

Future<GoogleSignIn> _google() async {
  final g = GoogleSignIn.instance;
  if (!_initialized) {
    await g.initialize(serverClientId: googleWebClientId);
    _initialized = true;
  }
  return g;
}

/// Deschide fereastra Google de alegere a contului și conectează sesiunea.
/// Întoarce false dacă utilizatoarea a renunțat.
Future<bool> signInWithGoogle(Session session) async {
  if (googleWebClientId.isEmpty) {
    throw ApiException(
        'Conectarea cu Google nu e activată încă în această versiune. '
        'Folosește deocamdată e-mailul și parola.');
  }
  final GoogleSignInAccount account;
  try {
    account = await (await _google()).authenticate();
  } on GoogleSignInException catch (e) {
    if (e.code == GoogleSignInExceptionCode.canceled) return false;
    throw ApiException('Google nu a putut face conectarea (${e.code.name}).');
  }
  final idToken = account.authentication.idToken;
  if (idToken == null) {
    throw ApiException('Google nu a trimis datele contului. Încearcă din nou.');
  }
  await session.loginWithGoogle(idToken);
  session.onLogout ??= signOutOfGoogle;
  return true;
}

Future<void> signOutOfGoogle() async {
  if (!_initialized) return;
  try {
    await GoogleSignIn.instance.signOut();
  } catch (_) {}
}
