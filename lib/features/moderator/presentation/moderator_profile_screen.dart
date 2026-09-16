import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/unexa_card.dart';
import '../../../core/widgets/unexa_status_badge.dart';
import '../../auth/providers/auth_provider.dart';
import '../../student/presentation/widgets/student_shell.dart';

/// Moderator profile — same layout as the student profile, plus a card
/// summarizing the moderator's verification permissions.
class ModeratorProfileScreen extends ConsumerWidget {
  const ModeratorProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserModelProvider).value;
    final college = ref.watch(currentCollegeModelProvider).value;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // CRs show their class identity; pure moderators don't have one.
    final hasAcademics = user.isCr &&
        ((user.departmentId?.isNotEmpty ?? false) ||
            (user.batchId?.isNotEmpty ?? false));

    return StudentShell(
      moderatorMode: true,
      title: 'Profile',
      currentRoute: '/moderator/profile',
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          UnexaCard(
            borderRadius: AppRadius.sm,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                  backgroundImage:
                      user.photoUrl == null ? null : CachedNetworkImageProvider(user.photoUrl!),
                  child: user.photoUrl == null
                      ? Text(
                          user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : 'U',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w900,
                              ),
                        )
                      : null,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        style:
                            Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        user.email,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        children: [
                          UnexaStatusBadge.role(user.role),
                          UnexaStatusBadge.status(user.accountStatus),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _ProfileSection(
            title: 'Institute',
            rows: [
              _ProfileRow('Institute', college?.name ?? 'Assigned institute'),
              _ProfileRow('Timezone', college?.timezone ?? 'Configured by institute'),
            ],
          ),
          // CRs keep their class identity — same academic details as the
          // student profile. No extra permission cards; CR is a student
          // with one extra power (verification).
          if (hasAcademics) ...[
            const SizedBox(height: AppSpacing.md),
            _ProfileSection(
              title: 'Academic Details',
              rows: [
                _ProfileRow('Department', user.departmentName ?? 'Not selected'),
                _ProfileRow('Batch', user.batchName ?? 'Not selected'),
                _ProfileRow('Year', user.year?.toString() ?? 'Not selected'),
                _ProfileRow('Section', user.sectionName ?? 'Not selected'),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  final String title;
  final List<_ProfileRow> rows;

  const _ProfileSection({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return UnexaCard(
      borderRadius: AppRadius.sm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 112,
                    child: Text(
                      row.label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.value,
                      textAlign: TextAlign.right,
                      style:
                          Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileRow {
  final String label;
  final String value;

  const _ProfileRow(this.label, this.value);
}
