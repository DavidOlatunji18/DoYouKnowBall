import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../sports.dart';
import '../theme.dart';
import '../widgets/brand_header.dart';
import '../widgets/chunky_card.dart';
import '../widgets/circle_back_button.dart';
import '../widgets/load_view.dart';
import '../widgets/marker_headline.dart';
import '../widgets/stagger_in.dart';

/// Lists a sport's categories; each one starts a 10-question round.
class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({
    super.key,
    required this.sportId,
    required this.sportName,
  });

  final int sportId;
  final String sportName;

  @override
  Widget build(BuildContext context) {
    final api = context.read<ApiClient>();
    final style = SportStyle.of(sportName);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 120),
          children: [
            BrandHeader(
              leading: CircleBackButton(
                onTap: () =>
                    context.canPop() ? context.pop() : context.go('/home'),
              ),
              trailing: Image.asset(
                style.asset,
                width: 42,
                height: 42,
                excludeFromSemantics: true,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              sportName.toUpperCase(),
              style: appFont(
                13,
                weight: 800,
                letterSpacing: 1.4,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 6),
            const MarkerHeadline(lead: 'Pick a', marked: 'category.'),
            const SizedBox(height: 28),
            LoadView<List<SportCategory>>(
              load: () => api.categories(sportId),
              builder: (context, categories) => Column(
                children: [
                  for (var i = 0; i < categories.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: StaggerIn(
                        index: i,
                        child: _CategoryCard(category: categories[i]),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category});

  final SportCategory category;

  @override
  Widget build(BuildContext context) {
    return ChunkyCard(
      semanticLabel: 'Play ${category.name}, 10 questions',
      onTap: () => context.push(
        Uri(
          path: '/play/${category.id}',
          queryParameters: {'name': category.name},
        ).toString(),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.name,
                  style: appFont(
                    19,
                    weight: 800,
                    letterSpacing: -0.3,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '10 questions',
                  style: appFont(13.5, weight: 500, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.green,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.ink, width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.play_arrow_rounded,
                  size: 20,
                  color: AppColors.ink,
                ),
                const SizedBox(width: 2),
                Text('Play', style: appFont(14.5, weight: 800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
