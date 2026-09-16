import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/unexa_card.dart';
import '../../../core/widgets/unexa_pdf_viewer_screen.dart';
import '../../../data/repositories/document_repository.dart';
import '../../auth/providers/auth_provider.dart';

/// Routine / Holidays button that opens the official PDF uploaded via the
/// Admin/Co-Admin portal. Fetches the active document live from Firestore.
/// Shared by the student dashboard AND the moderator home.
class OfficialPdfButton extends ConsumerStatefulWidget {
  final IconData icon;
  final String label;
  final String type;

  const OfficialPdfButton({
    super.key,
    required this.icon,
    required this.label,
    required this.type,
  });

  @override
  ConsumerState<OfficialPdfButton> createState() => _OfficialPdfButtonState();
}

class _OfficialPdfButtonState extends ConsumerState<OfficialPdfButton> {
  bool _opening = false;

  Future<void> _open() async {
    final user = ref.read(currentUserModelProvider).value;
    if (user == null || _opening) return;

    setState(() => _opening = true);
    try {
      final doc =
          await ref.read(documentRepositoryProvider).getActiveDocument(user.collegeId, widget.type);

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
