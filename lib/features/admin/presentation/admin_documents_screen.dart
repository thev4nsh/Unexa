import '../../../core/widgets/staff_back_app_bar.dart';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/unexa_card.dart';
import '../../../data/models/document_model.dart';
import '../../../data/repositories/document_repository.dart';
import '../../auth/providers/auth_provider.dart';

/// Admin / Co-Admin portal screen to upload & manage the official PDFs
/// (Routine timetable PDF and Holiday list PDF) that students open from
/// the Routine / Holidays buttons on their dashboard.
class AdminDocumentsScreen extends ConsumerWidget {
  const AdminDocumentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserModelProvider).value;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: const StaffBackAppBar(title: 'Official Documents'),
      body: StreamBuilder<List<DocumentModel>>(
        stream: ref.watch(documentRepositoryProvider).streamDocuments(user.collegeId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Could not load documents: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final documents = snapshot.data ?? [];
          final routine = documents
              .where((d) => d.type == AppConstants.docTypeTimetablePdf && d.isActive)
              .toList();
          final holiday = documents
              .where((d) => d.type == AppConstants.docTypeHolidayPdf && d.isActive)
              .toList();

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              _OfficialUploadCard(
                title: 'Routine PDF',
                subtitle: 'The class-routine timetable students open from the Routine button.',
                icon: Icons.table_chart_rounded,
                activeDoc: routine.isEmpty ? null : routine.first,
                onPickFile: () => _pickAndPublish(
                  context,
                  ref,
                  user.collegeId,
                  user,
                  AppConstants.docTypeTimetablePdf,
                  'Official Routine',
                ),
                onUnpublish: routine.isEmpty
                    ? null
                    : () => _unpublish(context, ref, user.collegeId, routine.first),
              ),
              const SizedBox(height: AppSpacing.md),
              _OfficialUploadCard(
                title: 'Holiday PDF',
                subtitle: 'The official holiday list students open from the Holidays button.',
                icon: Icons.beach_access_rounded,
                activeDoc: holiday.isEmpty ? null : holiday.first,
                onPickFile: () => _pickAndPublish(
                  context,
                  ref,
                  user.collegeId,
                  user,
                  AppConstants.docTypeHolidayPdf,
                  'Official Holiday List',
                ),
                onUnpublish: holiday.isEmpty
                    ? null
                    : () => _unpublish(context, ref, user.collegeId, holiday.first),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _pickAndPublish(
    BuildContext context,
    WidgetRef ref,
    String collegeId,
    dynamic actor,
    String type,
    String title,
  ) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: false,
      );

      final path = result?.files.single.path;
      if (path == null) return; // user cancelled

      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Publish document?'),
          content: Text(
              '"${result!.files.single.name}" will be published to all students of your institute. Any previous version is replaced.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Publish'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      await ref.read(documentRepositoryProvider).publishOfficialDocument(
            collegeId: collegeId,
            type: type,
            title: title,
            file: File(path),
            actor: actor,
          );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$title published to all students')),
        );
      }
    } on FormatException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_friendlyError(error)),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _unpublish(
    BuildContext context,
    WidgetRef ref,
    String collegeId,
    DocumentModel doc,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unpublish document?'),
        content: Text(
            '"${doc.title}" (v${doc.version}) will no longer be visible to students. The stored file remains in Firebase Storage.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unpublish'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(documentRepositoryProvider).deleteDocument(collegeId, doc.id, doc.storagePath);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document unpublished')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_friendlyError(error)),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  String _friendlyError(Object error) {
    final message = error.toString();
    if (message.contains('object-not-found')) {
      return 'Storage bucket not found. Open Firebase Console → Storage → "Get started" to create it (one time), then retry. No code change needed.';
    }
    if (message.contains('permission-denied') || message.contains('unauthorized')) {
      return 'Permission denied. Deploy the latest Storage rules (signed-in read/write for documents) and check your role.';
    }
    if (message.contains('unavailable')) {
      return 'Network unavailable. Check your connection and try again.';
    }
    if (message.contains('canceled')) {
      return 'Upload canceled.';
    }
    if (message.contains('quota-exceeded') || message.contains('bucket')) {
      return 'Storage problem (quota or bucket). Check Firebase Console → Storage usage.';
    }
    return 'Could not complete the upload. $message';
  }
}

/// Card showing the currently active version of an official PDF with
/// upload/replace and unpublish actions.
class _OfficialUploadCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final DocumentModel? activeDoc;
  final VoidCallback onPickFile;
  final VoidCallback? onUnpublish;

  const _OfficialUploadCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.activeDoc,
    required this.onPickFile,
    this.onUnpublish,
  });

  @override
  Widget build(BuildContext context) {
    final doc = activeDoc;

    return UnexaCard(
      borderRadius: AppRadius.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: AppRadius.mdRadius,
                ),
                child: Icon(icon, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
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
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.sm + 2),
            decoration: BoxDecoration(
              color: doc != null
                  ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.08)
                  : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.06),
              borderRadius: AppRadius.mdRadius,
            ),
            child: doc == null
                ? Text(
                    'Nothing published yet — students will see "No PDF published yet".',
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                : Row(
                    children: [
                      const Icon(Icons.verified_rounded,
                          size: 18, color: Color(0xFF10B981)),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Version ${doc.version} • published '
                          '${doc.uploadedAt != null ? '${doc.uploadedAt!.day}/${doc.uploadedAt!.month}/${doc.uploadedAt!.year}' : ''}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onPickFile,
                  icon: Icon(doc == null ? Icons.upload_rounded : Icons.swap_horiz_rounded),
                  label: Text(doc == null ? 'Upload PDF' : 'Replace'),
                ),
              ),
              if (doc != null) ...[
                const SizedBox(width: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: onUnpublish,
                  icon: const Icon(Icons.visibility_off_outlined),
                  label: const Text('Unpublish'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
