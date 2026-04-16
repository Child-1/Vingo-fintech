import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MyrabaColorScheme — ThemeExtension (dark + light)
// Access in any widget via: context.mc.bg, context.mc.surface, etc.
// ─────────────────────────────────────────────────────────────────────────────
class MyrabaColorScheme extends ThemeExtension<MyrabaColorScheme> {
  final bool isDark;

  // Brand (same in both themes)
  final Color brand;
  final Color brandDark;
  final Color brandDeep;
  final Color brandGlow;
  final Color purple;
  final Color purpleGlow;
  final Color teal;
  final Color tealGlow;
  final Color gold;
  final Color goldGlow;
  final Color blue;
  final Color red;

  // Backgrounds
  final Color bg;
  final Color surface;
  final Color surfaceHigh;
  final Color surfaceLine;

  // Text
  final Color textPrimary;
  final Color textSecond;
  final Color textHint;

  const MyrabaColorScheme({
    required this.isDark,
    required this.brand,
    required this.brandDark,
    required this.brandDeep,
    required this.brandGlow,
    required this.purple,
    required this.purpleGlow,
    required this.teal,
    required this.tealGlow,
    required this.gold,
    required this.goldGlow,
    required this.blue,
    required this.red,
    required this.bg,
    required this.surface,
    required this.surfaceHigh,
    required this.surfaceLine,
    required this.textPrimary,
    required this.textSecond,
    required this.textHint,
  });

  // ── Aliases kept for backwards-compat ──────────────────────────────
  Color get green      => brand;
  Color get greenDark  => brandDark;
  Color get greenDeep  => brandDeep;
  Color get greenGlow  => brandGlow;
  Color get orange     => brand;
  Color get success    => teal;
  Color get warning    => gold;
  Color get error      => red;
  Color get info       => blue;

