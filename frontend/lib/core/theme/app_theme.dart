import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData dark() => _base(Brightness.dark, AppColors.dark);

  static ThemeData light() => _base(Brightness.light, AppColors.light);

  static ThemeData _base(Brightness brightness, AppColors colors) {
    final baseText = GoogleFonts.soraTextTheme(
      ThemeData(brightness: brightness).textTheme,
    ).apply(
      bodyColor: colors.ink,
      displayColor: colors.ink,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: colors.bg,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: colors.acc,
        onPrimary: colors.onAcc,
        secondary: colors.rob,
        onSecondary: colors.onAcc,
        error: colors.due,
        onError: colors.onAcc,
        surface: colors.card,
        onSurface: colors.ink,
      ),
      textTheme: baseText.copyWith(
        bodyLarge: baseText.bodyLarge?.copyWith(fontSize: 16, height: 1.4),
        bodyMedium: baseText.bodyMedium?.copyWith(fontSize: 15, height: 1.4),
        bodySmall: baseText.bodySmall?.copyWith(
          fontSize: 13,
          color: colors.ink2,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: baseText.titleLarge?.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
        titleMedium: baseText.titleMedium?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
        labelLarge: baseText.labelLarge?.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.bg,
        foregroundColor: colors.ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.sora(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: colors.ink,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.card,
        contentTextStyle: GoogleFonts.sora(
          color: colors.ink,
          fontWeight: FontWeight.w600,
        ),
        actionTextColor: colors.acc,
      ),
      dividerColor: colors.line,
      extensions: [colors],
    );
  }
}
