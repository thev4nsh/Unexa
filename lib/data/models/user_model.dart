import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_constants.dart';
import 'ban_model.dart';

/// Comprehensive User Model for UNEXA Platform.
class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final String collegeId;
  final String role; // owner, admin, co_admin, moderator, student
  final String accountStatus; // active, pending, rejected, suspended, banned
  final String? departmentId;
  final String? departmentName;
  final String? batchId;
  final String? batchName;
  final int? year;
  final int? semester;
  final String? sectionId;
  final String? sectionName;
  final BanModel? banDetails;
  final String? rejectionReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    required this.collegeId,
    this.role = AppConstants.roleStudent,
    this.accountStatus = AppConstants.statusPending,
    this.departmentId,
    this.departmentName,
    this.batchId,
    this.batchName,
    this.year,
    this.semester,
    this.sectionId,
    this.sectionName,
    this.banDetails,
    this.rejectionReason,
    this.createdAt,
    this.updatedAt,
  });

  bool get isOwner => role == AppConstants.roleOwner;
  bool get isAdmin => role == AppConstants.roleAdmin;
  bool get isCoAdmin => role == AppConstants.roleCoAdmin;
  bool get isModerator => role == AppConstants.roleModerator;

  /// CR: class representative — moderator POWERS + full STUDENT experience.
  bool get isCr => role == AppConstants.roleCr;
  bool get isStudent => role == AppConstants.roleStudent;

  /// Any role that can open the verification screen.
  bool get isModeratorKind => isModerator || isCr;

  /// CR counts as staff for routing but keeps the student experience.
  bool get isStaff => isOwner || isAdmin || isCoAdmin || isModeratorKind;

  /// Moderators/CRs and above can verify students (approve / reject / ban).
  bool get canModerateStudents => isModeratorKind || isCoAdmin || isAdmin || isOwner;

  /// Admin / Co-Admin / Owner manage staff roles and remove accounts.
  bool get canManageRoles => isCoAdmin || isAdmin || isOwner;

  /// Only Admin / Owner can grant or revoke the Co-Admin role.
  bool get canPromoteCoAdmin => isAdmin || isOwner;

  bool get isActive => accountStatus == AppConstants.statusActive;
  bool get isPending => accountStatus == AppConstants.statusPending;
  bool get isRejected => accountStatus == AppConstants.statusRejected;
  bool get isBanned => accountStatus == AppConstants.statusBanned || (banDetails?.isActive ?? false);
  bool get isSuspended => accountStatus == AppConstants.statusSuspended;

  /// Whether the student has filled in their academic onboarding (department, batch, etc.)
  /// CRs need onboarding too — their class is part of the CR role.
  bool get isOnboardingComplete {
    if (isStaff && !isCr) return true;
    return departmentId != null && batchId != null;
  }

  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return UserModel(
      uid: doc.id,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? 'User',
      photoUrl: data['photoUrl'] as String?,
      collegeId: data['collegeId'] as String? ?? '',
      role: data['role'] as String? ?? AppConstants.roleStudent,
      accountStatus: data['accountStatus'] as String? ?? AppConstants.statusPending,
      departmentId: data['departmentId'] as String?,
      departmentName: data['departmentName'] as String?,
      batchId: data['batchId'] as String?,
      batchName: data['batchName'] as String?,
      year: data['year'] as int?,
      semester: data['semester'] as int?,
      sectionId: data['sectionId'] as String?,
      sectionName: data['sectionName'] as String?,
      banDetails: data['ban'] != null ? BanModel.fromMap(data['ban'] as Map<String, dynamic>) : null,
      rejectionReason: data['rejectionReason'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'collegeId': collegeId,
      'role': role,
      'accountStatus': accountStatus,
      if (departmentId != null) 'departmentId': departmentId,
      if (departmentName != null) 'departmentName': departmentName,
      if (batchId != null) 'batchId': batchId,
      if (batchName != null) 'batchName': batchName,
      if (year != null) 'year': year,
      if (semester != null) 'semester': semester,
      if (sectionId != null) 'sectionId': sectionId,
      if (sectionName != null) 'sectionName': sectionName,
      if (banDetails != null) 'ban': banDetails!.toMap(),
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoUrl,
    String? collegeId,
    String? role,
    String? accountStatus,
    String? departmentId,
    String? departmentName,
    String? batchId,
    String? batchName,
    int? year,
    int? semester,
    String? sectionId,
    String? sectionName,
    BanModel? banDetails,
    String? rejectionReason,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      collegeId: collegeId ?? this.collegeId,
      role: role ?? this.role,
      accountStatus: accountStatus ?? this.accountStatus,
      departmentId: departmentId ?? this.departmentId,
      departmentName: departmentName ?? this.departmentName,
      batchId: batchId ?? this.batchId,
      batchName: batchName ?? this.batchName,
      year: year ?? this.year,
      semester: semester ?? this.semester,
      sectionId: sectionId ?? this.sectionId,
      sectionName: sectionName ?? this.sectionName,
      banDetails: banDetails ?? this.banDetails,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
