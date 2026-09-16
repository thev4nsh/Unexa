import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/unexa_card.dart';
import '../../../core/widgets/unexa_empty_state.dart';
import '../../../core/widgets/unexa_loading_shimmer.dart';
import '../providers/student_dashboard_provider.dart';
import 'widgets/student_shell.dart';

class StudentCalendarScreen extends ConsumerWidget {
  const StudentCalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(upcomingCalendarEventsProvider);

    return StudentShell(
      title: 'Calendar',
      currentRoute: '/student/calendar',
      child: eventsAsync.when(
        data: (events) {
          if (events.isEmpty) return UnexaEmptyState.noEvents();

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: events.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final event = events[index];
              final color = _eventColor(context, event.type);

              return UnexaCard(
                borderRadius: AppRadius.sm,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 54,
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: AppRadius.smRadius,
                      ),
                      child: Column(
                        children: [
                          Text(
                            event.date.day.toString().padLeft(2, '0'),
                            style: TextStyle(
                              color: color,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            DateFormatter.formatCompactDate(event.date).split(' ')[1],
                            style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  event.title,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ),
                              _EventPill(label: event.type, color: color),
                            ],
                          ),
                          if (event.description != null && event.description!.trim().isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              event.description!,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    height: 1.35,
                                  ),
                            ),
                          ],
                          if (event.startTime != null || event.endTime != null) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              children: [
                                Icon(
                                  Icons.schedule_rounded,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Text(
                                  '${event.startTime ?? 'All day'}${event.endTime != null ? ' - ${event.endTime}' : ''}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => StudentPagePadding(child: UnexaLoadingShimmer.cardList()),
        error: (error, _) => Center(child: Text('Could not load calendar: $error')),
      ),
    );
  }

  Color _eventColor(BuildContext context, String type) {
    switch (type.toLowerCase()) {
      case 'holiday':
        return const Color(0xFFD97706);
      case 'exam':
        return Theme.of(context).colorScheme.error;
      case 'academic':
        return Theme.of(context).colorScheme.primary;
      default:
        return Theme.of(context).colorScheme.secondary;
    }
  }
}

class _EventPill extends StatelessWidget {
  final String label;
  final Color color;

  const _EventPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.fullRadius,
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
