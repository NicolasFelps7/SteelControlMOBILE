import 'package:flutter/material.dart';

class SteelColors {
  static const ink = Color(0xFF0B1220);
  static const navy = Color(0xFF10213F);
  static const primary = Color(0xFF2563EB);
  static const primaryDark = Color(0xFF1D4ED8);
  static const canvas = Color(0xFFF2F6FB);
  static const card = Color(0xFFFFFFFF);
  static const muted = Color(0xFF64748B);
  static const border = Color(0xFFDCE5F0);
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFDC2626);
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
      surface: dark ? const Color(0xFF0F1A2D) : Colors.white,
      onSurface: dark ? const Color(0xFFF1F5F9) : SteelColors.ink,
      outline: dark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
      outlineVariant: dark ? const Color(0xFF22304A) : SteelColors.border,
      surfaceContainerHighest: dark ? const Color(0xFF17243A) : const Color(0xFFF1F5F9),
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark ? const Color(0xFF07101F) : SteelColors.canvas,
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
        color: dark ? const Color(0xFF111B2E) : Colors.white,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: dark ? const Color(0xFF24324A) : SteelColors.border,
          ),
          borderRadius: BorderRadius.circular(22),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF0A1425) : const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: dark ? const Color(0xFF263652) : SteelColors.border,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: SteelColors.primary, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
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
        color: dark ? const Color(0xFF24324A) : SteelColors.border,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: dark ? const Color(0xFF0F1A2D) : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 18,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: dark ? const Color(0xFF152238) : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: dark ? const Color(0xFF0F1A2D) : Colors.white,
        indicatorColor: SteelColors.primary.withValues(alpha: .14),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(fontWeight: states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600)),
      ),
    );
  }
}
