import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// An error message box that shakes side to side each time [shakeKey] changes.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message, required this.shakeKey});

  final String message;
  final int shakeKey;

  @override
  Widget build(BuildContext context) {
    final animate = !MediaQuery.disableAnimationsOf(context);

    return TweenAnimationBuilder<double>(
      key: ValueKey(shakeKey),
      tween: Tween(begin: animate ? 0 : 1, end: 1),
      duration: const Duration(milliseconds: 480),
      builder: (context, t, child) => Transform.translate(
        offset: Offset(math.sin(t * math.pi * 6) * (1 - t) * 12, 0),
        child: child,
      ),
      child: Semantics(
        liveRegion: true,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.dangerSoft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.ink, width: 2),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.ink,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(message, style: appFont(14.5, weight: 600))),
            ],
          ),
        ),
      ),
    );
  }
}
