import '../../../core/widgets/staff_back_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/unexa_card.dart';
import '../../../core/widgets/unexa_empty_state.dart';
import '../../../core/widgets/unexa_status_badge.dart';
import '../../../data/models/academic_models.dart';
import '../../../data/models/timetable_model.dart';
import '../../../data/repositories/academic_repository.dart';
import '../../../data/repositories/timetable_repository.dart';
import '../../auth/providers/auth_provider.dart';

class AdminTimetableScreen extends ConsumerStatefulWidget {
  const AdminTimetableScreen({super.key});

  @override
  ConsumerState<AdminTimetableScreen> createState() => _AdminTimetableScreenState();
}

class _AdminTimetableScreenState extends ConsumerState<AdminTimetableScreen> {
  // Browse filters: department -> batch -> optional section -> day.
  // With no department picked, ALL entries (every department/batch/day) show.
  String? _browseDepartmentId;
  String? _browseDepartmentName;
  String? _browseBatchId;
  String? _browseBatchName;
  String? _browseSectionId;
  String? _browseSectionName;
  String _browseDay = DateFormatter.currentDayName();

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserModelProvider).value;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: const StaffBackAppBar(title: 'Manage Timetable'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context, ref, user.collegeId, user.uid),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Class'),
      ),
      body: Column(
        children: [
          _buildBrowseFilters(user.collegeId),
          Expanded(
            child: StreamBuilder<List<TimetableEntryModel>>(
              // Department picked -> scoped stream (batch/section optional).
              // Nothing picked -> every entry across the institute.
              stream: _browseDepartmentId != null
                  ? ref.watch(timetableRepositoryProvider).streamScopedTimetable(
                      collegeId: user.collegeId,
                      day: _browseDay,
                      departmentId: _browseDepartmentId,
                      batchId: (_browseBatchId?.isNotEmpty ?? false) ? _browseBatchId : null,
                      sectionId: (_browseSectionId?.isNotEmpty ?? false) ? _browseSectionId : null,
                    )
                  : ref.watch(timetableRepositoryProvider).streamAllTimetable(collegeId: user.collegeId),
              builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Could not load timetable: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snapshot.data!;
          if (entries.isEmpty) {
            final scoped = _browseDepartmentId != null;
            if (scoped) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    'No classes for ${_browseBatchName ?? _browseDepartmentName ?? 'this department'}'
                    '${(_browseSectionName?.isNotEmpty ?? false) ? ' • Section $_browseSectionName' : ''}'
                    ' on $_browseDay',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              );
            }
            return UnexaEmptyState.noClasses();
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: entries.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final entry = entries[index];
              return UnexaCard(
                borderRadius: AppRadius.sm,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entry.subjectName, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: AppSpacing.xs),
                          Text('${entry.day} • ${DateFormatter.formatTimeRange(entry.startTime, entry.endTime)}'),
                          // Audience line — always shows exactly who this
                          // class reaches (answers "which batch is this?").
                          if (entry.batchId.isEmpty ||
                              (entry.batchName?.isNotEmpty ?? false) ||
                              (entry.sectionName?.isNotEmpty ?? false))
                            Text(
                              [
                                if (entry.batchId.isEmpty)
                                  'Common Batch'
                                else if (entry.batchName?.isNotEmpty ?? false)
                                  entry.batchName!,
                                if (entry.sectionName?.isNotEmpty ?? false)
                                  'Section ${entry.sectionName!}',
                              ].join(' • '),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          Text('${entry.room}${entry.faculty != null ? ' • ${entry.faculty}' : ''}'),
                        ],
                      ),
                    ),
                    UnexaStatusBadge.timetableType(entry.type),
                    IconButton(
                      tooltip: 'Delete',
                      onPressed: () async {
                        try {
                          await ref.read(timetableRepositoryProvider).deleteEntry(user.collegeId, entry.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Timetable entry deleted')),
                            );
                          }
                        } catch (error) {
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
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
              );
            },
          );
        },
            ),
          ),
        ],
      ),
    );
  }

  /// Browse panel: staff pick department -> batch -> optional section -> day
  /// to inspect a specific group's schedule without ever seeing an ID.
  Widget _buildBrowseFilters(String collegeId) {
    final academicRepo = ref.watch(academicRepositoryProvider);
    final scoped = _browseDepartmentId != null && (_browseBatchId?.isNotEmpty ?? false);

    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04),
        borderRadius: AppRadius.smRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.filter_alt_rounded,
                  size: 16, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: AppSpacing.xs),
              Text('Browse schedule',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const Spacer(),
              if (_browseDepartmentId != null)
                IconButton(
                  tooltip: 'Clear filters — show all entries',
                  iconSize: 18,
                  onPressed: () => setState(() {
                    _browseDepartmentId = null;
                    _browseDepartmentName = null;
                    _browseBatchId = null;
                    _browseBatchName = null;
                    _browseSectionId = null;
                    _browseSectionName = null;
                  }),
                  icon: const Icon(Icons.filter_alt_off_rounded),
                ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: StreamBuilder<List<DepartmentModel>>(
                  stream: academicRepo.streamDepartments(collegeId),
                  builder: (context, snapshot) {
                    final departments = snapshot.data ?? const [];
                    return DropdownButtonFormField<String>(
                      initialValue: departments.any((d) => d.id == _browseDepartmentId)
                          ? _browseDepartmentId
                          : null,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Department', isDense: true),
                      items: departments
                          .map((d) => DropdownMenuItem(
                                value: d.id,
                                child: Text(
                                    d.code.isEmpty ? d.name : '${d.name} (${d.code})',
                                    overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (value) => setState(() {
                        _browseDepartmentId = value;
                        _browseDepartmentName = null;
                        for (final d in departments) {
                          if (d.id == value) _browseDepartmentName = d.name;
                        }
                        _browseBatchId = null;
                        _browseBatchName = null;
                        _browseSectionId = null;
                        _browseSectionName = null;
                      }),
                    );
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _browseDay,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Day', isDense: true),
                  items: const [
                    DropdownMenuItem(value: 'Monday', child: Text('Monday')),
                    DropdownMenuItem(value: 'Tuesday', child: Text('Tuesday')),
                    DropdownMenuItem(value: 'Wednesday', child: Text('Wednesday')),
                    DropdownMenuItem(value: 'Thursday', child: Text('Thursday')),
                    DropdownMenuItem(value: 'Friday', child: Text('Friday')),
                    DropdownMenuItem(value: 'Saturday', child: Text('Saturday')),
                    DropdownMenuItem(value: 'Sunday', child: Text('Sunday')),
                  ],
                  onChanged: (value) => setState(() => _browseDay = value ?? _browseDay),
                ),
              ),
            ],
          ),
          if (_browseDepartmentId != null) ...[
            const SizedBox(height: AppSpacing.xs),
            StreamBuilder<List<BatchModel>>(
              stream: academicRepo.streamBatches(collegeId, departmentId: _browseDepartmentId),
              builder: (context, snapshot) {
                final batches = snapshot.data ?? const [];
                return DropdownButtonFormField<String>(
                  initialValue: batches.any((b) => b.id == _browseBatchId) ? _browseBatchId : null,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Batch', isDense: true),
                  items: batches
                      .map((b) => DropdownMenuItem(
                            value: b.id,
                            child: Text(b.name, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() {
                    _browseBatchId = value;
                    _browseBatchName = null;
                    for (final b in batches) {
                      if (b.id == value) _browseBatchName = b.name;
                    }
                    _browseSectionId = null;
                    _browseSectionName = null;
                  }),
                );
              },
            ),
          ],
          if (scoped) ...[
            const SizedBox(height: AppSpacing.xs),
            StreamBuilder<List<SectionModel>>(
              stream: academicRepo.streamSections(collegeId, batchId: _browseBatchId),
              builder: (context, snapshot) {
                final sections = snapshot.data ?? const [];
                if (sections.isEmpty) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'This batch has no sections — showing the whole batch',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontStyle: FontStyle.italic),
                    ),
                  );
                }
                return DropdownButtonFormField<String>(
                  initialValue: sections.any((s) => s.id == _browseSectionId) ? _browseSectionId : null,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Section', isDense: true),
                  items: [
                    const DropdownMenuItem<String>(value: null, child: Text('Whole batch')),
                    ...sections.map((s) => DropdownMenuItem(
                          value: s.id,
                          child: Text(s.name, overflow: TextOverflow.ellipsis),
                        )),
                  ],
                  onChanged: (value) => setState(() {
                    _browseSectionId = value;
                    _browseSectionName = null;
                    for (final s in sections) {
                      if (s.id == value) _browseSectionName = s.name;
                    }
                  }),
                );
              },
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Text(
            scoped
                ? 'Showing: ${_browseDepartmentName ?? ''} • ${(_browseBatchName?.isNotEmpty ?? false) ? _browseBatchName! : 'all batches'}'
                    '${(_browseSectionName?.isNotEmpty ?? false) ? ' • Section $_browseSectionName' : ''}'
                    ' • $_browseDay'
                : 'Showing: all departments • all batches • all days',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref, String collegeId, String actorUid) {
    final rootContext = context;
    final roomController = TextEditingController();
    final facultyController = TextEditingController();
    final startController = TextEditingController(text: '09:00 AM');
    final endController = TextEditingController(text: '10:00 AM');
    // Everything structural is a String-ID dropdown — model-object keys crash
    // dropdowns when Firestore re-emits new instances (see academic dialogs).
    String? selectedDepartmentId;
    String? selectedBatchId;
    String? selectedSubjectId;
    String? selectedSectionId;
    // Faculty is picked from the searchable roster; empty roster +
    // typed text = manual entry (roster can stay optional).
    String? selectedFacultyName;
    String day = DateFormatter.currentDayName();
    String type = AppConstants.timetableTypeClass;
    bool isSaving = false;

    void disposeControllers() {
      roomController.dispose();
      facultyController.dispose();
      startController.dispose();
      endController.dispose();
    }

    /// Searchable faculty selection: type to filter the roster live, tap a
    /// result to select. Returns the picked (id, name), or null when the
    /// sheet is dismissed — the field still accepts free typing for manual
    /// entry, so the roster is a convenience, not a gate.
    Future<(String, String)?> pickFaculty() async {
      final faculties = await ref
          .read(academicRepositoryProvider)
          .streamFaculties(collegeId)
          .first;
      if (!rootContext.mounted) return null;

      String query = '';
      String? pickedId;
      String? pickedName;

      await showModalBottomSheet<void>(
        context: rootContext,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (sheetContext) => StatefulBuilder(
          builder: (context, setSheetState) => Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              top: AppSpacing.lg,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom +
                  AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Search faculty',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                        onChanged: (v) =>
                            setSheetState(() => query = v.trim().toLowerCase()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: () {
                    final results = faculties.where((f) {
                      if (query.isEmpty) return true;
                      return f.name.toLowerCase().contains(query) ||
                          (f.departmentName ?? '')
                              .toLowerCase()
                              .contains(query);
                    }).toList()
                      ..sort((a, b) => a.name
                          .toLowerCase()
                          .compareTo(b.name.toLowerCase()));

                    if (results.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Text(
                          query.isEmpty
                              ? 'No faculties added yet — add them in the Faculties dashboard, or type a name below.'
                              : 'No faculty matches "$query" — you can still type the name manually below.',
                          style: Theme.of(sheetContext).textTheme.bodySmall,
                        ),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final f = results[index];
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(f.name.isNotEmpty
                                ? f.name[0].toUpperCase()
                                : '?'),
                          ),
                          title: Text(f.name),
                          subtitle: (f.departmentName?.isNotEmpty ?? false)
                              ? Text(f.departmentName!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis)
                              : null,
                          trailing: pickedId == f.id
                              ? const Icon(Icons.check_circle_rounded)
                              : null,
                          onTap: () {
                            pickedId = f.id;
                            pickedName = f.name;
                            Navigator.pop(sheetContext);
                          },
                        );
                      },
                    );
                  }(),
                ),
              ],
            ),
          ),
        ),
      );

      if (pickedId == null || pickedName == null) return null;
      return (pickedId!, pickedName!);
    }

    Future<void> pickTime(TextEditingController controller) async {
      final parsed = DateFormatter.parseMinutesFromMidnight(controller.text) ?? 540;
      final initial = TimeOfDay(hour: parsed ~/ 60, minute: parsed % 60);
      final picked = await showTimePicker(context: rootContext, initialTime: initial);
      if (picked != null) {
        final hour12 = picked.hourOfPeriod == 0 ? 12 : picked.hourOfPeriod;
        final amPm = picked.period == DayPeriod.am ? 'AM' : 'PM';
        final minuteStr = picked.minute.toString().padLeft(2, '0');
        controller.text = '$hour12:$minuteStr $amPm';
      }
    }

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Timetable Entry'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ---- Department ----
                StreamBuilder<List<DepartmentModel>>(
                  stream: ref.read(academicRepositoryProvider).streamDepartments(collegeId),
                  builder: (context, snapshot) {
                    final departments = snapshot.data ?? [];
                    if (snapshot.hasData && departments.isEmpty) {
                      return const Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
                          child: Text(
                            'Your institute has no departments yet — add one in Academic Setup first',
                            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                          ),
                        ),
                      );
                    }
                    return DropdownButtonFormField<String>(
                      initialValue:
                          departments.any((d) => d.id == selectedDepartmentId) ? selectedDepartmentId : null,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Department'),
                      items: departments
                          .map((item) => DropdownMenuItem(
                                value: item.id,
                                child: Text(item.code.isEmpty ? item.name : '${item.name} (${item.code})',
                                    overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (value) => setDialogState(() {
                        selectedDepartmentId = value;
                        // Dependent picks reset when the parent changes.
                        selectedSubjectId = null;
                        selectedBatchId = null;
                        selectedSectionId = null;
                      }),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.sm),

                // ---- Batch (filtered by department) ----
                if (selectedDepartmentId != null)
                  StreamBuilder<List<BatchModel>>(
                    stream: ref
                        .read(academicRepositoryProvider)
                        .streamBatches(collegeId, departmentId: selectedDepartmentId),
                    builder: (context, snapshot) {
                      final batches = snapshot.data ?? [];
                      if (snapshot.hasData && batches.isEmpty) {
                        return const Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
                            child: Text(
                              'No batches in this department yet — add one in Academic Setup first',
                              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                            ),
                          ),
                        );
                      }
                      return DropdownButtonFormField<String>(
                        initialValue: batches.any((b) => b.id == selectedBatchId) ? selectedBatchId : null,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Batch'),
                        items: batches
                            .map((item) => DropdownMenuItem(
                                value: item.id,
                                child: Text(item.name, overflow: TextOverflow.ellipsis)))
                            .toList(),
                        onChanged: (value) => setDialogState(() {
                          selectedBatchId = value;
                          selectedSectionId = null;
                        }),
                      );
                    },
                  ),
                if (selectedDepartmentId != null) const SizedBox(height: AppSpacing.sm),

                // ---- Section: shown ONLY when the batch actually has sections ----
                if (selectedBatchId != null)
                  StreamBuilder<List<SectionModel>>(
                    stream: ref
                        .read(academicRepositoryProvider)
                        .streamSections(collegeId, batchId: selectedBatchId),
                    builder: (context, snapshot) {
                      final sections = snapshot.data ?? [];
                      if (sections.isEmpty) {
                        // Whole-batch class — every section of the batch sees it.
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'No sections in this batch — class applies to the whole batch',
                              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                            ),
                          ),
                        );
                      }
                      return DropdownButtonFormField<String>(
                        initialValue:
                            sections.any((s) => s.id == selectedSectionId) ? selectedSectionId : null,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Section (optional)'),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('Whole batch'),
                          ),
                          ...sections.map(
                            (item) => DropdownMenuItem(
                                value: item.id,
                                child: Text(item.name, overflow: TextOverflow.ellipsis)),
                          ),
                        ],
                        onChanged: (value) => setDialogState(() => selectedSectionId = value),
                      );
                    },
                  ),
                if (selectedBatchId != null) const SizedBox(height: AppSpacing.sm),

                // ---- Subject (only subjects of the chosen department) ----
                if (selectedDepartmentId != null)
                  StreamBuilder<List<SubjectModel>>(
                    stream: ref
                        .read(academicRepositoryProvider)
                        .streamSubjects(collegeId, departmentId: selectedDepartmentId),
                    builder: (context, snapshot) {
                      final subjects = snapshot.data ?? [];
                      if (subjects.isEmpty) {
                        return const Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
                            child: Text(
                              'No subjects added for this department yet — add them in Academic Setup',
                              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                            ),
                          ),
                        );
                      }
                      return DropdownButtonFormField<String>(
                        initialValue:
                            subjects.any((s) => s.id == selectedSubjectId) ? selectedSubjectId : null,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Subject'),
                        items: subjects
                            .map((item) => DropdownMenuItem(
                                  value: item.id,
                                  child: Text(item.code == null || item.code!.isEmpty
                                      ? item.name
                                      : '${item.name} (${item.code})',
                                    overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (value) => setDialogState(() => selectedSubjectId = value),
                      );
                    },
                  ),
                if (selectedDepartmentId != null) const SizedBox(height: AppSpacing.sm),

                TextField(controller: roomController, decoration: const InputDecoration(labelText: 'Room or lab')),
                // Faculty: search icon opens the roster picker; the field
                // also accepts free typing when the roster has no match.
                TextField(
                  controller: facultyController,
                  decoration: InputDecoration(
                    labelText: 'Faculty (optional)',
                    suffixIcon: IconButton(
                      tooltip: 'Search faculty list',
                      icon: const Icon(Icons.manage_search_rounded),
                      onPressed: () async {
                        final picked = await pickFaculty();
                        if (picked != null) {
                          setDialogState(() {
                            selectedFacultyName = picked.$2;
                            facultyController.text = picked.$2;
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<String>(
                  initialValue: day,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Day'),
                  items: const [
                    DropdownMenuItem(value: 'Monday', child: Text('Monday')),
                    DropdownMenuItem(value: 'Tuesday', child: Text('Tuesday')),
                    DropdownMenuItem(value: 'Wednesday', child: Text('Wednesday')),
                    DropdownMenuItem(value: 'Thursday', child: Text('Thursday')),
                    DropdownMenuItem(value: 'Friday', child: Text('Friday')),
                    DropdownMenuItem(value: 'Saturday', child: Text('Saturday')),
                    DropdownMenuItem(value: 'Sunday', child: Text('Sunday')),
                  ],
                  onChanged: (value) => setDialogState(() => day = value ?? day),
                ),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(value: AppConstants.timetableTypeClass, child: Text('Class')),
                    DropdownMenuItem(value: AppConstants.timetableTypeLab, child: Text('Lab')),
                  ],
                  onChanged: (value) => setDialogState(() => type = value ?? AppConstants.timetableTypeClass),
                ),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => pickTime(startController),
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Start'),
                          child: Text(startController.text),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: InkWell(
                        onTap: () => pickTime(endController),
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'End'),
                          child: Text(endController.text),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: isSaving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final room = roomController.text.trim();
                      if (selectedDepartmentId == null ||
                          selectedBatchId == null ||
                          selectedSubjectId == null ||
                          room.isEmpty) {
                        ScaffoldMessenger.of(rootContext).showSnackBar(
                          const SnackBar(content: Text('Department, batch, subject, and room are required')),
                        );
                        return;
                      }

                      setDialogState(() => isSaving = true);
                      try {
                        // Resolve the subject's display name from its id.
                        final subjects = await ref
                            .read(academicRepositoryProvider)
                            .streamSubjects(collegeId, departmentId: selectedDepartmentId)
                            .first;
                        String? subjectName;
                        for (final s in subjects) {
                          if (s.id == selectedSubjectId) {
                            subjectName = s.name;
                            break;
                          }
                        }

                        // Resolve display names so no card or student view
                        // ever shows a raw batch/section id.
                        final batches = await ref
                            .read(academicRepositoryProvider)
                            .streamBatches(collegeId, departmentId: selectedDepartmentId)
                            .first;
                        String? batchName;
                        for (final b in batches) {
                          if (b.id == selectedBatchId) {
                            batchName = b.name;
                            break;
                          }
                        }
                        String? sectionName;
                        if ((selectedSectionId ?? '').isNotEmpty) {
                          final sections = await ref
                              .read(academicRepositoryProvider)
                              .streamSections(collegeId, batchId: selectedBatchId!)
                              .first;
                          for (final s in sections) {
                            if (s.id == selectedSectionId) {
                              sectionName = s.name;
                              break;
                            }
                          }
                        }

                        await ref.read(timetableRepositoryProvider).addEntry(
                              TimetableEntryModel(
                                id: '',
                                collegeId: collegeId,
                                departmentId: selectedDepartmentId!,
                                batchId: selectedBatchId!,
                                batchName: batchName,
                                sectionId: (selectedSectionId?.isEmpty ?? true) ? null : selectedSectionId,
                                sectionName: (sectionName?.isEmpty ?? true) ? null : sectionName,
                                subjectId: selectedSubjectId,
                                subjectName: (subjectName == null || subjectName.isEmpty)
                                    ? 'Subject'
                                    : subjectName,
                                type: type,
                                faculty: selectedFacultyName ??
                                    (facultyController.text.trim().isEmpty
                                        ? null
                                        : facultyController.text.trim()),
                                room: room,
                                day: day,
                                startTime: startController.text.trim(),
                                endTime: endController.text.trim(),
                                createdBy: actorUid,
                              ),
                            );
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        if (rootContext.mounted) {
                          ScaffoldMessenger.of(rootContext).showSnackBar(
                            const SnackBar(content: Text('Timetable entry created')),
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
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Create'),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      // Dispose after the exit transition unmounts the fields.
      Future.delayed(const Duration(milliseconds: 500), disposeControllers);
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
