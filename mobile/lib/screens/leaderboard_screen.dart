import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../auth/session.dart';
import '../game_events.dart';
import '../sports.dart';
import '../theme.dart';
import '../widgets/brand_header.dart';
import '../widgets/chunky_button.dart';
import '../widgets/load_view.dart';
import '../widgets/marker_headline.dart';
import '../widgets/stagger_in.dart';

/// Leaderboard tab: pick a sport, then see each player's best round in it. The top
/// three stand on a podium, everyone else is listed below, and your own spot is
/// highlighted (or, if you haven't played that sport, a nudge to go play).
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final _sports = GlobalKey<LoadViewState<List<Sport>>>();
  // A new key per sport, so switching sport starts a fresh load.
  var _board = GlobalKey<LoadViewState<List<LeaderboardEntry>>>();
  int? _sportId;

  Future<void> _refresh() =>
      _board.currentState?.reload(quiet: true) ??
      _sports.currentState?.reload(quiet: true) ??
      Future.value();

  @override
  Widget build(BuildContext context) {
    final api = context.read<ApiClient>();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.ink,
          backgroundColor: AppColors.green,
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 120),
            children: [
              const BrandHeader(),
              const SizedBox(height: 22),
              const MarkerHeadline(lead: 'Who knows', marked: 'ball?'),
              const SizedBox(height: 20),
              LoadView<List<Sport>>(
                key: _sports,
                load: api.sports,
                builder: (context, sports) {
                  if (sports.isEmpty) return const _NoSports();
                  final selected = sports.firstWhere(
                    (s) => s.id == _sportId,
                    orElse: () => sports.first,
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SportSwitcher(
                        sports: sports,
                        selectedId: selected.id,
                        onSelect: (id) => setState(() {
                          _sportId = id;
                          _board = GlobalKey();
                        }),
                      ),
                      const SizedBox(height: 26),
                      LoadView<List<LeaderboardEntry>>(
                        key: _board,
                        load: () => api.leaderboard(selected.id),
                        reloadWhen: context.read<GameEvents>(),
                        builder: (context, entries) =>
                            _Board(sport: selected, entries: entries),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SportSwitcher extends StatelessWidget {
  const _SportSwitcher({
    required this.sports,
    required this.selectedId,
    required this.onSelect,
  });

  final List<Sport> sports;
  final int selectedId;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (i, sport) in sports.indexed) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: _SportChip(
              style: SportStyle.of(sport.name),
              selected: sport.id == selectedId,
              onTap: () => onSelect(sport.id),
            ),
          ),
        ],
      ],
    );
  }
}

class _SportChip extends StatelessWidget {
  const _SportChip({
    required this.style,
    required this.selected,
    required this.onTap,
  });

  final SportStyle style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: style.label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.green : AppColors.card,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.ink, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.ink,
                offset: selected ? const Offset(3, 3) : Offset.zero,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(style.asset, width: 24, height: 24),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  style.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appFont(15, weight: selected ? 700 : 600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Board extends StatelessWidget {
  const _Board({required this.sport, required this.entries});

  final Sport sport;
  final List<LeaderboardEntry> entries;

  @override
  Widget build(BuildContext context) {
    final me = context.watch<Session>().user?.displayName;
    final style = SportStyle.of(sport.name);
    final onBoard = entries.any((e) => e.displayName == me);
    void play() => context.go(
      Uri(
        path: '/home/sport/${sport.id}',
        queryParameters: {'name': style.label},
      ).toString(),
    );

    if (entries.isEmpty) {
      return _Nudge(
        title: 'No scores yet',
        body: 'Nobody has played ${style.label} yet. Play a round and take #1.',
        onPlay: play,
      );
    }

    final podium = entries.take(3).toList();
    final rest = entries.skip(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Podium(entries: podium, me: me),
        const SizedBox(height: 22),
        for (final (i, entry) in rest.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: StaggerIn(
              index: i,
              child: _Row(entry: entry, isMe: entry.displayName == me),
            ),
          ),
        if (!onBoard) ...[
          const SizedBox(height: 8),
          _Nudge(
            title: "You're not on the board yet",
            body: 'Play a round of ${style.label} to get ranked.',
            onPlay: play,
          ),
        ],
      ],
    );
  }
}

/// The top three on gold, silver and bronze blocks: #2 left, #1 in the middle
/// (tallest, with a trophy), #3 right.
class _Podium extends StatelessWidget {
  const _Podium({required this.entries, required this.me});

  final List<LeaderboardEntry> entries;
  final String? me;

  static const _gold = Color(0xFFFFD60A);
  static const _silver = Color(0xFFDCDCE6);
  static const _bronze = Color(0xFFF2A65A);

