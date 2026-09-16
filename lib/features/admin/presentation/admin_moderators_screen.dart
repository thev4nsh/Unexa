import '../../../core/widgets/staff_back_app_bar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/screen_privacy_guard.dart';
import '../../../core/widgets/unexa_card.dart';
import '../../../core/widgets/unexa_empty_state.dart';
import '../../../data/services/firebase_service.dart';
import '../../../data/services/role_management_service.dart';
import '../../auth/providers/auth_provider.dart';

/// Manage Moderators — role management panel.
///
/// Visibility: Admin and Co-Admin only. Moderators and students never see it.
/// Powers:
///   - Admin: promote student -> moderator OR co_admin; demote both.
///   - Co-Admin: promote student -> moderator; demote moderators only.
/// Every change requires a reason and writes an audit log entry.
class AdminModeratorsScreen extends ConsumerStatefulWidget {
  const AdminModeratorsScreen({super.key});

  @override
  ConsumerState<AdminModeratorsScreen> createState() =>
      _AdminModeratorsScreenState();
}

class _AdminModeratorsScreenState
    extends ConsumerState<AdminModeratorsScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserModelProvider).value;
    if (me == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Server-side rule also blocks moderator writes; this hides the panel.
    final isAdmin = me.isAdmin || me.isOwner;
    final isCoAdmin = me.isCoAdmin;
    if (!isAdmin && !isCoAdmin) {
      return Scaffold(
        appBar: const StaffBackAppBar(title: 'Manage Moderators'),
        body: const Center(
          child: Text('You do not have permission to manage staff roles.'),
        ),
      );
    }

    return SecureScreen(
      child: Scaffold(
      appBar: const StaffBackAppBar(title: 'Manage Moderators'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search by name or email',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (value) => setState(() => _search = value.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: ref
                  .watch(firestoreProvider)
                  .collection(FirestorePaths.users(me.collegeId))
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                      child: Text('Could not load members: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Keep the doc id together with its data — no fragile lookups.
                final members = (snapshot.data?.docs ?? [])
                    .map((d) => {'id': d.id, ...d.data()})
                    .where((u) =>
                        (u['accountStatus'] ?? '') == AppConstants.statusActive)
                    .where((u) {
                  if (_search.isEmpty) return true;
                  final name = (u['displayName'] ?? '').toString().toLowerCase();
                  final email = (u['email'] ?? '').toString().toLowerCase();
                  return name.contains(_search) || email.contains(_search);
                }).toList()
                  ..sort((a, b) => (a['displayName'] ?? '')
                      .toString()
                      .compareTo((b['displayName'] ?? '').toString()));

                if (members.isEmpty) {
                  return UnexaEmptyState(
                    icon: Icons.manage_accounts_rounded,
                    title: _search.isEmpty ? 'Nothing to show' : 'No matches',
                    subtitle: _search.isEmpty
                        ? 'Approved members will appear here once students join your institute.'
                        : 'No member matches "$_search".',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: members.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final u = members[index];
                    return _MemberTile(
                      collegeId: me.collegeId,
                      uid: u['id'] as String,
                      name: (u['displayName'] ?? 'Member') as String,
                      email: (u['email'] ?? '') as String,
                      role: (u['role'] ?? AppConstants.roleStudent) as String,
                      departmentName: (u['departmentName'] ?? '') as String?,
                      batchName: (u['batchName'] ?? '') as String?,
                                            sectionName: (u['sectionName'] ?? '') as String?,
                      isAdmin: isAdmin,
                      isCoAdmin: isCoAdmin,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    ));
  }
}

class _MemberTile extends ConsumerWidget {
  final String collegeId;
  final String uid;
  final String name;
  final String email;
  final String role;

  /// Academic links decide whether this moderator is a CR (student + mod).
  final String? departmentName;
  final String? batchName;
  final String? sectionName;

  /// True when the signed-in user is Admin/Owner (can manage co-admins too).
  final bool isAdmin;

  /// True when the signed-in user is a Co-Admin (moderator management only).
  final bool isCoAdmin;

  const _MemberTile({
    required this.collegeId,
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.isAdmin,
    required this.isCoAdmin,
    this.departmentName,
    this.batchName,
    this.sectionName,
  });

  bool get isModerator => role == AppConstants.roleModerator;
  bool get isCrRole => role == AppConstants.roleCr;
  bool get isModeratorKind => isModerator || isCrRole;
  bool get isCoAdminRole => role == AppConstants.roleCoAdmin;
  bool get isStudentRole => role == AppConstants.roleStudent;
  bool get isProtectedRole =>
      role == AppConstants.roleAdmin || role == AppConstants.roleOwner;

  /// Class membership decides whether a student->Mod promotion keeps a CR
  /// path (class data retained = can become CR without re-onboarding).
  bool get hasAcademics =>
      (departmentName?.isNotEmpty ?? false) || (batchName?.isNotEmpty ?? false);

  String get classLabel => [
        departmentName,
        batchName,
        if (sectionName?.isNotEmpty ?? false) 'Sec $sectionName',
      ].whereType<String>().where((s) => s.isNotEmpty).join(' • ');

  /// Whether THIS signed-in user may act on THIS member.
  bool get canAct {
    if (isProtectedRole) return false; // admins/owners only via platform owner
    if (isAdmin) {
      // Admin manages students, moderators, CRs and co-admins.
      return isStudentRole || isModeratorKind || isCoAdminRole;
    }
    if (isCoAdmin) {
      // Co-Admin manages students, moderators and CRs — not co-admins.
      return isStudentRole || isModeratorKind;
    }
    return false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return UnexaCard(
      borderRadius: AppRadius.sm,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        leading: CircleAvatar(
          backgroundColor:
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(email, overflow: TextOverflow.ellipsis),
            if (isCrRole)
              Text('CR • $classLabel',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  )),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCrRole) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                  borderRadius: AppRadius.fullRadius,
                ),
                child: const Text('CR',
                    style: TextStyle(
                      color: Color(0xFF7C3AED),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    )),
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            _RoleChip(role: role),
          ],
        ),
        onTap: canAct ? () => _showActions(context, ref) : null,
      ),
    );
  }

  void _showActions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(name,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  Text(email, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: AppSpacing.md),
                  // Admin + Co-Admin can both grant Mod and CR.
                  if (isStudentRole) ...[
                    _ActionTile(
                      icon: Icons.shield_rounded,
                      title: 'Promote as Mod',
                      subtitle:
                          'Only moderator powers — approve, reject, ban. Staff access; student pages are hidden.',
                      onTap: () =>
                          _changeRole(context, ref, AppConstants.roleModerator),
                    ),
                    _ActionTile(
                      icon: Icons.workspace_premium_rounded,
                      title: 'Promote as CR',
                      subtitle: hasAcademics
                          ? 'Moderator powers + full student experience. Their class ($classLabel) is kept — they see their classes and Verification.'
                          : 'Moderator powers + full student experience — but this member has no class selected. They will be asked to pick one first.',
                      onTap: () =>
                          _changeRole(context, ref, AppConstants.roleCr),
                    ),
                  ],
                  // Direct Mod <-> CR switches, both directions.
                  if (isModerator)
                    _ActionTile(
                      icon: Icons.workspace_premium_rounded,
                      title: 'Change to CR',
                      subtitle: hasAcademics
                          ? 'Adds the student experience — their saved class is restored and they see both.'
                          : 'Adds the student experience — this moderator has no saved class, they will pick one on next login.',
                      onTap: () =>
                          _changeRole(context, ref, AppConstants.roleCr),
                    ),
                  if (isCrRole)
                    _ActionTile(
                      icon: Icons.shield_rounded,
                      title: 'Change to Mod',
                      subtitle:
                          'Moderator powers only — student pages hidden. Their class data is kept and restored if made CR again.',
                      onTap: () =>
                          _changeRole(context, ref, AppConstants.roleModerator),
                    ),
                  // Only Admin can grant or revoke Co-Admin — offered directly
                  // for students, moderators AND CRs. No demote detour needed.
                  if (isAdmin && !isCoAdminRole)
                    _ActionTile(
                      icon: Icons.admin_panel_settings_rounded,
                      title: 'Promote to Co-Admin',
                      subtitle:
                          'Full operational access except owner actions — a direct upgrade from their current role.',
                      onTap: () =>
                          _changeRole(context, ref, AppConstants.roleCoAdmin),
                    ),
                  // Both can demote mods/CRs; only Admin touches co-admins.
                  if (isModeratorKind)
                    _ActionTile(
                      icon: Icons.school_rounded,
                      title: 'Demote to Student',
                      subtitle: hasAcademics
                          ? 'Removes all moderator powers. They stay in their class as a regular student.'
                          : 'Removes all moderator powers (this member has no class membership).',
                      onTap: () =>
                          _changeRole(context, ref, AppConstants.roleStudent),
                    ),
                  if (isCoAdminRole && isAdmin) ...[
                    _ActionTile(
                      icon: Icons.shield_rounded,
                      title: 'Change to Moderator',
                      subtitle: 'Downgrade co-admin powers',
                      onTap: () =>
                          _changeRole(context, ref, AppConstants.roleModerator),
                    ),
                    _ActionTile(
                      icon: Icons.school_rounded,
                      title: 'Demote to Student',
                      subtitle: 'Remove co-admin powers',
                      onTap: () =>
                          _changeRole(context, ref, AppConstants.roleStudent),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _changeRole(
      BuildContext context, WidgetRef ref, String newRole) async {
    Navigator.pop(context);

    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Change role to ${newRole.replaceAll('_', '-')}?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$name will immediately gain or lose portal access.'),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: reasonController,
                decoration:
                    const InputDecoration(labelText: 'Reason (required)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) return;
              Navigator.pop(context, true);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final actor = ref.read(currentUserModelProvider).value;
      if (actor == null) throw StateError('Not signed in');

      await ref.read(roleManagementServiceProvider).changeRole(
            actor: actor,
            collegeId: collegeId,
            targetUid: uid,
            newRole: newRole,
            reason: reasonController.text.trim(),
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name is now ${newRole.replaceAll('_', '-')}')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not change role: $error'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.mdRadius,
        side: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle:
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String role;

  const _RoleChip({required this.role});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (role) {
      AppConstants.roleOwner => ('Owner', const Color(0xFF7C3AED)),
      AppConstants.roleAdmin => ('Admin', const Color(0xFFDC2626)),
      AppConstants.roleCoAdmin => ('Co-Admin', const Color(0xFFD97706)),
      AppConstants.roleModerator => ('Moderator', const Color(0xFF2563EB)),
      AppConstants.roleCr => ('CR', const Color(0xFF7C3AED)),
      _ => ('Student', const Color(0xFF10B981)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.fullRadius,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
