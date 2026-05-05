import 'package:flutter/material.dart';

import '../theme/theme_context.dart';
import '../tokens/app_metrics.dart';

class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hintText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.onChanged,
    this.enabled = true,
    this.keyboardType,
    this.obscureText = false,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hintText;
  final String? errorText;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final TextInputType? keyboardType;
  final bool obscureText;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..addListener(_handleFocus);
  }

  void _handleFocus() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;
    final isFocused = _focusNode.hasFocus;
    final bg = Color.lerp(
          colors.surfaceHigh,
          colors.surfaceHighest,
          isDark ? 0.38 : 0.62,
        ) ??
        colors.surfaceHighest;
    final fieldBorderColor = hasError
        ? colors.error.withValues(alpha: isDark ? 0.55 : 0.4)
        : (isFocused
              ? Color.lerp(
                    bg,
                    colors.primary,
                    isDark ? 0.48 : 0.32,
                  ) ??
                  colors.primary.withValues(alpha: 0.28)
              : Color.lerp(
                    bg,
                    colors.onSurface,
                    isDark ? 0.18 : 0.12,
                  ) ??
                  bg);
    final lightInset = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.white.withValues(alpha: 0.72);
    final darkInset = isDark
        ? Colors.black.withValues(alpha: 0.5)
        : colors.onSurface.withValues(alpha: 0.14);
    final fieldShadow = <BoxShadow>[
      BoxShadow(
        color: darkInset,
        blurRadius: isFocused ? 5 : 7,
        offset: const Offset(2, 2),
      ),
      BoxShadow(
        color: lightInset,
        blurRadius: isFocused ? 5 : 7,
        offset: const Offset(-2, -2),
      ),
    ];
    final borderColor = hasError
        ? colors.error.withValues(alpha: 0.3)
        : colors.outlineVariant.withValues(alpha: 0.15);

    return Semantics(
      textField: true,
      enabled: widget.enabled,
      label: widget.label ?? widget.hintText ?? 'Input field',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: AppRadius.full,
          border: Border.all(
            color: fieldBorderColor.withValues(alpha: isDark ? 0.82 : 0.7),
            width: isFocused ? 1.2 : 1,
          ),
          boxShadow: fieldShadow,
        ),
        child: TextField(
          enabled: widget.enabled,
          focusNode: _focusNode,
          obscureText: widget.obscureText,
          keyboardType: widget.keyboardType,
          controller: widget.controller,
          onChanged: widget.onChanged,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colors.onSurface),
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hintText,
            errorText: widget.errorText,
            floatingLabelBehavior: FloatingLabelBehavior.auto,
            labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant.withValues(alpha: 0.9),
              fontWeight: FontWeight.w600,
            ),
            hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant.withValues(alpha: 0.62),
            ),
            filled: true,
            fillColor: Colors.transparent,
            isDense: false,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            prefixIcon: widget.prefixIcon == null
                ? null
                : Icon(
                    widget.prefixIcon,
                    size: 20,
                    color: colors.onSurfaceVariant.withValues(alpha: 0.88),
                  ),
            suffixIcon: widget.suffixIcon == null
                ? null
                : Icon(
                    widget.suffixIcon,
                    size: 20,
                    color: colors.onSurfaceVariant.withValues(alpha: 0.88),
                  ),
            border: OutlineInputBorder(
              borderRadius: AppRadius.full,
              borderSide: BorderSide(color: borderColor.withValues(alpha: 0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppRadius.full,
              borderSide: BorderSide(color: borderColor.withValues(alpha: 0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppRadius.full,
              borderSide: BorderSide(color: borderColor.withValues(alpha: 0)),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: AppRadius.full,
              borderSide: BorderSide(color: borderColor.withValues(alpha: 0)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: AppRadius.full,
              borderSide: BorderSide(color: borderColor.withValues(alpha: 0)),
            ),
          ),
        ),
      ),
    );
  }
}
