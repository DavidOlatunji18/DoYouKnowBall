import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../ranks.dart';
import '../sports.dart';
import '../theme.dart';
import '../widgets/chunky_button.dart';
import '../widgets/confetti.dart';
import '../widgets/level_up.dart';
import '../widgets/rank_badges.dart';
import '../widgets/score_ring.dart';

/// The end of a round: the score in a colored ring, a verdict, your best in this
/// category, your longest streak and your rank in the sport, then every question
/// with what you picked. Best and rank load in the background and show "–"
/// until they arrive (or if they can't be loaded).
class ResultsView extends StatefulWidget {
  const ResultsView({
    super.key,
    required this.quiz,
    required this.game,
    required this.picks,
    required this.sportId,
    required this.sportName,
    required this.categoryName,
    required this.onPlayAgain,
    required this.onHome,
  });

  final Quiz quiz;
  final GameResult game;

  /// What the player tapped on each question, by index; -1 if skipped.
  final List<int> picks;
  final int? sportId;

  /// The API name or the display label; either works with [SportStyle].
  final String sportName;
  final String categoryName;
  final VoidCallback onPlayAgain;
  final VoidCallback onHome;

  /// The headline and line under it, by score out of 10.
  static (String, String) verdict(int score, int total) {
    final outOf10 = total == 0 ? 0 : score * 10 / total;
    if (outOf10 >= 10) {
      return (
        'Certified ball knower.',
        'Perfect round. Nobody can tell you anything.',
      );
    }
    if (outOf10 >= 8) {
      return ('You know ball.', 'Solid round. Run it back for a perfect 10?');
    }
    if (outOf10 >= 5) {
      return (
        'You know some ball.',
        "Not bad. A few more and you're dangerous.",
      );
    }
    return ('Do you though?', 'Rough one. Shake it off and go again.');
  }

  @override
  State<ResultsView> createState() => _ResultsViewState();
}

