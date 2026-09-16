import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/staff_shell.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/pending_count_provider.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserModelProvider).value;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Role-aware grid. Pure Moderators see ONLY verification;
    // Admin / Co-Admin / Owner see the full operational suite.
    final canManageAcademics = user.isAdmin || user.isOwner || user.isCoAdmin;
    final pendingCount = ref.watch(pendingVerificationCountProvider).value ?? 0;

    final cards = <StaffCard>[
      StaffCard(
        icon: Icons.verified_user_rounded,
        label: 'Verification',
        route: '/admin/verification',
        badgeCount: pendingCount,
      ),
      if (canManageAcademics) ...[
        const StaffCard(
          icon: Icons.campaign_rounded,
          label: 'Announcement',
          route: '/admin/announcements',
        ),
        const StaffCard(
          icon: Icons.table_chart_rounded,
          label: 'TimeTable',
          route: '/admin/timetable',
        ),
        const StaffCard(
          icon: Icons.beach_access_rounded,
          label: 'Holidays',
          route: '/admin/calendar',
        ),
        const StaffCard(
          icon: Icons.account_tree_rounded,
          label: 'Manage Batches',
          route: '/admin/academics',
        ),
        const StaffCard(
          icon: Icons.badge_rounded,
          label: 'Faculties',
          route: '/admin/faculties',
        ),
        const StaffCard(
          icon: Icons.folder_rounded,
          label: 'Documents',
          route: '/admin/documents',
        ),
      ],
      // Admin and Co-Admin manage staff roles; moderators never see this.
      if (user.isAdmin || user.isOwner || user.isCoAdmin)
        const StaffCard(
          icon: Icons.manage_accounts_rounded,
          label: 'Manage Moderators',
          route: '/admin/moderators',
        ),
      // Audit trail: who approved/banned/changed what, when, and why
      if (user.isAdmin || user.isOwner || user.isCoAdmin)
        const StaffCard(
          icon: Icons.receipt_long_rounded,
          label: 'Activity Logs',
          route: '/admin/audit-logs',
        ),
    ];

    return StaffShell(
      name: user.displayName,
      role: staffRoleLabel(user.role),
      cards: cards,
    );
  }
}
