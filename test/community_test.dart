import 'dart:convert';

import 'package:croi/community/api.dart';
import 'package:croi/community/community.dart';
import 'package:croi/community/community_screen.dart';
import 'package:croi/community/models.dart';
import 'package:croi/community/session.dart';
import 'package:croi/data/profile_store.dart';
import 'package:croi/garments/straight_skirt.dart';
import 'package:croi/models/measurements.dart';
import 'package:croi/models/profile.dart';
import 'package:croi/screens/pattern_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> postJson(int id,
        {String text = 'Sfat bun', Map? pattern, String? link}) =>
    {
      'id': id,
      'author': {'id': 7, 'display_name': 'Maria'},
      'text': text,
      'link_url': link,
      'image_url': null,
      'pattern': pattern,
      'like_count': 2,
      'comment_count': 1,
      'liked_by_me': false,
      'can_delete': false,
      'hidden': false,
      'created_at': '2026-11-25T10:00:00Z',
    };

http.Response jsonResponse(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  group('Clientul API', () {
    test('citește pagina de postări și trimite tokenul', () async {
      late http.Request seen;
      final api = CommunityApi(
        baseUrl: 'http://server',
        client: MockClient((req) async {
          seen = req;
          return jsonResponse({
            'posts': [
              postJson(2, pattern: {
                'garment_id': 'fusta-dreapta',
                'options': {'lungime': 60}
              }),
              postJson(1, link: 'https://exemplu.ro'),
            ],
            'next_before_id': 1,
          });
        }),
      )..token = 'abc';
      final page = await api.feed(beforeId: 5);
      expect(seen.url.queryParameters['before_id'], '5');
      expect(seen.headers['Authorization'], 'Bearer abc');
      expect(page.posts.map((p) => p.id), [2, 1]);
      expect(page.posts.first.pattern!.options['lungime'], 60.0);
      expect(page.posts.last.linkUrl, 'https://exemplu.ro');
      expect(page.nextBeforeId, 1);
    });

    test('mesajele de eroare ale serverului ajung la utilizatoare', () async {
      final api = CommunityApi(
        baseUrl: 'http://server',
        client: MockClient((_) async =>
            jsonResponse({'detail': 'E-mail sau parolă greșită.'}, 401)),
      );
      await expectLater(
        api.login('a@b.ro', 'x'),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'mesaj', 'E-mail sau parolă greșită.')
            .having((e) => e.unauthorized, 'neautorizat', isTrue)),
      );
    });

    test('erorile de validare devin propoziții în română', () async {
      final api = CommunityApi(
        baseUrl: 'http://server',
        client: MockClient((_) async => jsonResponse({
              'detail': [
                {
                  'loc': ['body', 'password'],
                  'msg': 'too short'
                }
              ]
            }, 422)),
      );
      await expectLater(
          api.register('a@b.ro', 'x', 'Ana'),
          throwsA(isA<ApiException>()
              .having((e) => e.message, 'mesaj', contains('8 caractere'))));
    });

    test('fără server: mesaj prietenos, nu o eroare tehnică', () async {
      final api = CommunityApi(
        baseUrl: 'http://server',
        client: MockClient(
            (_) async => throw http.ClientException('connection refused')),
      );
      await expectLater(
          api.feed(),
          throwsA(isA<ApiException>()
              .having((e) => e.message, 'mesaj', contains('conecta'))));
    });
  });

  test('sesiunea se păstrează după repornire', () async {
    SharedPreferences.setMockInitialValues({});
    final api = CommunityApi(
      baseUrl: 'http://server',
      client: MockClient((_) async => jsonResponse({
            'token': 'tok',
            'user': {'id': 3, 'display_name': 'Ana', 'is_admin': false}
          })),
    );
    await Session(api).login('ana@exemplu.ro', 'parola-buna');

    final api2 = CommunityApi(baseUrl: 'http://server');
    final restored = Session(api2);
    await restored.restore();
    expect(restored.user?.displayName, 'Ana');
    expect(api2.token, 'tok');

    await restored.logout();
    final after = Session(CommunityApi(baseUrl: 'http://server'));
    await after.restore();
    expect(after.loggedIn, isFalse);
  });

  test('un login de pe alt server nu se refolosește', () async {
    SharedPreferences.setMockInitialValues({});
    final local = CommunityApi(
      baseUrl: 'http://10.0.2.2:8000',
      client: MockClient((_) async => jsonResponse({
            'token': 'tok-local',
            'user': {'id': 3, 'display_name': 'Ana', 'is_admin': false}
          })),
    );
    await Session(local).login('ana@exemplu.ro', 'parola-buna');

    final cloud = CommunityApi(baseUrl: 'https://patronette-api.onrender.com');
    final session = Session(cloud);
    await session.restore();
    expect(session.loggedIn, isFalse);
    expect(cloud.token, isNull);
  });

  testWidgets('tokenul respins: deconectare și postările se văd fără cont',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final api = CommunityApi(
      baseUrl: 'http://server',
      client: MockClient((req) async {
        if (req.url.path == '/auth/login') {
          return jsonResponse({
            'token': 'expirat',
            'user': {'id': 3, 'display_name': 'Ana', 'is_admin': false}
          });
        }
        if (req.headers.containsKey('Authorization')) {
          return jsonResponse(
              {'detail': 'Sesiunea a expirat. Conectează-te din nou.'}, 401);
        }
        return jsonResponse({
          'posts': [postJson(1, text: 'Postare publică')],
          'next_before_id': null,
        });
      }),
    );
    final session = Session(api);
    await tester.runAsync(() => session.login('ana@exemplu.ro', 'parola-buna'));
    expect(session.loggedIn, isTrue);

    await tester.pumpWidget(MaterialApp(
      home: CommunityScreen(store: ProfileStore(), session: session),
    ));
    await tester.pumpAndSettle();
    expect(session.loggedIn, isFalse);
    expect(find.text('Postare publică'), findsOneWidget);
    expect(find.textContaining('expirat'), findsNothing);
    expect(find.text('Conectare'), findsOneWidget);
  });

  test('timpul postării se scrie pe înțeles', () {
    final now = DateTime(2026, 11, 25, 12);
    expect(timeAgo(now.subtract(const Duration(seconds: 20)), now: now),
        'chiar acum');
    expect(timeAgo(now.subtract(const Duration(minutes: 5)), now: now),
        'acum 5 min');
    expect(timeAgo(now.subtract(const Duration(hours: 1)), now: now),
        'acum o oră');
    expect(timeAgo(now.subtract(const Duration(days: 1)), now: now), 'ieri');
    expect(timeAgo(DateTime(2026, 3, 3), now: now), '3 mar.');
    expect(timeAgo(DateTime(2025, 3, 3), now: now), '3 mar. 2025');
  });

  testWidgets('comunitatea afișează postările de la server', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final api = CommunityApi(
      baseUrl: 'http://server',
      client: MockClient((_) async => jsonResponse({
            'posts': [
              postJson(1,
                  text: 'Călcați fiecare cusătură',
                  pattern: {'garment_id': 'pantaloni', 'options': {}}),
            ],
            'next_before_id': null,
          })),
    );
    await tester.pumpWidget(MaterialApp(
      home: CommunityScreen(store: ProfileStore(), session: Session(api)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Călcați fiecare cusătură'), findsOneWidget);
    expect(find.text('Maria'), findsOneWidget);
    expect(find.text('Pantaloni'), findsOneWidget); // tiparul atașat
    expect(find.text('Conectare'), findsOneWidget);
  });

  testWidgets('un tipar distribuit se deschide cu setările lui, în limite',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final profile =
        Profile(id: '1', name: 'Ana', values: Map.of(kExampleMeasurements));
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      home: PatternScreen(
        key: key,
        garment: const StraightSkirt(),
        profile: profile,
        // lungime peste limită, o setare necunoscută și una validă
        initialOptions: const {'lungime': 500, 'necunoscuta': 3, 'largime': 6},
      ),
    ));
    await tester.pumpAndSettle();
    final state = key.currentState as dynamic;
    final Map<String, double> options = state.debugOptions;
    final lengthOption =
        const StraightSkirt().options.firstWhere((o) => o.key == 'lungime');
    expect(options['lungime'], lengthOption.max);
    expect(options['largime'], 6);
    expect(options.containsKey('necunoscuta'), isFalse);
  });

  test('tiparul distribuit nu conține măsuri', () {
    const shared =
        SharedPattern(garmentId: 'fusta-dreapta', options: {'lungime': 60});
    final json = jsonEncode(shared.toJson());
    for (final key in kExampleMeasurements.keys) {
      expect(json.contains(key), isFalse, reason: key);
    }
  });
}
