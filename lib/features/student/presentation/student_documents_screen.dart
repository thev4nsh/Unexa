import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/unexa_card.dart';
import '../../../core/widgets/unexa_empty_state.dart';
import '../../../core/widgets/unexa_loading_shimmer.dart';
import '../../../core/widgets/unexa_status_badge.dart';
import '../../../data/models/document_model.dart';
import '../providers/student_dashboard_provider.dart';
import 'widgets/student_shell.dart';

class StudentDocumentsScreen extends ConsumerWidget {
  const StudentDocumentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documentsAsync = ref.watch(officialDocumentsProvider);

    return StudentShell(
      title: 'Documents',
      currentRoute: '/student/documents',
      child: documentsAsync.when(
        data: (documents) {
          if (documents.isEmpty) return UnexaEmptyState.noDocuments();

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: documents.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final doc = documents[index];
              return UnexaCard(
                borderRadius: AppRadius.sm,
                onTap: () => _showDocumentSheet(context, doc),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: AppRadius.smRadius,
                      ),
                      child: Icon(
                        _iconFor(doc),
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doc.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Version ${doc.version}${doc.uploadedAt != null ? ' • Published ${doc.uploadedAt!.toLocal().toString().split(' ').first}' : ''}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    UnexaStatusBadge(
                      label: _labelFor(doc),
                      backgroundColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.12),
                      textColor: Theme.of(context).colorScheme.secondary,
                      icon: Icons.verified_rounded,
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => StudentPagePadding(child: UnexaLoadingShimmer.cardList()),
        error: (error, _) => Center(child: Text('Could not load documents: $error')),
      ),
    );
  }

  IconData _iconFor(DocumentModel doc) {
    if (doc.isTimetablePdf) return Icons.table_chart_rounded;
    if (doc.isHolidayPdf) return Icons.beach_access_rounded;
    return Icons.picture_as_pdf_rounded;
  }

  String _labelFor(DocumentModel doc) {
    if (doc.isTimetablePdf) return 'TIMETABLE';
    if (doc.isHolidayPdf) return 'HOLIDAY';
    return 'PDF';
  }

  void _showDocumentSheet(BuildContext context, DocumentModel doc) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  doc.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'This official document is tenant-scoped in Firebase Storage.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                SelectableText(
                  doc.downloadUrl.isEmpty ? 'Download URL is not available yet.' : doc.downloadUrl,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: doc.downloadUrl.isEmpty
                      ? null
                      : () async {
                          await Clipboard.setData(ClipboardData(text: doc.downloadUrl));
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Document link copied')),
                            );
                          }
                        },
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copy link'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