class _ResultsViewState extends State<ResultsView> {
  /// Best score in this category before this round; null if this was the first.
  int? _previousBest;
  bool _bestLoaded = false;
  int? _rank;
  bool _rankLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadBest();
    _loadRank();
    final game = widget.game;
    if (game.after.level > game.before.level) {
      // Celebrate once the results are on screen behind it.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showLevelUp(
            context,
            before: game.before,
            after: game.after,
            xpEarned: game.xp.total,
          );
        }
      });
    }
  }

  Future<void> _loadBest() async {
    try {
      final history = await context.read<ApiClient>().history();
      final earlier = history.where(
        (g) =>
            g.gameId != widget.game.gameId &&
            SportStyle.of(g.sportName).label ==
                SportStyle.of(widget.sportName).label &&
            g.categoryName == widget.categoryName,
      );
      if (!mounted) return;
      setState(() {
        _previousBest = earlier.isEmpty
            ? null
            : earlier.map((g) => g.score).reduce((a, b) => a > b ? a : b);
        _bestLoaded = true;
      });
    } on ApiError {
      // Leave it as "–"; the round itself is already saved.
    }
  }

  Future<void> _loadRank() async {
    final sportId = widget.sportId;
    if (sportId == null) return;
    try {
      final board = await context.read<ApiClient>().leaderboard(
        sportId: sportId,
      );
      if (!mounted) return;
      setState(() {
        _rank = board.me?.rank;
        _rankLoaded = true;
      });
    } on ApiError {
      // Leave it as "–".
    }
  }

  int get _bestStreak {
    var streak = 0;
    var best = 0;
    for (final item in widget.game.review) {
      streak = item.correct ? streak + 1 : 0;
      if (streak > best) best = streak;
    }
    return best;
  }

  void _challengeSoon() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.ink,
          content: Text(
            'Challenging friends is coming soon. Stay tuned!',
            style: appFont(15, weight: 600, color: AppColors.card),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final (title, subtitle) = ResultsView.verdict(game.score, game.total);
    final style = SportStyle.of(widget.sportName);
    final previous = _previousBest;
    final isNewBest = previous != null && game.score > previous;
    final best = previous == null || game.score > previous
        ? game.score
        : previous;
    final questionsById = {for (final q in widget.quiz.questions) q.id: q};

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Row(
              children: [
                Semantics(
                  button: true,
                  label: 'Close',
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: widget.onHome,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.ink, width: 2),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.ink, width: 2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        style.asset,
                        width: 18,
                        height: 18,
                        excludeFromSemantics: true,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.categoryName,
                        style: appFont(13, weight: 600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: ScoreRing(score: game.score, total: game.total),
            ),
            const SizedBox(height: 16),
            Semantics(
              header: true,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: appFont(28, weight: 700, letterSpacing: -0.5),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: appFont(14, weight: 500, color: AppColors.muted),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    value: _bestLoaded ? '$best/${game.total}' : '–',
                    label: 'Your best',
                    badge: isNewBest ? 'New' : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatTile(value: '$_bestStreak', label: 'Streak'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatTile(
                    value: _rankLoaded && _rank != null ? '#$_rank' : '–',
                    label: 'Rank',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _XpCard(game: game),
            const SizedBox(height: 22),
            ChunkyButton(label: 'Play again', onPressed: widget.onPlayAgain),
            const SizedBox(height: 12),
            _ChallengeButton(onTap: _challengeSoon),
            const SizedBox(height: 4),
            TextButton(
              onPressed: widget.onHome,
              style: TextButton.styleFrom(foregroundColor: AppColors.muted),
              child: Text(
                'Back to Home',
                style: appFont(14.5, weight: 600, color: AppColors.muted),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'YOUR ANSWERS',
              style: appFont(
                12,
                weight: 700,
                letterSpacing: 1.2,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 10),
            for (final (i, item) in game.review.indexed)
              if (questionsById[item.questionId] case final question?)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _RecapRow(
                    question: question,
                    item: item,
                    // The server's record is the source of truth; fall back to
                    // what was tapped in case it's missing.
                    picked: item.selectedIndex >= 0
                        ? item.selectedIndex
                        : (i < widget.picks.length ? widget.picks[i] : -1),
                  ),
                ),
          ],
        ),
        if (AppColors.forScore(game.score, game.total) == AppColors.green)
          const Positioned.fill(child: Confetti()),
      ],
    );
  }
}

/// The XP this round earned and where it came from, with the level bar after it.
class _XpCard extends StatelessWidget {
  const _XpCard({required this.game});

  final GameResult game;

  @override
  Widget build(BuildContext context) {
    final xp = game.xp;
    final after = game.after;
    final rank = RankStyle.of(after.rank);

    Widget line(String label, int amount, {bool dim = false}) => Opacity(
      opacity: dim ? 0.4 : 1,
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Expanded(child: Text(label, style: appFont(12.5, weight: 500))),
            Text('+$amount', style: appFont(12.5, weight: 600)),
          ],
        ),
      ),
    );

    return Semantics(
      container: true,
      label:
          '${xp.total} XP earned. Level ${after.level}, ${after.levelXp} of '
          '${after.levelXpNeeded} XP to the next level',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.ink, width: 2),
          boxShadow: const [
            BoxShadow(color: AppColors.ink, offset: Offset(3, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    'XP EARNED',
                    style: appFont(
                      11,
                      weight: 700,
                      letterSpacing: 1.1,
                      color: AppColors.muted,
                    ),
                  ),
                ),
                Text(
                  '+${xp.total}',
                  style: funFont(26, weight: 600, height: 1),
                ),
              ],
            ),
            const SizedBox(height: 6),
            line('${game.score} correct × 10', xp.correct),
            line('Round complete', xp.round),
            line(
              'Perfect round',
              xp.perfect == 0 ? 30 : xp.perfect,
              dim: xp.perfect == 0,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('Lv ${after.level}', style: appFont(12, weight: 600)),
                const Spacer(),
                Text.rich(
                  TextSpan(
                    style: appFont(10.5, weight: 500, color: AppColors.muted),
                    children: [
                      TextSpan(
                        text: formatXp(after.levelXp),
                        style: appFont(10.5, weight: 600),
                      ),
                      TextSpan(text: ' / ${formatXp(after.levelXpNeeded)} XP'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LevelBar(fraction: after.fraction, rank: rank),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label, this.badge});

  final String value;
  final String label;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$label: $value${badge != null ? ', new best' : ''}',
      excludeSemantics: true,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.ink, width: 2),
              boxShadow: const [
                BoxShadow(color: AppColors.ink, offset: Offset(3, 3)),
              ],
            ),
            child: Column(
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(value, style: appFont(20, weight: 700)),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label.toUpperCase(),
                    style: appFont(
                      10.5,
                      weight: 700,
                      letterSpacing: 1,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (badge != null)
            Positioned(
              top: -10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.green,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.ink, width: 1.5),
                ),
                child: Text(
                  badge!.toUpperCase(),
                  style: appFont(9.5, weight: 700, letterSpacing: 0.8),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// "Challenge a friend" with a "Soon" tag, ready for multiplayer.
class _ChallengeButton extends StatelessWidget {
  const _ChallengeButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Challenge a friend, coming soon',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.ink, width: 2),
            boxShadow: const [
              BoxShadow(color: AppColors.ink, offset: Offset(4, 4)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.sports_mma_rounded, color: AppColors.ink),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Challenge a friend',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appFont(16, weight: 600),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'SOON',
                  style: appFont(
                    10,
                    weight: 700,
                    letterSpacing: 0.8,
                    color: AppColors.card,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One question in the recap: a green check or a red X, the question, and either
/// the answer (right) or your pick crossed out next to the answer (missed).
class _RecapRow extends StatelessWidget {
  const _RecapRow({
    required this.question,
    required this.item,
    required this.picked,
  });

  final QuizQuestion question;
  final ReviewItem item;
  final int picked;

  @override
  Widget build(BuildContext context) {
    final right = item.correct;
    final answer = question.options[item.correctIndex];
    final pickedText = picked >= 0 && picked < question.options.length
        ? question.options[picked]
        : null;
    final detail = appFont(12, weight: 500, color: AppColors.muted);

    return Semantics(
      container: true,
      label: right
          ? 'Right. ${question.text} $answer'
          : 'Missed. ${question.text} '
                '${pickedText == null ? 'No answer' : 'You picked $pickedText'}. '
                'Answer: $answer',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: right ? AppColors.cream : AppColors.dangerSoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: right ? AppColors.ink : AppColors.danger,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: right ? AppColors.correctMark : AppColors.danger,
                shape: BoxShape.circle,
              ),
              child: Icon(
                right ? Icons.check_rounded : Icons.close_rounded,
                size: 18,
                color: AppColors.card,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(question.text, style: appFont(13, weight: 600)),
                  const SizedBox(height: 2),
                  if (right)
                    Text(answer, style: detail)
                  else
                    Text.rich(
                      TextSpan(
                        style: detail,
                        children: [
                          if (pickedText == null)
                            const TextSpan(text: 'No answer')
                          else
                            TextSpan(
                              text: pickedText,
                              style: const TextStyle(
                                color: AppColors.danger,
                                decoration: TextDecoration.lineThrough,
                                decorationColor: AppColors.danger,
                              ),
                            ),
                          const TextSpan(text: ' · Answer: '),
                          TextSpan(
                            text: answer,
                            style: appFont(12, weight: 700),
                          ),
                        ],
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
