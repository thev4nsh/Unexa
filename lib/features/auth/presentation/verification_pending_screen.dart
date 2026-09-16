import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/unexa_button.dart';
import '../../../core/widgets/unexa_card.dart';
import '../../auth/providers/auth_provider.dart';

/// The gate screen every non-active member sees: pending, rejected, banned,
/// suspended or disapproved. Live-streamed — the moment staff act, the exact
/// reason, the staff member's name and the timestamp appear here.
class VerificationPendingScreen extends ConsumerWidget {
  const VerificationPendingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserModelProvider);
    final requestAsync = ref.watch(ownVerificationRequestProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: userAsync.when(
              data: (user) {
                if (user == null) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.manage_search_rounded,
                          size: 48, color: theme.colorScheme.primary),
                      const SizedBox(height: 24),
                      Text(
                        'Account setup is incomplete',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Select your institute and sign in again to finish creating your access request.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      UnexaButton(
                        text: 'Sign Out',
                        variant: UnexaButtonVariant.outline,
                        onPressed: () =>
                            ref.read(authControllerProvider.notifier).signOut(),
                      ),
                    ],
                  );
                }

                IconData icon = Icons.hourglass_top_rounded;
                Color color = theme.colorScheme.primary;
                String title = 'Verification in progress';
                String message =
                    'Your institute account is authenticated. Your UNEXA access request is waiting for administrator approval.';
                String? reason;
                String? actedBy;
                DateTime? actedAt;

                final request = requestAsync.value;

                if (user.isBanned) {
                  icon = Icons.block_rounded;
                  color = theme.colorScheme.error;
                  title = 'Account Banned';
                  final ban = user.banDetails;
                  reason = ban?.reason;
                  actedBy = ban?.bannedByName;
                  actedAt = ban?.createdAt;
                  message = 'Your access has been restricted by your institute.';
                } else if (user.isRejected) {
                  icon = Icons.cancel_outlined;
                  color = theme.colorScheme.error;
                  title = 'Access Rejected';
                  reason = user.rejectionReason;
                  actedBy = request?.actionedByName;
                  actedAt = request?.actionDate;
                  message =
                      'Your access request was rejected by your institute.';
                } else if (user.isSuspended) {
                  icon = Icons.pause_circle_outline_rounded;
                  color = const Color(0xFFD97706);
                  title = 'Account Suspended';
                  reason = request?.actionReason;
                  actedBy = request?.actionedByName;
                  actedAt = request?.actionDate;
                  message =
                      'Your campus access is temporarily paused. Contact your institute administrator.';
                } else if (request?.actionReason != null &&
                    (request?.actionReason ?? '').startsWith('Disapproved')) {
                  // Disapproved: user doc is pending again but staff left an
                  // explanation — show it instead of the plain waiting text.
                  icon = Icons.undo_rounded;
                  color = const Color(0xFFD97706);
                  title = 'Approval withdrawn';
                  reason = request?.actionReason;
                  actedBy = request?.actionedByName;
                  actedAt = request?.actionDate;
                  message =
                      'Your previous approval was withdrawn. Your request is back in the queue for review.';
                }

                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          shape: BoxShape.circle),
                      child: Icon(icon, size: 48, color: color),
                    ),
                    const SizedBox(height: 24),
                    Text(title,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Text(message,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium),

                    // ---- Reason block: who, when, why ----
                    if (reason != null && reason.trim().isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      UnexaCard(
                        borderRadius: AppRadius.sm,
                        color: color.withValues(alpha: 0.06),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Reason',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: color,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                reason,
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              if ((actedBy?.isNotEmpty ?? false) ||
                                  actedAt != null)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(top: AppSpacing.xs),
                                  child: Text(
                                    _actionLine(actedBy, actedAt),
                                    style:
                                        theme.textTheme.bodySmall?.copyWith(
                                      color: theme
                                          .colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),
                    UnexaButton(
                      text: 'Check Status',
                      variant: UnexaButtonVariant.primary,
                      onPressed: () {
                        ref.invalidate(currentUserModelProvider);
                        ref.invalidate(userCollegeIdProvider);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Checking latest verification status...'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    UnexaButton(
                      text: 'Sign Out',
                      variant: UnexaButtonVariant.outline,
                      onPressed: () =>
                          ref.read(authControllerProvider.notifier).signOut(),
                    ),
                  ],
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (e, s) => Text('Error: $e'),
            ),
          ),
        ),
      ),
    );
  }

  String _actionLine(String? actedBy, DateTime? actedAt) {
    final who = (actedBy?.isNotEmpty ?? false) ? 'by $actedBy' : '';
    final when = actedAt != null
        ? '${actedAt.day}/${actedAt.month}/${actedAt.year} • '
            '${actedAt.hour.toString().padLeft(2, '0')}:${actedAt.minute.toString().padLeft(2, '0')}'
        : '';
    final parts = [who, when].where((p) => p.isNotEmpty).toList();
    return parts.isEmpty ? '' : parts.join(' • ');
  }
}
