import 'package:flutter/material.dart';

import '../theme.dart';

/// The round outlined back button used at the top of pushed screens.
class CircleBackButton extends StatelessWidget {
  const CircleBackButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.card,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.ink, width: 2),
            boxShadow: const [
              BoxShadow(color: AppColors.ink, offset: Offset(2, 2)),
            ],
          ),
          child: const Icon(Icons.arrow_back_rounded, color: AppColors.ink),
        ),
      ),
    );
  }
}
