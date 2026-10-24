import 'package:flutter/material.dart';

/// Fades and slides a list item up into place, a little after the item before it.
/// Shows immediately when the system's Reduce Motion setting is on.
class StaggerIn extends StatefulWidget {
  const StaggerIn({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<StaggerIn>
    with SingleTickerProviderStateMixin {
  // The delay is built into the animation (an Interval) rather than a timer, so
  // nothing is left pending if the screen goes away early.
  static const _duration = Duration(milliseconds: 420);
  late final Duration _delay = Duration(milliseconds: 70 * widget.index);
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _delay + _duration,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Interval(
      _delay.inMilliseconds / (_delay + _duration).inMilliseconds,
      1,
      curve: Curves.easeOutCubic,
    ),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _curve.value,
        child: Transform.translate(
          offset: Offset(0, (1 - _curve.value) * 18),
          child: child,
        ),
      ),
    );
  }
}
