import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// A labelled text field in the app's outlined style. It gets a green offset
/// shadow while focused and a red outline with a message when [errorText] is set.
class AuthField extends StatefulWidget {
  const AuthField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.errorText,
    this.isPassword = false,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
    this.footer,
    this.inputFormatters,
    this.prefixText,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? errorText;
  final bool isPassword;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// Extra content under the field, such as password requirements.
  final Widget? footer;

  final List<TextInputFormatter>? inputFormatters;

  /// Fixed text before the input, such as '@' for usernames.
  final String? prefixText;

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  final _focus = FocusNode();
  bool _obscured = true;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null;
    final focused = _focus.hasFocus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label.toUpperCase(),
          style: appFont(12, weight: 700, letterSpacing: 1.2),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasError ? AppColors.danger : AppColors.ink,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: hasError
                    ? AppColors.danger
                    : (focused ? AppColors.green : AppColors.ink),
                offset: focused || hasError
                    ? const Offset(4, 4)
                    : const Offset(2, 2),
              ),
            ],
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focus,
            obscureText: widget.isPassword && _obscured,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            autofillHints: widget.autofillHints,
            autocorrect: false,
            enableSuggestions: !widget.isPassword,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            inputFormatters: widget.inputFormatters,
            cursorColor: AppColors.ink,
            style: appFont(17, weight: 500),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: widget.hint,
              prefixText: widget.prefixText,
              prefixStyle: appFont(17, weight: 600),
              hintStyle: appFont(
                17,
                color: AppColors.muted.withValues(alpha: 0.7),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 17,
              ),
              suffixIcon: widget.isPassword
                  ? IconButton(
                      tooltip: _obscured ? 'Show password' : 'Hide password',
                      icon: Icon(
                        _obscured
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      color: AppColors.ink,
                      onPressed: () => setState(() => _obscured = !_obscured),
                    )
                  : null,
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.topLeft,
          child: hasError
              ? Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 17,
                        color: AppColors.danger,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.errorText!,
                          style: appFont(
                            13.5,
                            weight: 600,
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        if (widget.footer != null) widget.footer!,
      ],
    );
  }
}
