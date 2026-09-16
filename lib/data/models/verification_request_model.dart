import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_constants.dart';

/// Represents an access verification request from a student to their college admin.
class VerificationRequestModel {
  final String id;
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final String collegeId;
  final String status; // pending, approved, rejected, banned, suspended
  final String? departmentName;
  final String? batchName;
  final String? sectionName;
  final int? year;
  final DateTime requestedAt;
  final String? actionedByUid;
  final String? actionedByName;
  final String? actionedByRole;
  final String? actionReason;
  final DateTime? actionDate;

  const VerificationRequestModel({
    required this.id,
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    required this.collegeId,
    this.status = AppConstants.statusPending,
    this.departmentName,
    this.batchName,
    this.sectionName,
    this.year,
    required this.requestedAt,
    this.actionedByUid,
    this.actionedByName,
    this.actionedByRole,
    this.actionReason,
    this.actionDate,
  });

  factory VerificationRequestModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return VerificationRequestModel(
      id: doc.id,
      uid: data['uid'] as String? ?? doc.id,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? 'Student',
      photoUrl: data['photoUrl'] as String?,
      collegeId: data['collegeId'] as String? ?? '',
      status: data['status'] as String? ?? AppConstants.statusPending,
      departmentName: data['departmentName'] as String?,
      batchName: data['batchName'] as String?,
      sectionName: data['sectionName'] as String?,
      year: data['year'] as int?,
      requestedAt: (data['requestedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      actionedByUid: data['actionedByUid'] as String?,
      actionedByName: data['actionedByName'] as String?,
      actionedByRole: data['actionedByRole'] as String?,
      actionReason: data['actionReason'] as String?,
      actionDate: (data['actionDate'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'collegeId': collegeId,
      'status': status,
      if (departmentName != null) 'departmentName': departmentName,
      if (batchName != null) 'batchName': batchName,
      if (sectionName != null) 'sectionName': sectionName,
      if (year != null) 'year': year,
      'requestedAt': Timestamp.fromDate(requestedAt),
      if (actionedByUid != null) 'actionedByUid': actionedByUid,
      if (actionedByName != null) 'actionedByName': actionedByName,
      if (actionedByRole != null) 'actionedByRole': actionedByRole,
      if (actionReason != null) 'actionReason': actionReason,
      if (actionDate != null) 'actionDate': Timestamp.fromDate(actionDate!),
    };
  }
}
