import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/unexa_card.dart';
import '../../../core/widgets/unexa_pdf_viewer_screen.dart';
import '../../../core/widgets/unexa_empty_state.dart';
import '../../../core/widgets/unexa_loading_shimmer.dart';
import '../../../core/widgets/unexa_theme_toggle.dart';
import '../../../data/models/timetable_model.dart';
import '../../../data/repositories/document_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/student_dashboard_provider.dart';
import 'widgets/student_shell.dart';

class StudentDashboardScreen extends ConsumerWidget {
  const StudentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserModelProvider).value;
    final college = ref.watch(currentCollegeModelProvider).value;
    final holidayAsync = ref.watch(todayHolidayProvider);
    final classesAsync = ref.watch(homeClassesProvider);
    final announcementsAsync = ref.watch(recentAnnouncementsProvider);

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Batch / Year chip line, e.g. "CSE • 2025 • Year 3 • Section A"
    final batchLine = [
      user.departmentName,
      user.batchName,
      if (user.year != null) 'Year ${user.year}',
      user.sectionName,
    ].whereType<String>().where((s) => s.trim().isNotEmpty).join(' • ');

    return StudentShell(
      title: user.displayName,
      subtitle: _roleLabel(user.role),
      currentRoute: '/student/home',
      actions: [
        const Center(child: ThemeToggleSun(size: 38)),
        IconButton(
          tooltip: 'Exit',
          icon: const Icon(Icons.power_settings_new_rounded),
          onPressed: () => _confirmExit(context),
        ),
      ],
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(homeClassesProvider);
          ref.invalidate(recentAnnouncementsProvider);
          ref.invalidate(todayHolidayProvider);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            if (batchLine.isNotEmpty)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
                    borderRadius: AppRadius.fullRadius,
                  ),
                  child: Text(
                    batchLine,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.md),

            // ---- Announcements card ----
            _SectionCard(
              title: 'Announcements',
              child: announcementsAsync.when(
                data: (items) {
                  if (items.isEmpty) {
                    return const _InlineNothing(
                        icon: Icons.campaign_outlined, text: 'Nothing to show');
                  }
                  return Column(
                    children: items.take(3).map((item) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .secondary
                                    .withValues(alpha: 0.12),
                                borderRadius: AppRadius.smRadius,
                              ),
                              child: Icon(
                                Icons.campaign_rounded,
                                size: 18,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  Text(
                                    item.body,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => UnexaLoadingShimmer.cardList(count: 2),
                error: (_, _) => const _InlineNothing(
                    icon: Icons.cloud_off_rounded, text: 'Updates unavailable'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // ---- Today's classes card ----
            _SectionCard(
              title: "Today's classes",
              child: holidayAsync.maybeWhen(
                data: (holiday) => holiday != null
                    ? UnexaEmptyState.holiday(holidayName: holiday.title)
                    : _classesBody(context, classesAsync),
                orElse: () => _classesBody(context, classesAsync),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ---- Routine & Holidays official PDF buttons ----
            Row(
              children: [
                Expanded(
                  child: _OfficialPdfButton(
                    icon: Icons.table_chart_rounded,
                    label: 'Routine',
                    type: 'timetable_pdf',
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _OfficialPdfButton(
                    icon: Icons.beach_access_rounded,
                    label: 'Holidays',
                    type: 'holiday_pdf',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: Text(
                college?.name ?? '',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _classesBody(
      BuildContext context, AsyncValue<List<TimetableEntryModel>> classesAsync) {
    return classesAsync.when(
      data: (classes) {
        if (classes.isEmpty) return UnexaEmptyState.noClasses();
        return Column(
          children: classes.take(4).map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  SizedBox(
                    width: 76,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.startTime,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 13)),
                        Text(entry.endTime,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(fontSize: 11)),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.subjectName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          '${entry.room}${entry.faculty != null && entry.faculty!.isNotEmpty ? ' • ${entry.faculty}' : ''}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  _TypeDot(isLab: entry.isLab),
                ],
              ),
            );
          }).toList(),
        );
      },
      loading: () => UnexaLoadingShimmer.cardList(count: 2),
      error: (_, _) => const _InlineNothing(
          icon: Icons.cloud_off_rounded, text: 'Schedule unavailable'),
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'owner':
        return 'Owner';
      case 'admin':
        return 'Admin';
      case 'co_admin':
        return 'Co-Admin';
      case 'moderator':
        return 'Moderator';
      default:
        return 'Student';
    }
  }

  void _confirmExit(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit UNEXA?'),
        content:
            const Text('You will stay signed in and can reopen the app anytime.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              SystemNavigator.pop();
            },
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }
}

/// Small colored dot differentiating Class vs Lab (minimal visual, per prototype).
class _TypeDot extends StatelessWidget {
  final bool isLab;

  const _TypeDot({required this.isLab});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isLab ? 'Lab' : 'Class',
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: isLab ? const Color(0xFF8B5CF6) : const Color(0xFF2563EB),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// Rounded section card used for Announcements & Today's classes (prototype boxes).
class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return UnexaCard(
      borderRadius: AppRadius.lg,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.xs),
          child,
        ],
      ),
    );
  }
}

class _InlineNothing extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InlineNothing({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          Text(
            text,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Routine / Holidays button that opens the official PDF uploaded via the
/// Admin/Co-Admin portal. Fetches the active document live from Firestore.
class _OfficialPdfButton extends ConsumerStatefulWidget {
  final IconData icon;
  final String label;
  final String type;

  const _OfficialPdfButton({
    required this.icon,
    required this.label,
    required this.type,
  });

  @override
  ConsumerState<_OfficialPdfButton> createState() => _OfficialPdfButtonState();
}

class _OfficialPdfButtonState extends ConsumerState<_OfficialPdfButton> {
  bool _opening = false;

  Future<void> _open() async {
    final user = ref.read(currentUserModelProvider).value;
    if (user == null || _opening) return;

    setState(() => _opening = true);
    try {
      final doc = await ref
          .read(documentRepositoryProvider)
          .getActiveDocument(user.collegeId, widget.type);

      if (!mounted) return;

      if (doc == null || doc.downloadUrl.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'No ${widget.label} PDF published yet. Your administrator can upload it from the portal.'),
          ),
        );
        return;
      }

      // Open in-app; no external browser needed.
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => UnexaPdfViewerScreen(
              title: '${widget.label} (v${doc.version})',
              url: doc.downloadUrl,
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not open the PDF. Check your connection.')),
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return UnexaCard(
      borderRadius: AppRadius.md,
      onTap: _opening ? null : _open,
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: _opening
            ? const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(widget.icon,
                      size: 20, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    widget.label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ],
              ),
      ),
    );
  }
}
