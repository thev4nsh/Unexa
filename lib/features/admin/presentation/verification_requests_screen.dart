import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/screen_privacy_guard.dart';
import '../../../core/widgets/staff_back_app_bar.dart';
import '../../../core/widgets/unexa_card.dart';
import '../../../core/widgets/unexa_empty_state.dart';
import '../../../core/widgets/unexa_status_badge.dart';
import '../../../data/models/academic_models.dart';
import '../../../data/repositories/academic_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/verification_management_provider.dart';

/// Verification hub with four tabs: Pending, Approved, Banned, Rejected.
/// Admin/Co-Admin additionally get an "All users" tab where any approved
/// member can be disapproved, banned or removed entirely.
class VerificationRequestsScreen extends ConsumerStatefulWidget {
  const VerificationRequestsScreen({super.key});
  @override
  ConsumerState<VerificationRequestsScreen> createState() => _VerificationRequestsScreenState();
}

class _VerificationRequestsScreenState extends ConsumerState<VerificationRequestsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(verificationStatusTabProvider.notifier).setTab('pending'));
  }

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(filteredVerificationRequestsProvider);
    final currentTab = ref.watch(verificationStatusTabProvider);
    final controllerState = ref.watch(verificationControllerProvider);
    final actor = ref.watch(currentUserModelProvider).value;
    final canDisapprove = actor?.canManageRoles ?? false;
    final roleFilter = ref.watch(verificationRoleFilterProvider);
    final deptFilter = ref.watch(verificationDeptFilterProvider);
    final batchFilter = ref.watch(verificationBatchFilterProvider);

    ref.listen(verificationControllerProvider, (previous, next) {
      next.whenOrNull(
        data: (_) {
          if (previous?.isLoading == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Verification action completed')),
            );
          }
        },
        error: (error, _) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.toString()), backgroundColor: Theme.of(context).colorScheme.error),
          );
        },
      );
    });

    return SecureScreen(
      child: Scaffold(
      appBar: const StaffBackAppBar(title: 'Verification'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search requests',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onChanged: (value) => ref.read(verificationSearchQueryProvider.notifier).setQuery(value),
                ),
                // All Users tab extras: role + class filters.
                if (currentTab == 'all' && canDisapprove) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _AllUsersFilters(
                    roleFilter: roleFilter,
                    deptFilter: deptFilter,
                    batchFilter: batchFilter,
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<String>(
                    segments: [
                      const ButtonSegment(value: 'pending', label: Text('Pending')),
                      const ButtonSegment(value: 'active', label: Text('Approved')),
                      const ButtonSegment(value: 'banned', label: Text('Banned')),
                      const ButtonSegment(value: 'rejected', label: Text('Rejected')),
                      if (canDisapprove)
                        const ButtonSegment(value: 'all', label: Text('All users')),
                    ],
                    selected: {currentTab},
                    onSelectionChanged: controllerState.isLoading
                        ? null
                        : (newSelection) =>
                            ref.read(verificationStatusTabProvider.notifier).setTab(newSelection.first),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: requestsAsync.when(
              data: (requests) {
                if (requests.isEmpty) return UnexaEmptyState.allCaughtUp();
                return ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: requests.length,
                  itemBuilder: (c, i) {
                    final req = requests[i];
                    final isAllUsersTab = currentTab == 'all';
                    final isApprovedTab = currentTab == 'active';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: UnexaCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(child: Text(req.displayName.isNotEmpty ? req.displayName[0] : '?')),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(child: Text(req.displayName, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                                // Tight but not rigid: the badge may compress
                                // (FittedBox scales it) instead of overflowing
                                // the row on narrow screens.
                                Flexible(child: UnexaStatusBadge.status(req.status)),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(req.email),
                            const Divider(height: AppSpacing.lg),
                            if (currentTab == 'pending')
                              // Wrap, not Row: three labelled buttons can exceed
                              // narrow widths (and large font scales) — extra
                              // buttons flow to a second line instead of
                              // throwing a RenderFlex overflow.
                              Wrap(
                                alignment: WrapAlignment.spaceAround,
                                spacing: AppSpacing.xs,
                                runSpacing: AppSpacing.xs,
                                children: [
                                  TextButton.icon(
                                    icon: const Icon(Icons.check, color: Colors.green),
                                    label: const Text('Approve'),
                                    onPressed: controllerState.isLoading
                                        ? null
                                        : () => ref.read(verificationControllerProvider.notifier).approveStudent(req.uid),
                                  ),
                                  TextButton.icon(
                                    icon: const Icon(Icons.close_rounded, color: Colors.orange),
                                    label: const Text('Reject'),
                                    onPressed: controllerState.isLoading
                                        ? null
                                        : () => _showReasonDialog(context, req.uid, 'reject'),
                                  ),
                                  TextButton.icon(
                                    icon: const Icon(Icons.block, color: Colors.red),
                                    label: const Text('Ban'),
                                    onPressed: controllerState.isLoading
                                        ? null
                                        : () => _showReasonDialog(context, req.uid, 'ban'),
                                  ),
                                ],
                              )
                            else if (isApprovedTab)
                              Wrap(
                                alignment: WrapAlignment.spaceAround,
                                spacing: AppSpacing.xs,
                                runSpacing: AppSpacing.xs,
                                children: [
                                  TextButton.icon(
                                    icon: const Icon(Icons.verified_rounded, color: Colors.green),
                                    label: const Text('Approved'),
                                    onPressed: null,
                                  ),
                                  if (canDisapprove)
                                    TextButton.icon(
                                      icon: const Icon(Icons.undo_rounded, color: Colors.deepOrange),
                                      label: const Text('Disapprove'),
                                      onPressed: controllerState.isLoading
                                          ? null
                                          : () => _showReasonDialog(context, req.uid, 'disapprove'),
                                    ),
                                  if (canDisapprove)
                                    TextButton.icon(
                                      icon: const Icon(Icons.block, color: Colors.red),
                                      label: const Text('Ban'),
                                      onPressed: controllerState.isLoading
                                          ? null
                                          : () => _showReasonDialog(context, req.uid, 'ban'),
                                    ),
                                ],
                              )
                            else if (currentTab == 'banned')
                              TextButton.icon(
                                icon: const Icon(Icons.lock_open, color: Colors.green),
                                label: const Text('Unban'),
                                onPressed: controllerState.isLoading
                                    ? null
                                    : () => _showReasonDialog(context, req.uid, 'unban'),
                              )
                            else if (isAllUsersTab && canDisapprove)
                              Wrap(
                                alignment: WrapAlignment.spaceAround,
                                spacing: AppSpacing.xs,
                                runSpacing: AppSpacing.xs,
                                children: [
                                  TextButton.icon(
                                    icon: const Icon(Icons.undo_rounded, color: Colors.deepOrange),
                                    label: const Text('Disapprove'),
                                    onPressed: controllerState.isLoading
                                        ? null
                                        : () => _showReasonDialog(context, req.uid, 'disapprove'),
                                  ),
                                  TextButton.icon(
                                    icon: const Icon(Icons.block, color: Colors.red),
                                    label: const Text('Ban'),
                                    onPressed: controllerState.isLoading
                                        ? null
                                        : () => _showReasonDialog(context, req.uid, 'ban'),
                                  ),
                                  TextButton.icon(
                                    icon: const Icon(Icons.person_remove_rounded, color: Colors.redAccent),
                                    label: const Text('Remove'),
                                    onPressed: controllerState.isLoading
                                        ? null
                                        : () => _showReasonDialog(context, req.uid, 'remove'),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    ));
  }

  void _showReasonDialog(BuildContext context, String targetUid, String action) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(switch (action) {
          'ban' => 'Ban Student',
          'reject' => 'Reject Student',
          'disapprove' => 'Disapprove Member',
          'remove' => 'Remove Completely',
          _ => 'Unban Student',
        }),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (action == 'disapprove')
              const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.sm),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'The member returns to the pending queue with their department and batch kept. They cannot sign in until re-approved.',
                    style: TextStyle(fontSize: 12.5),
                  ),
                ),
              ),
            TextField(
              controller: reasonController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Reason (Required)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) return;
              final notifier = ref.read(verificationControllerProvider.notifier);
              switch (action) {
                case 'ban':
                  notifier.banStudent(targetUid, reason);
                  break;
                case 'reject':
                  notifier.rejectStudent(targetUid, reason);
                  break;
                case 'disapprove':
                  notifier.disapproveStudent(targetUid, reason);
                  break;
                case 'remove':
                  notifier.removeUserCompletely(targetUid, reason);
                  break;
                default:
                  notifier.unbanStudentFromProfile(targetUid, reason);
              }
              Navigator.pop(context);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}

/// Role chips + department/batch dropdowns for the All Users tab.
class _AllUsersFilters extends ConsumerWidget {
  final String? roleFilter;
  final String? deptFilter;
  final String? batchFilter;

  const _AllUsersFilters({
    required this.roleFilter,
    required this.deptFilter,
    required this.batchFilter,
  });

  static const _roleChoices = [
    ('all', 'All roles'),
    ('student', 'Students'),
    ('cr', 'CRs'),
    ('moderator', 'Moderators'),
    ('co_admin', 'Co-Admins'),
    ('admin', 'Admins'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserModelProvider).value;
    if (user == null) return const SizedBox.shrink();
    final academicRepo = ref.watch(academicRepositoryProvider);
    final hasFilter = roleFilter != null || deptFilter != null || batchFilter != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ---- Role chips ----
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _roleChoices.map((choice) {
              final selected = choice.$1 == (roleFilter ?? 'all');
              return Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: ChoiceChip(
                  label: Text(choice.$2),
                  selected: selected,
                  onSelected: (_) => ref
                      .read(verificationRoleFilterProvider.notifier)
                      .setFilter(choice.$1 == 'all' ? null : choice.$1),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        // ---- Class filters: department -> batch ----
        Row(
          children: [
            Expanded(
              child: StreamBuilder<List<DepartmentModel>>(
                stream: academicRepo.streamDepartments(user.collegeId),
                builder: (context, snapshot) {
                  final departments = snapshot.data ?? const [];
                  return DropdownButtonFormField<String>(
                    // Filter by NAME — verification requests store names.
                    initialValue:
                        departments.any((d) => d.name == deptFilter) ? deptFilter : null,
                    isExpanded: true,
                    isDense: true,
                    decoration: const InputDecoration(labelText: 'Department'),
                    items: departments
                        .map((d) => DropdownMenuItem(
                              value: d.name,
                              child: Text(
                                  d.code.isEmpty ? d.name : '${d.name} (${d.code})',
                                  overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (value) {
                      ref.read(verificationDeptFilterProvider.notifier).setFilter(value);
                      // Batch depends on department.
                      ref.read(verificationBatchFilterProvider.notifier).setFilter(null);
                    },
                  );
                },
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: StreamBuilder<List<BatchModel>>(
                stream: (deptFilter?.isNotEmpty ?? false)
                    ? academicRepo.streamBatches(user.collegeId, departmentId: deptFilter)
                    : const Stream.empty(),
                builder: (context, snapshot) {
                  final batches = snapshot.data ?? const [];
                  return DropdownButtonFormField<String>(
                    initialValue: batches.any((b) => b.name == batchFilter) ? batchFilter : null,
                    isExpanded: true,
                    isDense: true,
                    decoration: const InputDecoration(labelText: 'Batch'),
                    items: batches
                        .map((b) => DropdownMenuItem(
                              value: b.name,
                              child: Text(b.name, overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (value) =>
                        ref.read(verificationBatchFilterProvider.notifier).setFilter(value),
                  );
                },
              ),
            ),
            if (hasFilter)
              IconButton(
                tooltip: 'Clear class filters',
                onPressed: () {
                  ref.read(verificationDeptFilterProvider.notifier).setFilter(null);
                  ref.read(verificationBatchFilterProvider.notifier).setFilter(null);
                },
                icon: const Icon(Icons.filter_alt_off_rounded),
              ),
          ],
        ),
      ],
    );
  }
}
