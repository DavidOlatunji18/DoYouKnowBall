import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../ranks.dart';
import '../theme.dart';
import 'chunky_button.dart';
import 'confetti.dart';
import 'rank_badges.dart';

/// A full-screen celebration after a round that leveled the player up: a
/// bigger "new rank" moment when the level crossed into a new rank, otherwise a
/// quick "level up".
Future<void> showLevelUp(
  BuildContext context, {
  required Progress before,
  required Progress after,
  required int xpEarned,
}) => showGeneralDialog<void>(
  context: context,
  barrierDismissible: false,
  barrierColor: AppColors.ink,
  transitionDuration: const Duration(milliseconds: 250),
  pageBuilder: (context, _, _) =>
      _LevelUp(before: before, after: after, xpEarned: xpEarned),
  transitionBuilder: (context, animation, _, child) =>
      FadeTransition(opacity: animation, child: child),
);

class _LevelUp extends StatelessWidget {
  const _LevelUp({
    required this.before,
    required this.after,
    required this.xpEarned,
  });

  final Progress before;
  final Progress after;
  final int xpEarned;

  @override
  Widget build(BuildContext context) {
    final rank = RankStyle.of(after.rank);
    final newRank = after.rank != before.rank;
    final next = rank.next;
    final levelsToNext = next == null ? null : next.fromLevel - after.level;
    final animate = !MediaQuery.disableAnimationsOf(context);

    return Material(
      color: AppColors.ink,
      child: Stack(
        // Stretch the content to full width so the column centers on screen.
        fit: StackFit.expand,
        children: [
          const Positioned.fill(child: Confetti()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  const Spacer(),
                  Text(
                    newRank ? 'NEW RANK UNLOCKED' : 'LEVEL UP',
                    style: appFont(
                      11.5,
                      weight: 700,
                      letterSpacing: 2,
                      color: AppColors.green,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (!newRank)
                    Text(
                      'Level ${after.level}',
                      style: funFont(38, weight: 600, color: AppColors.card),
                    ),
                  if (!newRank) ...[
                    const SizedBox(height: 4),
                    Text(
                      '+$xpEarned XP this round',
                      style: appFont(
                        13.5,
                        weight: 500,
                        color: const Color(0xFFBDBBC9),
                      ),
                    ),
                  ],
                  const SizedBox(height: 26),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: animate ? 0.6 : 1, end: 1),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.elasticOut,
                    builder: (context, scale, child) =>
                        Transform.scale(scale: scale, child: child),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.06),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.green.withValues(alpha: 0.35),
                            blurRadius: 60,
                          ),
                        ],
                      ),
                      child: RankShield(rank: rank, width: newRank ? 120 : 96),
                    ),
                  ),
                  const SizedBox(height: 22),
                  if (newRank) ...[
                    Text(
                      rank.name,
                      style: funFont(36, weight: 600, color: AppColors.card),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'You reached level ${after.level}. The bulb’s getting brighter.',
                      textAlign: TextAlign.center,
                      style: appFont(
                        13.5,
                        weight: 500,
                        color: const Color(0xFFBDBBC9),
                        height: 1.4,
                      ),
                    ),
                  ] else
                    Text.rich(
                      TextSpan(
                        style: appFont(
                          13.5,
                          weight: 500,
                          color: const Color(0xFFBDBBC9),
                        ),
                        children: [
                          const TextSpan(text: 'Still '),
                          TextSpan(
                            text: rank.name,
                            style: appFont(
                              13.5,
                              weight: 600,
                              color: AppColors.card,
                            ),
                          ),
                          if (next != null && levelsToNext != null)
                            TextSpan(
                              text:
                                  ' · $levelsToNext level${levelsToNext == 1 ? '' : 's'} to ${next.name}',
                            ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  const Spacer(),
                  SizedBox(
                    width: 220,
                    child: ChunkyButton(
                      label: newRank ? "Let's go" : 'Nice',
                      height: 50,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
