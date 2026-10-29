import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../game_events.dart';
import '../sports.dart';
import '../theme.dart';
import '../widgets/chunky_button.dart';
import '../widgets/marker_headline.dart';
import 'results_view.dart';

enum _Stage { intro, playing, finishing, results, failed }

/// A full round, full-screen: a 3-2-1 intro (the questions load meanwhile), then
/// one question at a time with instant feedback from the server, then results.
/// The app never knows the answers ahead of time: each pick is sent to
/// `POST /quiz/answer`, and the final score comes from `POST /games`.
class QuizScreen extends StatefulWidget {
  const QuizScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
    required this.sportId,
    required this.sportName,
  });

  final int categoryId;
  final String categoryName;
  final int? sportId;

  /// The sport's API name ("NFL") or label ("Football"); [SportStyle] takes either.
  final String sportName;

  /// How long each number of the 3-2-1 countdown stays up.
  static const countdownStep = Duration(milliseconds: 800);

  /// How long the feedback shows before moving on by itself.
  static const rightPause = Duration(milliseconds: 1500);
  static const wrongPause = Duration(milliseconds: 2200);

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  _Stage _stage = _Stage.intro;
  int _count = 3;
  Quiz? _quiz;
  String? _error;
  int _index = 0;
  int _score = 0;

  /// The option the player tapped on the current question, while it's checked
  /// and after. Null until they pick.
  int? _picked;
  AnswerResult? _result;

  /// Per question: true/false once answered, null before.
  late List<bool?> _outcomes;
  late List<int> _picks;
  GameResult? _game;

  Timer? _countdown;
  Timer? _advance;

  ApiClient get _api => context.read<ApiClient>();

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _countdown?.cancel();
    _advance?.cancel();
    super.dispose();
  }

  /// Starts (or restarts) a round: the countdown and the question request run
  /// side by side, so there's usually no waiting once it reaches zero.
  void _start() {
    _countdown?.cancel();
    _advance?.cancel();
    setState(() {
      _stage = _Stage.intro;
      _count = 3;
      _quiz = null;
      _error = null;
      _index = 0;
      _score = 0;
      _picked = null;
      _result = null;
      _game = null;
    });

    _countdown = Timer.periodic(QuizScreen.countdownStep, (timer) {
      if (_count > 1) {
        setState(() => _count--);
      } else {
        timer.cancel();
        _countdown = null;
        _maybeBegin();
      }
    });

    _api
        .quiz(widget.categoryId)
        .then(
          (quiz) {
            if (!mounted) return;
            if (quiz.questions.isEmpty) {
              setState(() {
                _stage = _Stage.failed;
                _error = 'No questions in this category yet. Try another one.';
              });
              return;
            }
            _quiz = quiz;
            _outcomes = List.filled(quiz.questions.length, null);
            _picks = List.filled(quiz.questions.length, -1);
            _maybeBegin();
          },
          onError: (Object e) {
            if (!mounted) return;
            _countdown?.cancel();
            setState(() {
              _stage = _Stage.failed;
              _error = e is ApiError ? e.message : ApiError.unknown;
            });
          },
        );
  }

  /// Shows the first question once the countdown is done and the questions are in.
  void _maybeBegin() {
    if (_stage == _Stage.intro && _countdown == null && _quiz != null) {
      setState(() => _stage = _Stage.playing);
    }
  }

  Future<void> _pick(int option) async {
    final quiz = _quiz!;
    if (_picked != null) return;
    setState(() => _picked = option);

    final AnswerResult result;
    try {
      result = await _api.answer(
        sessionToken: quiz.sessionToken,
        questionId: quiz.questions[_index].id,
        selectedIndex: option,
      );
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() => _picked = null);
      _toast(e.message);
      return;
    }
    if (!mounted) return;

    result.correct
        ? HapticFeedback.lightImpact()
        : HapticFeedback.heavyImpact();
    setState(() {
      _result = result;
      _score = result.score;
      _outcomes[_index] = result.correct;
      _picks[_index] = option;
    });
    _scheduleNext();
  }

  void _scheduleNext([Duration? after]) {
    _advance?.cancel();
    _advance = Timer(
      after ??
          (_result!.correct ? QuizScreen.rightPause : QuizScreen.wrongPause),
      _next,
    );
  }

  void _next() {
    _advance?.cancel();
    if (_index == _quiz!.questions.length - 1) {
      _finish();
      return;
    }
    setState(() {
      _index++;
      _picked = null;
      _result = null;
    });
  }

  Future<void> _finish() async {
    setState(() {
      _stage = _Stage.finishing;
      _error = null;
    });
    try {
      final game = await _api.submitGame(_quiz!.sessionToken);
      if (!mounted) return;
      context.read<GameEvents>().gameFinished();
      setState(() {
        _game = game;
        _stage = _Stage.results;
      });
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.failed;
        _error = e.message;
      });
    }
  }

  void _leave() => context.canPop() ? context.pop() : context.go('/home');

  /// Asks before leaving mid-round. Pauses the auto-advance while the sheet is up.
  Future<void> _confirmQuit() async {
    _advance?.cancel();
    final leave = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.ink.withValues(alpha: 0.4),
      builder: (context) => const _QuitSheet(),
    );
    if (!mounted) return;
    if (leave ?? false) {
      _leave();
    } else if (_result != null) {
      _scheduleNext(const Duration(milliseconds: 1200));
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.ink,
          content: Text(
            message,
            style: appFont(15, weight: 600, color: AppColors.card),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final style = SportStyle.of(widget.sportName);

    final Widget body = switch (_stage) {
      _Stage.intro => _Intro(
        count: _count,
        style: style,
        categoryName: widget.categoryName,
        questionCount: _quiz?.questions.length ?? 10,
        onClose: _leave,
      ),
      _Stage.playing => _QuestionView(
        key: ValueKey(_index),
        question: _quiz!.questions[_index],
        index: _index,
        total: _quiz!.questions.length,
        score: _score,
        outcomes: _outcomes,
        picked: _picked,
        result: _result,
        ball: style.asset,
        onPick: _pick,
        onNext: _next,
        onClose: _confirmQuit,
      ),
      _Stage.finishing => const Center(
        child: CircularProgressIndicator(color: AppColors.ink),
      ),
      _Stage.results => ResultsView(
        quiz: _quiz!,
        game: _game!,
        picks: _picks,
        sportId: widget.sportId,
        sportName: widget.sportName,
        categoryName: widget.categoryName,
        onPlayAgain: _start,
        onHome: () => context.go('/home'),
      ),
      _Stage.failed => _Failed(
        message: _error ?? ApiError.unknown,
        // A failed submit can be retried as-is; anything else starts over.
        onRetry: _quiz != null && _outcomes.any((o) => o != null)
            ? _finish
            : _start,
        onClose: _leave,
      ),
    };

    return PopScope(
      canPop: _stage != _Stage.playing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmQuit();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          body: SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: KeyedSubtree(key: ValueKey(_stage), child: body),
            ),
          ),
        ),
      ),
    );
  }
}

