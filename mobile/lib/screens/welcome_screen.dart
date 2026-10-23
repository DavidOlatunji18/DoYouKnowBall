import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../theme.dart';
import '../widgets/chunky_button.dart';

/// First screen for signed-out users: logo, headline, the five sport balls,
/// a tagline, and the sign up / log in actions. The top half animates in once,
/// then the balls bob gently. With "reduce motion" on, it all appears at once.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  static const headline = 'Think you know ball?';
  static const tagline = 'Come test out your ball knowledge';
  static const balls = [
    'soccer',
    'football',
    'basketball',
    'baseball',
    'hockey',
  ];

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  // One timeline drives the whole entrance; each element animates within its own slice of it.
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3400),
  );

  // Looping controller for the balls' idle bob, started after the entrance finishes.
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    if (MediaQuery.disableAnimationsOf(context)) {
      _intro.value = 1;
    } else {
      _intro.forward().whenComplete(() {
        if (mounted) _idle.repeat();
      });
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _idle.dispose();
    super.dispose();
  }

  Animation<double> _slice(
    double begin,
    double end, [
    Curve curve = Curves.easeOutCubic,
  ]) => CurvedAnimation(
    parent: _intro,
    curve: Interval(begin, end, curve: curve),
  );

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const Spacer(flex: 3),
                _FadeRise(
                  animation: _slice(0.0, 0.14),
                  child: Image.asset(
                    'assets/branding/logo-transparent.png',
                    height: 76,
                    semanticLabel: 'Do You Know Ball? logo',
                  ),
                ),
                const SizedBox(height: 20),
                _FadeRise(
                  animation: _slice(0.06, 0.32),
                  distance: 24,
                  child: Text(
                    WelcomeScreen.headline,
                    textAlign: TextAlign.center,
                    style: appFont(
                      44,
                      weight: 800,
                      height: 1.05,
                      letterSpacing: -1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                _BallRow(intro: _intro, idle: _idle),
                const SizedBox(height: 40),
                _Typewriter(
                  text: WelcomeScreen.tagline,
                  progress: _slice(0.58, 0.86, Curves.linear),
                ),
                const SizedBox(height: 48),
                // The actions are static: there's enough motion above them.
                ChunkyButton(
                  label: 'Sign up',
                  onPressed: () => context.push('/signup'),
                ),
                const SizedBox(height: 10),
                // Wraps onto two lines on small screens or with large text sizes.
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Already have an account?',
                      style: appFont(15, color: AppColors.muted),
                    ),
                    TextButton(
                      onPressed: () => context.push('/login'),
                      child: const Text('Log in'),
                    ),
                  ],
                ),
                const Spacer(flex: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Fades a child in while sliding it up into place.
class _FadeRise extends StatelessWidget {
  const _FadeRise({
    required this.animation,
    required this.child,
    this.distance = 16,
  });

  final Animation<double> animation;
  final Widget child;
  final double distance;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) => Opacity(
        opacity: animation.value,
        child: Transform.translate(
          offset: Offset(0, (1 - animation.value) * distance),
          child: child,
        ),
      ),
    );
  }
}

/// The five sport balls. Each drops in from above with a bounce and a spin,
/// one after another, then they bob slightly out of step with each other.
class _BallRow extends StatelessWidget {
  const _BallRow({required this.intro, required this.idle});

  final AnimationController intro;
  final AnimationController idle;

  static const _size = 46.0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Soccer, football, basketball, baseball and hockey',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (var i = 0; i < WelcomeScreen.balls.length; i++)
            _buildBall(WelcomeScreen.balls[i], i),
        ],
      ),
    );
  }

  Widget _buildBall(String name, int index) {
    final start = 0.26 + index * 0.06;
    final drop = CurvedAnimation(
      parent: intro,
      curve: Interval(start, start + 0.2, curve: Curves.bounceOut),
    );
    final appear = CurvedAnimation(
      parent: intro,
      curve: Interval(start, start + 0.04),
    );
    final image = Image.asset(
      'assets/balls/$name.png',
      width: _size,
      height: _size,
      excludeFromSemantics: true,
    );

    return AnimatedBuilder(
      animation: Listenable.merge([intro, idle]),
      child: image,
      builder: (context, child) {
        final bob = math.sin((idle.value + index * 0.18) * 2 * math.pi) * 4;
        return Opacity(
          opacity: appear.value,
          child: Transform.translate(
            offset: Offset(0, (1 - drop.value) * -36 + bob),
            child: Transform.rotate(
              angle: (1 - drop.value) * -math.pi,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// Types the text out letter by letter with a blinking cursor. The untyped part is
/// laid out invisibly so the centred line doesn't shift while typing.
class _Typewriter extends StatelessWidget {
  const _Typewriter({required this.text, required this.progress});

  final String text;
  final Animation<double> progress;

  @override
  Widget build(BuildContext context) {
    final style = appFont(18, weight: 500, color: AppColors.muted);

    return Semantics(
      label: text,
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: progress,
        builder: (context, _) {
          final shown = (text.length * progress.value).round();
          final typing = progress.value > 0 && progress.value < 1;
          return Text.rich(
            TextSpan(
              style: style,
              children: [
                TextSpan(text: text.substring(0, shown)),
                if (typing)
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: _Cursor(height: style.fontSize! * 1.2),
                  ),
                TextSpan(
                  text: text.substring(shown),
                  style: style.copyWith(color: Colors.transparent),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          );
        },
      ),
    );
  }
}

/// A zero-width blinking bar, so showing it doesn't push the text sideways.
class _Cursor extends StatefulWidget {
  const _Cursor({required this.height});

  final double height;

  @override
  State<_Cursor> createState() => _CursorState();
}

class _CursorState extends State<_Cursor> with SingleTickerProviderStateMixin {
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 0,
      height: widget.height,
      child: OverflowBox(
        maxWidth: 4,
        alignment: Alignment.centerLeft,
        child: FadeTransition(
          opacity: _blink,
          child: Container(
            width: 2.5,
            height: widget.height,
            color: AppColors.ink,
          ),
        ),
      ),
    );
  }
}
