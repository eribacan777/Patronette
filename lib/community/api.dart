import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'models.dart';

/// Adresa serverului. Se poate schimba la build:
///   flutter build apk --dart-define=API_URL=https://patronette-api.onrender.com
/// Implicit: serverul local. Pe emulatorul Android, calculatorul se vede ca
/// 10.0.2.2; în browser, ca localhost.
String defaultApiUrl() {
  const fromBuild = String.fromEnvironment('API_URL');
  if (fromBuild.isNotEmpty) return fromBuild;
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:8000';
  }
  return 'http://localhost:8000';
}

/// O eroare cu mesajul primit de la server, gata de afișat.
class ApiException implements Exception {
  ApiException(this.message, {this.status});

  final String message;
  final int? status;

  bool get unauthorized => status == 401;

  @override
  String toString() => message;
}

/// Clientul HTTP pentru API-ul comunității.
class CommunityApi {
  CommunityApi({String? baseUrl, http.Client? client})
      : baseUrl = baseUrl ?? defaultApiUrl(),
        _http = client ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  /// Tokenul de login, pus de [Session].
  String? token;

  static const _timeout = Duration(seconds: 20);

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: query);

  /// Adresa completă a unei poze (pentru `Image.network`).
  String imageUrl(String path) => '$baseUrl$path';

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<dynamic> _send(Future<http.Response> Function() request) async {
    final http.Response r;
    try {
      r = await request().timeout(_timeout);
    } catch (_) {
      throw ApiException(
          'Nu mă pot conecta la comunitate. Verifică internetul și încearcă din nou.');
    }
    if (r.statusCode >= 200 && r.statusCode < 300) {
      return r.body.isEmpty ? null : jsonDecode(utf8.decode(r.bodyBytes));
    }
    throw ApiException(_errorMessage(r), status: r.statusCode);
  }

  static String _errorMessage(http.Response r) {
    try {
      final detail = (jsonDecode(utf8.decode(r.bodyBytes)) as Map)['detail'];
      if (detail is String) return detail;
      // Erorile de validare vin ca listă; prima e de ajuns.
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first as Map;
        final field = (first['loc'] as List?)?.last;
        return switch (field) {
          'email' => 'Adresa de e-mail nu este validă.',
          'password' => 'Parola trebuie să aibă cel puțin 8 caractere.',
          'display_name' =>
            'Numele trebuie să aibă între 2 și 40 de caractere.',
          _ => first['msg'].toString(),
        };
      }
    } catch (_) {}
    return 'A apărut o eroare (${r.statusCode}). Încearcă din nou.';
  }

  Future<dynamic> _get(String path, [Map<String, String>? query]) =>
      _send(() => _http.get(_uri(path, query), headers: _headers));

  Future<dynamic> _json(String method, String path, [Object? body]) =>
      _send(() {
        final req = http.Request(method, _uri(path))
          ..headers.addAll({..._headers, 'Content-Type': 'application/json'});
        if (body != null) req.body = jsonEncode(body);
        return _http.send(req).then(http.Response.fromStream);
      });

  // ---------------------------------------------------------------- conturi

  Future<(String, AppUser)> _auth(
      String path, Map<String, dynamic> body) async {
    final j = await _json('POST', path, body) as Map<String, dynamic>;
    return (
      j['token'] as String,
      AppUser.fromJson(j['user'] as Map<String, dynamic>)
    );
  }

  Future<(String, AppUser)> register(
          String email, String password, String name) =>
      _auth('/auth/register',
          {'email': email, 'password': password, 'display_name': name});

  Future<(String, AppUser)> login(String email, String password) =>
      _auth('/auth/login', {'email': email, 'password': password});

  Future<(String, AppUser)> loginWithGoogle(String idToken) =>
      _auth('/auth/google', {'id_token': idToken});

  Future<AppUser> me() async =>
      AppUser.fromJson(await _get('/auth/me') as Map<String, dynamic>);

  // ---------------------------------------------------------------- postări

  Future<PostPage> feed({int? beforeId}) async {
    final j = await _get('/posts', {
      'limit': '20',
      if (beforeId != null) 'before_id': '$beforeId',
    }) as Map<String, dynamic>;
    return PostPage(
      [
        for (final p in j['posts'] as List)
          Post.fromJson(p as Map<String, dynamic>)
      ],
      j['next_before_id'] as int?,
    );
  }

  Future<Post> post(int id) async =>
      Post.fromJson(await _get('/posts/$id') as Map<String, dynamic>);

  Future<Post> createPost({
    required String text,
    String? linkUrl,
    SharedPattern? pattern,
    Uint8List? imageBytes,
    String? imageName,
  }) async {
    final j = await _send(() async {
      final req = http.MultipartRequest('POST', _uri('/posts'))
        ..headers.addAll(_headers)
        ..fields['text'] = text;
      if (linkUrl != null && linkUrl.isNotEmpty) {
        req.fields['link_url'] = linkUrl;
      }
      if (pattern != null) req.fields['pattern'] = jsonEncode(pattern.toJson());
      if (imageBytes != null) {
        req.files.add(http.MultipartFile.fromBytes('image', imageBytes,
            filename: imageName ?? 'poza.jpg'));
      }
      return http.Response.fromStream(await _http.send(req));
    }) as Map<String, dynamic>;
    return Post.fromJson(j);
  }

  Future<void> deletePost(int id) => _json('DELETE', '/posts/$id');

  Future<void> like(int id) => _json('PUT', '/posts/$id/like');
  Future<void> unlike(int id) => _json('DELETE', '/posts/$id/like');

  Future<List<Comment>> comments(int postId) async => [
        for (final c in await _get('/posts/$postId/comments') as List)
          Comment.fromJson(c as Map<String, dynamic>),
      ];

  Future<Comment> addComment(int postId, String text) async => Comment.fromJson(
      await _json('POST', '/posts/$postId/comments', {'text': text})
          as Map<String, dynamic>);

  Future<void> deleteComment(int id) => _json('DELETE', '/comments/$id');

  // ---------------------------------------------------------------- moderare

  Future<void> report(int postId, String reason) =>
      _json('POST', '/posts/$postId/report', {'reason': reason});

  Future<void> block(int userId) => _json('PUT', '/users/$userId/block');

  Future<List<ReportedPost>> reportedPosts() async => [
        for (final r in await _get('/admin/reports') as List)
          ReportedPost.fromJson(r as Map<String, dynamic>),
      ];

  Future<void> hidePost(int id) => _json('POST', '/admin/posts/$id/hide');
  Future<void> restorePost(int id) => _json('POST', '/admin/posts/$id/restore');
}
