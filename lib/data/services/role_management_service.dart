import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/firestore_paths.dart';
import '../models/user_model.dart';
import 'firebase_service.dart';

/// Trusted operations for staff role management (Admin/Owner only).
/// Changes the role on the college-scoped user document and appends an
/// audit log. Firestore rules additionally constrain who can change roles.
class RoleManagementService {
  final FirebaseFirestore _firestore;

  RoleManagementService(this._firestore);

  /// Full role change with actor info and audit log.
  Future<void> changeRole({
    required UserModel actor,
    required String collegeId,
    required String targetUid,
    required String newRole,
    required String reason,
  }) async {
    if (reason.trim().isEmpty) {
      throw ArgumentError('A reason is required for role changes.');
    }

    final actorIsAdmin = actor.isAdmin || actor.isOwner;
    final actorIsCoAdmin = actor.isCoAdmin;
    if (!actorIsAdmin && !actorIsCoAdmin) {
      throw StateError('Only Admins and Co-Admins can change staff roles.');
    }

    // Co-Admins may only manage students <-> moderators.
    // Granting/revoking co_admin requires Admin/Owner.
    if (!actorIsAdmin && newRole == AppConstants.roleCoAdmin) {
      throw StateError('Only Admins can grant or revoke the Co-Admin role.');
    }

    const allowed = [
      AppConstants.roleStudent,
      AppConstants.roleModerator,
      AppConstants.roleCr,
      AppConstants.roleCoAdmin,
    ];
    if (!allowed.contains(newRole)) {
      throw ArgumentError(
          'Only student, moderator, cr, or co_admin roles can be assigned from the app.');
    }

    final userRef = _firestore.doc(FirestorePaths.user(collegeId, targetUid));
    final snap = await userRef.get();
    if (!snap.exists) {
      throw StateError('Member not found in this institute.');
    }

    final target = UserModel.fromFirestore(snap);
    if (target.isOwner || target.isAdmin) {
      throw StateError(
          'Admin and Owner roles can only be managed by the platform Owner.');
    }
    if (target.role == newRole) {
      throw StateError('Member already has this role.');
    }

    // Co-Admin actors cannot demote other Co-Admins.
    if (!actorIsAdmin && target.isCoAdmin) {
      throw StateError('Co-Admins cannot modify other Co-Admin accounts.');
    }

    final batch = _firestore.batch();

    batch.update(userRef, {
      'role': newRole,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final auditRef =
        _firestore.collection(FirestorePaths.auditLogs(collegeId)).doc();
    batch.set(auditRef, {
      'collegeId': collegeId,
      'actorUid': actor.uid,
      'actorName': actor.displayName,
      'actorEmail': actor.email,
      'actorRole': actor.role,
      'action': AppConstants.auditRoleChanged,
      // CR switches preserve class membership automatically — the academic
      // fields are never touched by role changes, only the role field moves.
      'targetUid': targetUid,
      'targetName': target.displayName,
      'reason': reason,
      'oldRole': target.role,
      'newRole': newRole,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }
}

final roleManagementServiceProvider = Provider<RoleManagementService>((ref) {
  return RoleManagementService(ref.watch(firestoreProvider));
});
