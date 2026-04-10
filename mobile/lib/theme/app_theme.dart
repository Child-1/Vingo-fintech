import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─── Myraba Design System ──────────────────────────────────────────
class MyrabaColors {
  // ── Brand primary: GTBank-style orange ───────────────────────────
  static const Color green       = Color(0xFFF26522);   // brand primary (orange)
  static const Color greenDark   = Color(0xFFD4541A);   // pressed / darker
  static const Color greenDeep   = Color(0xFFB84410);   // deep accent
  static const Color greenGlow   = Color(0x22F26522);   // 13% opacity glow

  // ── Brand secondary: electric purple ─────────────────────────────
  static const Color purple      = Color(0xFF9333EA);   // vibrant electric purple
  static const Color purpleGlow  = Color(0x409333EA);   // 25% glow

  // ── Semantic green (money received / positive) ───────────────────
  static const Color teal        = Color(0xFF10B981);
  static const Color tealGlow    = Color(0x2210B981);

  // ── Backgrounds ──────────────────────────────────────────────────
  static const Color bg          = Color(0xFF0C0A18);   // deep purple-tinted black
  static const Color surface     = Color(0xFF141128);   // purple-tinted card surface
  static const Color surfaceHigh = Color(0xFF1E1838);   // elevated card
  static const Color surfaceLine = Color(0xFF3D3060);   // visible purple dividers

  // ── Text ─────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecond  = Color(0xFFB0A8C8);
  static const Color textHint    = Color(0xFF6B6185);

  // ── Accents ──────────────────────────────────────────────────────
  static const Color gold        = Color(0xFFF59E0B);
  static const Color goldGlow    = Color(0x22F59E0B);
  static const Color blue        = Color(0xFF3B82F6);
  static const Color orange      = Color(0xFFF26522);   // alias for green
  static const Color red         = Color(0xFFEF4444);

  // ── Status ───────────────────────────────────────────────────────
  static const Color success     = Color(0xFF10B981);
  static const Color warning     = Color(0xFFF59E0B);
  static const Color error       = Color(0xFFEF4444);
  static const Color info        = Color(0xFF3B82F6);
}

class MyrabaText {
  static const _base = TextStyle(color: MyrabaColors.textPrimary);

  static final displayLg = _base.copyWith(fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -1.0);
  static final displayMd = _base.copyWith(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.5);
  static final headingLg = _base.copyWith(fontSize: 24, fontWeight: FontWeight.w700);
  static final headingMd = _base.copyWith(fontSize: 20, fontWeight: FontWeight.w700);
  static final headingSm = _base.copyWith(fontSize: 17, fontWeight: FontWeight.w600);
  static final bodyLg    = _base.copyWith(fontSize: 16, fontWeight: FontWeight.w400);
  static final bodyMd    = _base.copyWith(fontSize: 14, fontWeight: FontWeight.w400);
  static final bodySm    = _base.copyWith(fontSize: 12, fontWeight: FontWeight.w400);
  static final label     = _base.copyWith(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8);
  static final amount    = _base.copyWith(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.5);
  static final amountSm  = _base.copyWith(fontSize: 20, fontWeight: FontWeight.w700, color: MyrabaColors.gold);
}

// ─── Theme ────────────────────────────────────────────────────────
ThemeData myrabaTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: MyrabaColors.bg,
    colorScheme: const ColorScheme.dark(
      primary:   MyrabaColors.orange,
      secondary: MyrabaColors.purple,
      surface:   MyrabaColors.surface,
      error:     MyrabaColors.red,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: MyrabaColors.bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: MyrabaColors.textPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: IconThemeData(color: MyrabaColors.textPrimary),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: MyrabaColors.orange,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: MyrabaColors.orange,
        side: const BorderSide(color: MyrabaColors.orange, width: 1.5),
        minimumSize: const Size(double.infinity, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: MyrabaColors.orange),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: MyrabaColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: MyrabaColors.surfaceLine),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: MyrabaColors.surfaceLine),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: MyrabaColors.orange, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: MyrabaColors.red),
      ),
      hintStyle: const TextStyle(color: MyrabaColors.textHint, fontSize: 14),
      labelStyle: const TextStyle(color: MyrabaColors.textSecond),
    ),
    dividerTheme: const DividerThemeData(color: MyrabaColors.surfaceLine, thickness: 1),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: MyrabaColors.surface,
      selectedItemColor: MyrabaColors.orange,
      unselectedItemColor: MyrabaColors.textHint,
      selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontSize: 11),
      elevation: 0,
    ),
    tabBarTheme: const TabBarThemeData(
      indicatorColor: MyrabaColors.orange,
      labelColor: MyrabaColors.orange,
      unselectedLabelColor: MyrabaColors.textHint,
    ),
  );
}

// ─── Reusable decorations ─────────────────────────────────────────
BoxDecoration myrabaCard({double radius = 20, Color? color}) => BoxDecoration(
  color: color ?? MyrabaColors.surface,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: MyrabaColors.surfaceLine),
);

BoxDecoration myrabaGlowCard(Color glowColor) => BoxDecoration(
  color: MyrabaColors.surface,
  borderRadius: BorderRadius.circular(20),
  border: Border.all(color: glowColor.withValues(alpha: 0.35)),
  boxShadow: [
    BoxShadow(color: glowColor.withValues(alpha: 0.12), blurRadius: 24, offset: const Offset(0, 4)),
  ],
);
