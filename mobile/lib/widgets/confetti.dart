import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// A one-off burst of falling paper pieces in the brand colors, drawn over
/// whatever is behind it. Draws nothing when Reduce Motion is on.
class Confetti extends StatefulWidget {
  const Confetti({super.key});

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  // Fixed seed so every burst looks the same and tests are predictable.
  final _pieces = List.generate(32, (i) => _Piece(math.Random(i)));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!MediaQuery.disableAnimationsOf(context) && !_controller.isAnimating) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return const SizedBox.shrink();
    return IgnorePointer(
      child: ExcludeSemantics(
        child: CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(_controller, _pieces),
        ),
      ),
    );
  }
}

class _Piece {
  _Piece(math.Random r)
    : x = r.nextDouble(),
      delay = r.nextDouble() * 0.35,
      speed = 0.75 + r.nextDouble() * 0.5,
      spin = (r.nextDouble() - 0.5) * 14,
      drift = (r.nextDouble() - 0.5) * 0.15,
      color = _colors[r.nextInt(_colors.length)];

  static const _colors = [
    AppColors.green,
    AppColors.card,
    AppColors.ink,
    Color(0xFFFFD60A),
    Color(0xFF3A86FF),
    Color(0xFFFF5FA2),
  ];

  final double x;
  final double delay;
  final double speed;
  final double spin;
  final double drift;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.progress, this.pieces) : super(repaint: progress);

  final Animation<double> progress;
  final List<_Piece> pieces;

  @override
  void paint(Canvas canvas, Size size) {
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = AppColors.ink;

    for (final p in pieces) {
      final t = ((progress.value - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (t == 0 || t == 1) continue;
      final y = -20 + t * p.speed * (size.height + 60);
      final x = (p.x + p.drift * t) * size.width;
      final rect = Rect.fromCenter(center: Offset.zero, width: 9, height: 14);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * t);
      final shape = RRect.fromRectAndRadius(rect, const Radius.circular(2));
      canvas.drawRRect(shape, Paint()..color = p.color);
      canvas.drawRRect(shape, outline);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => false;
}
