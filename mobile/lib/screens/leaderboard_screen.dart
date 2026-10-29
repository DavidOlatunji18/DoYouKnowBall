import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../game_events.dart';
import '../ranks.dart';
import '../sports.dart';
import '../theme.dart';
import '../widgets/brand_header.dart';
import '../widgets/chunky_button.dart';
import '../widgets/load_view.dart';
import '../widgets/marker_headline.dart';
import '../widgets/rank_badges.dart';

/// Leaderboard tab: the top 10 players by XP, across all sports (Global) or in
/// one sport. Each row shows the player's rank shield, level and XP; #1's name
/// shimmers in gold. If you're outside the top 10, your row is pinned below.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final _sports = GlobalKey<LoadViewState<List<Sport>>>();
  // A new key per tab, so switching tabs starts a fresh load.
  var _board = GlobalKey<LoadViewState<Leaderboard>>();

  /// The selected sport, or null for the global board.
  Sport? _sport;

  Future<void> _refresh() =>
      _board.currentState?.reload(quiet: true) ??
      _sports.currentState?.reload(quiet: true) ??
      Future.value();

  void _select(Sport? sport) => setState(() {
    _sport = sport;
    _board = GlobalKey();
  });

  @override
  Widget build(BuildContext context) {
    final api = context.read<ApiClient>();
    final sport = _sport;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.ink,
          backgroundColor: AppColors.green,
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            children: [
              const BrandHeader(),
              const SizedBox(height: 22),
              const MarkerHeadline(lead: 'Who knows', marked: 'ball?'),
              const SizedBox(height: 18),
              LoadView<List<Sport>>(
                key: _sports,
                load: api.sports,
                builder: (context, sports) =>
                    _Tabs(sports: sports, selected: sport, onSelect: _select),
              ),
              const SizedBox(height: 18),
              Text.rich(
                TextSpan(
                  text: sport == null
                      ? 'GLOBAL'
                      : SportStyle.of(sport.name).label.toUpperCase(),
                  style: appFont(12.5, weight: 700, letterSpacing: 0.6),
                  children: [
                    TextSpan(
                      text: '  (Top 10 · all time)',
                      style: appFont(
                        12.5,
                        weight: 500,
                        color: const Color(0xFF9A98A8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              LoadView<Leaderboard>(
                key: _board,
                load: () => api.leaderboard(sportId: sport?.id),
                reloadWhen: context.read<GameEvents>(),
                builder: (context, board) => _Board(sport: sport, board: board),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Global first, then a tab per sport. Scrolls sideways when they don't fit.
class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.sports,
    required this.selected,
    required this.onSelect,
  });

  final List<Sport> sports;
  final Sport? selected;
  final ValueChanged<Sport?> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          _Tab(
            label: 'Global',
            icon: const Icon(
              Icons.public_rounded,
              size: 18,
              color: AppColors.ink,
            ),
            selected: selected == null,
            onTap: () => onSelect(null),
          ),
          for (final sport in sports) ...[
            const SizedBox(width: 8),
            _Tab(
              label: SportStyle.of(sport.name).label,
              icon: Image.asset(
                SportStyle.of(sport.name).asset,
                width: 20,
                height: 20,
              ),
              selected: selected?.id == sport.id,
              onTap: () => onSelect(sport),
            ),
          ],
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Widget icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            color: selected ? AppColors.green : AppColors.card,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.ink, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.ink,
                offset: selected ? const Offset(2, 2) : Offset.zero,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              const SizedBox(width: 6),
              Text(label, style: appFont(13, weight: selected ? 600 : 500)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Board extends StatelessWidget {
  const _Board({required this.sport, required this.board});

  /// Null for the global board.
  final Sport? sport;
  final Leaderboard board;

  @override
  Widget build(BuildContext context) {
    final me = board.me;
    final meInTop =
        me != null && board.top.any((e) => e.displayName == me.displayName);
    final label = sport == null ? null : SportStyle.of(sport!.name).label;

    void play() => context.go(
      sport == null
          ? '/home'
          : Uri(
              path: '/home/sport/${sport!.id}',
              queryParameters: {'name': label},
            ).toString(),
    );

    if (board.top.isEmpty) {
      return _Nudge(
        title: 'No scores yet',
        body: label == null
            ? 'Nobody has played yet. Play a round and take #1.'
            : 'Nobody has played $label yet. Play a round and take #1.',
        onPlay: play,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.ink, width: 2),
            boxShadow: const [
              BoxShadow(color: AppColors.ink, offset: Offset(3, 3)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Column(
              children: [
                for (final (i, entry) in board.top.indexed) ...[
                  if (i > 0)
                    Container(
                      height: 1,
                      color: AppColors.ink.withValues(alpha: 0.08),
                    ),
                  _Row(
                    entry: entry,
                    isMe: entry.displayName == me?.displayName,
                    sheenDelay: Duration(milliseconds: 250 * i),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (me != null && !meInTop) ...[
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFEAFFF3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.ink, width: 2),
              boxShadow: const [
                BoxShadow(color: AppColors.ink, offset: Offset(3, 3)),
              ],
            ),
            child: _Row(entry: me, isMe: true, pinned: true),
          ),
        ],
        if (me == null) ...[
          const SizedBox(height: 14),
          _Nudge(
            title: "You're not on the board yet",
            body: label == null
                ? 'Play a round to get ranked.'
                : 'Play a round of $label to get ranked.',
            onPlay: play,
          ),
        ],
      ],
    );
  }
}

/// One player: position (a medal for the top 3), rank shield, name with their
/// level and a small rank pill underneath, and XP on the right (with their best
/// score below it on sport boards).
class _Row extends StatelessWidget {
  const _Row({
    required this.entry,
    required this.isMe,
    this.pinned = false,
    this.sheenDelay = Duration.zero,
  });

  final LeaderboardEntry entry;
  final bool isMe;

  /// The pinned "you" row under the list draws its own background.
  final bool pinned;
  final Duration sheenDelay;

  static const _medals = ['🥇', '🥈', '🥉'];
  static const _soft = Color(0xFF9A98A8);

  @override
  Widget build(BuildContext context) {
    final rank = RankStyle.of(entry.rankName);
    final first = entry.rank == 1;
    final best = entry.bestScore;
    final name = isMe ? '${entry.displayName} · you' : entry.displayName;

    return Semantics(
      container: true,
      label:
          'Rank ${entry.rank}, @${entry.displayName}${isMe ? ', you' : ''}, '
          'level ${entry.level} ${rank.name}, ${formatXp(entry.xp)} XP'
          '${best != null ? ', best $best out of 10' : ''}',
      excludeSemantics: true,
      child: Container(
        height: 58,
        color: isMe && !pinned ? const Color(0xFFEAFFF3) : null,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              child: entry.rank <= 3
                  ? Text(
                      _medals[entry.rank - 1],
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18),
                    )
                  : Text(
                      '${entry.rank}',
                      textAlign: TextAlign.center,
                      style: appFont(
                        12.5,
                        weight: 700,
                        color: const Color(0xFF6F6E7D),
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            RankShield(rank: rank, width: 24, sheenDelay: sheenDelay),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: first
                            ? _GoldName(name)
                            : Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: appFont(14, weight: 500),
                              ),
                      ),
                      if (first) ...[
                        const SizedBox(width: 3),
                        const Icon(
                          Icons.workspace_premium_rounded,
                          size: 15,
                          color: Color(0xFFE0A800),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        'Lvl ${entry.level}',
                        style: appFont(10.5, weight: 500, color: _soft),
                      ),
                      const SizedBox(width: 5),
                      Flexible(child: RankPill(rank: rank, small: true)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text.rich(
                  TextSpan(
                    style: appFont(12.5, weight: 500, color: AppColors.muted),
                    children: [
                      TextSpan(
                        text: formatXp(entry.xp),
                        style: appFont(
                          12.5,
                          weight: 600,
                          color: const Color(0xFF4A4958),
                        ),
                      ),
                      const TextSpan(text: ' XP'),
                    ],
                  ),
                ),
                if (best != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Best $best/10',
                    style: appFont(10.5, weight: 500, color: _soft),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// #1's name in gold with a shimmer sweeping across it.
class _GoldName extends StatefulWidget {
  const _GoldName(this.name);

  final String name;

  @override
  State<_GoldName> createState() => _GoldNameState();
}

class _GoldNameState extends State<_GoldName>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  static const _gold = [
    Color(0xFFA87400),
    Color(0xFFE0A800),
    Color(0xFFFFE680),
    Color(0xFFE0A800),
    Color(0xFFA87400),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Text(
      widget.name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: appFont(14, weight: 600, color: Colors.white),
    );
    return AnimatedBuilder(
      animation: _controller,
      child: text,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) {
          // Slide a wide gold gradient across the name.
          final shift = (1 - _controller.value * 2.2) * bounds.width;
          return const LinearGradient(colors: _gold).createShader(
            Rect.fromLTWH(
              shift - bounds.width,
              0,
              bounds.width * 3,
              bounds.height,
            ),
          );
        },
        child: child,
      ),
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
          Text(title, style: appFont(16, weight: 600)),
          const SizedBox(height: 4),
          Text(
            body,
            style: appFont(
              13.5,
              weight: 500,
              color: AppColors.muted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          ChunkyButton(label: 'Play a round', height: 48, onPressed: onPlay),
        ],
      ),
    );
  }
}
