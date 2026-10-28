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

  /// Warm cream for cards that should stand apart from white ones (the question,
  /// the score ring, result tiles).
  static const cream = Color(0xFFF4F1EA);

  /// A deeper green for small "correct" marks that sit on light backgrounds.
  static const correctMark = Color(0xFF0FA958);

  /// The A, B, C and D letter colors. None are green or red, which mean right and wrong.
  static const answerLetters = [
    Color(0xFFFFD60A), // yellow
    Color(0xFF3A86FF), // blue
    Color(0xFFFF8A3D), // orange
    Color(0xFFFF5FA2), // pink
  ];

  /// A round's color by score: red for 0-4, yellow for 5-7, green for 8-10 (out of 10).
  static Color forScore(int score, int total) {
    final outOf10 = total == 0 ? 0 : score * 10 / total;
    if (outOf10 >= 8) return green;
    if (outOf10 >= 5) return const Color(0xFFFFC83D);
    return danger;
  }
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
        textStyle: appFont(16, weight: 600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.ink,
        textStyle: appFont(14.5, weight: 600),
      ),
    ),
  );
}
