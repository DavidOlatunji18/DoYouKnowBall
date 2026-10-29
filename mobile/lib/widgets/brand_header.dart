import 'package:flutter/material.dart';

import '../theme.dart';
import 'outlined_text.dart';

/// The header at the top of every in-app screen: the bulb logo on a green tile at
/// the left with "dykb?" (green, outlined) beside it, an optional button before it
/// (e.g. back) and one at the far right (e.g. a sport's ball), and a thin divider below.
class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key, this.leading, this.trailing});

  /// Shown before the logo, e.g. a back button.
  final Widget? leading;

  /// Shown at the far right, e.g. a sport's ball.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 14)],
            Semantics(
              label: 'Do You Know Ball?',
              excludeSemantics: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // The bulb on a green rounded square, like an app icon.
                  Container(
                    width: 38,
                    height: 38,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.green,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: AppColors.ink, width: 2),
                      boxShadow: const [
                        BoxShadow(color: AppColors.ink, offset: Offset(2, 2)),
                      ],
                    ),
                    child: Image.asset('assets/branding/logo-transparent.png'),
                  ),
                  const SizedBox(width: 10),
                  OutlinedText(
                    'dykb?',
                    style: funFont(22, weight: 700, letterSpacing: 0.4),
                    strokeWidth: 3.5,
                  ),
                ],
              ),
            ),
            const Spacer(),
            ?trailing,
          ],
        ),
        const SizedBox(height: 12),
        Container(height: 1.5, color: AppColors.ink.withValues(alpha: 0.12)),
      ],
    );
  }
}