  // ── Reusable decorations ───────────────────────────────────────────
  BoxDecoration card({double radius = 20, Color? color}) => BoxDecoration(
    color: color ?? surface,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: surfaceLine),
  );

  BoxDecoration glowCard(Color glowColor) => BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: glowColor.withValues(alpha: 0.35)),
    boxShadow: [
      BoxShadow(
          color: glowColor.withValues(alpha: 0.12),
          blurRadius: 24,
          offset: const Offset(0, 4)),
    ],
  );

  // ── Dark palette ───────────────────────────────────────────────────
  static const dark = MyrabaColorScheme(
    isDark:      true,
    brand:       Color(0xFFF26522),
    brandDark:   Color(0xFFD4541A),
    brandDeep:   Color(0xFFB84410),
    brandGlow:   Color(0x22F26522),
    purple:      Color(0xFF9333EA),
    purpleGlow:  Color(0x409333EA),
    teal:        Color(0xFF10B981),
    tealGlow:    Color(0x2210B981),
    gold:        Color(0xFFF59E0B),
    goldGlow:    Color(0x22F59E0B),
    blue:        Color(0xFF3B82F6),
    red:         Color(0xFFEF4444),
    bg:          Color(0xFF0C0A18),
    surface:     Color(0xFF141128),
    surfaceHigh: Color(0xFF1E1838),
    surfaceLine: Color(0xFF3D3060),
    textPrimary: Color(0xFFFFFFFF),
    textSecond:  Color(0xFFB0A8C8),
    textHint:    Color(0xFF6B6185),
  );

  // ── Light palette ──────────────────────────────────────────────────
  static const light = MyrabaColorScheme(
    isDark:      false,
    brand:       Color(0xFFF26522),
    brandDark:   Color(0xFFD4541A),
    brandDeep:   Color(0xFFB84410),
    brandGlow:   Color(0x18F26522),
    purple:      Color(0xFF7C22D4),
    purpleGlow:  Color(0x207C22D4),
    teal:        Color(0xFF059669),
    tealGlow:    Color(0x18059669),
    gold:        Color(0xFFD97706),
    goldGlow:    Color(0x18D97706),
    blue:        Color(0xFF2563EB),
    red:         Color(0xFFDC2626),
    bg:          Color(0xFFF5F3FF),
    surface:     Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFEDE9FE),
    surfaceLine: Color(0xFFDDD6FE),
    textPrimary: Color(0xFF1A1535),
    textSecond:  Color(0xFF5C5478),
    textHint:    Color(0xFF9E96B8),
  );

  @override
  MyrabaColorScheme copyWith({
    bool? isDark,
    Color? brand, Color? brandDark, Color? brandDeep, Color? brandGlow,
    Color? purple, Color? purpleGlow,
    Color? teal, Color? tealGlow,
    Color? gold, Color? goldGlow,
    Color? blue, Color? red,
    Color? bg, Color? surface, Color? surfaceHigh, Color? surfaceLine,
    Color? textPrimary, Color? textSecond, Color? textHint,
  }) => MyrabaColorScheme(
    isDark:      isDark      ?? this.isDark,
    brand:       brand       ?? this.brand,
    brandDark:   brandDark   ?? this.brandDark,
    brandDeep:   brandDeep   ?? this.brandDeep,
    brandGlow:   brandGlow   ?? this.brandGlow,
    purple:      purple      ?? this.purple,
    purpleGlow:  purpleGlow  ?? this.purpleGlow,
    teal:        teal        ?? this.teal,
    tealGlow:    tealGlow    ?? this.tealGlow,
    gold:        gold        ?? this.gold,
    goldGlow:    goldGlow    ?? this.goldGlow,
    blue:        blue        ?? this.blue,
    red:         red         ?? this.red,
    bg:          bg          ?? this.bg,
    surface:     surface     ?? this.surface,
    surfaceHigh: surfaceHigh ?? this.surfaceHigh,
    surfaceLine: surfaceLine ?? this.surfaceLine,
    textPrimary: textPrimary ?? this.textPrimary,
    textSecond:  textSecond  ?? this.textSecond,
    textHint:    textHint    ?? this.textHint,
  );

  @override
  MyrabaColorScheme lerp(MyrabaColorScheme? other, double t) {
    if (other == null) return this;
    return MyrabaColorScheme(
      isDark:      t < 0.5 ? isDark : other.isDark,
      brand:       Color.lerp(brand, other.brand, t)!,
      brandDark:   Color.lerp(brandDark, other.brandDark, t)!,
      brandDeep:   Color.lerp(brandDeep, other.brandDeep, t)!,
      brandGlow:   Color.lerp(brandGlow, other.brandGlow, t)!,
      purple:      Color.lerp(purple, other.purple, t)!,
      purpleGlow:  Color.lerp(purpleGlow, other.purpleGlow, t)!,
      teal:        Color.lerp(teal, other.teal, t)!,
      tealGlow:    Color.lerp(tealGlow, other.tealGlow, t)!,
      gold:        Color.lerp(gold, other.gold, t)!,
      goldGlow:    Color.lerp(goldGlow, other.goldGlow, t)!,
      blue:        Color.lerp(blue, other.blue, t)!,
      red:         Color.lerp(red, other.red, t)!,
      bg:          Color.lerp(bg, other.bg, t)!,
      surface:     Color.lerp(surface, other.surface, t)!,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      surfaceLine: Color.lerp(surfaceLine, other.surfaceLine, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecond:  Color.lerp(textSecond, other.textSecond, t)!,
      textHint:    Color.lerp(textHint, other.textHint, t)!,
    );
  }
}

// ─── BuildContext shorthand ───────────────────────────────────────────────────
extension McExt on BuildContext {
  MyrabaColorScheme get mc =>
      Theme.of(this).extension<MyrabaColorScheme>() ?? MyrabaColorScheme.dark;
}

