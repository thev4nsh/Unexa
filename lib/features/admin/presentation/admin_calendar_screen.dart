import '../../../core/widgets/staff_back_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/unexa_card.dart';
import '../../../core/widgets/unexa_empty_state.dart';
import '../../../data/models/calendar_event_model.dart';
import '../../../data/repositories/calendar_repository.dart';
import '../../auth/providers/auth_provider.dart';

class AdminCalendarScreen extends ConsumerWidget {
  const AdminCalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserModelProvider).value;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: const StaffBackAppBar(title: 'Manage Calendar'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context, ref, user.collegeId, user.uid),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Event'),
      ),
      body: StreamBuilder<List<CalendarEventModel>>(
        stream: ref.watch(calendarRepositoryProvider).streamEvents(user.collegeId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Could not load calendar: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final events = snapshot.data!;
          if (events.isEmpty) return UnexaEmptyState.noEvents();
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: events.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final event = events[index];
              return UnexaCard(
                borderRadius: AppRadius.sm,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(event.isHoliday ? Icons.beach_access_rounded : Icons.event_rounded),
                  title: Text(event.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${DateFormatter.formatCompactDate(event.date)} • ${event.type}'),
                  trailing: IconButton(
                    tooltip: 'Delete',
                    onPressed: () async {
                      try {
                        await ref.read(calendarRepositoryProvider).deleteEvent(user.collegeId, event.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Calendar event deleted')),
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
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref, String collegeId, String actorUid) {
    final rootContext = context;
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    String type = 'event';
    DateTime selectedDate = DateTime.now();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('New Calendar Event'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
              TextField(controller: descriptionController, decoration: const InputDecoration(labelText: 'Description')),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<String>(
                initialValue: type,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(value: 'event', child: Text('Event')),
                  DropdownMenuItem(value: 'academic', child: Text('Academic')),
                  DropdownMenuItem(value: 'exam', child: Text('Exam')),
                  DropdownMenuItem(value: 'holiday', child: Text('Holiday')),
                ],
                onChanged: (value) => setState(() => type = value ?? 'event'),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 900)),
                  );
                  if (picked != null) setState(() => selectedDate = picked);
                },
                icon: const Icon(Icons.calendar_today_rounded),
                label: Text(DateFormatter.formatCompactDate(selectedDate)),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: isSaving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final title = titleController.text.trim();
                      if (title.isEmpty) {
                        ScaffoldMessenger.of(rootContext).showSnackBar(
                          const SnackBar(content: Text('Event title is required')),
                        );
                        return;
                      }
                      setState(() => isSaving = true);
                      try {
                        await ref.read(calendarRepositoryProvider).addEvent(
                              CalendarEventModel(
                                id: '',
                                collegeId: collegeId,
                                title: title,
                                description: descriptionController.text.trim(),
                                date: selectedDate,
                                type: type,
                                createdBy: actorUid,
                              ),
                            );
                        if (context.mounted) Navigator.pop(context);
                        if (rootContext.mounted) {
                          ScaffoldMessenger.of(rootContext).showSnackBar(
                            const SnackBar(content: Text('Calendar event created')),
                          );
                        }
                      } catch (error) {
                        setState(() => isSaving = false);
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
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}

String _friendlyAdminError(Object error) {
  final message = error.toString();
  if (message.contains('permission-denied')) {
    return 'Permission denied. Make sure your institute user role is admin or co_admin and Firestore rules are deployed.';
  }
  if (message.contains('unavailable')) {
    return 'Network unavailable. Check your connection and try again.';
  }
  return 'Could not save. $message';
}
