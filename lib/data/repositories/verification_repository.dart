import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/firestore_paths.dart';
import '../../core/errors/app_exception.dart';
import '../models/ban_model.dart';
import '../models/user_model.dart';
import '../models/verification_request_model.dart';
import '../services/firebase_service.dart';

/// Repository managing staff verification requests, approvals, rejections, bans, and unbans.
class VerificationRepository {
  final FirebaseFirestore _firestore;

  VerificationRepository(this._firestore);

  /// Stream of verification requests for a specific college and status
  Stream<List<VerificationRequestModel>> streamRequests(String collegeId, {String? status}) {
    Query query = _firestore.collection(FirestorePaths.verificationRequests(collegeId));
    if (status != null && status.isNotEmpty) {
      query = query.where('status', isEqualTo: status);
    }
    return query.snapshots().map((snap) {
      final list = snap.docs.map((d) => VerificationRequestModel.fromFirestore(d as DocumentSnapshot<Map<String, dynamic>>)).toList();
      // Sort in memory by requestedAt desc
      list.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
      return list;
    });
  }

  /// Live set of uids that still have a user document in this college.
  /// Admin lists use it to hide requests whose owner was deleted from
  /// Firebase — the entry disappears in real time, no stale rows.
  Stream<Set<String>> streamExistingUserIds(String collegeId) {
    return _firestore
        .collection(FirestorePaths.users(collegeId))
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.id).toSet());
  }

  /// Live uid -> role map for the All Users tab's role filter and chips.
  Stream<Map<String, String>> streamUserRoles(String collegeId) {
    return _firestore
        .collection(FirestorePaths.users(collegeId))
        .snapshots()
        .map((snap) => {
              for (final d in snap.docs)
                d.id: (d.data()['role'] as String?) ?? 'student',
            });
  }

  Future<UserModel?> getUser(String collegeId, String uid) async {
    final snap = await _firestore.doc(FirestorePaths.user(collegeId, uid)).get();
    if (!snap.exists) return null;
    return UserModel.fromFirestore(snap);
  }

  /// Stream the user's OWN verification request — the pending screen uses it
  /// to show who acted, when, and why (ban / reject / disapprove reasons).
  /// Rules allow a member to read their own request document.
  Stream<VerificationRequestModel?> streamOwnRequest(String collegeId, String uid) {
    return _firestore
        .doc(FirestorePaths.verificationRequest(collegeId, uid))
        .snapshots()
        .map((snap) =>
            snap.exists ? VerificationRequestModel.fromFirestore(snap) : null);
  }

  /// Fetch target's display name once for audit trail readability.
  Future<String> _targetName(String collegeId, String targetUid) async {
    try {
      final snap = await _firestore.doc(FirestorePaths.user(collegeId, targetUid)).get();
      if (snap.exists) {
        return (snap.data()?['displayName'] as String?) ?? targetUid;
      }
    } catch (_) {}
    return targetUid;
  }

  /// Approve student request
  Future<void> approveStudent({
    required String collegeId,
    required String targetUid,
    required UserModel actor,
  }) async {
    final targetName = await _targetName(collegeId, targetUid);
    final batch = _firestore.batch();

    // 1. Update user document
    final userRef = _firestore.doc(FirestorePaths.user(collegeId, targetUid));
    batch.update(userRef, {
      'accountStatus': AppConstants.statusActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 2. Update verification request document
    final reqRef = _firestore.doc(FirestorePaths.verificationRequest(collegeId, targetUid));
    batch.update(reqRef, {
      'status': AppConstants.statusActive,
      'actionedByUid': actor.uid,
      'actionedByName': actor.displayName,
      'actionedByRole': actor.role,
      'actionDate': FieldValue.serverTimestamp(),
    });

    // 3. Update global user index
    final globalRef = _firestore.collection(FirestorePaths.globalUsers).doc(targetUid);
    batch.set(globalRef, {
      'collegeId': collegeId,
      'accountStatus': AppConstants.statusActive,
    }, SetOptions(merge: true));

    // 4. Append audit log
    final auditRef = _firestore.collection(FirestorePaths.auditLogs(collegeId)).doc();
    batch.set(auditRef, {
      'collegeId': collegeId,
      'actorUid': actor.uid,
      'actorName': actor.displayName,
      'actorEmail': actor.email,
      'actorRole': actor.role,
      'action': '${actor.role.toUpperCase()}_APPROVED_STUDENT',
      'targetUid': targetUid,
      'targetName': targetName,
      'reason': 'Student verified by staff',
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Reject student request with mandatory reason
  Future<void> rejectStudent({
    required String collegeId,
    required String targetUid,
    required UserModel actor,
    required String reason,
  }) async {
    if (reason.trim().isEmpty) {
      throw const ValidationException('A reason is required for rejection.');
    }

    final targetName = await _targetName(collegeId, targetUid);
    final batch = _firestore.batch();

    final userRef = _firestore.doc(FirestorePaths.user(collegeId, targetUid));
    batch.update(userRef, {
      'accountStatus': AppConstants.statusRejected,
      'rejectionReason': reason,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final reqRef = _firestore.doc(FirestorePaths.verificationRequest(collegeId, targetUid));
    batch.update(reqRef, {
      'status': AppConstants.statusRejected,
      'actionReason': reason,
      'actionedByUid': actor.uid,
      'actionedByName': actor.displayName,
      'actionedByRole': actor.role,
      'actionDate': FieldValue.serverTimestamp(),
    });

    final globalRef = _firestore.collection(FirestorePaths.globalUsers).doc(targetUid);
    batch.set(globalRef, {
      'collegeId': collegeId,
      'accountStatus': AppConstants.statusRejected,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final auditRef = _firestore.collection(FirestorePaths.auditLogs(collegeId)).doc();
    batch.set(auditRef, {
      'collegeId': collegeId,
      'actorUid': actor.uid,
      'actorName': actor.displayName,
      'actorEmail': actor.email,
      'actorRole': actor.role,
      'action': '${actor.role.toUpperCase()}_REJECTED_STUDENT',
      'targetUid': targetUid,
      'targetName': targetName,
      'reason': reason,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Ban student with mandatory reason and hierarchical level
  Future<void> banStudent({
    required String collegeId,
    required String targetUid,
    required UserModel actor,
    required String reason,
  }) async {
    if (reason.trim().isEmpty) {
      throw const ValidationException('A reason is required for banning an account.');
    }

    final targetName = await _targetName(collegeId, targetUid);
    final banLevel = actor.role == AppConstants.roleOwner
        ? AppConstants.banLevelOwner
        : actor.role == AppConstants.roleAdmin
            ? AppConstants.banLevelAdmin
            : AppConstants.banLevelModerator;

    final banData = BanModel(
      isActive: true,
      level: banLevel,
      bannedByUid: actor.uid,
      bannedByName: actor.displayName,
      bannedByRole: actor.role,
      reason: reason,
      createdAt: DateTime.now(),
    );

    final batch = _firestore.batch();

    final userRef = _firestore.doc(FirestorePaths.user(collegeId, targetUid));
    batch.update(userRef, {
      'accountStatus': AppConstants.statusBanned,
      'ban': banData.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final reqRef = _firestore.doc(FirestorePaths.verificationRequest(collegeId, targetUid));
    batch.update(reqRef, {
      'status': AppConstants.statusBanned,
      'actionReason': reason,
      'actionedByUid': actor.uid,
      'actionedByName': actor.displayName,
      'actionedByRole': actor.role,
      'actionDate': FieldValue.serverTimestamp(),
    });

    final globalRef = _firestore.collection(FirestorePaths.globalUsers).doc(targetUid);
    batch.set(globalRef, {
      'collegeId': collegeId,
      'accountStatus': AppConstants.statusBanned,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final auditRef = _firestore.collection(FirestorePaths.auditLogs(collegeId)).doc();
    batch.set(auditRef, {
      'collegeId': collegeId,
      'actorUid': actor.uid,
      'actorName': actor.displayName,
      'actorEmail': actor.email,
      'actorRole': actor.role,
      'action': '${actor.role.toUpperCase()}_BANNED_STUDENT',
      'targetUid': targetUid,
      'targetName': targetName,
      'reason': reason,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// REMOVE COMPLETELY: wipes a person from every collection in one atomic
  /// batch — user document, verification request, and global index — then
  /// writes an audit log entry. If they register again they arrive as a
  /// brand-new pending student needing fresh approval.
  Future<void> removeUserCompletely({
    required String collegeId,
    required String targetUid,
    required UserModel actor,
    required String reason,
  }) async {
    if (reason.trim().isEmpty) {
      throw const ValidationException('A reason is required to remove an account.');
    }

    final targetName = await _targetName(collegeId, targetUid);
    final batch = _firestore.batch();

    // 1. Delete the college user document (kills every profile + academic link)
    batch.delete(_firestore.doc(FirestorePaths.user(collegeId, targetUid)));

    // 2. Delete the verification request (kills the admin-list entry)
    batch.delete(
      _firestore.doc(FirestorePaths.verificationRequest(collegeId, targetUid)),
    );

    // 3. Delete the global user index entry (kills fast-startup routing)
    batch.delete(_firestore.collection(FirestorePaths.globalUsers).doc(targetUid));

    // 4. Audit log (append-only, kept forever)
    final auditRef = _firestore.collection(FirestorePaths.auditLogs(collegeId)).doc();
    batch.set(auditRef, {
      'collegeId': collegeId,
      'actorUid': actor.uid,
      'actorName': actor.displayName,
      'actorEmail': actor.email,
      'actorRole': actor.role,
      'action': '${actor.role.toUpperCase()}_REMOVED_USER',
      'targetUid': targetUid,
      'targetName': targetName,
      'reason': reason,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Disapprove an already-approved student: they return to the pending
  /// queue with their academic links kept. Works on any role so co-admins
  /// can pull back a student who was mistakenly promoted, too.
  Future<void> disapproveStudent({
    required String collegeId,
    required String targetUid,
    required UserModel actor,
    required String reason,
  }) async {
    if (reason.trim().isEmpty) {
      throw const ValidationException('A reason is required to disapprove a member.');
    }
    if (!actor.canModerateStudents) {
      throw const PermissionDeniedException('Only verification staff can disapprove.');
    }

    final targetName = await _targetName(collegeId, targetUid);
    final batch = _firestore.batch();

    // 1. User document — back to pending, academics kept.
    final userRef = _firestore.doc(FirestorePaths.user(collegeId, targetUid));
    batch.update(userRef, {
      'accountStatus': AppConstants.statusPending,
      'ban.isActive': false,
      'ban.unbannedByUid': actor.uid,
      'ban.unbanReason': 'Disapproved: $reason',
    });

    // 2. Verification request — visible again in the Pending tab.
    final reqRef = _firestore.doc(FirestorePaths.verificationRequest(collegeId, targetUid));
    batch.update(reqRef, {
      'status': AppConstants.statusPending,
      'actionReason': 'Disapproved: $reason',
      'actionedByUid': actor.uid,
      'actionedByName': actor.displayName,
      'actionedByRole': actor.role,
      'actionDate': FieldValue.serverTimestamp(),
    });

    // 3. Global index — routing shows the pending screen again.
    final globalRef = _firestore.collection(FirestorePaths.globalUsers).doc(targetUid);
    batch.set(globalRef, {
      'collegeId': collegeId,
      'accountStatus': AppConstants.statusPending,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 4. Audit log — permanent trail.
    final auditRef = _firestore.collection(FirestorePaths.auditLogs(collegeId)).doc();
    batch.set(auditRef, {
      'collegeId': collegeId,
      'actorUid': actor.uid,
      'actorName': actor.displayName,
      'actorEmail': actor.email,
      'actorRole': actor.role,
      'action': '${actor.role.toUpperCase()}_DISAPPROVED_MEMBER',
      'targetUid': targetUid,
      'targetName': targetName,
      'reason': reason,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Unban student (Strictly checks ban hierarchy)
  Future<void> unbanStudent({
    required String collegeId,
    required String targetUid,
    required UserModel actor,
    required BanModel currentBan,
    required String reason,
  }) async {
    if (!currentBan.canUnban(actor.role)) {
      throw const PermissionDeniedException(
        '⚠️ This account was banned by an administrator/owner. Moderators cannot remove this restriction.',
      );
    }

    final targetName = await _targetName(collegeId, targetUid);
    final batch = _firestore.batch();

    final userRef = _firestore.doc(FirestorePaths.user(collegeId, targetUid));
    batch.update(userRef, {
      'accountStatus': AppConstants.statusActive,
      'ban.isActive': false,
      'ban.unbannedByUid': actor.uid,
      'ban.unbanReason': reason,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final reqRef = _firestore.doc(FirestorePaths.verificationRequest(collegeId, targetUid));
    batch.update(reqRef, {
      'status': AppConstants.statusActive,
      'actionReason': 'Unbanned: $reason',
      'actionedByUid': actor.uid,
      'actionedByName': actor.displayName,
      'actionedByRole': actor.role,
      'actionDate': FieldValue.serverTimestamp(),
    });

    final globalRef = _firestore.collection(FirestorePaths.globalUsers).doc(targetUid);
    batch.set(globalRef, {
      'collegeId': collegeId,
      'accountStatus': AppConstants.statusActive,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final auditRef = _firestore.collection(FirestorePaths.auditLogs(collegeId)).doc();
    batch.set(auditRef, {
      'collegeId': collegeId,
      'actorUid': actor.uid,
      'actorName': actor.displayName,
      'actorEmail': actor.email,
      'actorRole': actor.role,
      'action': '${actor.role.toUpperCase()}_UNBANNED_STUDENT',
      'targetUid': targetUid,
      'targetName': targetName,
      'reason': reason,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }
}

final verificationRepositoryProvider = Provider<VerificationRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return VerificationRepository(firestore);
});
