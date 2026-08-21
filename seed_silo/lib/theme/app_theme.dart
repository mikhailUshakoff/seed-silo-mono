import 'package:flutter/material.dart';

/// Brand palette sampled from the Seed Silo icon (a seed/sprout with
/// roots inside a circle), then refined for contrast and precision:
/// the accent is more saturated and the neutrals are cooler/darker
/// than the raw icon colors, so the UI reads as "vault" rather than
/// "wood cabin" while still sharing the icon's hue family.
///
/// Keeping these as named, semantic constants -- rather than scattering
/// `Colors.green` / `Colors.red` / `Colors.grey` across screens --
/// is what lets every screen share one consistent, trustworthy look.
class BrandColors {
  BrandColors._();

  // --- Core neutrals (cool, precise dark "vault") ---
  static const espressoDeep = Color(0xFF100C08); // scaffold background
  static const espressoSurface = Color(0xFF1A120A); // cards, sheets
  static const espressoSurfaceHigh = Color(0xFF241A10); // app bar, elevated
  static const border = Color(0xFF2E2013); // hairline borders
  static const borderStrong = Color(0xFF3A2C1C); // emphasized dividers

  // --- Text ---
  static const cream = Color(0xFFF5EEDF); // primary text/icons
  static const tan = Color(0xFFC2B79D); // secondary text, hints

  // --- Brand accent (refined from the icon's sage green) ---
  static const sageBright = Color(0xFF7CB668); // buttons, links, accent
  static const sageDim = Color(0xFF5C8A4C); // pressed / disabled sage

  // --- Semantic status colors ---
  // Named explicitly (rather than reusing "sageBright" ad hoc) so the
  // *meaning* of a color is unambiguous everywhere it's used: green only
  // ever means confirmed/safe, amber only ever means pending, rust only
  // ever means danger/destructive.
  static const verified = sageBright; // confirmed, active, safe
  static const pending = Color(0xFFD9A441); // awaiting confirmation
  static const rust = Color(0xFFCF5C3E); // error / destructive

  // --- Original icon colors (kept for icon/asset-adjacent contexts) ---
  static const espresso = Color(0xFF362212); // icon line work
  static const sage = Color(0xFFC7D2AA); // icon leaf/root fill
  static const sand = Color(0xFFD2C9AA); // icon background

  /// Tabular-figure monospace style for anything a user must verify
  /// character-by-character: addresses, tx hashes, chain IDs, raw
  /// calldata. Monospace is a standard security/engineering signal --
  /// it tells the user "this value is exact, compare it carefully."
  static const mono = TextStyle(
    fontFamily: 'monospace',
    fontFeatures: [FontFeature.tabularFigures()],
    letterSpacing: 0.2,
  );
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: BrandColors.sageBright,
      onPrimary: BrandColors.espressoDeep,
      primaryContainer: BrandColors.sage,
      onPrimaryContainer: BrandColors.espressoDeep,
      secondary: BrandColors.tan,
      onSecondary: BrandColors.espressoDeep,
      secondaryContainer: BrandColors.espressoSurfaceHigh,
      onSecondaryContainer: BrandColors.cream,
      tertiary: BrandColors.sand,
      onTertiary: BrandColors.espressoDeep,
      error: BrandColors.rust,
      onError: BrandColors.cream,
      errorContainer: Color(0xFF3B160E),
      onErrorContainer: BrandColors.rust,
      surface: BrandColors.espressoSurface,
      onSurface: BrandColors.cream,
      surfaceContainerHighest: BrandColors.espressoSurfaceHigh,
      onSurfaceVariant: BrandColors.tan,
      outline: BrandColors.tan,
      outlineVariant: BrandColors.borderStrong,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: BrandColors.cream,
      onInverseSurface: BrandColors.espressoDeep,
      inversePrimary: BrandColors.sageDim,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: BrandColors.espressoDeep,
      fontFamily: 'Roboto',
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
          color: BrandColors.cream,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: BrandColors.cream,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(
          color: BrandColors.cream,
          height: 1.4,
        ),
        bodySmall: base.textTheme.bodySmall?.copyWith(
          color: BrandColors.tan,
        ),
        labelLarge: base.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: BrandColors.espressoSurfaceHigh,
        foregroundColor: BrandColors.cream,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: BrandColors.cream,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: BrandColors.espressoSurfaceHigh,
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: BrandColors.border, width: 1),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: BrandColors.sageBright,
        textColor: BrandColors.cream,
      ),
      dividerTheme: const DividerThemeData(
        color: BrandColors.border,
        thickness: 1,
        space: 24,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: BrandColors.espressoSurface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: BrandColors.borderStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: BrandColors.borderStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: BrandColors.sageBright, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: BrandColors.rust),
        ),
        labelStyle: const TextStyle(color: BrandColors.tan),
        hintStyle: const TextStyle(color: BrandColors.tan),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: BrandColors.sageBright,
          foregroundColor: BrandColors.espressoDeep,
          disabledBackgroundColor: BrandColors.sageDim.withValues(alpha: 0.4),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: BrandColors.sageBright,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: BrandColors.cream),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: BrandColors.espressoSurface,
        selectedColor: BrandColors.sageBright,
        labelStyle: const TextStyle(color: BrandColors.cream),
        side: const BorderSide(color: BrandColors.borderStrong),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return BrandColors.sageBright;
          }
          return BrandColors.tan;
        }),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: BrandColors.sageBright,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: BrandColors.espressoSurfaceHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: BrandColors.espressoSurfaceHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: BrandColors.espressoSurfaceHigh,
        contentTextStyle: const TextStyle(color: BrandColors.cream),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
