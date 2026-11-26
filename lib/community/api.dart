import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'models.dart';

/// Serverul din cloud (Render), cu baza de date PostgreSQL pe Neon.
const cloudApiUrl = 'https://patronette-api.onrender.com';

/// Adresa serverului:
/// - varianta finală (release) folosește serverul din cloud;
/// - în dezvoltare, serverul local: pe emulatorul Android calculatorul se
///   vede ca 10.0.2.2, în browser ca localhost;
/// - oricare se poate schimba la build:
///   flutter build apk --dart-define=API_URL=http://10.0.2.2:8000
String defaultApiUrl() {
  const fromBuild = String.fromEnvironment('API_URL');
  if (fromBuild.isNotEmpty) return fromBuild;
  if (kReleaseMode) return cloudApiUrl;
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

  /// Apelat când serverul respinge tokenul (expirat sau de pe alt server).
  /// [Session] o deconectează pe utilizatoare.
  void Function()? onUnauthorized;

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
    // Un token respins nu mai are niciun rost: îl uităm, ca următoarele
    // cereri (de exemplu lista de postări) să meargă fără cont.
    if (r.statusCode == 401 && token != null) {
      token = null;
      onUnauthorized?.call();
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

  static PostPage _page(dynamic json) {
    final j = json as Map<String, dynamic>;
    return PostPage(
      [
        for (final p in j['posts'] as List)
          Post.fromJson(p as Map<String, dynamic>)
      ],
      j['next_before_id'] as int?,
    );
  }

  /// Cele mai noi postări; cu [following], doar de la cei pe care îi urmăresc.
  Future<PostPage> feed({int? beforeId, bool following = false}) async =>
      _page(await _get('/posts', {
        'limit': '20',
        if (beforeId != null) 'before_id': '$beforeId',
        if (following) 'following': 'true',
      }));

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

  // ---------------------------------------------------------------- profiluri

  Future<UserProfile> profile(int userId) async => UserProfile.fromJson(
      await _get('/users/$userId') as Map<String, dynamic>);

  Future<PostPage> userPosts(int userId, {int? beforeId}) async =>
      _page(await _get('/users/$userId/posts', {
        if (beforeId != null) 'before_id': '$beforeId',
      }));

  Future<UserProfile> updateMe({String? displayName, String? bio}) async =>
      UserProfile.fromJson(await _json('PATCH', '/me', {
        if (displayName != null) 'display_name': displayName,
        if (bio != null) 'bio': bio,
      }) as Map<String, dynamic>);

  Future<UserProfile> setAvatar(Uint8List bytes, String name) async {
    final j = await _send(() async {
      final req = http.MultipartRequest('PUT', _uri('/me/avatar'))
        ..headers.addAll(_headers)
        ..files
            .add(http.MultipartFile.fromBytes('image', bytes, filename: name));
      return http.Response.fromStream(await _http.send(req));
    }) as Map<String, dynamic>;
    return UserProfile.fromJson(j);
  }

  Future<UserProfile> deleteAvatar() async => UserProfile.fromJson(
      await _json('DELETE', '/me/avatar') as Map<String, dynamic>);

  Future<UserProfile> follow(int userId) async => UserProfile.fromJson(
      await _json('PUT', '/users/$userId/follow') as Map<String, dynamic>);

  Future<UserProfile> unfollow(int userId) async => UserProfile.fromJson(
      await _json('DELETE', '/users/$userId/follow') as Map<String, dynamic>);

  Future<void> unblock(int userId) => _json('DELETE', '/users/$userId/block');

  Future<List<AppUser>> _people(String path) async => [
        for (final u in await _get(path) as List)
          AppUser.fromJson(u as Map<String, dynamic>),
      ];

  Future<List<AppUser>> followers(int userId) =>
      _people('/users/$userId/followers');
  Future<List<AppUser>> following(int userId) =>
      _people('/users/$userId/following');

  // ---------------------------------------------------------------- colecții

  static List<PostCollection> _collections(dynamic j) => [
        for (final c in j as List)
          PostCollection.fromJson(c as Map<String, dynamic>),
      ];

  /// Colecțiile mele; cu [postId], fiecare spune dacă postarea e în ea.
  Future<List<PostCollection>> myCollections({int? postId}) async =>
      _collections(await _get(
          '/me/collections', {if (postId != null) 'post_id': '$postId'}));

  Future<List<PostCollection>> userCollections(int userId) async =>
      _collections(await _get('/users/$userId/collections'));

  Future<PostCollection> createCollection(String name,
          {required bool isPublic}) async =>
      PostCollection.fromJson(await _json(
              'POST', '/me/collections', {'name': name, 'is_public': isPublic})
          as Map<String, dynamic>);

  Future<PostCollection> updateCollection(int id,
          {String? name, bool? isPublic}) async =>
      PostCollection.fromJson(await _json('PATCH', '/collections/$id', {
        if (name != null) 'name': name,
        if (isPublic != null) 'is_public': isPublic,
      }) as Map<String, dynamic>);

  Future<void> deleteCollection(int id) => _json('DELETE', '/collections/$id');

  Future<void> savePost(int collectionId, int postId) =>
      _json('PUT', '/collections/$collectionId/posts/$postId');

  Future<void> unsavePost(int collectionId, int postId) =>
      _json('DELETE', '/collections/$collectionId/posts/$postId');

  Future<(PostCollection, List<Post>)> collection(int id) async {
    final j = await _get('/collections/$id') as Map<String, dynamic>;
    return (
      PostCollection.fromJson(j['collection'] as Map<String, dynamic>),
      [
        for (final p in j['posts'] as List)
          Post.fromJson(p as Map<String, dynamic>)
      ],
    );
  }
}
