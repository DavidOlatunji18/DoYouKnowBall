import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../auth/session.dart';
import '../ranks.dart';
import '../sports.dart';
import '../theme.dart';
import '../widgets/brand_header.dart';
import '../widgets/chunky_card.dart';
import '../widgets/load_view.dart';
import '../widgets/marker_headline.dart';
import '../widgets/outlined_text.dart';
import '../widgets/progress_builder.dart';
import '../widgets/rank_badges.dart';
import '../widgets/rank_ladder.dart';
import '../widgets/stagger_in.dart';

/// The Home tab: welcomes the player and lists the sports to play, followed by
/// the sports that don't have questions yet as "coming soon" cards.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<ApiClient>();
    final username = context.watch<Session>().user?.displayName;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          // Bottom padding keeps the last card clear of the floating nav bar.
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
          children: [
            const BrandHeader(),
            const SizedBox(height: 22),
            if (username != null) ...[
              // The welcome line gets the rank shield and level once progress loads.
              ProgressBuilder(
                builder: (context, progress) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      container: true,
                      label: 'Welcome @$username',
                      excludeSemantics: true,
                      child: Text.rich(
                        TextSpan(
                          text: 'Welcome ',
                          style: funFont(21, weight: 500, height: 1.2),
                          children: [
                            WidgetSpan(
                              alignment: PlaceholderAlignment.baseline,
                              baseline: TextBaseline.alphabetic,
                              child: OutlinedText(
                                '@$username',
                                style: funFont(21, weight: 600, height: 1.2),
                                strokeWidth: 4,
                              ),
                            ),
                            if (progress != null)
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: RankShield(
                                    rank: RankStyle.of(progress.rank),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (progress != null) ...[
                      const SizedBox(height: 12),
                      LevelSummary(
                        progress: progress,
                        onTap: () => showRankLadder(context, progress),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 22),
            ],
            const MarkerHeadline(lead: 'Pick your', marked: 'sport.'),
            const SizedBox(height: 20),
            LoadView<List<Sport>>(
              load: api.sports,
              builder: (context, sports) {
                final playable = sports
                    .map((s) => SportStyle.of(s.name).label)
                    .toSet();
                final comingSoon = SportStyle.comingSoon
                    .where((s) => !playable.contains(s.label))
                    .toList();
                var index = 0;
                return Column(
                  children: [
                    for (final sport in sports)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: StaggerIn(
                          index: index++,
                          child: _SportCard(sport: sport),
                        ),
                      ),
                    for (final style in comingSoon)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: StaggerIn(
                          index: index++,
                          child: _ComingSoonCard(style: style),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SportCard extends StatelessWidget {
  const _SportCard({required this.sport});

  final Sport sport;

  @override
  Widget build(BuildContext context) {
    final style = SportStyle.of(sport.name);

    return ChunkyCard(
      semanticLabel: '${style.label}. ${style.blurb}',
      onTap: () => context.push(
        Uri(
          path: '/home/sport/${sport.id}',
          queryParameters: {'name': style.label},
        ).toString(),
      ),
      child: _SportRow(
        name: style.label,
        blurb: style.blurb,
        asset: style.asset,
        badge: const _Badge(
          icon: Icons.play_arrow_rounded,
          color: AppColors.green,
        ),
      ),
    );
  }
}

/// A sport without questions yet: shown so the lineup feels complete, but it
/// just explains that it's on the way when tapped.
class _ComingSoonCard extends StatelessWidget {
  const _ComingSoonCard({required this.style});

  final SportStyle style;

  @override
  Widget build(BuildContext context) {
    final name = style.label;

    return ChunkyCard(
      semanticLabel: '$name, coming soon',
      onTap: () {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.ink,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              content: Text(
                '$name trivia is coming soon. Stay tuned!',
                style: appFont(15, weight: 600, color: AppColors.card),
              ),
            ),
          );
      },
      child: Opacity(
        opacity: 0.55,
        child: _SportRow(
          name: name,
          blurb: 'Coming soon',
          asset: style.asset,
          badge: const _Badge(icon: Icons.lock_rounded, color: AppColors.card),
        ),
      ),
    );
  }
}

class _SportRow extends StatelessWidget {
  const _SportRow({
    required this.name,
    required this.blurb,
    required this.asset,
    required this.badge,
  });

  final String name;
  final String blurb;
  final String asset;
  final Widget badge;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Image.asset(asset, width: 46, height: 46, excludeFromSemantics: true),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: appFont(17, weight: 700, letterSpacing: -0.2)),
              const SizedBox(height: 4),
              Text(
                blurb,
                style: appFont(12.5, weight: 500, color: AppColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        badge,
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.ink, width: 2),
      ),
      child: Icon(icon, color: AppColors.ink, size: 20),
    );
  }
}
