import 'package:flutter/material.dart';

import 'data/profile_store.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final store = ProfileStore();
  // Desenăm interfața imediat; profilurile se încarcă în fundal.
  runApp(PatronetteApp(store: store));
  store.load();
}

class PatronetteApp extends StatelessWidget {
  const PatronetteApp({super.key, required this.store});

  final ProfileStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Patronette',
      debugShowCheckedModeBanner: false,
      theme: patronetteTheme(Brightness.light),
      darkTheme: patronetteTheme(Brightness.dark),
      home: HomeScreen(store: store),
    );
  }
}
