import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// The round's score in a cream circle, with a ring that fills up to it. The ring
/// is red, yellow or green depending on the score ([AppColors.forScore]).
class ScoreRing extends StatelessWidget {
  const ScoreRing({
    super.key,
    required this.score,
    required this.total,
    this.size = 176,
  });

  final int score;
  final int total;
  final double size;

  @override
  Widget build(BuildContext context) {
    final animate = !MediaQuery.disableAnimationsOf(context);
    final fraction = total == 0 ? 0.0 : score / total;

    return Semantics(
      label: '$score out of $total',
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: animate ? 0 : fraction, end: fraction),
          duration: const Duration(milliseconds: 1100),
          curve: Curves.easeOutCubic,
          builder: (context, t, child) => CustomPaint(
            painter: _RingPainter(t, AppColors.forScore(score, total)),
            child: child,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$score', style: funFont(56, weight: 700, height: 1)),
              const SizedBox(height: 2),
              Text(
                'out of $total',
                style: appFont(14, weight: 600, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.fraction, this.color);

  final double fraction;
  final Color color;

  static const _stroke = 14.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - _stroke / 2;

    canvas.drawCircle(center, radius, Paint()..color = AppColors.cream);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..color = AppColors.ink.withValues(alpha: 0.1),
    );
    // Thin ink outline inside the track, like the app's other cards.
    canvas.drawCircle(
      center,
      radius - _stroke / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.ink,
    );
    if (fraction > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * fraction,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _stroke
          ..strokeCap = StrokeCap.round
          ..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.color != color;
}
