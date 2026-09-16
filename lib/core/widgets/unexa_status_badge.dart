import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Pill badge for roles, account statuses, and timetable types (Class vs Lab).
class UnexaStatusBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final IconData? icon;

  const UnexaStatusBadge({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.icon,
  });

  /// Factory for account status (active, pending, rejected, banned, suspended)
  factory UnexaStatusBadge.status(String status) {
    switch (status.toLowerCase()) {
      case AppConstants.statusActive:
        return const UnexaStatusBadge(
          label: 'Active',
          backgroundColor: Color(0xFFDCFCE7),
          textColor: Color(0xFF15803D),
          icon: Icons.check_circle_outline,
        );
      case AppConstants.statusPending:
        return const UnexaStatusBadge(
          label: 'Pending Approval',
          backgroundColor: Color(0xFFFEF3C7),
          textColor: Color(0xFFB45309),
          icon: Icons.hourglass_top_rounded,
        );
      case AppConstants.statusRejected:
        return const UnexaStatusBadge(
          label: 'Rejected',
          backgroundColor: Color(0xFFFEE2E2),
          textColor: Color(0xFFB91C1C),
          icon: Icons.cancel_outlined,
        );
      case AppConstants.statusBanned:
        return const UnexaStatusBadge(
          label: 'Banned',
          backgroundColor: Color(0xFF450A0A),
          textColor: Color(0xFFFCA5A5),
          icon: Icons.block_rounded,
        );
      case AppConstants.statusSuspended:
        return const UnexaStatusBadge(
          label: 'Suspended',
          backgroundColor: Color(0xFFFFEDD5),
          textColor: Color(0xFFC2410C),
          icon: Icons.pause_circle_outline,
        );
      default:
        return UnexaStatusBadge(
          label: status.toUpperCase(),
          backgroundColor: const Color(0xFFF1F5F9),
          textColor: const Color(0xFF475569),
        );
    }
  }

  /// Factory for roles (owner, admin, co_admin, moderator, student)
  factory UnexaStatusBadge.role(String role) {
    switch (role.toLowerCase()) {
      case AppConstants.roleOwner:
        return const UnexaStatusBadge(
          label: 'OWNER',
          backgroundColor: Color(0xFFEDE9FE),
          textColor: Color(0xFF6D28D9),
          icon: Icons.shield_rounded,
        );
      case AppConstants.roleAdmin:
        return const UnexaStatusBadge(
          label: 'ADMIN',
          backgroundColor: Color(0xFFDBEAFE),
          textColor: Color(0xFF1D4ED8),
          icon: Icons.admin_panel_settings_rounded,
        );
      case AppConstants.roleCoAdmin:
        return const UnexaStatusBadge(
          label: 'CO-ADMIN',
          backgroundColor: Color(0xFFE0E7FF),
          textColor: Color(0xFF4338CA),
          icon: Icons.verified_user_rounded,
        );
      case AppConstants.roleModerator:
        return const UnexaStatusBadge(
          label: 'MODERATOR',
          backgroundColor: Color(0xFFCCFBF1),
          textColor: Color(0xFF0F766E),
          icon: Icons.manage_accounts_rounded,
        );
      case AppConstants.roleCr:
        return const UnexaStatusBadge(
          label: 'CR',
          backgroundColor: Color(0xFFEDE9FE),
          textColor: Color(0xFF6D28D9),
          icon: Icons.workspace_premium_rounded,
        );
      case AppConstants.roleStudent:
      default:
        return const UnexaStatusBadge(
          label: 'STUDENT',
          backgroundColor: Color(0xFFF1F5F9),
          textColor: Color(0xFF475569),
          icon: Icons.school_rounded,
        );
    }
  }

  /// Factory for Class vs Lab
  factory UnexaStatusBadge.timetableType(String type) {
    final isLab = type.toLowerCase() == AppConstants.timetableTypeLab;
    return UnexaStatusBadge(
      label: isLab ? 'LAB' : 'CLASS',
      backgroundColor: isLab ? AppColors.labBadge.withValues(alpha: 0.12) : AppColors.classBadge.withValues(alpha: 0.12),
      textColor: isLab ? AppColors.labBadge : AppColors.classBadge,
      icon: isLab ? Icons.science_outlined : Icons.menu_book_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: AppRadius.fullRadius,
      ),
      // FittedBox: when a tight parent (narrow phone, crowded row) cannot
      // give the badge its intrinsic width, the content scales down slightly
      // instead of throwing a RenderFlex overflow. At normal widths it is
      // exactly the size it always was.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: textColor),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: textColor,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
