import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../ranks.dart';
import '../theme.dart';

/// A soft white streak that sweeps across [child] every few seconds, for the
/// glistening look on badges and XP bars. [clipper] shapes the streak (a rounded
/// rectangle by default). Does nothing when Reduce Motion is on.
class Sheen extends StatefulWidget {
  const Sheen({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(999)),
    this.clipper,
    this.delay = Duration.zero,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final CustomClipper<Path>? clipper;

  /// Offsets this sheen from others on screen so they don't all flash at once.
  final Duration delay;

  static const period = Duration(milliseconds: 3200);

  @override
  State<Sheen> createState() => _SheenState();
}

class _SheenState extends State<Sheen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Sheen.period,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      final offset =
          widget.delay.inMilliseconds / Sheen.period.inMilliseconds % 1;
      // Setting the value stops the controller, so it goes before repeat().
      _controller.value = offset;
      _controller.repeat(period: Sheen.period);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;

    final streak = IgnorePointer(
      child: CustomPaint(painter: _SheenPainter(_controller)),
    );
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: widget.clipper != null
              ? ClipPath(clipper: widget.clipper, child: streak)
              : ClipRRect(borderRadius: widget.borderRadius, child: streak),
        ),
      ],
    );
  }
}

class _SheenPainter extends CustomPainter {
  _SheenPainter(this.progress) : super(repaint: progress);

  final Animation<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    // The streak crosses during the first 45% of each cycle, then rests.
    final t = (progress.value / 0.45).clamp(0.0, 1.0);
    if (t >= 1) return;
    final width = size.width * 0.4 + 12;
    final x = -width + t * (size.width + width * 2);
    final rect = Rect.fromLTWH(x, -size.height, width, size.height * 3);

    canvas.save();
    canvas.translate(rect.center.dx, size.height / 2);
    canvas.skew(-0.35, 0);
    canvas.translate(-rect.center.dx, -size.height / 2);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.7),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SheenPainter old) => false;
}

/// The light bulb from the logo, colored for a rank: the glass glows in the
/// rank's color and gains rays as the rank goes up. Unlit at the lowest ranks.
class RankBulb extends StatelessWidget {
  const RankBulb({super.key, required this.rank, this.size = 20});

  final RankStyle rank;
  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _BulbPainter(rank));
}

class _BulbPainter extends CustomPainter {
  _BulbPainter(this.rank);

  final RankStyle rank;

  @override
  void paint(Canvas canvas, Size size) {
    // Drawn on a 32x32 grid, like an icon.
    canvas.scale(size.width / 32);
    final line = rank.dark ? Colors.white : AppColors.ink;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final rays = Paint.from(stroke)
      ..color = rank.dark ? AppColors.green : AppColors.ink;
    void ray(double x1, double y1, double x2, double y2) =>
        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), rays);
    if (rank.glow >= 1) {
      ray(16, 2.5, 16, 5.1);
      ray(5.5, 7, 7.4, 8.6);
      ray(26.5, 7, 24.6, 8.6);
    }
    if (rank.glow >= 2) {
      ray(2.5, 15.5, 5.1, 15.5);
      ray(29.5, 15.5, 26.9, 15.5);
    }
    if (rank.glow >= 3) {
      ray(8.3, 3.4, 9.4, 5.6);
      ray(23.7, 3.4, 22.6, 5.6);
    }

    final glass = Path()
      ..moveTo(16, 7.5)
      ..cubicTo(11.4, 7.5, 8, 10.9, 8, 15.2)
      ..cubicTo(8, 18, 9.4, 19.8, 10.8, 21.2)
      ..cubicTo(11.8, 22.2, 12.4, 23.2, 12.4, 24.5)
      ..lineTo(19.6, 24.5)
      ..cubicTo(19.6, 23.2, 20.2, 22.2, 21.2, 21.2)
      ..cubicTo(22.6, 19.8, 24, 18, 24, 15.2)
      ..cubicTo(24, 10.9, 20.6, 7.5, 16, 7.5)
      ..close();
    canvas.drawPath(
      glass,
      Paint()..color = rank.glow == 0 ? Colors.white : rank.bulb,
    );
    canvas.drawPath(glass, Paint.from(stroke)..color = line);
    canvas.drawLine(
      const Offset(12.6, 26.6),
      const Offset(19.4, 26.6),
      Paint.from(stroke)..color = line,
    );
    canvas.drawLine(
      const Offset(13.4, 29),
      const Offset(18.6, 29),
      Paint.from(stroke)..color = line,
    );

    if (rank.glow == 0) {
      // An unlit filament.
      canvas.drawPath(
        Path()
          ..moveTo(14, 15.5)
          ..lineTo(16, 17.5)
          ..lineTo(18, 15.5),
        Paint.from(stroke)
          ..strokeWidth = 1.6
          ..color = const Color(0xFF9A98A8),
      );
    } else {
      // A little shine on the glass.
      canvas.drawPath(
        Path()
          ..moveTo(13, 13.3)
          ..quadraticBezierTo(13.4, 11.6, 15.6, 11.3),
        Paint.from(stroke)
          ..strokeWidth = 1.8
          ..color = Colors.white.withValues(alpha: 0.85),
      );
    }
  }

  @override
  bool shouldRepaint(_BulbPainter old) => old.rank != rank;
}

/// The shield outline the rank badge sits in, on a 44x50 grid.
class _ShieldClipper extends CustomClipper<Path> {
  const _ShieldClipper();

