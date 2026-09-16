import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/firestore_paths.dart';
import '../models/college_model.dart';
import '../services/firebase_service.dart';

/// Repository managing college configurations, tenant onboarding, and dynamic branding.
class CollegeRepository {
  final FirebaseFirestore _firestore;

  CollegeRepository(this._firestore);

  /// Stream of all active colleges for the student college picker
  Stream<List<CollegeModel>> streamActiveColleges() {
    return _firestore
        .collection(FirestorePaths.colleges)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => CollegeModel.fromFirestore(d)).toList());
  }

  /// Real-time stream of a specific college configuration (for live branding updates)
  Stream<CollegeModel?> streamCollege(String collegeId) {
    return _firestore.doc(FirestorePaths.college(collegeId)).snapshots().map((snap) {
      if (!snap.exists) return null;
      return CollegeModel.fromFirestore(snap);
    });
  }

  /// Get college by ID once
  Future<CollegeModel?> getCollege(String collegeId) async {
    final doc = await _firestore.doc(FirestorePaths.college(collegeId)).get();
    if (!doc.exists) return null;
    return CollegeModel.fromFirestore(doc);
  }

  /// Update college branding (Admin / Owner)
  Future<void> updateBranding({
    required String collegeId,
    required String name,
    String? logoUrl,
    required String primaryColorHex,
    required String secondaryColorHex,
    required String actorUid,
    required String actorRole,
  }) async {
    final docRef = _firestore.doc(FirestorePaths.college(collegeId));
    await docRef.update({
      'name': name,
      'logoUrl': ?logoUrl,
      'primaryColorHex': primaryColorHex,
      'secondaryColorHex': secondaryColorHex,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Append audit log
    await _firestore.collection(FirestorePaths.auditLogs(collegeId)).add({
      'collegeId': collegeId,
      'actorUid': actorUid,
      'actorName': 'Staff',
      'actorEmail': '',
      'actorRole': actorRole,
      'action': 'BRANDING_UPDATED',
      'reason': 'Institute branding updated',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Create a new college tenant (Platform Owner)
  Future<void> createCollege(CollegeModel college) async {
    final docRef = _firestore.collection(FirestorePaths.colleges).doc(college.id);
    await docRef.set(college.toMap());
  }
}

final collegeRepositoryProvider = Provider<CollegeRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return CollegeRepository(firestore);
});
