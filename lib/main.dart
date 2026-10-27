import 'package:flutter/material.dart';

import 'data/profile_store.dart';
import 'screens/home_screen.dart';

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
    const seed = Color(0xFFB5523B); // cărămiziu, ca o cretă de croitor
    return MaterialApp(
      title: 'Patronette',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: HomeScreen(store: store),
    );
  }
}
