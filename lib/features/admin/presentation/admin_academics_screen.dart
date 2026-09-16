import '../../../core/widgets/staff_back_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/unexa_card.dart';
import '../../../data/models/academic_models.dart';
import '../../../data/repositories/academic_repository.dart';
import '../../auth/providers/auth_provider.dart';

class AdminAcademicsScreen extends ConsumerWidget {
  const AdminAcademicsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserModelProvider).value;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return DefaultTabController(
      length: 4,
      child: Builder(
        builder: (context) => Scaffold(
          appBar: StaffBackAppBar(
            title: 'Academic Setup',
            bottom: const TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: 'Departments'),
                Tab(text: 'Batches'),
                Tab(text: 'Sections'),
                Tab(text: 'Subjects'),
              ],
            ),
          ),
          floatingActionButton: AnimatedBuilder(
            animation: DefaultTabController.of(context),
            builder: (context, _) {
              // Sections are read-only (managed inside batches) — no add button there.
              if (DefaultTabController.of(context).index == 2) {
                return const SizedBox.shrink();
              }
              return FloatingActionButton.extended(
                onPressed: () => _showAddDialog(context, ref, user.collegeId),
                icon: const Icon(Icons.add_rounded),
                // Bottom-right button always names what it adds on the current
                // tab ("Add Department", "Add Batch", …) and follows switches.
                label: Text(const [
                  'Add Department',
                  'Add Batch',
                  'Add Subject',
                ][_addDialogTabIndex(DefaultTabController.of(context).index)]),
              );
            },
          ),
          body: TabBarView(
            children: [
              _DepartmentList(collegeId: user.collegeId),
              _BatchList(collegeId: user.collegeId),
              _SectionList(collegeId: user.collegeId),
              _SubjectList(collegeId: user.collegeId),
            ],
          ),
        ),
      ),
    );
  }

  /// Tab 3 is Subjects in the TabBar but index 2 in the add dialog
  /// (tab 2 = Sections is read-only and never opens the dialog).
  static int _addDialogTabIndex(int tabIndex) => tabIndex == 3 ? 2 : tabIndex;

  void _showAddDialog(BuildContext context, WidgetRef ref, String collegeId) {
    final rootContext = context;
    // Tab indexes: 0 departments, 1 batches, 2 sections (read-only, never
    // reaches here), 3 subjects. Map to the add-dialog kind.
    final tabIndex = _addDialogTabIndex(DefaultTabController.of(context).index);
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    // Dropdowns are keyed by String IDs — model instances are re-created on
    // every Firestore snapshot, and object-keyed values crash the dropdown
    // with the "There should be exactly one item" assertion.
    String? selectedDepartmentId;
    bool isSaving = false;
    bool withSections = false;
    final sectionControllers = <TextEditingController>[];

    final labels = ['Department', 'Batch', 'Subject'];
    final label = labels[tabIndex];

    void disposeAddDialogControllers() {
      nameController.dispose();
      codeController.dispose();
      for (final controller in sectionControllers) {
        controller.dispose();
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Add $label'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(labelText: '$label name'),
                ),
                if (tabIndex == 0 || tabIndex == 2) ...[
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: codeController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Code'),
                  ),
                ],
                if (tabIndex != 0) ...[
                  const SizedBox(height: AppSpacing.sm),
                  StreamBuilder<List<DepartmentModel>>(
                    stream: ref.read(academicRepositoryProvider).streamDepartments(collegeId),
                    builder: (context, snapshot) {
                      final departments = snapshot.data ?? [];
                      return DropdownButtonFormField<String>(
                        initialValue: departments.any((d) => d.id == selectedDepartmentId) ? selectedDepartmentId : null,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Department'),
                        items: departments
                            .map((item) => DropdownMenuItem(
                                  value: item.id,
                                  child: Text(item.code.isEmpty ? item.name : '${item.code} · ${item.name}',
                                      overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: isSaving
                            ? null
                            : (value) => setDialogState(() => selectedDepartmentId = value),
                      );
                    },
                  ),
                ],
                // Multi-section creation: tick the box, then add A / B / C… inline.
                if (tabIndex == 1) ...[
                  const SizedBox(height: AppSpacing.xs),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: withSections,
                    title: const Text('Add multiple sections'),
                    subtitle: const Text('Creates Section A, B, C… under this batch'),
                    onChanged: isSaving
                        ? null
                        : (value) => setDialogState(() {
                              withSections = value ?? false;
                              if (withSections && sectionControllers.isEmpty) {
                                sectionControllers.add(TextEditingController());
                              }
                            }),
                  ),
                  if (withSections)
                    ...List.generate(sectionControllers.length, (i) {
                      return Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: sectionControllers[i],
                                textCapitalization: TextCapitalization.characters,
                                decoration: InputDecoration(
                                  labelText: 'Section ${i + 1}',
                                  hintText: 'e.g. ${String.fromCharCode(65 + i)}',
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Add another section',
                              icon: const Icon(Icons.add_circle_outline_rounded),
                              onPressed: isSaving
                                  ? null
                                  : () => setDialogState(
                                      () => sectionControllers.add(TextEditingController())),
                            ),
                            if (sectionControllers.length > 1)
                              IconButton(
                                tooltip: 'Remove',
                                icon: const Icon(Icons.remove_circle_outline_rounded),
                                onPressed: isSaving
                                    ? null
                                    : () => setDialogState(() {
                                          sectionControllers[i].dispose();
                                          sectionControllers.removeAt(i);
                                        }),
                              ),
                          ],
                        ),
                      );
                    }),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final name = nameController.text.trim();
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(rootContext).showSnackBar(
                          SnackBar(content: Text('$label name is required')),
                        );
                        return;
                      }
                      final sectionNames = sectionControllers
                          .map((c) => c.text.trim())
                          .where((text) => text.isNotEmpty)
                          .toList();
                      if (tabIndex == 1 && withSections && sectionNames.isEmpty) {
                        ScaffoldMessenger.of(rootContext).showSnackBar(
                          const SnackBar(
                              content: Text('Add at least one section name, or untick "Add multiple sections"')),
                        );
                        return;
                      }

                      setDialogState(() => isSaving = true);
                      try {
                        final repo = ref.read(academicRepositoryProvider);
                        if (tabIndex == 0) {
                          await repo.addDepartment(collegeId, name, codeController.text.trim());
                        } else if (tabIndex == 1) {
                          if (withSections) {
                            // One atomic write: batch + its sections together.
                            await repo.addBatchWithSections(
                              collegeId,
                              name,
                              departmentId: selectedDepartmentId,
                              sectionNames: sectionNames,
                            );
                          } else {
                            await repo.addBatch(
                              collegeId,
                              name,
                              departmentId: selectedDepartmentId,
                            );
                          }
                        } else {
                          await repo.addSubject(
                            collegeId,
                            name,
                            code: codeController.text.trim(),
                            departmentId: selectedDepartmentId,
                          );
                        }
                        if (context.mounted) Navigator.pop(context);
                        if (rootContext.mounted) {
                          ScaffoldMessenger.of(rootContext).showSnackBar(
                            SnackBar(content: Text('$label created')),
                          );
                        }
                      } catch (error) {
                        setDialogState(() => isSaving = false);
                        if (rootContext.mounted) {
                          ScaffoldMessenger.of(rootContext).showSnackBar(
                            SnackBar(
                              content: Text(_friendlyAdminError(error)),
                              backgroundColor: Theme.of(rootContext).colorScheme.error,
                            ),
                          );
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create'),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      // Dispose AFTER the dialog's exit transition has fully unmounted the
      // fields — disposing mid-transition trips a defunct-element assert.
      Future.delayed(const Duration(milliseconds: 500), disposeAddDialogControllers);
    });
  }
}

