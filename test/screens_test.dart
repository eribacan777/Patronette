import 'package:croi/garments/circle_skirt.dart';
import 'package:croi/garments/straight_skirt.dart';
import 'package:croi/models/measurements.dart';
import 'package:croi/models/profile.dart';
import 'package:croi/screens/fabric_screen.dart';
import 'package:croi/screens/pattern_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final profile = Profile(id: '1', name: 'Ana', values: Map.of(kExampleMeasurements));

/// Derulează panoul de setări până când [finder] e pe ecran.
Future<void> reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).last);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> openPattern(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: screen));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('ecranul tiparului arată câți metri trebuie cumpărați', (tester) async {
    await openPattern(tester, PatternScreen(garment: const StraightSkirt(), profile: profile));

    final material = find.text('Material necesar');
    await reveal(tester, material);
    expect(material, findsOneWidget);
    expect(find.textContaining('Cumpără'), findsOneWidget);
    expect(find.textContaining('Nu încape'), findsNothing);
  });

  testWidgets('fusta cloș lungă pe material îngust primește avertizare', (tester) async {
    await openPattern(tester, PatternScreen(garment: const CircleSkirt(), profile: profile));

    final narrow = find.text('110 cm');
    await reveal(tester, narrow);
    await tester.tap(narrow);
    await tester.pumpAndSettle();
    expect(find.textContaining('Nu încape pe materialul pliat'), findsOneWidget);
  });

  testWidgets('butonul deschide desenul cu așezarea pe material', (tester) async {
    await openPattern(tester, PatternScreen(garment: const StraightSkirt(), profile: profile));

    final button = find.text('Vezi așezarea pe material');
    await reveal(tester, button);
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(find.byType(FabricScreen), findsOneWidget);
    expect(find.textContaining('pliat în două pe lung'), findsOneWidget);
    expect(find.textContaining('Cumpără'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
