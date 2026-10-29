import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../ranks.dart';
import '../theme.dart';
import 'chunky_button.dart';
import 'rank_badges.dart';

/// Shows every rank from YKB down to Waterboy: ranks you've passed are checked,
/// yours is highlighted, and the ones above are locked.
Future<void> showRankLadder(BuildContext context, Progress progress) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.ink.withValues(alpha: 0.4),
      builder: (context) => _RankLadder(progress: progress),
    );

class _RankLadder extends StatelessWidget {
  const _RankLadder({required this.progress});

  final Progress progress;

  @override
  Widget build(BuildContext context) {
    final mine = RankStyle.of(progress.rank);
    final myIndex = RankStyle.all.indexOf(mine);
    final toNext = progress.levelXpNeeded - progress.levelXp;

    return Container(
      padding: EdgeInsets.fromLTRB(
        18,
        18,
        18,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppColors.ink, width: 2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Your rank',
            textAlign: TextAlign.center,
            style: appFont(19, weight: 700),
          ),
          const SizedBox(height: 2),
          Text(
            'Climb from Waterboy to YKB',
            textAlign: TextAlign.center,
            style: appFont(12, weight: 500, color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          for (final rank in RankStyle.all.reversed)
            _Rung(
              rank: rank,
              state: switch (RankStyle.all.indexOf(rank)) {
                final i when i == myIndex => _RungState.current,
                final i when i < myIndex => _RungState.done,
                _ => _RungState.locked,
              },
            ),
          const SizedBox(height: 12),
          Text(
            'Level ${progress.level} · ${formatXp(toNext)} XP to level ${progress.level + 1}',
            textAlign: TextAlign.center,
            style: appFont(12.5, weight: 600),
          ),
          const SizedBox(height: 8),
          LevelBar(fraction: progress.fraction, rank: mine, height: 12),
          const SizedBox(height: 16),
          ChunkyButton(
            label: 'Got it',
            height: 48,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

enum _RungState { done, current, locked }

class _Rung extends StatelessWidget {
  const _Rung({required this.rank, required this.state});

  final RankStyle rank;
  final _RungState state;

  @override
  Widget build(BuildContext context) {
    final current = state == _RungState.current;
    final label = switch (state) {
      _RungState.current => 'your rank',
      _RungState.done => 'unlocked',
      _RungState.locked => 'locked',
    };

    return Semantics(
      container: true,
      label: '${rank.name}, levels ${rank.levels}, $label',
      excludeSemantics: true,
      child: Opacity(
        opacity: state == _RungState.locked ? 0.45 : 1,
        child: Container(
          margin: const EdgeInsets.only(bottom: 3),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: current ? AppColors.card : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: current ? AppColors.ink : Colors.transparent,
              width: 2,
            ),
            boxShadow: current
                ? const [BoxShadow(color: AppColors.ink, offset: Offset(3, 3))]
                : null,
          ),
          child: Row(
            children: [
              RankShield(rank: rank, width: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rank.name, style: appFont(13.5, weight: 600)),
                    Text(
                      'Levels ${rank.levels}',
                      style: appFont(11, weight: 500, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              switch (state) {
                _RungState.current => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.green,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.ink, width: 1.5),
                  ),
                  child: Text(
                    'YOU',
                    style: appFont(9.5, weight: 700, letterSpacing: 0.8),
                  ),
                ),
                _RungState.done => const Icon(
                  Icons.check_circle_rounded,
                  size: 20,
                  color: AppColors.correctMark,
                ),
                _RungState.locked => const Icon(
                  Icons.lock_rounded,
                  size: 18,
                  color: AppColors.muted,
                ),
              },
            ],
          ),
        ),
      ),
    );
  }
}