String _friendlyAdminError(Object error) {
  final message = error.toString();
  if (message.contains('permission-denied')) {
    return 'Permission denied. Make sure your institute user role is admin or co_admin and Firestore rules are deployed.';
  }
  if (message.contains('unavailable')) {
    return 'Network unavailable. Check your connection and try again.';
  }
  return 'Could not save. $message';
}

class _DepartmentList extends ConsumerWidget {
  final String collegeId;

  const _DepartmentList({required this.collegeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(academicRepositoryProvider);
    return StreamBuilder<List<DepartmentModel>>(
      stream: repo.streamDepartments(collegeId),
      builder: (context, snapshot) {
        final items = snapshot.data ?? [];
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (items.isEmpty) return const _EmptyAcademicSetup(label: 'departments');
        return _AdminList(
          children: items
              .map((item) => _InfoTile(
                    title: item.name,
                    subtitle: item.code.isEmpty ? item.id : '${item.code} • ${item.id}',
                    onEdit: () => _showEditSimpleDialog(context, ref, collegeId,
                        isSubject: false, existing: item),
                    onDelete: () => _confirmDelete(context, ref, collegeId, tabIndex: 0, id: item.id, name: item.name),
                  ))
              .toList(),
        );
      },
    );
  }
}

class _BatchList extends ConsumerWidget {
  final String collegeId;

