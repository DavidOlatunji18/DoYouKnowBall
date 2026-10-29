import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// A tappable white card in the app's sticker style: ink outline and a hard ink
/// shadow that it sinks into when pressed, like [ChunkyButton].
class ChunkyCard extends StatefulWidget {
  const ChunkyCard({
    super.key,
    required this.child,
    required this.onTap,
    this.semanticLabel,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final VoidCallback onTap;
  final String? semanticLabel;
  final EdgeInsetsGeometry padding;

  static const _depth = 4.0;

  @override
  State<ChunkyCard> createState() => _ChunkyCardState();
}

class _ChunkyCardState extends State<ChunkyCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final depth = _pressed ? 0.0 : ChunkyCard._depth;

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(
            ChunkyCard._depth - depth,
            ChunkyCard._depth - depth,
            0,
          ),
          padding: widget.padding,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.ink, width: 2),
            boxShadow: [
              BoxShadow(color: AppColors.ink, offset: Offset(depth, depth)),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