/// The ✕ in the corner.
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap, this.label = 'Quit'});

  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.card,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.ink, width: 2),
          ),
          child: const Icon(Icons.close_rounded, color: AppColors.ink),
        ),
      ),
    );
  }
}

class _Intro extends StatefulWidget {
  const _Intro({
    required this.count,
    required this.style,
    required this.categoryName,
    required this.questionCount,
    required this.onClose,
  });

  final int count;
  final SportStyle style;
  final String categoryName;
  final int questionCount;
  final VoidCallback onClose;

  @override
  State<_Intro> createState() => _IntroState();
}

class _IntroState extends State<_Intro> with SingleTickerProviderStateMixin {
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!MediaQuery.disableAnimationsOf(context) && !_bob.isAnimating) {
      _bob.repeat();
    }
  }

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animate = !MediaQuery.disableAnimationsOf(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _CloseButton(label: 'Close', onTap: widget.onClose),
          ),
          const Spacer(),
          AnimatedBuilder(
            animation: _bob,
            builder: (context, child) {
              final wave = math.sin(_bob.value * 2 * math.pi);
              return Transform.translate(
                offset: Offset(0, -6 + wave * 6),
                child: Transform.rotate(angle: wave * 0.1, child: child),
              );
            },
            child: Image.asset(
              widget.style.asset,
              width: 112,
              height: 112,
              excludeFromSemantics: true,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            '${widget.style.label} · ${widget.categoryName}'.toUpperCase(),
            textAlign: TextAlign.center,
            style: appFont(
              12,
              weight: 700,
              letterSpacing: 1.4,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 8),
          const MarkerHeadline(
            lead: 'Do you know',
            marked: 'ball?',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _Chip(
                icon: Icons.quiz_rounded,
                text: '${widget.questionCount} questions',
              ),
              const _Chip(icon: Icons.bolt_rounded, text: '1 point each'),
            ],
          ),
          const SizedBox(height: 30),
          Semantics(
            liveRegion: true,
            label: 'Starting in ${widget.count}',
            excludeSemantics: true,
            child: TweenAnimationBuilder<double>(
              key: ValueKey(widget.count),
              tween: Tween(begin: animate ? 0.6 : 1, end: 1),
              duration: const Duration(milliseconds: 450),
              curve: Curves.elasticOut,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: Container(
                width: 120,
                height: 120,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.ink, width: 3),
                  boxShadow: const [
                    BoxShadow(color: AppColors.ink, offset: Offset(4, 4)),
                  ],
                ),
                child: Text(
                  '${widget.count}',
                  style: funFont(60, weight: 700, height: 1),
                ),
              ),
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.ink, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.ink),
          const SizedBox(width: 5),
          Text(text, style: appFont(13, weight: 600)),
        ],
      ),
    );
  }
}