  const _BatchList({required this.collegeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(academicRepositoryProvider);
    return StreamBuilder<List<DepartmentModel>>(
      // Parent map so every batch shows which department it belongs to.
      stream: repo.streamDepartments(collegeId),
      builder: (context, deptSnap) {
        final deptById = {for (final d in deptSnap.data ?? <DepartmentModel>[]) d.id: d};
        return StreamBuilder<List<BatchModel>>(
          stream: repo.streamBatches(collegeId),
          builder: (context, batchSnap) {
            return StreamBuilder<List<SectionModel>>(
              stream: repo.streamSections(collegeId),
              builder: (context, sectionSnap) {
                final batches = batchSnap.data ?? [];
                if (!batchSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (batches.isEmpty) return const _EmptyAcademicSetup(label: 'batches');

                // Group sections under their batch (used by the editor + delete).
                final sectionsByBatch = <String, List<SectionModel>>{};
                for (final section in sectionSnap.data ?? const <SectionModel>[]) {
                  final batchId = section.batchId;
                  if (batchId == null) continue;
                  sectionsByBatch.putIfAbsent(batchId, () => []).add(section);
                }

                return _AdminList(
                  children: batches.map((batch) {
                    final dept =
                        batch.departmentId == null ? null : deptById[batch.departmentId];
                    final parent = dept == null
                        ? 'No department'
                        : (dept.code.isNotEmpty ? '${dept.name} • ${dept.code}' : dept.name);

                    final sections = sectionsByBatch[batch.id] ?? const <SectionModel>[];

                    // Tile shows ONLY the batch name — sections live in the
                    // Sections tab and in this tile's edit dialog.
                    return _InfoTile(
                      title: batch.name,
                      subtitle: parent,
                      onEdit: () => _showEditBatchDialog(
                        context,
                        ref,
                        collegeId,
                        batch: batch,
                        department: dept,
                        sections: sections,
                      ),
                      onDelete: () => _confirmDelete(
                        context,
                        ref,
                        collegeId,
                        tabIndex: 1,
                        id: batch.id,
                        name: batch.name,
                        sectionIds: sections.map((s) => s.id).toList(),
                      ),
                    );
                  }).toList(),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _SectionList extends ConsumerWidget {
  final String collegeId;

  const _SectionList({required this.collegeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(academicRepositoryProvider);
    return StreamBuilder<List<BatchModel>>(
      // Parent maps so every entry shows batch AND department code.
      stream: repo.streamBatches(collegeId),
      builder: (context, batchSnap) {
        return StreamBuilder<List<DepartmentModel>>(
          stream: repo.streamDepartments(collegeId),
          builder: (context, deptSnap) {
            final deptById = {for (final d in deptSnap.data ?? <DepartmentModel>[]) d.id: d};
            return StreamBuilder<List<SectionModel>>(
              stream: repo.streamSections(collegeId),
              builder: (context, snapshot) {
                final sections = snapshot.data ?? [];
                if (!snapshot.hasData || !batchSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Group sections under their batch for display.
                final sectionsByBatch = <String, List<SectionModel>>{};
                for (final section in sections) {
                  final batchId = section.batchId;
                  if (batchId == null) continue;
                  sectionsByBatch.putIfAbsent(batchId, () => []).add(section);
                }

                // Rows: batches WITHOUT sections show alone ("3rd Year");
                // batches WITH sections show one row per section
                // ("3rd Year A", "3rd Year B").
                final rows = <(String, String)>[];
                for (final batch in batchSnap.data ?? const <BatchModel>[]) {
                  final dept = batch.departmentId == null ? null : deptById[batch.departmentId];
                  final parent = dept == null
                      ? ''
                      : (dept.code.isNotEmpty ? '${dept.name} • ${dept.code}' : dept.name);

                  final batchSections = sectionsByBatch[batch.id] ?? const <SectionModel>[];
                  if (batchSections.isEmpty) {
                    rows.add((batch.name, parent.isEmpty ? 'No department' : parent));
                  } else {
                    for (final section in batchSections) {
                      rows.add(('${batch.name} ${section.name}', parent));
                    }
                  }
                }

                if (rows.isEmpty) return const _EmptyAcademicSetup(label: 'batches');

                return Column(
                  children: [
                    // Read-only notice: sections are managed in Batches.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
                      child: Row(
                        children: [
                          Icon(Icons.lock_outline_rounded,
                              size: 16,
                              color: Theme.of(context).colorScheme.onSurfaceVariant),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              'Read-only — sections are managed inside Batches (Edit → Sections).',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _AdminList(
                        children: rows
                            .map((row) => _InfoTile(
                                  title: row.$1,
                                  subtitle: row.$2,
                                ))
                            .toList(),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _SubjectList extends ConsumerWidget {
  final String collegeId;

  const _SubjectList({required this.collegeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(academicRepositoryProvider);
    return StreamBuilder<List<DepartmentModel>>(
      // Parent map so every subject shows which department it belongs to.
      stream: repo.streamDepartments(collegeId),
      builder: (context, deptSnap) {
        final deptById = {for (final d in deptSnap.data ?? <DepartmentModel>[]) d.id: d};
        return StreamBuilder<List<SubjectModel>>(
          stream: repo.streamSubjects(collegeId),
          builder: (context, snapshot) {
            final items = snapshot.data ?? [];
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            if (items.isEmpty) return const _EmptyAcademicSetup(label: 'subjects');
            return _AdminList(
              children: items
                  .map((item) {
                    final dept = item.departmentId == null ? null : deptById[item.departmentId];
                    final parent = dept == null
                        ? (item.code ?? 'No department')
                        : (dept.code.isNotEmpty ? '${dept.name} • ${dept.code}' : dept.name);
                    return _InfoTile(
                      title: item.name,
                      subtitle: parent,
                      onEdit: () => _showEditSimpleDialog(context, ref, collegeId,
                          isSubject: true, existing: item),
                      onDelete: () => _confirmDelete(context, ref, collegeId, tabIndex: 2, id: item.id, name: item.name),
                    );
                  })
                  .toList(),
            );
          },
        );
      },
    );
  }
}

/// Edit dialog for Department and Subject (name + code + department link).
Future<void> _showEditSimpleDialog(
  BuildContext context,
  WidgetRef ref,
  String collegeId, {
  required bool isSubject,
  required dynamic existing,
}) async {
  final label = isSubject ? 'Subject' : 'Department';
  final nameController = TextEditingController(text: existing.name as String);
  final codeController = TextEditingController(
    text: existing.code == null ? '' : existing.code as String,
  );
  // String-ID keyed (never a model object — see add-dialog note above).
  String? selectedDepartmentId = isSubject ? existing.departmentId as String? : null;

  final saved = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text('Edit $label'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: '$label name'),
              ),
              if (!isSubject) ...[
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(labelText: 'Code'),
                ),
              ],
              if (isSubject) ...[
                const SizedBox(height: AppSpacing.sm),
                StreamBuilder<List<DepartmentModel>>(
                  stream: ref.read(academicRepositoryProvider).streamDepartments(collegeId),
                  builder: (context, snapshot) {
                    final departments = snapshot.data ?? [];
                    return DropdownButtonFormField<String>(
                      initialValue:
                          departments.any((d) => d.id == selectedDepartmentId) ? selectedDepartmentId : null,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Department'),
                      items: departments
                          .map((item) => DropdownMenuItem(
                                value: item.id,
                                child: Text(item.code.isEmpty ? item.name : '${item.code} · ${item.name}',
                                    overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (value) => setDialogState(() => selectedDepartmentId = value),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );

  // Dispose after the dialog's exit transition unmounts the fields.
  Future.delayed(const Duration(milliseconds: 500), () {
    nameController.dispose();
    codeController.dispose();
  });

  if (saved != true || !context.mounted) return;
  final name = nameController.text.trim();
  if (name.isEmpty) return;

  try {
    final repo = ref.read(academicRepositoryProvider);
    if (isSubject) {
      await repo.updateSubject(
        collegeId,
        existing.id as String,
        name,
        code: codeController.text,
        departmentId: selectedDepartmentId,
      );
    } else {
      await repo.updateDepartment(collegeId, existing.id as String, name, codeController.text);
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label updated')),
      );
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update: $error'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }
}

/// Edit dialog for a Batch: name, department, and its sections
/// (rename handled per-section implicitly via add/remove — sections live here).
Future<void> _showEditBatchDialog(
  BuildContext context,
  WidgetRef ref,
  String collegeId, {
  required BatchModel batch,
  required DepartmentModel? department,
  required List<SectionModel> sections,
}) async {
  final nameController = TextEditingController(text: batch.name);
  String? selectedDepartmentId = batch.departmentId;
  final removedSectionIds = <String>{};
  final newSectionControllers = <TextEditingController>[];
  bool isSaving = false;

  void disposeControllers() {
    nameController.dispose();
    for (final controller in newSectionControllers) {
      controller.dispose();
    }
  }

  final saved = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text('Edit ${batch.name}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Batch name'),
              ),
              const SizedBox(height: AppSpacing.sm),
              StreamBuilder<List<DepartmentModel>>(
                stream: ref.read(academicRepositoryProvider).streamDepartments(collegeId),
                builder: (context, snapshot) {
                  final departments = snapshot.data ?? [];
                  return DropdownButtonFormField<String>(
                    initialValue:
                        departments.any((d) => d.id == selectedDepartmentId) ? selectedDepartmentId : null,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Department'),
                    items: departments
                        .map((item) => DropdownMenuItem(
                              value: item.id,
                              child: Text(item.code.isEmpty ? item.name : '${item.code} · ${item.name}',
                                  overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (value) => setDialogState(() => selectedDepartmentId = value),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),
              Text('Sections', style: Theme.of(context).textTheme.labelLarge),
              if (sections.isEmpty && newSectionControllers.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Text('No sections — students join this batch without a section.'),
                ),
              ...sections.map((section) {
                final isRemoved = removedSectionIds.contains(section.id);
                return CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: isRemoved,
                  title: Text(
                    '${batch.name} ${section.name}',
                    style: isRemoved
                        ? const TextStyle(decoration: TextDecoration.lineThrough)
                        : null,
                  ),
                  subtitle: const Text('Tick to remove on Save'),
                  onChanged: (remove) => setDialogState(() {
                    if (remove ?? false) {
                      removedSectionIds.add(section.id);
                    } else {
                      removedSectionIds.remove(section.id);
                    }
                  }),
                );
              }),
              ...List.generate(newSectionControllers.length, (i) {
                return Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: newSectionControllers[i],
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            labelText: 'New section ${i + 1}',
                            hintText: 'e.g. ${String.fromCharCode(65 + i)}',
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Add another section',
                        icon: const Icon(Icons.add_circle_outline_rounded),
                        onPressed: () =>
                            setDialogState(() => newSectionControllers.add(TextEditingController())),
                      ),
                      if (newSectionControllers.length > 1)
                        IconButton(
                          tooltip: 'Remove',
                          icon: const Icon(Icons.remove_circle_outline_rounded),
                          onPressed: () => setDialogState(() {
                            newSectionControllers[i].dispose();
                            newSectionControllers.removeAt(i);
                          }),
                        ),
                    ],
                  ),
                );
              }),
              if (newSectionControllers.isEmpty)
                TextButton.icon(
                  onPressed: () =>
                      setDialogState(() => newSectionControllers.add(TextEditingController())),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add section'),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: isSaving ? null : () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: isSaving
                ? null
                : () async {
                    setDialogState(() => isSaving = true);
                    try {
                      final repo = ref.read(academicRepositoryProvider);
                      final newName = nameController.text.trim();
                      if (newName.isNotEmpty) {
                        await repo.updateBatch(
                          collegeId,
                          batch.id,
                          newName,
                          departmentId: selectedDepartmentId,
                        );
                      }
                      for (final sectionId in removedSectionIds) {
                        await repo.deleteSection(collegeId, sectionId);
                      }
                      for (final controller in newSectionControllers) {
                        final sectionName = controller.text.trim();
                        if (sectionName.isNotEmpty) {
                          await repo.addSection(collegeId, sectionName, batchId: batch.id);
                        }
                      }
                      if (context.mounted) Navigator.pop(context, true);
                    } catch (error) {
                      setDialogState(() => isSaving = false);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(_friendlyAdminError(error)),
                            backgroundColor: Theme.of(context).colorScheme.error,
                          ),
                        );
                      }
                    }
                  },
            child: isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
    ),
  );

  Future.delayed(const Duration(milliseconds: 500), disposeControllers);

  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${batch.name} updated')),
    );
  }
}

Future<void> _confirmDelete(
  BuildContext context,
  WidgetRef ref,
  String collegeId, {
  required int tabIndex,
  required String id,
  required String name,
  List<String> sectionIds = const [],
}) async {
  final labels = ['department', 'batch', 'subject'];
  final label = labels[tabIndex];

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Delete $label?'),
      content: Text(
          '"$name" will be permanently removed. Students referencing it may need re-onboarding.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    final repo = ref.read(academicRepositoryProvider);
    if (tabIndex == 0) {
      await repo.deleteDepartment(collegeId, id);
    } else if (tabIndex == 1) {
      // Sections live under the batch — remove them too (no orphans).
      for (final sectionId in sectionIds) {
        await repo.deleteSection(collegeId, sectionId);
      }
      await repo.deleteBatch(collegeId, id);
    } else {
      await repo.deleteSubject(collegeId, id);
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label deleted')),
      );
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not delete: $error'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }
}

class _AdminList extends StatelessWidget {
  final List<Widget> children;

  const _AdminList({required this.children});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: children.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) => children[index],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _InfoTile({
    required this.title,
    required this.subtitle,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return UnexaCard(
      borderRadius: AppRadius.sm,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        isThreeLine: subtitle.contains('\n'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onEdit != null)
              IconButton(
                tooltip: 'Edit',
                icon: const Icon(Icons.edit_outlined),
                onPressed: onEdit,
              ),
            if (onDelete != null)
              IconButton(
                tooltip: 'Delete',
                icon: Icon(Icons.delete_outline_rounded,
                    color: Theme.of(context).colorScheme.error),
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyAcademicSetup extends StatelessWidget {
  final String label;

  const _EmptyAcademicSetup({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_tree_outlined,
              size: 42,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No $label configured',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Use the add button to create tenant-specific academic data.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
