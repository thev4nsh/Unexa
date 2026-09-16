import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/unexa_card.dart';
import '../../../core/widgets/unexa_empty_state.dart';
import '../../../core/widgets/unexa_loading_shimmer.dart';
import '../../../core/widgets/unexa_status_badge.dart';
import '../providers/student_dashboard_provider.dart';
import 'widgets/student_shell.dart';

class StudentTimetableScreen extends ConsumerWidget {
  const StudentTimetableScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesAsync = ref.watch(todayClassesProvider);

    return StudentShell(
      title: '${DateFormatter.currentDayName()} Timetable',
      currentRoute: '/student/timetable',
      child: classesAsync.when(
        data: (classes) {
          if (classes.isEmpty) return UnexaEmptyState.noClasses();
          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: classes.length,
            itemBuilder: (c, i) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: UnexaCard(
                borderRadius: AppRadius.sm,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Expanded so a long time range and a large font
                        // scale can't push the badge out of the card.
                        Expanded(
                          child: Text(
                            DateFormatter.formatTimeRange(
                                classes[i].startTime, classes[i].endTime),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        UnexaStatusBadge.timetableType(classes[i].type),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(classes[i].subjectName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('${classes[i].room} \u2022 ${classes[i].faculty ?? 'TBD'}'),
                  ],
                ),
              ),
            ),
          );
        },
        loading: () => UnexaLoadingShimmer.cardList(),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
