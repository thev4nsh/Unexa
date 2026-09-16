import 'package:cloud_firestore/cloud_firestore.dart';

/// Immutable append-only audit record model.
class AuditLogModel {
  final String id;
  final String collegeId;
  final String actorUid;
  final String actorName;
  final String actorEmail;
  final String actorRole;
  final String action;
  final String? targetUid;
  final String? targetName;
  final String? reason;
  final Map<String, dynamic>? oldValues;
  final Map<String, dynamic>? newValues;
  final DateTime timestamp;

  const AuditLogModel({
    required this.id,
    required this.collegeId,
    required this.actorUid,
    required this.actorName,
    required this.actorEmail,
    required this.actorRole,
    required this.action,
    this.targetUid,
    this.targetName,
    this.reason,
    this.oldValues,
    this.newValues,
    required this.timestamp,
  });

  factory AuditLogModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AuditLogModel(
      id: doc.id,
      collegeId: data['collegeId'] as String? ?? '',
      actorUid: data['actorUid'] as String? ?? '',
      actorName: data['actorName'] as String? ?? 'User',
      actorEmail: data['actorEmail'] as String? ?? '',
      actorRole: data['actorRole'] as String? ?? '',
      action: data['action'] as String? ?? '',
      targetUid: data['targetUid'] as String?,
      targetName: data['targetName'] as String?,
      reason: data['reason'] as String?,
      oldValues: data['oldValues'] as Map<String, dynamic>?,
      newValues: data['newValues'] as Map<String, dynamic>?,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'collegeId': collegeId,
      'actorUid': actorUid,
      'actorName': actorName,
      'actorEmail': actorEmail,
      'actorRole': actorRole,
      'action': action,
      if (targetUid != null) 'targetUid': targetUid,
      if (targetName != null) 'targetName': targetName,
      if (reason != null) 'reason': reason,
      if (oldValues != null) 'oldValues': oldValues,
      if (newValues != null) 'newValues': newValues,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