  static Path shape(Size size) {
    final sx = size.width / 44;
    final sy = size.height / 50;
    return Path()
      ..moveTo(22 * sx, 2 * sy)
      ..lineTo(40 * sx, 8 * sy)
      ..lineTo(40 * sx, 22 * sy)
      ..cubicTo(40 * sx, 34 * sy, 32 * sx, 43 * sy, 22 * sx, 48 * sy)
      ..cubicTo(12 * sx, 43 * sy, 4 * sx, 34 * sy, 4 * sx, 22 * sy)
      ..lineTo(4 * sx, 8 * sy)
      ..close();
  }

  @override
  Path getClip(Size size) => shape(size);

  @override
  bool shouldReclip(_ShieldClipper old) => false;
}

/// A player's rank as a shield with the glowing bulb inside. [width] sets the
/// size; the shield is a little taller than it is wide.
class RankShield extends StatelessWidget {
  const RankShield({
    super.key,
    required this.rank,
    this.width = 30,
    this.sheenDelay = Duration.zero,
  });

  final RankStyle rank;
  final double width;
  final Duration sheenDelay;

  @override
  Widget build(BuildContext context) {
    final size = Size(width, width * 50 / 44);
    return Semantics(
      label: '${rank.name} rank',
      excludeSemantics: true,
      child: Sheen(
        clipper: const _ShieldClipper(),
        delay: sheenDelay,
        child: SizedBox.fromSize(
          size: size,
          child: CustomPaint(
            painter: _ShieldPainter(rank),
            child: Padding(
              // The bulb sits in the upper middle of the shield.
              padding: EdgeInsets.fromLTRB(
                size.width * 0.2,
                size.height * 0.2,
                size.width * 0.2,
                size.height * 0.24,
              ),
              child: FittedBox(child: RankBulb(rank: rank, size: 32)),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShieldPainter extends CustomPainter {
  _ShieldPainter(this.rank);

  final RankStyle rank;

  @override
  void paint(Canvas canvas, Size size) {
    final shape = _ShieldClipper.shape(size);
    canvas.drawPath(shape, Paint()..color = rank.background);
    canvas.drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width / 44 * 2.5
        ..strokeJoin = StrokeJoin.round
        ..color = AppColors.ink,
    );
  }

  @override
  bool shouldRepaint(_ShieldPainter old) => old.rank != rank;
}

/// The rank's name in a pill with its bulb. [small] is the compact version used
/// in leaderboard rows.
class RankPill extends StatelessWidget {
  const RankPill({super.key, required this.rank, this.small = false});

  final RankStyle rank;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${rank.name} rank',
      excludeSemantics: true,
      child: Sheen(
        child: Container(
          height: small ? 16 : 24,
          padding: EdgeInsets.fromLTRB(small ? 2 : 3, 0, small ? 6 : 9, 0),
          decoration: BoxDecoration(
            color: rank.background,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.ink, width: small ? 1.2 : 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              RankBulb(rank: rank, size: small ? 12 : 18),
              SizedBox(width: small ? 2 : 3),
              Flexible(
                child: Text(
                  rank.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appFont(
                    small ? 8.5 : 11,
                    weight: 600,
                    color: rank.onBackground,
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

/// A slim XP bar filled in the rank's color, with a sheen.
class LevelBar extends StatelessWidget {
  const LevelBar({
    super.key,
    required this.fraction,
    required this.rank,
    this.height = 12,
  });

  final double fraction;
  final RankStyle rank;
  final double height;

  @override
  Widget build(BuildContext context) {
    final animate = !MediaQuery.disableAnimationsOf(context);
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.ink, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: animate ? 0 : fraction, end: fraction),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: value.clamp(0.0, 1.0),
              heightFactor: 1,
              child: value <= 0
                  ? const SizedBox.shrink()
                  : Sheen(
                      delay: const Duration(milliseconds: 600),
                      child: Container(
                        decoration: BoxDecoration(
                          color: rank.barColor,
                          borderRadius: BorderRadius.circular(999),
                          border: const Border(
                            right: BorderSide(color: AppColors.ink, width: 2),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The level line used on Home and Profile: rank pill and level on the left, the
/// XP count on the right, and the bar underneath. Tapping it opens the ladder.
class LevelSummary extends StatelessWidget {
  const LevelSummary({super.key, required this.progress, this.onTap});

  final Progress progress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final rank = RankStyle.of(progress.rank);
    return Semantics(
      container: true,
      button: onTap != null,
      label:
          '${rank.name}, level ${progress.level}, ${progress.levelXp} of '
          '${progress.levelXpNeeded} XP to the next level',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                RankPill(rank: rank),
                const SizedBox(width: 6),
                Text('Lv ${progress.level}', style: appFont(12, weight: 600)),
                const Spacer(),
                Text.rich(
                  TextSpan(
                    style: appFont(10.5, weight: 500, color: AppColors.muted),
                    children: [
                      TextSpan(
                        text: formatXp(progress.levelXp),
                        style: appFont(10.5, weight: 600),
                      ),
                      TextSpan(
                        text: ' / ${formatXp(progress.levelXpNeeded)} XP',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LevelBar(fraction: progress.fraction, rank: rank),
          ],
        ),
      ),
    );
  }
}

/// 48210 -> "48,210".
String formatXp(int xp) {
  final digits = xp.abs().toString();
  final out = StringBuffer(xp < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}
