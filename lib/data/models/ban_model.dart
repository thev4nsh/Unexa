import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_constants.dart';

/// Structured ban model enforcing role hierarchy (Moderator < Admin < Owner).
class BanModel {
  final bool isActive;
  final String level; // moderator, admin, owner
  final String bannedByUid;
  final String bannedByName;
  final String bannedByRole;
  final String reason;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const BanModel({
    required this.isActive,
    required this.level,
    required this.bannedByUid,
    required this.bannedByName,
    required this.bannedByRole,
    required this.reason,
    this.createdAt,
    this.updatedAt,
  });

  /// Check if the caller with a given role can unban this user.
  /// Moderator can ONLY unban if ban level is moderator.
  /// Admin can unban if ban level is moderator or admin.
  /// Owner can unban anyone.
  bool canUnban(String callerRole) {
    if (!isActive) return false;
    final r = callerRole.toLowerCase();
    if (r == AppConstants.roleOwner) return true;
    if (r == AppConstants.roleAdmin) {
      return level == AppConstants.banLevelModerator || level == AppConstants.banLevelAdmin;
    }
    if (r == AppConstants.roleCoAdmin) {
      return level == AppConstants.banLevelModerator;
    }
    if (r == AppConstants.roleModerator) {
      return level == AppConstants.banLevelModerator;
    }
    return false;
  }

  factory BanModel.fromMap(Map<String, dynamic> map) {
    return BanModel(
      isActive: map['isActive'] as bool? ?? false,
      level: map['level'] as String? ?? AppConstants.banLevelModerator,
      bannedByUid: map['bannedByUid'] as String? ?? '',
      bannedByName: map['bannedByName'] as String? ?? 'Staff',
      bannedByRole: map['bannedByRole'] as String? ?? AppConstants.roleModerator,
      reason: map['reason'] as String? ?? 'No reason provided',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isActive': isActive,
      'level': level,
      'bannedByUid': bannedByUid,
      'bannedByName': bannedByName,
      'bannedByRole': bannedByRole,
      'reason': reason,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
