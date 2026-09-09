import 'package:flutter/material.dart';

class SteelColors {
  SteelColors._();

  // Identidade SteelControl — Command Center industrial.
  static const ink = Color(0xFF0F1418);
  static const graphite = Color(0xFF151B1F);
  static const graphiteSoft = Color(0xFF1C2429);
  static const steel700 = Color(0xFF3A464D);
  static const steel600 = Color(0xFF4C5961);
  static const steel500 = Color(0xFF69767E);
  static const titanium = Color(0xFF96A2AA);
  static const titaniumLight = Color(0xFFC4CCD1);

  // Neutro técnico: não compete visualmente com os estados da máquina.
  static const primary = Color(0xFF53616A);
  static const primaryDark = Color(0xFF364149);

  // Âmbar é usado somente para identidade, seleção e ação.
  static const industrialAccent = Color(0xFFC98212);
  static const industrialAccentDark = Color(0xFF9D6208);

  static const canvas = Color(0xFFF0F2F3);
  static const card = Color(0xFFFFFFFF);
  static const panelLight = Color(0xFFF7F8F8);
  static const panelDark = Color(0xFF1A2126);
  static const muted = Color(0xFF6C7880);
  static const mutedDark = Color(0xFF9AA5AC);
  static const border = Color(0xFFD8DEE2);
  static const borderDark = Color(0xFF303A40);

  static const success = Color(0xFF1D9A5B);
  static const warning = Color(0xFFC98212);
  static const danger = Color(0xFFC83B3B);
}

class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: SteelColors.primary,
      brightness: brightness,
      primary: SteelColors.primary,
      secondary: SteelColors.industrialAccent,
      tertiary: SteelColors.industrialAccent,
      error: SteelColors.danger,
      surface: dark ? SteelColors.panelDark : SteelColors.card,
    ).copyWith(
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: dark ? const Color(0xFFF2F4F5) : SteelColors.ink,
      outline: dark ? SteelColors.borderDark : const Color(0xFFC7D0D5),
      outlineVariant: dark ? const Color(0xFF283137) : SteelColors.border,
      surfaceContainerHighest: dark ? const Color(0xFF222B30) : SteelColors.panelLight,
      surfaceContainerLow: dark ? const Color(0xFF171E22) : const Color(0xFFF9FAFA),
      surfaceContainerLowest: dark ? SteelColors.ink : Colors.white,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark ? SteelColors.ink : SteelColors.canvas,
      fontFamily: 'Roboto',
      splashFactory: InkSparkle.splashFactory,
    );

    final textTheme = base.textTheme.copyWith(
      displaySmall: base.textTheme.displaySmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -.7,
        height: 1.04,
      ),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -.35,
        height: 1.08,
      ),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -.2,
        height: 1.12,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -.08,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.42),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.38),
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: dark ? SteelColors.ink : SteelColors.canvas,
        foregroundColor: dark ? Colors.white : SteelColors.ink,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        color: dark ? SteelColors.panelDark : Colors.white,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: dark ? SteelColors.borderDark : SteelColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF20282D) : const Color(0xFFF8F9F9),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        labelStyle: TextStyle(color: dark ? SteelColors.mutedDark : SteelColors.muted),
        hintStyle: TextStyle(color: (dark ? SteelColors.mutedDark : SteelColors.muted).withValues(alpha: .72)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: dark ? SteelColors.borderDark : SteelColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: dark ? SteelColors.borderDark : SteelColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: SteelColors.industrialAccent, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: SteelColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: SteelColors.danger, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: SteelColors.industrialAccent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: dark ? const Color(0xFF30393E) : const Color(0xFFE0E4E6),
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: dark ? const Color(0xFFE6EAEC) : SteelColors.ink,
          side: BorderSide(color: dark ? SteelColors.borderDark : const Color(0xFFC7D0D5)),
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: SteelColors.industrialAccentDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? const Color(0xFF232B30) : SteelColors.graphite,
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dividerTheme: DividerThemeData(color: dark ? SteelColors.borderDark : SteelColors.border),
      dialogTheme: DialogThemeData(
        backgroundColor: dark ? SteelColors.panelDark : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: dark ? const Color(0xFF20282D) : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: dark ? const Color(0xFF222B30) : const Color(0xFFF3F5F6),
        selectedColor: SteelColors.industrialAccent.withValues(alpha: .12),
        side: BorderSide(color: dark ? SteelColors.borderDark : SteelColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 70,
        backgroundColor: dark ? SteelColors.graphite : Colors.white,
        indicatorColor: SteelColors.industrialAccent.withValues(alpha: .13),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? (dark ? const Color(0xFFFFC66A) : SteelColors.industrialAccentDark)
                : (dark ? const Color(0xFFC6CED2) : SteelColors.muted),
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? (dark ? const Color(0xFFFFB33A) : SteelColors.industrialAccentDark)
                : (dark ? const Color(0xFFA7B0B5) : SteelColors.muted),
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: dark ? SteelColors.panelDark : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
    );
  }
}
