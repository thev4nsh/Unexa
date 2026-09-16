import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/firestore_paths.dart';
import '../models/announcement_model.dart';
import '../services/firebase_service.dart';

/// Repository for announcements and student targeting.
class AnnouncementRepository {
  final FirebaseFirestore _firestore;

  AnnouncementRepository(this._firestore);

  /// Stream announcements applicable to a student's scope
  Stream<List<AnnouncementModel>> streamStudentAnnouncements({
    required String collegeId,
    String? departmentId,
    String? batchId,
    String? sectionId,
  }) {
    return _firestore
        .collection(FirestorePaths.announcements(collegeId))
        .where('isPublished', isEqualTo: true)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => AnnouncementModel.fromFirestore(d))
          .where((a) => a.isRelevantForStudent(
                departmentId: departmentId,
                batchId: batchId,
                sectionId: sectionId,
              ))
          .toList();
      list.sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
      return list;
    });
  }

  /// Stream all announcements for staff management
  Stream<List<AnnouncementModel>> streamAllAnnouncements(String collegeId) {
    return _firestore
        .collection(FirestorePaths.announcements(collegeId))
        .snapshots()
        .map((snap) {
      final list = snap.docs.map((d) => AnnouncementModel.fromFirestore(d)).toList();
      list.sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
      return list;
    });
  }

  /// Add a new announcement (Staff)
  Future<void> createAnnouncement(AnnouncementModel announcement) async {
    await _firestore.collection(FirestorePaths.announcements(announcement.collegeId)).add({
      ...announcement.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Delete announcement (Staff)
  Future<void> deleteAnnouncement(String collegeId, String announcementId) async {
    await _firestore.doc(FirestorePaths.announcement(collegeId, announcementId)).delete();
  }
}

final announcementRepositoryProvider = Provider<AnnouncementRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return AnnouncementRepository(firestore);
});
