import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/brand_header.dart';
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
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
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
