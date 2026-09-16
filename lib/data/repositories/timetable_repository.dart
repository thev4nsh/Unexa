import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/firestore_paths.dart';
import '../../core/utils/date_formatter.dart';
import '../models/timetable_model.dart';
import '../services/firebase_service.dart';

/// Repository for timetable entries and student schedule streaming.
class TimetableRepository {
  final FirebaseFirestore _firestore;

  TimetableRepository(this._firestore);

  /// Stream student's timetable for a specific day
  Stream<List<TimetableEntryModel>> streamStudentTimetable({
    required String collegeId,
    required String day,
    String? batchId,
    String? departmentId,
    String? sectionId,
  }) {
    // NOTE: no isActive filter — legacy entries created before the field
    // existed (or docs edited in the console) have no isActive and would be
    // silently invisible. Entries are hard-deleted, so nothing sets it false.
    Query query = _firestore
        .collection(FirestorePaths.timetable(collegeId))
        .where('day', isEqualTo: day);

    if (batchId != null && batchId.isNotEmpty) {
      query = query.where('batchId', isEqualTo: batchId);
    }

    return query.snapshots().map((snap) {
      final entries = snap.docs
          .map((d) => TimetableEntryModel.fromFirestore(d as DocumentSnapshot<Map<String, dynamic>>))
          .where((e) {
            if (sectionId != null && sectionId.isNotEmpty && e.sectionId != null && e.sectionId!.isNotEmpty) {
              return e.sectionId == sectionId;
            }
            return true;
          })
          .toList();

      // Sort by start time minutes from midnight
      entries.sort((a, b) {
        final aMin = DateFormatter.parseMinutesFromMidnight(a.startTime) ?? 0;
        final bMin = DateFormatter.parseMinutesFromMidnight(b.startTime) ?? 0;
        return aMin.compareTo(bMin);
      });

      return entries;
    });
  }

  /// Stream all timetable entries for staff view (with day and batch filters)
  Stream<List<TimetableEntryModel>> streamAllTimetable({
    required String collegeId,
    String? day,
    String? batchId,
  }) {
    Query query = _firestore.collection(FirestorePaths.timetable(collegeId));
    if (day != null && day.isNotEmpty) {
      query = query.where('day', isEqualTo: day);
    }
    if (batchId != null && batchId.isNotEmpty) {
      query = query.where('batchId', isEqualTo: batchId);
    }

    return query.snapshots().map((snap) {
      final entries = snap.docs
          .map((d) => TimetableEntryModel.fromFirestore(d as DocumentSnapshot<Map<String, dynamic>>))
          .toList();
      entries.sort((a, b) {
        final aMin = DateFormatter.parseMinutesFromMidnight(a.startTime) ?? 0;
        final bMin = DateFormatter.parseMinutesFromMidnight(b.startTime) ?? 0;
        return aMin.compareTo(bMin);
      });
      return entries;
    });
  }

  /// Stream a department/batch/section scoped timetable for a given day.
  /// Section-specific entries appear only to that section; entries with no
  /// section apply to every section of the batch. A batchId of '' means the
  /// synthetic Common Batch — those viewers see only entries that were added
  /// to the common batch (batchId ''), never another batch's classes.
  /// NOTE: no isActive filter — legacy entries without the field must show.
  Stream<List<TimetableEntryModel>> streamScopedTimetable({
    required String collegeId,
    required String day,
    String? departmentId,
    String? batchId,
    String? sectionId,
  }) {
    Query query = _firestore
        .collection(FirestorePaths.timetable(collegeId))
        .where('day', isEqualTo: day);

    if (batchId != null && batchId.isNotEmpty) {
      query = query.where('batchId', isEqualTo: batchId);
    }

    return query.snapshots().map((snap) {
      final entries = snap.docs
          .map((d) => TimetableEntryModel.fromFirestore(d as DocumentSnapshot<Map<String, dynamic>>))
          .where((e) {
            if (departmentId != null && departmentId.isNotEmpty && e.departmentId.isNotEmpty) {
              if (e.departmentId != departmentId) return false;
            }
            // Common Batch viewer: only entries added to the common batch.
            if (batchId != null && batchId.isEmpty) {
              if (e.batchId.isNotEmpty) return false;
            }
            if (sectionId != null && sectionId.isNotEmpty && e.sectionId != null && e.sectionId!.isNotEmpty) {
              if (e.sectionId != sectionId) return false;
            }
            return true;
          })
          .toList();
      entries.sort((a, b) {
        final aMin = DateFormatter.parseMinutesFromMidnight(a.startTime) ?? 0;
        final bMin = DateFormatter.parseMinutesFromMidnight(b.startTime) ?? 0;
        return aMin.compareTo(bMin);
      });
      return entries;
    });
  }

  /// Add a new timetable entry (Staff)
  Future<void> addEntry(TimetableEntryModel entry) async {
    await _firestore.collection(FirestorePaths.timetable(entry.collegeId)).add(entry.toMap());
  }

  /// Update an existing timetable entry (Staff)
  Future<void> updateEntry(TimetableEntryModel entry) async {
    await _firestore.doc(FirestorePaths.timetableEntry(entry.collegeId, entry.id)).update(entry.toMap());
  }

  /// Delete a timetable entry (Staff)
  Future<void> deleteEntry(String collegeId, String entryId) async {
    await _firestore.doc(FirestorePaths.timetableEntry(collegeId, entryId)).delete();
  }
}

final timetableRepositoryProvider = Provider<TimetableRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return TimetableRepository(firestore);
});
