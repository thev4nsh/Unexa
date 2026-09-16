import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/firestore_paths.dart';
import '../models/audit_log_model.dart';
import '../services/firebase_service.dart';

/// Repository for viewing immutable audit logs.
class AuditRepository {
  final FirebaseFirestore _firestore;

  AuditRepository(this._firestore);

  /// Stream audit logs for college, newest first
  Stream<List<AuditLogModel>> streamAuditLogs(String collegeId) {
    return _firestore
        .collection(FirestorePaths.auditLogs(collegeId))
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs.map((d) => AuditLogModel.fromFirestore(d)).toList());
  }
}

final auditRepositoryProvider = Provider<AuditRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return AuditRepository(firestore);
});
