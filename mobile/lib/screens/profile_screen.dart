import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../auth/session.dart';
import '../format.dart';
import '../game_events.dart';
import '../sports.dart';
import '../theme.dart';
import '../widgets/brand_header.dart';
import '../widgets/chunky_button.dart';
import '../widgets/load_view.dart';

/// Profile tab: who you are, your stats, and your recent games. Stats are worked
/// out from your game history, so there's a single request behind the screen.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  /// How many recent games to list.
  static const recentCount = 10;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _history = GlobalKey<LoadViewState<List<GameRecord>>>();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final api = context.read<ApiClient>();
    final user = session.user;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.ink,
          backgroundColor: AppColors.green,
          onRefresh: () =>
              _history.currentState?.reload(quiet: true) ?? Future.value(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 120),
            children: [
              const BrandHeader(),
              const SizedBox(height: 32),
              if (user != null) ...[
                Center(child: _Avatar(name: user.displayName)),
                const SizedBox(height: 16),
                Text(
                  '@${user.displayName}',
                  textAlign: TextAlign.center,
                  style: appFont(24, weight: 900, letterSpacing: -0.4),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  textAlign: TextAlign.center,
                  style: appFont(14, weight: 500, color: AppColors.muted),
                ),
                const SizedBox(height: 24),
              ],
              Center(
                child: SizedBox(
                  width: 160,
                  child: ChunkyButton(
                    label: 'Log out',
                    color: AppColors.danger,
                    textColor: AppColors.card,
                    height: 48,
                    onPressed: session.signOut,
                  ),
                ),
              ),
              const SizedBox(height: 36),
              LoadView<List<GameRecord>>(
                key: _history,
                load: api.history,
                reloadWhen: context.read<GameEvents>(),
                builder: (context, games) => games.isEmpty
                    ? const _NoGamesYet()
                    : _StatsAndRecent(games: games),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsAndRecent extends StatelessWidget {
  const _StatsAndRecent({required this.games});

  final List<GameRecord> games;

  @override
  Widget build(BuildContext context) {
    final correct = games.fold<int>(0, (sum, g) => sum + g.score);
    final asked = games.fold<int>(0, (sum, g) => sum + g.total);
    final best = games.reduce(
      (a, b) => a.score / a.total >= b.score / b.total ? a : b,
    );

    // Best round per sport, in the order the sports were first played.
    final bestBySport = <String, GameRecord>{};
    for (final game in games.reversed) {
      final current = bestBySport[game.sportName];
      if (current == null ||
          game.score / game.total > current.score / current.total) {
        bestBySport[game.sportName] = game;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Your stats'),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _StatTile(value: '${games.length}', label: 'Games'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                value: '${(100 * correct / asked).round()}%',
                label: 'Accuracy',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                value: '${best.score}/${best.total}',
                label: 'Best',
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Text(
          'BEST BY SPORT',
          style: appFont(
            12,
            weight: 800,
            letterSpacing: 1.2,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 10),
        for (final entry in bestBySport.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _GameRow(
              sportName: entry.key,
              title: SportStyle.of(entry.key).label,
              subtitle: 'Best round: ${entry.value.categoryName}',
              score: entry.value.score,
              total: entry.value.total,
            ),
          ),
        const SizedBox(height: 26),
        const _SectionTitle('Recent games'),
        const SizedBox(height: 14),
        for (final game in games.take(ProfileScreen.recentCount))
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _GameRow(
              sportName: game.sportName,
              title: game.categoryName,
              subtitle:
                  '${SportStyle.of(game.sportName).label} · ${friendlyDate(game.playedAt)}',
              score: game.score,
              total: game.total,
            ),
          ),
      ],
    );
  }
}

class _NoGamesYet extends StatelessWidget {
  const _NoGamesYet();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Your stats'),
        const SizedBox(height: 8),
        Text(
          'No games yet. Play your first round and your stats and recent games will show up here.',
          style: appFont(15, weight: 500, color: AppColors.muted, height: 1.4),
        ),
        const SizedBox(height: 18),
        ChunkyButton(
          label: 'Play a round',
          onPressed: () => context.go('/home'),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: appFont(22, weight: 900, letterSpacing: -0.4));
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.ink, width: 2),
        boxShadow: const [
          BoxShadow(color: AppColors.ink, offset: Offset(3, 3)),
        ],
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: appFont(26, weight: 900, letterSpacing: -0.6),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: appFont(
              11,
              weight: 800,
              letterSpacing: 1,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

/// A row for one round: the sport's ball, a title and subtitle, and the score
/// in a pill that turns green for 7 or better out of 10.
class _GameRow extends StatelessWidget {
  const _GameRow({
    required this.sportName,
    required this.title,
    required this.subtitle,
    required this.score,
    required this.total,
  });

  final String sportName;
  final String title;
  final String subtitle;
  final int score;
  final int total;

  @override
  Widget build(BuildContext context) {
    final strong = score / total >= 0.7;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.ink, width: 2),
      ),
      child: Row(
        children: [
          Image.asset(
            SportStyle.of(sportName).asset,
            width: 34,
            height: 34,
            excludeFromSemantics: true,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: appFont(15.5, weight: 800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: appFont(12.5, weight: 500, color: AppColors.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: strong ? AppColors.green : AppColors.background,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.ink, width: 2),
            ),
            child: Text('$score/$total', style: appFont(14, weight: 900)),
          ),
        ],
      ),
    );
  }
}

/// The player's first letter in a big green circle.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      height: 104,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.green,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.ink, width: 2.5),
        boxShadow: const [
          BoxShadow(color: AppColors.ink, offset: Offset(4, 4)),
        ],
      ),
      child: Text(
        name.isEmpty ? '?' : name[0].toUpperCase(),
        style: appFont(50, weight: 900),
      ),
    );
  }
}
