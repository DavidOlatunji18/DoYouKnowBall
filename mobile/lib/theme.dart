import 'package:flutter/material.dart';

/// Brand colors. Text on [green] and [background] is always [ink]:
/// white on the green is only 1.3:1 contrast, black is 15.6:1.
abstract final class AppColors {
  static const green = Color(0xFF05FF85);
  static const background = Color(0xFFECEAF6);
  static const ink = Color(0xFF121212);
  static const muted = Color(0xFF5F5E6E);
  static const card = Color(0xFFFFFFFF);
  static const danger = Color(0xFFC62F2F);
  static const dangerSoft = Color(0xFFFFE3DE);
}

/// Montserrat text. It's a variable font, so the weight is set on its 'wght' axis
/// (100-1000) rather than picked from separate font files.
TextStyle appFont(
  double size, {
  double weight = 400,
  Color color = AppColors.ink,
  double? height,
  double letterSpacing = 0,
}) {
  return TextStyle(
    fontFamily: 'Montserrat',
    fontSize: size,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
    fontWeight: FontWeight.values[((weight / 100).round() - 1).clamp(0, 8)],
    fontVariations: [FontVariation.weight(weight)],
  );
}

/// Fredoka: a soft, rounded font for the friendly touches (the "dykb?" wordmark
/// and the welcome line). Also variable, so weight works the same way.
TextStyle funFont(
  double size, {
  double weight = 600,
  Color color = AppColors.ink,
  double? height,
  double letterSpacing = 0,
}) {
  return appFont(
    size,
    weight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  ).copyWith(fontFamily: 'Fredoka');
}

ThemeData buildTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.green,
    primary: AppColors.green,
    onPrimary: AppColors.ink,
    surface: AppColors.background,
    onSurface: AppColors.ink,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: 'Montserrat',
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.green,
        foregroundColor: AppColors.ink,
        minimumSize: const Size.fromHeight(58),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.ink, width: 2),
        ),
        textStyle: appFont(18, weight: 700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.ink,
        textStyle: appFont(15, weight: 700),
      ),
    ),
  );
}
