import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/unexa_card.dart';
import '../../../core/widgets/unexa_empty_state.dart';
import '../../../core/widgets/unexa_loading_shimmer.dart';
import '../providers/student_dashboard_provider.dart';
import 'widgets/student_shell.dart';

class StudentAnnouncementsScreen extends ConsumerWidget {
  const StudentAnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final announcementsAsync = ref.watch(recentAnnouncementsProvider);

    return StudentShell(
      title: 'Announcements',
      currentRoute: '/student/announcements',
      child: announcementsAsync.when(
        data: (announcements) {
          if (announcements.isEmpty) return UnexaEmptyState.noAnnouncements();
          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: announcements.length,
            itemBuilder: (c, i) {
              final ann = announcements[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: UnexaCard(
                  borderRadius: AppRadius.sm,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ann.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: AppSpacing.xs),
                      Text('By ${ann.authorName} \u2022 ${ann.createdAt != null ? ann.createdAt!.toLocal().toString().split(' ')[0] : ''}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: AppSpacing.sm),
                      Text(ann.body),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => UnexaLoadingShimmer.cardList(),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