  @override
  Widget build(BuildContext context) {
    Widget spot(int place, Color color, double height) {
      if (entries.length < place) return const Expanded(child: SizedBox());
      final entry = entries[place - 1];
      return Expanded(
        child: _PodiumSpot(
          entry: entry,
          color: color,
          blockHeight: height,
          isMe: entry.displayName == me,
          crowned: place == 1,
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        spot(2, _silver, 78),
        const SizedBox(width: 8),
        spot(1, _gold, 104),
        const SizedBox(width: 8),
        spot(3, _bronze, 60),
      ],
    );
  }
}

class _PodiumSpot extends StatelessWidget {
  const _PodiumSpot({
    required this.entry,
    required this.color,
    required this.blockHeight,
    required this.isMe,
    required this.crowned,
  });

  final LeaderboardEntry entry;
  final Color color;
  final double blockHeight;
  final bool isMe;
  final bool crowned;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label:
          'Rank ${entry.rank}, @${entry.displayName}${isMe ? ', you' : ''}, '
          'best ${entry.bestScore}',
      excludeSemantics: true,
      child: Column(
        children: [
          if (crowned)
            const Icon(
              Icons.emoji_events_rounded,
              size: 28,
              color: AppColors.ink,
            ),
          const SizedBox(height: 4),
          _Avatar(name: entry.displayName, size: crowned ? 64 : 54),
          const SizedBox(height: 8),
          Text(
            '@${entry.displayName}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: appFont(13.5, weight: 700),
          ),
          if (isMe) ...[const SizedBox(height: 4), const _YouTag()],
          const SizedBox(height: 8),
          Container(
            height: blockHeight,
            width: double.infinity,
            alignment: Alignment.topCenter,
            padding: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
              border: Border.all(color: AppColors.ink, width: 2),
            ),
            child: Column(
              children: [
                Text(
                  '${entry.rank}',
                  style: funFont(26, weight: 700, height: 1),
                ),
                const SizedBox(height: 2),
                Text(
                  'Best ${entry.bestScore}',
                  style: appFont(11.5, weight: 700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One player below the podium: rank, initial, name, games played and best score.
class _Row extends StatelessWidget {
  const _Row({required this.entry, required this.isMe});

  final LeaderboardEntry entry;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final games = entry.gamesPlayed == 1
        ? '1 game'
        : '${entry.gamesPlayed} games';

    return Semantics(
      container: true,
      label:
          'Rank ${entry.rank}, @${entry.displayName}${isMe ? ', you' : ''}, '
          'best ${entry.bestScore}, $games',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFFD6FFE9) : AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.ink, width: 2),
          boxShadow: isMe
              ? const [BoxShadow(color: AppColors.ink, offset: Offset(3, 3))]
              : null,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: Text(
                '${entry.rank}',
                style: appFont(16, weight: 700, color: AppColors.muted),
              ),
            ),
            _Avatar(name: entry.displayName, size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '@${entry.displayName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: appFont(15, weight: 700),
                        ),
                      ),
                      if (isMe) ...[const SizedBox(width: 6), const _YouTag()],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    games,
                    style: appFont(12.5, weight: 500, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _ScorePill(score: entry.bestScore),
          ],
        ),
      ),
    );
  }
}

/// A player's initial in a circle, like the Profile avatar.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.size});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.cream,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.ink, width: 2),
      ),
      child: Text(
        name.isEmpty ? '?' : name[0].toUpperCase(),
        style: appFont(size * 0.42, weight: 700),
      ),
    );
  }
}

/// Best score in a pill colored like the results ring (scores are out of 10).
class _ScorePill extends StatelessWidget {
  const _ScorePill({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        // Ink on the full red is hard to read, so low scores get the soft red.
        color: switch (AppColors.forScore(score, 10)) {
          AppColors.danger => AppColors.dangerSoft,
          final color => color,
        },
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.ink, width: 2),
      ),
      child: Text('$score/10', style: appFont(14, weight: 700)),
    );
  }
}

class _YouTag extends StatelessWidget {
  const _YouTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.green,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.ink, width: 1.5),
      ),
      child: Text('YOU', style: appFont(9.5, weight: 700, letterSpacing: 0.8)),
    );
  }
}

class _Nudge extends StatelessWidget {
  const _Nudge({required this.title, required this.body, required this.onPlay});

  final String title;
  final String body;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.ink, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: appFont(18, weight: 700)),
          const SizedBox(height: 4),
          Text(
            body,
            style: appFont(
              14,
              weight: 500,
              color: AppColors.muted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          ChunkyButton(label: 'Play a round', height: 50, onPressed: onPlay),
        ],
      ),
    );
  }
}

class _NoSports extends StatelessWidget {
  const _NoSports();

  @override
  Widget build(BuildContext context) => Text(
    'No sports yet.',
    style: appFont(16, weight: 500, color: AppColors.muted),
  );
}
