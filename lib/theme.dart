import 'package:flutter/material.dart';

/// Culorile Patronette, luate din ilustrația fetei: rozul sărăfanului,
/// blondul-miere al codițelor, turcoazul aței de pe mosor și hârtia
/// roz-crem de pe fundal. Nuanțele închise sunt alese ca textul alb de pe
/// butoane să se citească ușor.
abstract final class PatronetteColors {
  static const rose = Color(0xFFA95560); // sărăfanul, mai închis pentru contrast
  static const roseLight = Color(0xFFF3D3D2);
  static const honey = Color(0xFF8C6239); // codițele și lemnul mesei
  static const honeyLight = Color(0xFFF2DFC4);
  static const thread = Color(0xFF4F7F7C); // ața turcoaz
  static const threadLight = Color(0xFFCFE5E2);
  static const paper = Color(0xFFFCF6F3); // hârtia roz-crem
  static const ink = Color(0xFF3D2B26); // contururile maro-calde
  static const lilac = Color(0xFF7A5C8E); // nasturii mov de pe fundal
  static const lilacLight = Color(0xFFE6DAEE);
}

/// O pereche de culori (închisă + deschisă) pentru elemente care trebuie să
/// se deosebească între ele: modelele de haine, profilurile.
class Accent {
  const Accent(this.strong, this.light);
  final Color strong;
  final Color light;

  static const all = [
    Accent(PatronetteColors.rose, PatronetteColors.roseLight),
    Accent(PatronetteColors.thread, PatronetteColors.threadLight),
    Accent(PatronetteColors.honey, PatronetteColors.honeyLight),
    Accent(PatronetteColors.lilac, PatronetteColors.lilacLight),
  ];

  static Accent of(int i) => all[i % all.length];
}

ThemeData patronetteTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final base = ColorScheme.fromSeed(
    seedColor: PatronetteColors.rose,
    brightness: brightness,
  );

  final scheme = dark
      ? base.copyWith(
          primary: const Color(0xFFEBA9B0),
          onPrimary: const Color(0xFF4A1F25),
          primaryContainer: const Color(0xFF6E3540),
          onPrimaryContainer: PatronetteColors.roseLight,
          secondary: const Color(0xFFE2C29A),
          secondaryContainer: const Color(0xFF5A4126),
          onSecondaryContainer: PatronetteColors.honeyLight,
          tertiary: const Color(0xFF9FCBC7),
          tertiaryContainer: const Color(0xFF2F5552),
          surface: const Color(0xFF221917),
          onSurface: const Color(0xFFF1E1DB),
          surfaceContainerLowest: const Color(0xFF1C1412),
          surfaceContainerLow: const Color(0xFF2A201D),
          surfaceContainer: const Color(0xFF2F2421),
          surfaceContainerHigh: const Color(0xFF3A2E2A),
          surfaceContainerHighest: const Color(0xFF463833),
          onSurfaceVariant: const Color(0xFFD9C4BD),
          outline: const Color(0xFFA08880),
          outlineVariant: const Color(0xFF55443F),
        )
      : base.copyWith(
          primary: PatronetteColors.rose,
          onPrimary: Colors.white,
          primaryContainer: PatronetteColors.roseLight,
          onPrimaryContainer: const Color(0xFF4A1F25),
          secondary: PatronetteColors.honey,
          onSecondary: Colors.white,
          secondaryContainer: PatronetteColors.honeyLight,
          onSecondaryContainer: const Color(0xFF3B2814),
          tertiary: PatronetteColors.thread,
          onTertiary: Colors.white,
          tertiaryContainer: PatronetteColors.threadLight,
          onTertiaryContainer: const Color(0xFF173533),
          surface: PatronetteColors.paper,
          onSurface: PatronetteColors.ink,
          surfaceContainerLowest: Colors.white,
          surfaceContainerLow: const Color(0xFFF9EFEB),
          surfaceContainer: const Color(0xFFF5E8E3),
          surfaceContainerHigh: const Color(0xFFF1E1DB),
          surfaceContainerHighest: const Color(0xFFECD9D2),
          onSurfaceVariant: const Color(0xFF6E5650),
          outline: const Color(0xFFA08880),
          outlineVariant: const Color(0xFFDDC9C2),
        );

  final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(18));
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: scheme.surface,
    // Bara de sus în rozul sărăfanului, ca să se vadă de la prima privire.
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? const Color(0xFF6E3540) : PatronetteColors.rose,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: rounded.copyWith(side: BorderSide(color: scheme.outlineVariant)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.secondaryContainer,
      labelStyle: TextStyle(color: scheme.onSecondaryContainer),
      side: BorderSide.none,
    ),
    sliderTheme: SliderThemeData(inactiveTrackColor: scheme.primaryContainer),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant),
  );
}
