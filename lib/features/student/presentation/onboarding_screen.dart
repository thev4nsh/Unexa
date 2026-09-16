import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/unexa_button.dart';
import '../../../core/widgets/unexa_empty_state.dart';
import '../../../core/widgets/unexa_error_view.dart';
import '../../../data/models/academic_models.dart';
import '../../../data/repositories/academic_repository.dart';
import '../../auth/providers/auth_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  DepartmentModel? _selectedDept;
  BatchModel? _selectedBatch;
  SectionModel? _selectedSection;
  bool _isSubmitting = false;

  /// True when the student continues with the synthetic "Common Batch"
  /// (used when the department has no batches configured yet).
  bool get _isCommonBatch => _selectedBatch != null && _selectedBatch!.id.isEmpty;

  bool _hasNoBatches(AsyncValue<List<BatchModel>>? asyncValue) {
    final data = asyncValue?.value;
    return data != null && data.isEmpty;
  }

  Future<void> _submit() async {
    final user = ref.read(currentUserModelProvider).value;
    if (user == null || _selectedDept == null || _selectedBatch == null) return;

    // Never submit a section the admin deleted while the student was picking.
    final liveSections = (_selectedBatch == null || _isCommonBatch)
        ? null
        : ref.read(sectionsProvider((user.collegeId, _selectedBatch!.id))).value;
    if (_selectedSection != null &&
        liveSections != null &&
        !liveSections.any((s) => s.id == _selectedSection!.id)) {
      _selectedSection = null;
    }

    // Section is MANDATORY when the batch defines sections — the student
    // cannot submit without choosing one (defense in depth; the Submit
    // button is already disabled for this case).
    final sectionRequired = liveSections != null && liveSections.isNotEmpty;
    if (sectionRequired && _selectedSection == null) return;

    setState(() => _isSubmitting = true);
    try {
      await ref.read(authControllerProvider.notifier).completeOnboarding(
            collegeId: user.collegeId,
            uid: user.uid,
            departmentId: _selectedDept!.id,
            departmentName: _selectedDept!.name,
            batchId: _selectedBatch!.id,
            batchName: _selectedBatch!.name,
            sectionId: _selectedSection?.id,
            sectionName: _selectedSection?.name,
          );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need to sign in again with Google.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(authControllerProvider.notifier).signOut();
            },
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserModelProvider).value;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final collegeId = user.collegeId;
    final deptsAsync = ref.watch(departmentsProvider(collegeId));
    final batchesAsync = _selectedDept == null
        ? null
        : ref.watch(batchesProvider((collegeId, _selectedDept!.id)));
    final sectionsAsync = (_selectedBatch == null || _isCommonBatch)
        ? null
        : ref.watch(sectionsProvider((collegeId, _selectedBatch!.id)));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Profile'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: _confirmLogout,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Select your academic details',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'This helps us show your exact timetable and announcements.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 24),

              // ---- Department ----
              _AcademicPicker<DepartmentModel>(
                label: 'Department',
                asyncValue: deptsAsync,
                value: _selectedDept,
                emptyState: UnexaEmptyState(
                  icon: Icons.account_tree_outlined,
                  title: 'Nothing to show yet',
                  subtitle:
                      'Your institute has not added any departments in UNEXA yet. Ask your administrator to add departments, then come back.',
                ),
                itemLabel: (item) => item.name,
                onChanged: (d) => setState(() {
                  _selectedDept = d;
                  _selectedBatch = null;
                  _selectedSection = null;
                }),
              ),
              const SizedBox(height: 16),

              // ---- Batch (depends on department) ----
              if (_selectedDept != null && !_isCommonBatch)
                _AcademicPicker<BatchModel>(
                  label: 'Batch',
                  asyncValue: batchesAsync ?? const AsyncValue.loading(),
                  value: _selectedBatch,
                  emptyState: UnexaEmptyState(
                    icon: Icons.groups_2_outlined,
                    title: 'Nothing to show in batches',
                    subtitle:
                        'No batches exist for ${_selectedDept!.name} yet. An administrator must create them first.',
                  ),
                  itemLabel: (item) => item.name,
                  onChanged: (b) => setState(() {
                    _selectedBatch = b;
                    _selectedSection = null;
                  }),
                ),

              // Department has no batches -> offer the shared "Common Batch"
              // so students are never blocked from onboarding.
              if (_selectedDept != null &&
                  !_isCommonBatch &&
                  _hasNoBatches(batchesAsync))
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Card(
                    child: ListTile(
                      leading: Icon(Icons.public_rounded,
                          color: Theme.of(context).colorScheme.primary),
                      title: const Text('Common Batch',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: const Text(
                          'No batches configured yet — continue with the institute-wide common batch.'),
                      trailing: const Icon(Icons.arrow_forward_rounded),
                      onTap: () => setState(() {
                        _selectedBatch = BatchModel(
                          id: '',
                          collegeId: collegeId,
                          name: 'Common Batch',
                        );
                        _selectedSection = null;
                      }),
                    ),
                  ),
                ),

              // Selected common batch shown as a removable chip.
              if (_isCommonBatch)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: InputChip(
                    avatar: Icon(Icons.check_circle_rounded,
                        color: Theme.of(context).colorScheme.primary),
                    label: const Text('Common Batch'),
                    onDeleted: () => setState(() => _selectedBatch = null),
                  ),
                ),
              const SizedBox(height: 16),

              // ---- Section ----
              // Shown only when the admin created sections for this batch.
              // When shown, selection is MANDATORY (Submit stays disabled
              // until one is picked). Batches without sections skip this
              // entirely — the student enters directly.
              if (_selectedBatch != null &&
                  !_isCommonBatch &&
                  (sectionsAsync?.value?.isNotEmpty ?? false))
                _AcademicPicker<SectionModel>(
                  label: 'Section',
                  asyncValue: sectionsAsync ?? const AsyncValue.loading(),
                  value: _selectedSection,
                  emptyState: UnexaEmptyState(
                    icon: Icons.view_agenda_outlined,
                    title: 'No sections configured',
                    subtitle:
                        'This batch has no sections. You can continue without selecting one.',
                  ),
                  itemLabel: (item) => item.name,
                  onChanged: (s) => setState(() => _selectedSection = s),
                ),
              const SizedBox(height: 32),
              UnexaButton(
                text: 'Submit',
                isLoading: _isSubmitting,
                onPressed:
                    (_selectedDept == null ||
                            _selectedBatch == null ||
                            _isSubmitting ||
                            // Mandatory section: batch has sections and none
                            // is chosen yet.
                            (_selectedBatch != null &&
                                !_isCommonBatch &&
                                (sectionsAsync?.value?.isNotEmpty ?? false) &&
                                _selectedSection == null))
                        ? null
                        : _submit,
              ),
              // Hint explaining WHY Submit is disabled.
              if (_selectedBatch != null &&
                  !_isCommonBatch &&
                  (sectionsAsync?.value?.isNotEmpty ?? false) &&
                  _selectedSection == null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    'Select your section to continue.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reusable academic dropdown: no buffering spinners when a list is empty,
/// instant "nothing to show" empty states, cached while offline.
class _AcademicPicker<T> extends StatelessWidget {
  final String label;
  final AsyncValue<List<T>> asyncValue;
  final T? value;
  final UnexaEmptyState emptyState;
  final String Function(T) itemLabel;
  final ValueChanged<T?> onChanged;

  const _AcademicPicker({
    required this.label,
    required this.asyncValue,
    required this.value,
    required this.emptyState,
    required this.itemLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return asyncValue.when(
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          const LinearProgressIndicator(minHeight: 2),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
      error: (e, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          UnexaErrorView(
            title: 'Could not load $label',
            message: 'Check your connection and try again.',
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
      data: (items) {
        if (items.isEmpty) return emptyState;
        return DropdownButtonFormField<T>(
          decoration: InputDecoration(labelText: label),
          initialValue: value,
          isExpanded: true,
          items: [
            ...items.map((item) => DropdownMenuItem<T>(
                  value: item,
                  child: Text(itemLabel(item)),
                )),
          ],
          onChanged: onChanged,
        );
      },
    );
  }
}
