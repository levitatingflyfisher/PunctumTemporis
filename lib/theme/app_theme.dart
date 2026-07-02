import 'package:flutter/material.dart';

/// Design tokens for the One Second A Day app
/// Supports Retro (CRT aesthetic), Modern (Material 3), and Hearth (OpenHearth warm) visual styles
class AppTheme {
  /// Active visual style: 'retro' | 'modern' | 'hearth'
  static String visualStyle = 'hearth';

  static bool get isRetro  => visualStyle == 'retro';
  static bool get isModern => visualStyle == 'modern';
  static bool get isHearth => visualStyle == 'hearth';

  // Hearth palette (from OpenHearth style guide)
  static const hearthPrimary         = Color(0xFFA85040); // hearth-500
  static const hearthPrimaryHover    = Color(0xFFC47B6A); // hearth-400
  static const hearthBgLight         = Color(0xFFFBF8F4); // linen-50
  static const hearthSurfaceLight    = Color(0xFFF5EFE6); // linen-100
  static const hearthSurfaceVarLight = Color(0xFFEAE1D4); // linen-200
  static const hearthTextLight       = Color(0xFF2C1810); // linen-900
  static const hearthBgDark          = Color(0xFF1C1007); // dark-surface-base
  static const hearthSurfaceDark     = Color(0xFF2A1810);
  static const hearthSurfaceVarDark  = Color(0xFF3A2418);
  static const hearthTextDark        = Color(0xFFFBF8F4); // linen-50

  // Accent color presets
  static const Map<String, Color> accentPresets = {
    'CRT Green': Color(0xFF00FF00),
    'Amber': Color(0xFFFFB000),
    'Hot Pink': Color(0xFFFF1493),
    'Electric Blue': Color(0xFF00BFFF),
    'Tangerine': Color(0xFFFF6600),
    'Lavender': Color(0xFFB388FF),
    'Mint': Color(0xFF00FFAA),
    'Coral': Color(0xFFFF6B6B),
  };

  // Dark theme colors (CRT aesthetic)
  static const darkBackground = Color(0xFF0A0A0A);
  static const darkSurface = Color(0xFF141414);
  static const darkSurfaceVariant = Color(0xFF1E1E1E);

  // Modern dark theme colors (slightly lighter surfaces)
  static const modernDarkSurface = Color(0xFF181818);
  static const modernDarkSurfaceVariant = Color(0xFF242424);

  // Light theme colors (Paper aesthetic)
  static const lightBackground = Color(0xFFF5F5F0);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceVariant = Color(0xFFE8E8E0);

  /// Build theme data based on brightness, accent, and visual style.
  /// NOTE: [accent] is ignored in Hearth mode — the palette always uses
  /// [hearthPrimary]. The stored accent value is preserved in prefs so it
  /// restores when the user switches back to Retro or Modern.
  static ThemeData buildTheme(Brightness brightness, Color accent) {
    assert(isRetro || isModern || isHearth,
        'Unknown visualStyle: "$visualStyle". Valid values: retro, modern, hearth.');
    if (isHearth) return _buildHearthTheme(brightness);

    final isDark = brightness == Brightness.dark;

    final surface =
        isDark ? (isModern ? modernDarkSurface : darkSurface) : lightSurface;
    final surfaceVariant = isDark
        ? (isModern ? modernDarkSurfaceVariant : darkSurfaceVariant)
        : lightSurfaceVariant;

    final cardRadius = isModern ? 12.0 : 4.0;
    final buttonRadius = isModern ? 10.0 : 4.0;
    final borderWidth = isModern ? 1.0 : 2.0;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: accent,
        onPrimary: _contrastColor(accent),
        secondary: accent.withOpacity(0.7),
        onSecondary: _contrastColor(accent),
        error: const Color(0xFFFF4444),
        onError: Colors.white,
        surface: surface,
        onSurface: isDark ? Colors.white : Colors.black87,
        surfaceContainerHighest: surfaceVariant,
      ),
      scaffoldBackgroundColor: isDark ? darkBackground : lightBackground,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: displayFont(
          fontSize: 18,
          color: isDark ? Colors.white : Colors.black87,
        ),
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: BorderSide(
            color: accent.withOpacity(isModern ? 0.15 : 0.3),
            width: borderWidth,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: _contrastColor(accent),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
          textStyle: monoFont(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          side: BorderSide(color: accent, width: borderWidth),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
          textStyle: monoFont(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ),
      iconTheme: IconThemeData(color: accent),
      dividerTheme: DividerThemeData(
        color: isModern
            ? (isDark ? Colors.white12 : Colors.black12)
            : accent.withOpacity(0.2),
        thickness: 1,
      ),
    );
  }

