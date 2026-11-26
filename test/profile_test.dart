import 'dart:convert';

import 'package:croi/community/api.dart';
import 'package:croi/community/community_screen.dart';
import 'package:croi/community/login_screen.dart';
import 'package:croi/community/profile_screen.dart';
import 'package:croi/community/session.dart';
import 'package:croi/data/profile_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

Map<String, dynamic> profileJson(
        {bool followed = false, int followers = 3, bool me = false}) =>
    {
      'id': 5,
      'display_name': 'Maria',
      'bio': 'Cos rochii de in.',
      'avatar_url': null,
      'post_count': 1,
      'follower_count': followers,
      'following_count': 2,
      'followed_by_me': followed,
      'blocked_by_me': false,
      'is_me': me,
    };

Map<String, dynamic> postJson(int id, {bool saved = false}) => {
      'id': id,
      'author': {'id': 5, 'display_name': 'Maria', 'avatar_url': null},
      'text': 'Tivul se calcă întâi',
      'link_url': null,
      'image_url': null,
      'pattern': null,
      'like_count': 0,
      'comment_count': 0,
      'liked_by_me': false,
      'saved_by_me': saved,
      'can_delete': false,
      'hidden': false,
      'created_at': '2026-11-26T10:00:00Z',
    };

Map<String, dynamic> collectionJson(int id, String name,
        {bool contains = false, bool public = true}) =>
    {
      'id': id,
      'owner': {'id': 3, 'display_name': 'Ana', 'avatar_url': null},
      'name': name,
      'is_public': public,
      'item_count': contains ? 1 : 0,
      'cover_url': null,
      'contains_post': contains,
    };

Future<Session> loggedIn(http.Client client) async {
  SharedPreferences.setMockInitialValues({});
  final session =
      Session(CommunityApi(baseUrl: 'http://server', client: client));
  await session.login('ana@exemplu.ro', 'parola-buna');
  return session;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('profilul arată cifrele, descrierea și urmărirea',
      (tester) async {
    final calls = <String>[];
    var followed = false;
    final client = MockClient((req) async {
      calls.add('${req.method} ${req.url.path}');
      switch (req.url.path) {
        case '/auth/login':
          return json({
            'token': 't',
            'user': {'id': 3, 'display_name': 'Ana'}
          });
        case '/users/5':
          return json(
              profileJson(followed: followed, followers: followed ? 4 : 3));
        case '/users/5/follow':
          followed = req.method == 'PUT';
          return json(
              profileJson(followed: followed, followers: followed ? 4 : 3));
        case '/users/5/posts':
          return json({
            'posts': [postJson(1)],
            'next_before_id': null
          });
        case '/users/5/collections':
          return json([collectionJson(9, 'Idei de vară')]);
      }
      return json({'detail': 'nu există'}, 404);
    });
    final session = await tester.runAsync(() => loggedIn(client));

    await tester.pumpWidget(MaterialApp(
      home: ProfileScreen(userId: 5, session: session!, store: ProfileStore()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Maria'), findsWidgets);
    expect(find.text('Cos rochii de in.'), findsOneWidget);
    expect(find.text('urmăritori'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Tivul se calcă întâi'), findsOneWidget); // în grilă

    await tester.tap(find.text('Urmărește'));
    await tester.pumpAndSettle();
    expect(calls, contains('PUT /users/5/follow'));
    expect(find.text('Urmărești'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);

    await tester.tap(find.text('Colecții'));
    await tester.pumpAndSettle();
    expect(find.text('Idei de vară'), findsOneWidget);
  });

  testWidgets('salvarea unei postări într-o colecție', (tester) async {
    final calls = <String>[];
    final client = MockClient((req) async {
      calls.add('${req.method} ${req.url.path}');
      switch (req.url.path) {
        case '/auth/login':
          return json({
            'token': 't',
            'user': {'id': 3, 'display_name': 'Ana'}
          });
        case '/posts':
          return json({
            'posts': [postJson(1)],
            'next_before_id': null
          });
        case '/me/collections':
          expect(req.url.queryParameters['post_id'], '1');
          return json([
            collectionJson(9, 'Idei de vară'),
            collectionJson(10, 'Tipare')
          ]);
        case '/collections/10/posts/1':
          return http.Response('', 204);
      }
      return json({'detail': 'nu există'}, 404);
    });
    final session = await tester.runAsync(() => loggedIn(client));
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: CommunityScreen(store: ProfileStore(), session: session!),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.bookmark_border));
    await tester.pumpAndSettle();
    expect(find.text('Salvează în colecție'), findsOneWidget);
    expect(find.text('Idei de vară'), findsOneWidget);

    await tester.tap(find.text('Tipare'));
    await tester.pumpAndSettle();
    expect(calls, contains('PUT /collections/10/posts/1'));

    await tester.tap(find.text('Gata'));
    await tester.pumpAndSettle();
    // Semnul de salvare devine plin pe postare.
    expect(find.byIcon(Icons.bookmark), findsOneWidget);
  });

  testWidgets('butonul „Continuă cu Google” apare pe Android', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home:
          LoginScreen(session: Session(CommunityApi(baseUrl: 'http://server'))),
    ));
    expect(find.text('Continuă cu Google'), findsOneWidget);

    // Fără clientul OAuth configurat, mesajul e clar, nu o eroare tehnică.
    await tester.tap(find.text('Continuă cu Google'));
    await tester.pumpAndSettle();
    expect(find.textContaining('nu e activată încă'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  test('profilul și colecțiile se citesc corect din răspunsul serverului',
      () async {
    final api = CommunityApi(
      baseUrl: 'http://server',
      client: MockClient((req) async => req.url.path == '/users/5'
          ? json(profileJson(followed: true))
          : json([collectionJson(9, 'Idei', contains: true, public: false)])),
    );
    final p = await api.profile(5);
    expect(p.displayName, 'Maria');
    expect(p.followedByMe, isTrue);
    expect(p.followerCount, 3);
    final cols = await api.myCollections(postId: 1);
    expect(cols.single.containsPost, isTrue);
    expect(cols.single.isPublic, isFalse);
  });
}
