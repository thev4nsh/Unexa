import '../../../core/widgets/staff_back_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/screen_privacy_guard.dart';
import '../../../core/widgets/unexa_card.dart';
import '../../../core/widgets/unexa_empty_state.dart';
import '../../../data/models/audit_log_model.dart';
import '../../../data/repositories/audit_repository.dart';
import '../../auth/providers/auth_provider.dart';

/// Activity Logs — the admin portal's audit trail.
/// Shows exactly which staff member approved / rejected / banned / unbanned a
/// student, at what time, and the reason they entered. Also captures role
/// changes, document publishes, timetable/calendar edits, and branding updates.
class AuditLogScreen extends ConsumerStatefulWidget {
  const AuditLogScreen({super.key});

  @override
  ConsumerState<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends ConsumerState<AuditLogScreen> {
  String _filter = 'ALL';
  String _search = '';

  static const _filters = <String, String>{
    'ALL': 'All',
    'APPROVED': 'Approvals',
    'REJECTED': 'Rejections',
    'BANNED': 'Bans',
    'UNBANNED': 'Unbans',
    'ROLE_CHANGED': 'Role changes',
    'DOCUMENT': 'Documents',
    'TIMETABLE': 'Timetable',
    'CALENDAR': 'Calendar',
    'ANNOUNCEMENT': 'Announcements',
  };

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserModelProvider).value;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return SecureScreen(
      child: Scaffold(
      appBar: StaffBackAppBar(
        title: 'Activity Logs',
        bottom: PreferredSize(
          // Measured budget: search field 52 + gap 8 + filter chips 36 +
          // bottom padding 8 = 104. The old hard-coded 92 was shorter than
          // the real content, throwing a ~5px RenderFlex overflow.
          preferredSize: const Size.fromHeight(104),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
            child: Column(
              children: [
                SizedBox(
                  height: 52,
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Search name, email or reason',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _filters.entries.map((entry) {
                      final selected = _filter == entry.key;
                      return Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: FilterChip(
                          label: Text(entry.value),
                          selected: selected,
                          onSelected: (_) => setState(() => _filter = entry.key),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<AuditLogModel>>(
        stream: ref.watch(auditRepositoryProvider).streamAuditLogs(user.collegeId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Could not load logs: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final logs = (snapshot.data ?? []).where((log) {
            // Action-group filter
            if (_filter != 'ALL' && !log.action.contains(_filter)) return false;
            // Text search across actor, target and reason
            if (_search.isNotEmpty) {
              final haystack = [
                log.actorName,
                log.actorEmail,
                log.targetName ?? '',
                log.reason ?? '',
                log.action,
              ].join(' ').toLowerCase();
              if (!haystack.contains(_search)) return false;
            }
            return true;
          }).toList();

          if (logs.isEmpty) {
            return UnexaEmptyState(
              icon: Icons.receipt_long_rounded,
              title: snapshot.hasData ? 'Nothing to show' : 'Loading…',
              subtitle: snapshot.hasData
                  ? 'No activity matches this filter yet. Approvals, bans, role changes and document publishes will appear here.'
                  : 'Fetching the audit trail…',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: logs.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) => _LogTile(log: logs[index]),
          );
        },
      ),
    ));
  }
}

class _LogTile extends StatelessWidget {
  final AuditLogModel log;

  const _LogTile({required this.log});

  (IconData, Color) _visuals(BuildContext context) {
    if (log.action.contains('APPROVED')) {
      return (Icons.check_circle_rounded, const Color(0xFF10B981));
    }
    if (log.action.contains('BANNED')) {
      return (Icons.block_rounded, Theme.of(context).colorScheme.error);
    }
    if (log.action.contains('UNBANNED')) {
      return (Icons.lock_open_rounded, const Color(0xFF10B981));
    }
    if (log.action.contains('REJECTED')) {
      return (Icons.cancel_rounded, const Color(0xFFF59E0B));
    }
    if (log.action.contains('ROLE')) {
      return (Icons.manage_accounts_rounded, const Color(0xFF7C3AED));
    }
    if (log.action.contains('DOCUMENT')) {
      return (Icons.picture_as_pdf_rounded, const Color(0xFF0EA5E9));
    }
    if (log.action.contains('TIMETABLE')) {
      return (Icons.table_chart_rounded, const Color(0xFF2563EB));
    }
    if (log.action.contains('CALENDAR')) {
      return (Icons.event_note_rounded, const Color(0xFFD97706));
    }
    if (log.action.contains('ANNOUNCEMENT')) {
      return (Icons.campaign_rounded, const Color(0xFF8B5CF6));
    }
    return (Icons.history_rounded, Theme.of(context).colorScheme.onSurfaceVariant);
  }

  String _actionLabel() {
    // "MODERATOR_APPROVED_STUDENT" -> "Moderator approved student"
    final words = log.action.toLowerCase().split('_');
    if (words.isEmpty) return 'Activity';
    return words
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _visuals(context);
    final ts = log.timestamp.toLocal();
    final time =
        '${ts.day}/${ts.month}/${ts.year} • ${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';

    return UnexaCard(
      borderRadius: AppRadius.sm,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: AppRadius.smRadius,
                  ),
                  child: Icon(icon, size: 19, color: color),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _actionLabel(),
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        time,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: AppRadius.fullRadius,
                  ),
                  child: Text(
                    log.actorRole.toUpperCase(),
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'By '),
                  TextSpan(
                    text: log.actorName,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  if (log.targetName != null && log.targetName!.isNotEmpty) ...[
                    const TextSpan(text: '  →  '),
                    TextSpan(
                      text: log.targetName!,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ],
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (log.reason != null && log.reason!.trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Reason: ${log.reason}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
