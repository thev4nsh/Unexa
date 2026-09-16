import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'unexa_button.dart';

/// Meaningful, clean empty state widget with optional action button.
class UnexaEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionText;
  final VoidCallback? onAction;
  final Color? iconColor;

  const UnexaEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionText,
    this.onAction,
    this.iconColor,
  });

  factory UnexaEmptyState.noClasses({VoidCallback? onRefresh}) {
    return UnexaEmptyState(
      icon: Icons.event_available_rounded,
      title: '🎉 No classes today!',
      subtitle: 'Enjoy your free time or catch up on your studies.',
      actionText: onRefresh != null ? 'Refresh' : null,
      onAction: onRefresh,
      iconColor: AppColors.success,
    );
  }

  factory UnexaEmptyState.holiday({String? holidayName}) {
    return UnexaEmptyState(
      icon: Icons.beach_access_rounded,
      title: '🏖️ Today is a holiday.',
      subtitle: holidayName != null ? '$holidayName — Have a great day!' : 'No classes scheduled for today.',
      iconColor: AppColors.warning,
    );
  }

  factory UnexaEmptyState.noAnnouncements() {
    return const UnexaEmptyState(
      icon: Icons.campaign_outlined,
      title: 'No announcements yet.',
      subtitle: 'Check back later for updates from your institute administration.',
    );
  }

  factory UnexaEmptyState.noEvents() {
    return const UnexaEmptyState(
      icon: Icons.calendar_today_rounded,
      title: 'No events scheduled.',
      subtitle: 'The academic calendar currently has no upcoming events.',
    );
  }

  factory UnexaEmptyState.allCaughtUp() {
    return const UnexaEmptyState(
      icon: Icons.done_all_rounded,
      title: "You're all caught up.",
      subtitle: 'There are no pending verification requests at this time.',
      iconColor: AppColors.success,
    );
  }

  factory UnexaEmptyState.noDocuments() {
    return const UnexaEmptyState(
      icon: Icons.folder_open_rounded,
      title: 'No official documents available.',
      subtitle: 'Official timetables and holiday lists will appear here once published.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // SingleChildScrollView instead of a bare Column: when this widget sits
    // inside a body that shrinks (software keyboard open during search, or a
    // short list area), the content scrolls instead of throwing a
    // "RenderFlex overflowed by N pixels" error. In loose-height parents it
    // behaves exactly like the previous centered Column.
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: (iconColor ?? theme.colorScheme.primary).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 40,
                color: iconColor ?? (isDark ? AppColors.darkTextSecondary : theme.colorScheme.primary),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                height: 1.4,
              ),
            ),
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.lg),
              UnexaButton(
                text: actionText!,
                onPressed: onAction,
                variant: UnexaButtonVariant.outline,
                width: 140,
                height: 40,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