  /// VT323 (Retro) / system (Modern) / Lora (Hearth) — main display font
  static TextStyle displayFont({
    double fontSize = 16,
    Color? color,
    FontWeight fontWeight = FontWeight.normal,
    double? letterSpacing,
  }) {
    if (isHearth) {
      return TextStyle(
        fontFamily: 'Lora',
        fontSize: fontSize,
        color: color,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing ?? 0,
      );
    }
    if (isModern) {
      return TextStyle(
        fontSize: fontSize,
        color: color,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing ?? 0.5,
      );
    }
    return TextStyle(
      fontFamily: 'VT323',
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing ?? 1.0,
    );
  }

  /// Press Start 2P (Retro) / Roboto Mono Bold (Modern) / Nunito Bold (Hearth)
  static TextStyle pixelFont({
    double fontSize = 12,
    Color? color,
    FontWeight fontWeight = FontWeight.normal,
  }) {
    if (isHearth) {
      return TextStyle(
        fontFamily: 'Nunito',
        fontSize: fontSize,
        color: color,
        fontWeight: FontWeight.w700,
        height: 1.3,
      );
    }
    if (isModern) {
      return TextStyle(
        fontFamily: 'Roboto Mono',
        fontSize: fontSize,
        color: color,
        fontWeight: FontWeight.bold,
        height: 1.3,
      );
    }
    return TextStyle(
      fontFamily: 'Press Start 2P',
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight,
      height: 1.5,
    );
  }

  /// Roboto Mono (Retro/Modern) / Nunito (Hearth) — for data and labels
  static TextStyle monoFont({
    double fontSize = 14,
    Color? color,
    FontWeight fontWeight = FontWeight.normal,
  }) {
    if (isHearth) {
      return TextStyle(
        fontFamily: 'Nunito',
        fontSize: fontSize,
        color: color,
        fontWeight: fontWeight,
      );
    }
    return TextStyle(
      fontFamily: 'Roboto Mono',
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight,
    );
  }

  /// Lora (Hearth) / displayFont (Retro/Modern) — large display headings
  static TextStyle headingFont({
    double fontSize = 24,
    Color? color,
    FontWeight fontWeight = FontWeight.w600,
  }) {
    if (isHearth) {
      return TextStyle(
        fontFamily: 'Lora',
        fontSize: fontSize,
        color: color,
        fontWeight: fontWeight,
      );
    }
    return displayFont(fontSize: fontSize, color: color, fontWeight: fontWeight);
  }

  static ThemeData _buildHearthTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final surface    = isDark ? hearthSurfaceDark    : hearthSurfaceLight;
    final surfaceVar = isDark ? hearthSurfaceVarDark  : hearthSurfaceVarLight;
    final onSurface  = isDark ? hearthTextDark        : hearthTextLight;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: hearthPrimary,
        onPrimary: Colors.white,
        secondary: hearthPrimaryHover,
        onSecondary: Colors.white,
        error: const Color(0xFFFF4444),
        onError: Colors.white,
        surface: surface,
        onSurface: onSurface,
        surfaceContainerHighest: surfaceVar,
      ),
      scaffoldBackgroundColor: isDark ? hearthBgDark : hearthBgLight,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: displayFont(fontSize: 18, color: onSurface),
        iconTheme: IconThemeData(color: onSurface),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.12)
                : hearthSurfaceVarLight,
            width: 1,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: hearthPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: const StadiumBorder(),
          textStyle: monoFont(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: hearthPrimary,
          side: const BorderSide(color: hearthPrimary, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: const StadiumBorder(),
          textStyle: monoFont(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ),
      iconTheme: const IconThemeData(color: hearthPrimary),
      dividerTheme: DividerThemeData(
        color: isDark ? Colors.white.withOpacity(0.12) : hearthSurfaceVarLight,
        thickness: 1,
      ),
    );
  }

  /// Calculate contrast color for text on colored background
  static Color _contrastColor(Color color) {
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}