class _QuestionView extends StatelessWidget {
  const _QuestionView({
    super.key,
    required this.question,
    required this.index,
    required this.total,
    required this.score,
    required this.outcomes,
    required this.picked,
    required this.result,
    required this.ball,
    required this.onPick,
    required this.onNext,
    required this.onClose,
  });

  final QuizQuestion question;
  final int index;
  final int total;
  final int score;
  final List<bool?> outcomes;
  final int? picked;
  final AnswerResult? result;
  final String ball;
  final ValueChanged<int> onPick;
  final VoidCallback onNext;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final result = this.result;
    final isLast = index == total - 1;

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _CloseButton(onTap: onClose),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Progress(outcomes: outcomes, index: index),
                  ),
                  const SizedBox(width: 10),
                  _ScorePill(score: score),
                ],
              ),
              Expanded(
                child: ListView(
                  // Room at the bottom so the feedback bar never covers an answer.
                  padding: const EdgeInsets.only(top: 20, bottom: 110),
                  children: [
                    Row(
                      children: [
                        Image.asset(
                          ball,
                          width: 22,
                          height: 22,
                          excludeFromSemantics: true,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'QUESTION ${index + 1} OF $total',
                          style: appFont(
                            12,
                            weight: 700,
                            letterSpacing: 1.2,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      constraints: const BoxConstraints(minHeight: 92),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.cream,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: AppColors.ink, width: 2),
                        boxShadow: const [
                          BoxShadow(color: AppColors.ink, offset: Offset(4, 4)),
                        ],
                      ),
                      child: Semantics(
                        header: true,
                        child: Text(
                          question.text,
                          style: appFont(
                            17.5,
                            weight: 700,
                            height: 1.3,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    for (var i = 0; i < question.options.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _AnswerButton(
                          index: i,
                          text: question.options[i],
                          state: _stateFor(i),
                          onTap: picked == null ? () => onPick(i) : null,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (result != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _FeedbackBar(
              correct: result.correct,
              nextLabel: isLast ? 'Results' : 'Next',
              onNext: onNext,
            ),
          ),
      ],
    );
  }

  _AnswerState _stateFor(int i) {
    final result = this.result;
    if (result == null) {
      return picked == i ? _AnswerState.checking : _AnswerState.idle;
    }
    if (i == result.correctIndex) return _AnswerState.correct;
    if (i == picked) return _AnswerState.wrong;
    return _AnswerState.dimmed;
  }
}

/// Ten segments across the top: green for right, red for wrong, outlined for
/// the current question.
class _Progress extends StatelessWidget {
  const _Progress({required this.outcomes, required this.index});

  final List<bool?> outcomes;
  final int index;

  @override
  Widget build(BuildContext context) {
    final right = outcomes.where((o) => o == true).length;
    return Semantics(
      container: true,
      label: 'Question ${index + 1} of ${outcomes.length}, $right right so far',
      excludeSemantics: true,
      child: Row(
        children: [
          for (var i = 0; i < outcomes.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 10,
                decoration: BoxDecoration(
                  color: switch (outcomes[i]) {
                    true => AppColors.green,
                    false => AppColors.danger,
                    null =>
                      i == index
                          ? AppColors.card
                          : AppColors.ink.withValues(alpha: 0.12),
                  },
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: outcomes[i] != null || i == index
                        ? AppColors.ink
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The running score in a green pill; it pops each time it goes up.
class _ScorePill extends StatelessWidget {
  const _ScorePill({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final animate = !MediaQuery.disableAnimationsOf(context);
    return Semantics(
      container: true,
      label: 'Score $score',
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        key: ValueKey(score),
        tween: Tween(begin: animate && score > 0 ? 1.35 : 1, end: 1),
        duration: const Duration(milliseconds: 450),
        curve: Curves.elasticOut,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.green,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.ink, width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bolt_rounded, size: 16, color: AppColors.ink),
              const SizedBox(width: 2),
              Text('$score', style: appFont(14, weight: 700)),
            ],
          ),
        ),
      ),
    );
  }
}

enum _AnswerState { idle, checking, correct, wrong, dimmed }

/// One answer: a colored letter (A-D) and the option, in a sticker-style button.
/// After the server replies it turns green (right), red with a shake (your wrong
/// pick), or fades (the rest).
class _AnswerButton extends StatefulWidget {
  const _AnswerButton({
    required this.index,
    required this.text,
    required this.state,
    required this.onTap,
  });

  final int index;
  final String text;
  final _AnswerState state;
  final VoidCallback? onTap;

  @override
  State<_AnswerButton> createState() => _AnswerButtonState();
}

class _AnswerButtonState extends State<_AnswerButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onTap != null && _pressed != value) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final letter = 'ABCD'[widget.index];
    final wrong = state == _AnswerState.wrong;
    final edge = wrong ? AppColors.danger : AppColors.ink;
    final sunk = _pressed || state == _AnswerState.checking;
    final depth = sunk ? 0.0 : 3.0;
    final animate = !MediaQuery.disableAnimationsOf(context);

    final background = switch (state) {
      _AnswerState.correct => AppColors.green,
      _AnswerState.wrong => AppColors.dangerSoft,
      _ => AppColors.card,
    };
    final letterColor = switch (state) {
      _AnswerState.correct || _AnswerState.wrong => AppColors.card,
      _ => AppColors.answerLetters[widget.index % 4],
    };

    final semanticsState = switch (state) {
      _AnswerState.correct => ', correct answer',
      _AnswerState.wrong => ', your answer, wrong',
      _ => '',
    };

    return Semantics(
      button: true,
      enabled: widget.onTap != null,
      label: '$letter. ${widget.text}$semanticsState',
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                widget.onTap!();
              },
        child: TweenAnimationBuilder<double>(
          key: ValueKey(wrong),
          tween: Tween(begin: wrong && animate ? 0 : 1, end: 1),
          duration: const Duration(milliseconds: 420),
          builder: (context, t, child) => Transform.translate(
            offset: Offset(math.sin(t * math.pi * 5) * (1 - t) * 10, 0),
            child: child,
          ),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: state == _AnswerState.dimmed ? 0.45 : 1,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              transform: Matrix4.translationValues(3 - depth, 3 - depth, 0),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: edge, width: 2),
                boxShadow: [
                  BoxShadow(color: edge, offset: Offset(depth, depth)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: letterColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: edge, width: 2),
                    ),
                    child: Text(
                      letter,
                      style: appFont(
                        11.5,
                        weight: 700,
                        color: wrong ? AppColors.danger : AppColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.text,
                      style: appFont(
                        14.5,
                        weight: 600,
                        color: wrong ? AppColors.danger : AppColors.ink,
                      ),
                    ),
                  ),
                  if (state == _AnswerState.checking)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: AppColors.ink,
                      ),
                    ),
                  if (state == _AnswerState.correct)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.ink,
                      size: 22,
                    ),
                  if (wrong)
                    const Icon(
                      Icons.cancel_rounded,
                      color: AppColors.danger,
                      size: 22,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Slides up after each answer: dark "Nice!" when right, white "Not quite" when
/// wrong, with a Next button (the round also moves on by itself).
class _FeedbackBar extends StatelessWidget {
  const _FeedbackBar({
    required this.correct,
    required this.nextLabel,
    required this.onNext,
  });

  final bool correct;
  final String nextLabel;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final animate = !MediaQuery.disableAnimationsOf(context);
    final foreground = correct ? AppColors.card : AppColors.ink;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: animate ? 0 : 1, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 30),
          child: child,
        ),
      ),
      child: Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          decoration: BoxDecoration(
            color: correct ? AppColors.ink : AppColors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.ink, width: 2),
            boxShadow: const [
              BoxShadow(color: AppColors.ink, offset: Offset(3, 3)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: correct ? AppColors.green : AppColors.danger,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.ink, width: 2),
                ),
                child: Icon(
                  correct ? Icons.check_rounded : Icons.close_rounded,
                  size: 22,
                  color: correct ? AppColors.ink : AppColors.card,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      correct ? 'Nice!' : 'Not quite',
                      style: funFont(17, weight: 600, color: foreground),
                    ),
                    Text(
                      correct ? 'You know ball.' : 'Lock in twin',
                      style: appFont(
                        13,
                        weight: 500,
                        color: foreground.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onNext,
                style: TextButton.styleFrom(foregroundColor: foreground),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      nextLabel,
                      style: appFont(13.5, weight: 700, color: foreground),
                    ),
                    Icon(Icons.chevron_right_rounded, color: foreground),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuitSheet extends StatelessWidget {
  const _QuitSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        24,
        20,
        24 + MediaQuery.paddingOf(context).bottom,
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
          Text('Leave this round?', style: appFont(22, weight: 700)),
          const SizedBox(height: 6),
          Text(
            "Your answers so far won't count, and you'll have to start a new round.",
            style: appFont(
              14,
              weight: 500,
              color: AppColors.muted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          ChunkyButton(
            label: 'Leave round',
            color: AppColors.danger,
            textColor: AppColors.card,
            height: 52,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: 12),
          ChunkyButton(
            label: 'Keep playing',
            color: AppColors.card,
            height: 52,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({
    required this.message,
    required this.onRetry,
    required this.onClose,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _CloseButton(label: 'Close', onTap: onClose),
          ),
          const Spacer(),
          Text(
            message,
            textAlign: TextAlign.center,
            style: appFont(
              16,
              weight: 600,
              color: AppColors.muted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          ChunkyButton(label: 'Try again', onPressed: onRetry),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}
