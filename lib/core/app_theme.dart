import 'package:flutter/material.dart';

class SteelColors {
  // Identidade SteelControl — aço/titânio, igual ao desktop.
  static const ink = Color(0xFF11161C);
  static const navy = Color(0xFF27313C);
  static const primary = Color(0xFF66727D);
  static const primaryDark = Color(0xFF46515D);
  // Bronze industrial usado apenas como destaque visual, como no desktop.
  static const industrialAccent = Color(0xFFC39A45);
  static const industrialAccentDark = Color(0xFF9A7534);
  static const titanium = Color(0xFF9AA6B1);
  static const titaniumLight = Color(0xFFBCC5CD);
  static const steel700 = Color(0xFF3D4854);
  static const steel800 = Color(0xFF27313C);
  static const steel900 = Color(0xFF18202A);
  static const canvas = Color(0xFFEEF1F4);
  static const card = Color(0xFFFFFFFF);
  static const muted = Color(0xFF6F7A85);
  static const border = Color(0xFFDDE3E8);
  static const success = Color(0xFF16A34A);
  // Âmbar de aviso continua separado do bronze visual da identidade.
  static const warning = Color(0xFFAD7A2D);
  static const danger = Color(0xFFC43D3D);
}

class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final generated = ColorScheme.fromSeed(
      seedColor: SteelColors.primary,
      brightness: brightness,
      primary: SteelColors.primary,
      error: SteelColors.danger,
    );
    final scheme = generated.copyWith(
      secondary: SteelColors.industrialAccent,
      onSecondary: Colors.white,
      tertiary: SteelColors.industrialAccent,
      surface: dark ? const Color(0xFF18202A) : Colors.white,
      onSurface: dark ? const Color(0xFFF1F4F6) : SteelColors.ink,
      outline: dark ? const Color(0xFF3D4854) : const Color(0xFFCBD2D9),
      outlineVariant: dark ? const Color(0xFF343E48) : SteelColors.border,
      surfaceContainerHighest: dark ? const Color(0xFF27313C) : const Color(0xFFF1F4F6),
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark ? const Color(0xFF11161C) : SteelColors.canvas,
      fontFamily: 'Roboto',
    );

    final textTheme = base.textTheme.copyWith(
      displaySmall: base.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1.3),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -.7),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -.45),
      titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -.25),
      titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.45),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.4),
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: dark ? Colors.white : SteelColors.ink,
      ),
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: dark ? const Color(0xFF18202A) : Colors.white,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: dark ? const Color(0xFF343E48) : SteelColors.border,
          ),
          borderRadius: BorderRadius.circular(22),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF20272F) : const Color(0xFFF7F8FA),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: dark ? const Color(0xFF3D4854) : SteelColors.border,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: SteelColors.primary, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: SteelColors.industrialAccent,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: DividerThemeData(
        color: dark ? const Color(0xFF343E48) : SteelColors.border,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: dark ? const Color(0xFF18202A) : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 18,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: dark ? const Color(0xFF20272F) : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: dark ? const Color(0xFF18202A) : Colors.white,
        indicatorColor: SteelColors.industrialAccent.withValues(alpha: .14),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(fontWeight: states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600, color: states.contains(WidgetState.selected) ? SteelColors.industrialAccentDark : null)),
      ),
    );
  }
}
