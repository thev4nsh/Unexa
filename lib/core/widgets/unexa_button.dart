import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

enum UnexaButtonVariant { primary, secondary, outline, destructive }

/// Standardized interactive button with loading state support.
class UnexaButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Widget? icon;
  final UnexaButtonVariant variant;
  final double? height;
  final double? width;

  const UnexaButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.variant = UnexaButtonVariant.primary,
    this.height = 50,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color getBgColor() {
      switch (variant) {
        case UnexaButtonVariant.primary:
          return theme.colorScheme.primary;
        case UnexaButtonVariant.secondary:
          return theme.colorScheme.secondary;
        case UnexaButtonVariant.destructive:
          return AppColors.error;
        case UnexaButtonVariant.outline:
          return Colors.transparent;
      }
    }

    Color getTextColor() {
      switch (variant) {
        case UnexaButtonVariant.outline:
          return theme.colorScheme.primary;
        case UnexaButtonVariant.primary:
        case UnexaButtonVariant.secondary:
        case UnexaButtonVariant.destructive:
          return Colors.white;
      }
    }

    BorderSide? getBorderSide() {
      if (variant == UnexaButtonVariant.outline) {
        return BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.4), width: 1.2);
      }
      return null;
    }

    return SizedBox(
      height: height,
      width: width ?? double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: getBgColor(),
          foregroundColor: getTextColor(),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.mdRadius,
            side: getBorderSide() ?? BorderSide.none,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        onPressed: isLoading ? null : onPressed,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(getTextColor()),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      icon!,
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Text(
                      text,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: getTextColor(),
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
