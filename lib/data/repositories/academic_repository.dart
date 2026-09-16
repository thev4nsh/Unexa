import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/firestore_paths.dart';
import '../models/academic_models.dart';
import '../services/firebase_service.dart';

// Riverpod-streamed providers so onboarding/admin UI never blocks on spinners
// and shows instant empty states when a list has no data.

final departmentsProvider = StreamProvider.autoDispose
    .family<List<DepartmentModel>, String>((ref, collegeId) {
  return ref.watch(academicRepositoryProvider).streamDepartments(collegeId);
});

final batchesProvider = StreamProvider.autoDispose
    .family<List<BatchModel>, (String, String)>(
        (ref, args) => ref.watch(academicRepositoryProvider).streamBatches(args.$1, departmentId: args.$2));

final sectionsProvider = StreamProvider.autoDispose
    .family<List<SectionModel>, (String, String)>(
        (ref, args) => ref.watch(academicRepositoryProvider).streamSections(args.$1, batchId: args.$2));

final subjectsProvider = StreamProvider.autoDispose
    .family<List<SubjectModel>, (String, String?)>((ref, args) {
  return ref.watch(academicRepositoryProvider).streamSubjects(args.$1, departmentId: args.$2);
});

// Unfiltered lists for admin targeting pickers.
final batchesAllProvider = StreamProvider.autoDispose
    .family<List<BatchModel>, String>(
        (ref, collegeId) => ref.watch(academicRepositoryProvider).streamBatches(collegeId));

final sectionsAllProvider = StreamProvider.autoDispose
    .family<List<SectionModel>, String>(
        (ref, collegeId) => ref.watch(academicRepositoryProvider).streamSections(collegeId));

/// Live faculty roster for pickers and the Manage Faculties screen.
final facultiesProvider = StreamProvider.autoDispose
    .family<List<FacultyModel>, String>(
        (ref, collegeId) => ref.watch(academicRepositoryProvider).streamFaculties(collegeId));

/// Repository for dynamic academic structures: Departments, Batches, Sections, and Subjects.
class AcademicRepository {
  final FirebaseFirestore _firestore;

  AcademicRepository(this._firestore);

  // DEPARTMENTS
  Stream<List<DepartmentModel>> streamDepartments(String collegeId) {
    return _firestore
        .collection(FirestorePaths.departments(collegeId))
        .snapshots()
        .map((s) => s.docs.map((d) => DepartmentModel.fromFirestore(d)).toList());
  }

