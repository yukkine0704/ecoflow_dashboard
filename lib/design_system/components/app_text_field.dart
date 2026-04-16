import 'package:flutter/material.dart';

import '../theme/theme_context.dart';
import '../tokens/app_metrics.dart';

class AppTextField extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final hasError = errorText != null && errorText!.isNotEmpty;
    final borderColor = hasError
        ? colors.error.withValues(alpha: 0.3)
        : colors.outlineVariant.withValues(alpha: 0.15);

    return Semantics(
      textField: true,
      enabled: enabled,
      label: label ?? hintText ?? 'Input field',
      child: TextField(
        enabled: enabled,
        obscureText: obscureText,
        keyboardType: keyboardType,
        controller: controller,
        onChanged: onChanged,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: colors.onSurface),
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          errorText: errorText,
          filled: true,
          fillColor: colors.surfaceHighest,
          isDense: false,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 20),
          suffixIcon: suffixIcon == null ? null : Icon(suffixIcon, size: 20),
          border: OutlineInputBorder(
            borderRadius: AppRadius.md,
            borderSide: BorderSide(color: borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadius.md,
            borderSide: BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppRadius.md,
            borderSide: BorderSide(
              color: colors.primary.withValues(alpha: 0.3),
              width: 1.2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: AppRadius.md,
            borderSide: BorderSide(
              color: colors.error.withValues(alpha: 0.3),
              width: 1.2,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: AppRadius.md,
            borderSide: BorderSide(
              color: colors.error.withValues(alpha: 0.4),
              width: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}