// ─── Legacy static class — kept so existing const usages still compile ────────
// New code should prefer context.mc.X
class MyrabaColors {
  static const Color green       = Color(0xFFF26522);
  static const Color greenDark   = Color(0xFFD4541A);
  static const Color greenDeep   = Color(0xFFB84410);
  static const Color greenGlow   = Color(0x22F26522);
  static const Color purple      = Color(0xFF9333EA);
  static const Color purpleGlow  = Color(0x409333EA);
  static const Color teal        = Color(0xFF10B981);
  static const Color tealGlow    = Color(0x2210B981);
  static const Color bg          = Color(0xFF0C0A18);
  static const Color surface     = Color(0xFF141128);
  static const Color surfaceHigh = Color(0xFF1E1838);
  static const Color surfaceLine = Color(0xFF3D3060);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecond  = Color(0xFFB0A8C8);
  static const Color textHint    = Color(0xFF6B6185);
  static const Color gold        = Color(0xFFF59E0B);
  static const Color goldGlow    = Color(0x22F59E0B);
  static const Color blue        = Color(0xFF3B82F6);
  static const Color orange      = Color(0xFFF26522);
  static const Color red         = Color(0xFFEF4444);
  static const Color success     = Color(0xFF10B981);
  static const Color warning     = Color(0xFFF59E0B);
  static const Color error       = Color(0xFFEF4444);
  static const Color info        = Color(0xFF3B82F6);
}

// ─── Text styles (brand-neutral; colours applied per widget) ─────────────────
class MyrabaText {
  static final displayLg = const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -1.0);
  static final displayMd = const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.5);
  static final headingLg = const TextStyle(fontSize: 24, fontWeight: FontWeight.w700);
  static final headingMd = const TextStyle(fontSize: 20, fontWeight: FontWeight.w700);
  static final headingSm = const TextStyle(fontSize: 17, fontWeight: FontWeight.w600);
  static final bodyLg    = const TextStyle(fontSize: 16);
  static final bodyMd    = const TextStyle(fontSize: 14);
  static final bodySm    = const TextStyle(fontSize: 12);
  static final label     = const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8);
}

// ─── ThemeData builders ───────────────────────────────────────────────────────
ThemeData _buildTheme(MyrabaColorScheme mc) {
  final brightness = mc.isDark ? Brightness.dark : Brightness.light;
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: mc.bg,
    extensions: [mc],
    colorScheme: ColorScheme(
      brightness: brightness,
      primary:    mc.brand,
      onPrimary:  Colors.white,
      secondary:  mc.purple,
      onSecondary: Colors.white,
      surface:    mc.surface,
      onSurface:  mc.textPrimary,
      error:      mc.red,
      onError:    Colors.white,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: mc.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: mc.textPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: IconThemeData(color: mc.textPrimary),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            mc.isDark ? Brightness.light : Brightness.dark,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: mc.brand,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: mc.brand,
        side: BorderSide(color: mc.brand, width: 1.5),
        minimumSize: const Size(double.infinity, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: mc.brand),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: mc.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: mc.surfaceLine),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: mc.surfaceLine),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: mc.brand, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: mc.red),
      ),
      hintStyle: TextStyle(color: mc.textHint, fontSize: 14),
      labelStyle: TextStyle(color: mc.textSecond),
    ),
    dividerTheme: DividerThemeData(color: mc.surfaceLine, thickness: 1),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: mc.surface,
      selectedItemColor: mc.brand,
      unselectedItemColor: mc.textHint,
      selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(fontSize: 11),
      elevation: 0,
    ),
    tabBarTheme: TabBarThemeData(
      indicatorColor: mc.brand,
      labelColor: mc.brand,
      unselectedLabelColor: mc.textHint,
    ),
  );
}

ThemeData myrabaTheme()      => _buildTheme(MyrabaColorScheme.dark);
ThemeData myrabaLightTheme() => _buildTheme(MyrabaColorScheme.light);

// ─── Legacy decoration helpers (dark-only, kept for compatibility) ────────────
BoxDecoration myrabaCard({double radius = 20, Color? color}) =>
    MyrabaColorScheme.dark.card(radius: radius, color: color);

BoxDecoration myrabaGlowCard(Color glowColor) =>
    MyrabaColorScheme.dark.glowCard(glowColor);
