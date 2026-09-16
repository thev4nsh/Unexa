import '../../../core/widgets/staff_back_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/unexa_card.dart';
import '../../../core/widgets/unexa_empty_state.dart';
import '../../../data/models/announcement_model.dart';
import '../../../data/repositories/announcement_repository.dart';
import '../../../data/repositories/academic_repository.dart';
import '../../auth/providers/auth_provider.dart';

class AdminAnnouncementsScreen extends ConsumerWidget {
  const AdminAnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserModelProvider).value;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: const StaffBackAppBar(title: 'Manage Announcements'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context, ref, user.collegeId, user.displayName),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Publish'),
      ),
      body: StreamBuilder<List<AnnouncementModel>>(
        stream: ref.watch(announcementRepositoryProvider).streamAllAnnouncements(user.collegeId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _AdminErrorState(
              message: 'Could not load announcements. Check your admin role and rules.',
              details: snapshot.error.toString(),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          if (items.isEmpty) return UnexaEmptyState.noAnnouncements();
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final item = items[index];
              return UnexaCard(
                borderRadius: AppRadius.sm,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(item.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          onPressed: () async {
                            try {
                              await ref.read(announcementRepositoryProvider).deleteAnnouncement(user.collegeId, item.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Announcement removed')),
                                );
                              }
                            } catch (error) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(_friendlyAdminError(error)),
                                    backgroundColor: Theme.of(context).colorScheme.error,
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                      ],
                    ),
                    Text(item.body),
                    const SizedBox(height: AppSpacing.sm),
                    Text('Target: ${item.targetScope}', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref, String collegeId, String authorName) {
    final rootContext = context;
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    String targetScope = 'all';
    final Set<String> targetIds = {};
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New Announcement'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: bodyController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Message'),
                  maxLines: 4,
                ),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<String>(
                  initialValue: targetScope,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Audience'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All students')),
                    DropdownMenuItem(value: 'department', child: Text('Specific department')),
                    DropdownMenuItem(value: 'batch', child: Text('Specific batch')),
                    DropdownMenuItem(value: 'section', child: Text('Specific section')),
                  ],
                  onChanged: isSaving
                      ? null
                      : (value) => setDialogState(() {
                            targetScope = value ?? 'all';
                            targetIds.clear();
                          }),
                ),
                if (targetScope != 'all') ...[
                  const SizedBox(height: AppSpacing.sm),
                  _TargetPicker(
                    collegeId: collegeId,
                    targetScope: targetScope,
                    selectedIds: targetIds,
                    enabled: !isSaving,
                    onChanged: (ids) => setDialogState(() {
                      targetIds
                        ..clear()
                        ..addAll(ids);
                    }),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final title = titleController.text.trim();
                      final body = bodyController.text.trim();
                      if (title.isEmpty || body.isEmpty) {
                        ScaffoldMessenger.of(rootContext).showSnackBar(
                          const SnackBar(content: Text('Title and message are required')),
                        );
                        return;
                      }
                      if (targetScope != 'all' && targetIds.isEmpty) {
                        ScaffoldMessenger.of(rootContext).showSnackBar(
                          const SnackBar(content: Text('Select at least one target')),
                        );
                        return;
                      }

                      setDialogState(() => isSaving = true);
                      try {
                        await ref.read(announcementRepositoryProvider).createAnnouncement(
                              AnnouncementModel(
                                id: '',
                                collegeId: collegeId,
                                title: title,
                                body: body,
                                authorName: authorName,
                                targetScope: targetScope,
                                targetIds: targetIds.toList(),
                              ),
                            );
                        if (context.mounted) Navigator.pop(context);
                        if (rootContext.mounted) {
                          ScaffoldMessenger.of(rootContext).showSnackBar(
                            const SnackBar(content: Text('Announcement published')),
                          );
                        }
                      } catch (error) {
                        setDialogState(() => isSaving = false);
                        if (rootContext.mounted) {
                          ScaffoldMessenger.of(rootContext).showSnackBar(
                            SnackBar(
                              content: Text(_friendlyAdminError(error)),
                              backgroundColor: Theme.of(rootContext).colorScheme.error,
                            ),
                          );
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Publish'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Picks the concrete department/batch/section documents that an announcement targets.
/// Students only receive announcements whose targets include their own scope.
class _TargetPicker extends ConsumerWidget {
  final String collegeId;
  final String targetScope;
  final Set<String> selectedIds;
  final bool enabled;
  final ValueChanged<Set<String>> onChanged;

  const _TargetPicker({
    required this.collegeId,
    required this.targetScope,
    required this.selectedIds,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<dynamic>> async;
    switch (targetScope) {
      case 'department':
        async = ref.watch(departmentsProvider(collegeId));
        break;
      case 'batch':
        async = ref.watch(batchesAllProvider(collegeId));
        break;
      case 'section':
        async = ref.watch(sectionsAllProvider(collegeId));
        break;
      default:
        async = const AsyncValue.data([]);
    }

    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: LinearProgressIndicator(minHeight: 2),
      ),
      error: (e, _) => Text('Could not load targets', style: Theme.of(context).textTheme.bodySmall),
      data: (items) {
        if (items.isEmpty) {
          return Text(
            'Nothing to show — create ${targetScope == 'department' ? 'departments' : targetScope == 'batch' ? 'batches' : 'sections'} first.',
            style: Theme.of(context).textTheme.bodySmall,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Targets', style: Theme.of(context).textTheme.labelLarge),
            ...items.map((item) => CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text((item as dynamic).name),
                  value: selectedIds.contains((item as dynamic).id),
                  onChanged: enabled
                      ? (checked) {
                          final next = {...selectedIds};
                          if (checked == true) {
                            next.add((item as dynamic).id);
                          } else {
                            next.remove((item as dynamic).id);
                          }
                          onChanged(next);
                        }
                      : null,
                )),
          ],
        );
      },
    );
  }
}

String _friendlyAdminError(Object error) {
  final message = error.toString();
  if (message.contains('permission-denied')) {
    return 'Permission denied. Your institute user must be admin or co_admin, and Firestore rules must be deployed.';
  }
  if (message.contains('unavailable')) {
    return 'Network unavailable. Check your connection and try again.';
  }
  return 'Could not save. $message';
}

class _AdminErrorState extends StatelessWidget {
  final String message;
  final String details;

  const _AdminErrorState({required this.message, required this.details});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: Theme.of(context).colorScheme.error, size: 44),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(details, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
