import 'package:flutter/material.dart';

import 'theme.dart';

/// How each rank looks: its badge background, the color its bulb glows, and how
/// many rays the bulb has (0 = unlit). The names and level ranges match the API's
/// `Levels` class; the server decides a player's rank, this only styles it.
class RankStyle {
  const RankStyle({
    required this.name,
    required this.fromLevel,
    required this.toLevel,
    required this.background,
    required this.bulb,
    required this.glow,
    this.dark = false,
  });

  final String name;
  final int fromLevel;

  /// The last level in this rank, or null for the top rank.
  final int? toLevel;
  final Color background;
  final Color bulb;
  final int glow;

  /// YKB's badge is black with a glowing green bulb.
  final bool dark;

  /// "1–4", or "100+" for the top rank.
  String get levels => toLevel == null ? '$fromLevel+' : '$fromLevel–$toLevel';

  /// The color for this rank's progress bar.
  Color get barColor => dark ? AppColors.green : bulb;

  /// Text drawn on this rank's badge.
  Color get onBackground => dark ? AppColors.green : AppColors.ink;

  static const all = [
    RankStyle(
      name: 'Waterboy',
      fromLevel: 1,
      toLevel: 4,
      background: Color(0xFFE4E2EC),
      bulb: Color(0xFFBDBBC9),
      glow: 0,
    ),
    RankStyle(
      name: 'Benchwarmer',
      fromLevel: 5,
      toLevel: 9,
      background: Color(0xFFE9D8C4),
      bulb: Color(0xFFC8A27A),
      glow: 0,
    ),
    RankStyle(
      name: 'Casual',
      fromLevel: 10,
      toLevel: 19,
      background: Color(0xFFCFE0FF),
      bulb: Color(0xFF6E9BFF),
      glow: 1,
    ),
    RankStyle(
      name: 'Real Fan',
      fromLevel: 20,
      toLevel: 29,
      background: Color(0xFFFFD9C2),
      bulb: Color(0xFFFF8A3D),
      glow: 1,
    ),
    RankStyle(
      name: 'Certified',
      fromLevel: 30,
      toLevel: 49,
      background: Color(0xFFB8FFDB),
      bulb: AppColors.green,
      glow: 2,
    ),
    RankStyle(
      name: 'Unc',
      fromLevel: 50,
      toLevel: 74,
      background: Color(0xFFE3D6FF),
      bulb: Color(0xFF9B6BFF),
      glow: 2,
    ),
    RankStyle(
      name: 'GOAT',
      fromLevel: 75,
      toLevel: 99,
      background: Color(0xFFFFF0A8),
      bulb: Color(0xFFFFD60A),
      glow: 3,
    ),
    RankStyle(
      name: 'YKB',
      fromLevel: 100,
      toLevel: null,
      background: AppColors.ink,
      bulb: AppColors.green,
      glow: 3,
      dark: true,
    ),
  ];

  /// Looked up by the rank name the API sends; unknown names get the first rank.
  static RankStyle of(String name) =>
      all.firstWhere((r) => r.name == name, orElse: () => all.first);

  static RankStyle forLevel(int level) =>
      all.lastWhere((r) => level >= r.fromLevel, orElse: () => all.first);

  /// The rank after this one, or null at the top.
  RankStyle? get next {
    final i = all.indexOf(this);
    return i + 1 < all.length ? all[i + 1] : null;
  }
}
