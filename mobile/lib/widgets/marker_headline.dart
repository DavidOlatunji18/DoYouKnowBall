import 'package:flutter/material.dart';

import '../theme.dart';

/// A big headline whose last word gets a green highlighter streak that sweeps
/// across it when it appears, e.g. "Join the league."
class MarkerHeadline extends StatelessWidget {
  const MarkerHeadline({
    super.key,
    required this.lead,
    required this.marked,
    this.textAlign = TextAlign.start,
  });

  final String lead;
  final String marked;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final style = appFont(32, weight: 700, height: 1.1, letterSpacing: -0.6);
    final animate = !MediaQuery.disableAnimationsOf(context);

    return Semantics(
      header: true,
      label: '$lead $marked',
      excludeSemantics: true,
      child: Text.rich(
        textAlign: textAlign,
        TextSpan(
          style: style,
          children: [
            TextSpan(text: '$lead\n'),
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: TweenAnimationBuilder<double>(
                key: ValueKey(marked),
                tween: Tween(begin: animate ? 0 : 1, end: 1),
                duration: const Duration(milliseconds: 520),
                curve: Curves.easeOutCubic,
                child: Text(marked, style: style),
                builder: (context, t, word) => Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: -6,
                      right: -6,
                      bottom: 3,
                      height: style.fontSize! * 0.42,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: t,
                          heightFactor: 1,
                          child: Transform.rotate(
                            angle: -0.025,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: AppColors.green,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    word!,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