  Future<void> addDepartment(String collegeId, String name, String code) async {
    await _firestore.collection(FirestorePaths.departments(collegeId)).add({
      'collegeId': collegeId,
      'name': name.trim(),
      'code': code.trim().toUpperCase(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateDepartment(String collegeId, String deptId, String name, String code) async {
    await _firestore.doc(FirestorePaths.department(collegeId, deptId)).update({
      'name': name.trim(),
      'code': code.trim().toUpperCase(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteDepartment(String collegeId, String deptId) async {
    await _firestore.doc(FirestorePaths.department(collegeId, deptId)).delete();
  }

  // FACULTIES
  /// Live roster of faculty members for this institute.
  Stream<List<FacultyModel>> streamFaculties(String collegeId) {
    return _firestore
        .collection(FirestorePaths.faculties(collegeId))
        .snapshots()
        .map((s) => s.docs.map((d) => FacultyModel.fromFirestore(d)).toList());
  }

  Future<void> addFaculty(String collegeId, String name,
      {String? departmentId, String? departmentName}) async {
    await _firestore.collection(FirestorePaths.faculties(collegeId)).add({
      'collegeId': collegeId,
      'name': name.trim(),
      if (departmentId != null && departmentId.isNotEmpty)
        'departmentId': departmentId,
      if (departmentName != null && departmentName.isNotEmpty)
        'departmentName': departmentName,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteFaculty(String collegeId, String facultyId) async {
    await _firestore.doc(FirestorePaths.faculty(collegeId, facultyId)).delete();
  }

  // BATCHES
  Stream<List<BatchModel>> streamBatches(String collegeId, {String? departmentId}) {
    Query query = _firestore.collection(FirestorePaths.batches(collegeId));
    if (departmentId != null && departmentId.isNotEmpty) {
      query = query.where('departmentId', isEqualTo: departmentId);
    }
    return query.snapshots().map((s) => s.docs.map((d) => BatchModel.fromFirestore(d as DocumentSnapshot<Map<String, dynamic>>)).toList());
  }

  Future<void> addBatch(String collegeId, String name, {String? departmentId}) async {
    await _firestore.collection(FirestorePaths.batches(collegeId)).add({
      'collegeId': collegeId,
      'name': name.trim(),
      if (departmentId != null && departmentId.isNotEmpty) 'departmentId': departmentId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Create a batch together with its sections (A, B, C…) in ONE atomic write.
  /// Students onboarding into this batch will then pick their section.
  Future<void> addBatchWithSections(
    String collegeId,
    String name, {
    String? departmentId,
    List<String> sectionNames = const [],
  }) async {
    final batchRef = _firestore.collection(FirestorePaths.batches(collegeId)).doc();
    final write = _firestore.batch();

    write.set(batchRef, {
      'collegeId': collegeId,
      'name': name.trim(),
      if (departmentId != null && departmentId.isNotEmpty) 'departmentId': departmentId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final seen = <String>{};
    for (final raw in sectionNames) {
      final sectionName = raw.trim().toUpperCase();
      if (sectionName.isEmpty || !seen.add(sectionName)) continue;
      final sectionRef = _firestore.collection(FirestorePaths.sections(collegeId)).doc();
      write.set(sectionRef, {
        'collegeId': collegeId,
        'name': sectionName,
        'batchId': batchRef.id,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await write.commit();
  }

  Future<void> updateBatch(String collegeId, String batchId, String name, {String? departmentId}) async {
    await _firestore.doc(FirestorePaths.batch(collegeId, batchId)).update({
      'name': name.trim(),
      if (departmentId != null && departmentId.isNotEmpty) 'departmentId': departmentId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteBatch(String collegeId, String batchId) async {
    await _firestore.doc(FirestorePaths.batch(collegeId, batchId)).delete();
  }

  /// Delete a batch together with every section under it in ONE atomic write
  /// — no orphaned sections left behind.
  Future<void> deleteBatchWithSections(String collegeId, String batchId) async {
    final sectionsSnap = await _firestore
        .collection(FirestorePaths.sections(collegeId))
        .where('batchId', isEqualTo: batchId)
        .get();

    final write = _firestore.batch();
    for (final doc in sectionsSnap.docs) {
      write.delete(doc.reference);
    }
    write.delete(_firestore.doc(FirestorePaths.batch(collegeId, batchId)));
    await write.commit();
  }

  // SECTIONS
  Stream<List<SectionModel>> streamSections(String collegeId, {String? batchId}) {
    Query query = _firestore.collection(FirestorePaths.sections(collegeId));
    if (batchId != null && batchId.isNotEmpty) {
      query = query.where('batchId', isEqualTo: batchId);
    }
    return query.snapshots().map((s) => s.docs.map((d) => SectionModel.fromFirestore(d as DocumentSnapshot<Map<String, dynamic>>)).toList());
  }

  Future<void> addSection(String collegeId, String name, {String? batchId}) async {
    await _firestore.collection(FirestorePaths.sections(collegeId)).add({
      'collegeId': collegeId,
      'name': name.trim().toUpperCase(),
      if (batchId != null && batchId.isNotEmpty) 'batchId': batchId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateSection(String collegeId, String sectionId, String name, {String? batchId}) async {
    await _firestore.doc(FirestorePaths.section(collegeId, sectionId)).update({
      'name': name.trim().toUpperCase(),
      if (batchId != null && batchId.isNotEmpty) 'batchId': batchId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteSection(String collegeId, String sectionId) async {
    await _firestore.doc(FirestorePaths.section(collegeId, sectionId)).delete();
  }

  // SUBJECTS
  Stream<List<SubjectModel>> streamSubjects(String collegeId, {String? departmentId}) {
    Query query = _firestore.collection(FirestorePaths.subjects(collegeId));
    if (departmentId != null && departmentId.isNotEmpty) {
      query = query.where('departmentId', isEqualTo: departmentId);
    }
    return query.snapshots().map((s) => s.docs.map((d) => SubjectModel.fromFirestore(d as DocumentSnapshot<Map<String, dynamic>>)).toList());
  }

  Future<void> addSubject(String collegeId, String name, {String? code, String? departmentId}) async {
    await _firestore.collection(FirestorePaths.subjects(collegeId)).add({
      'collegeId': collegeId,
      'name': name.trim(),
      if (code != null && code.isNotEmpty) 'code': code.trim().toUpperCase(),
      if (departmentId != null && departmentId.isNotEmpty) 'departmentId': departmentId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateSubject(String collegeId, String subjectId, String name, {String? code, String? departmentId}) async {
    await _firestore.doc(FirestorePaths.subject(collegeId, subjectId)).update({
      'name': name.trim(),
      if (code != null && code.isNotEmpty) 'code': code.trim().toUpperCase(),
      if (departmentId != null && departmentId.isNotEmpty) 'departmentId': departmentId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteSubject(String collegeId, String subjectId) async {
    // Cascade: remove every timetable entry (class) that references this
    // subject in ONE atomic write — no orphaned classes left behind.
    final classesSnap = await _firestore
        .collection(FirestorePaths.timetable(collegeId))
        .where('subjectId', isEqualTo: subjectId)
        .get();

    final write = _firestore.batch();
    for (final doc in classesSnap.docs) {
      write.delete(doc.reference);
    }
    write.delete(_firestore.doc(FirestorePaths.subject(collegeId, subjectId)));
    await write.commit();
  }
}

final academicRepositoryProvider = Provider<AcademicRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return AcademicRepository(firestore);
});
