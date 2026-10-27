import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme.dart';
import '../widgets/brand_header.dart';
import '../widgets/circle_back_button.dart';
import '../widgets/marker_headline.dart';

/// Challenge tab: head-to-head games against friends. Coming in a later version;
/// the tab is here so the app is laid out around it from the start.
class ChallengeScreen extends StatelessWidget {
  const ChallengeScreen({super.key});

  @override
  Widget build(BuildContext context) => const _ComingSoon(
    lead: 'Challenge a',
    marked: 'friend.',
    body:
        'Battle your friends head to head and settle who really knows ball. Coming soon.',
  );
}

/// Leaderboard tab, until its screen is built.
class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) => const _ComingSoon(
    lead: 'The',
    marked: 'leaderboard.',
    body: 'Top players for each sport will show up here.',
  );
}

/// The quiz, until its screen is built from the sketch. Full-screen, no tab bar.
class QuizPlaceholderScreen extends StatelessWidget {
  const QuizPlaceholderScreen({super.key, required this.categoryName});

  final String categoryName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleBackButton(
                onTap: () =>
                    context.canPop() ? context.pop() : context.go('/home'),
              ),
              const Spacer(),
              MarkerHeadline(lead: categoryName, marked: 'quiz.'),
              const SizedBox(height: 12),
              Text(
                'The quiz screen is next.',
                style: appFont(16, weight: 500, color: AppColors.muted),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComingSoon extends StatelessWidget {
  const _ComingSoon({
    required this.lead,
    required this.marked,
    required this.body,
  });

  final String lead;
  final String marked;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 120),
          children: [
            const BrandHeader(),
            const SizedBox(height: 22),
            MarkerHeadline(lead: lead, marked: marked),
            const SizedBox(height: 14),
            Text(body, style: appFont(16, weight: 500, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}
