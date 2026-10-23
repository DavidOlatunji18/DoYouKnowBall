import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// The app's primary button: ink outline and a hard ink shadow, like a sticker.
/// Pressing it pushes the button down into its shadow.
class ChunkyButton extends StatefulWidget {
  const ChunkyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.color = AppColors.green,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final Color color;

  static const _depth = 4.0;

  @override
  State<ChunkyButton> createState() => _ChunkyButtonState();
}

class _ChunkyButtonState extends State<ChunkyButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  void _setPressed(bool value) {
    if (_enabled && _pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final depth = _pressed ? 0.0 : ChunkyButton._depth;

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.loading ? '${widget.label}, loading' : widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: _enabled
            ? () {
                HapticFeedback.lightImpact();
                widget.onPressed!();
              }
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          height: 58,
          transform: Matrix4.translationValues(
            ChunkyButton._depth - depth,
            ChunkyButton._depth - depth,
            0,
          ),
          decoration: BoxDecoration(
            color: _enabled || widget.loading
                ? widget.color
                : widget.color.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.ink, width: 2),
            boxShadow: [
              BoxShadow(color: AppColors.ink, offset: Offset(depth, depth)),
            ],
          ),
          alignment: Alignment.center,
          child: widget.loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.6,
                    color: AppColors.ink,
                  ),
                )
              : Text(widget.label, style: appFont(18, weight: 700)),
        ),
      ),
    );
  }
}
