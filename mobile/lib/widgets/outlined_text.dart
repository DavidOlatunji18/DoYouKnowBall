import 'package:flutter/material.dart';

import '../theme.dart';

/// Brand-green text with an ink outline, like a sticker. Plain green is unreadable
/// on the light background (about 1.2:1 contrast); the outline keeps it legible.
class OutlinedText extends StatelessWidget {
  const OutlinedText(
    this.text, {
    super.key,
    required this.style,
    this.strokeWidth = 3,
  });

  final String text;
  final TextStyle style;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // The outline is a second copy of the text; screen readers skip it.
        ExcludeSemantics(
          child: Text(
            text,
            style: style.copyWith(
              color: null,
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = strokeWidth
                ..strokeJoin = StrokeJoin.round
                ..color = AppColors.ink,
            ),
          ),
        ),
        Text(text, style: style.copyWith(color: AppColors.green)),
      ],
    );
  }
}
