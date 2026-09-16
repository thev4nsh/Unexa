import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/screen_privacy_guard.dart';
import '../../../core/widgets/staff_back_app_bar.dart';
import '../../../core/widgets/unexa_card.dart';
import '../../../core/widgets/unexa_empty_state.dart';
import '../../../data/models/academic_models.dart';
import '../../../data/repositories/academic_repository.dart';
import '../../auth/providers/auth_provider.dart';

/// Institute faculty roster: add once, then pick from a searchable list
/// when creating timetable classes — no more typing names every time.
class AdminFacultiesScreen extends ConsumerStatefulWidget {
  const AdminFacultiesScreen({super.key});

  @override
  ConsumerState<AdminFacultiesScreen> createState() =>
      _AdminFacultiesScreenState();
}

class _AdminFacultiesScreenState extends ConsumerState<AdminFacultiesScreen> {
  String _search = '';

  void _showAddDialog() {
    final user = ref.read(currentUserModelProvider).value;
    if (user == null) return;

    final nameController = TextEditingController();
    String? departmentId;
    String? departmentName;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Faculty'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Faculty name'),
                  textCapitalization: TextCapitalization.words,
                  autofocus: true,
                ),
                const SizedBox(height: AppSpacing.sm),
                // Optional department tag so the picker can show context.
                StreamBuilder<List<DepartmentModel>>(
                  stream: ref
                      .read(academicRepositoryProvider)
                      .streamDepartments(user.collegeId),
                  builder: (context, snapshot) {
                    final departments = snapshot.data ?? const [];
                    return DropdownButtonFormField<String>(
                      initialValue: departmentId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                          labelText: 'Department (optional)'),
                      items: departments
                          .map((d) => DropdownMenuItem(
                                value: d.id,
                                child: Text(
                                  d.code.isEmpty
                                      ? d.name
                                      : '${d.name} (${d.code})',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
                          .toList(),
                      onChanged: (value) => setDialogState(() {
                        departmentId = value;
                        departmentName = null;
                        for (final d in departments) {
                          if (d.id == value) departmentName = d.name;
                        }
                      }),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed:
                  isSaving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final name = nameController.text.trim();
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Faculty name is required')),
                        );
                        return;
                      }
                      setDialogState(() => isSaving = true);
                      try {
                        await ref
                            .read(academicRepositoryProvider)
                            .addFaculty(
                              user.collegeId,
                              name,
                              departmentId: departmentId,
                              departmentName: departmentName,
                            );
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                      } catch (error) {
                        setDialogState(() => isSaving = false);
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(content: Text('Could not add: $error')),
                          );
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Add'),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      Future.delayed(
          const Duration(milliseconds: 500), nameController.dispose);
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserModelProvider).value;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return SecureScreen(
      child: Scaffold(
        appBar: const StaffBackAppBar(title: 'Manage Faculties'),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showAddDialog,
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('Add Faculty'),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Search faculty',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (v) =>
                    setState(() => _search = v.trim().toLowerCase()),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<FacultyModel>>(
                stream: ref
                    .watch(academicRepositoryProvider)
                    .streamFaculties(user.collegeId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                        child: Text('Could not load: ${snapshot.error}'));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final faculties = (snapshot.data ?? const [])
                      .where((f) {
                        if (_search.isEmpty) return true;
                        return f.name.toLowerCase().contains(_search) ||
                            (f.departmentName ?? '')
                                .toLowerCase()
                                .contains(_search);
                      })
                      .toList()
                    ..sort((a, b) =>
                        a.name.toLowerCase().compareTo(b.name.toLowerCase()));

                  if (faculties.isEmpty) {
                    return UnexaEmptyState(
                      icon: Icons.badge_outlined,
                      title: _search.isEmpty ? 'Nothing to show' : 'No matches',
                      subtitle: _search.isEmpty
                          ? 'Add faculty members once — they appear as one-tap options when creating classes.'
                          : 'No faculty matches "$_search".',
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: faculties.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final f = faculties[index];
                      return UnexaCard(
                        borderRadius: AppRadius.sm,
                        child: Row(
                          children: [
                            CircleAvatar(
                              child: Text(
                                  f.name.isNotEmpty
                                      ? f.name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(f.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  if (f.departmentName?.isNotEmpty ?? false)
                                    Text(f.departmentName!,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Remove',
                              icon: const Icon(Icons.delete_outline_rounded),
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (c) => AlertDialog(
                                    title: const Text('Remove faculty?'),
                                    content: Text(
                                        '${f.name} will be removed from the roster. Already-created classes keep their faculty name.'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(c, false),
                                        child: const Text('Cancel'),
                                      ),
                                      FilledButton(
                                        onPressed: () => Navigator.pop(c, true),
                                        child: const Text('Remove'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true) {
                                  await ref
                                      .read(academicRepositoryProvider)
                                      .deleteFaculty(user.collegeId, f.id);
                                }
                              },
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
      ),
    );
  }
}
