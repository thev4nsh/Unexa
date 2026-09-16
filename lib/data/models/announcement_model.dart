import 'package:cloud_firestore/cloud_firestore.dart';

/// Announcement model supporting college-wide and targeted notifications.
class AnnouncementModel {
  final String id;
  final String collegeId;
  final String title;
  final String body;
  final String authorName;
  final String targetScope; // 'all', 'department', 'batch', 'section'
  final List<String> targetIds;
  final bool isPublished;
  final DateTime? publishAt;
  final DateTime? expiresAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AnnouncementModel({
    required this.id,
    required this.collegeId,
    required this.title,
    required this.body,
    required this.authorName,
    this.targetScope = 'all',
    this.targetIds = const [],
    this.isPublished = true,
    this.publishAt,
    this.expiresAt,
    this.createdAt,
    this.updatedAt,
  });

  /// Check if an announcement applies to a given student's academic scope
  bool isRelevantForStudent({
    String? departmentId,
    String? batchId,
    String? sectionId,
  }) {
    if (targetScope == 'all') return true;
    if (targetScope == 'department' && departmentId != null) {
      return targetIds.contains(departmentId);
    }
    if (targetScope == 'batch' && batchId != null) {
      return targetIds.contains(batchId);
    }
    if (targetScope == 'section' && sectionId != null) {
      return targetIds.contains(sectionId);
    }
    return false;
  }

  factory AnnouncementModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AnnouncementModel(
      id: doc.id,
      collegeId: data['collegeId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      authorName: data['authorName'] as String? ?? 'Admin',
      targetScope: data['targetScope'] as String? ?? 'all',
      targetIds: List<String>.from(data['targetIds'] as List? ?? []),
      isPublished: data['isPublished'] as bool? ?? true,
      publishAt: (data['publishAt'] as Timestamp?)?.toDate(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'collegeId': collegeId,
      'title': title,
      'body': body,
      'authorName': authorName,
      'targetScope': targetScope,
      'targetIds': targetIds,
      'isPublished': isPublished,
      if (publishAt != null) 'publishAt': Timestamp.fromDate(publishAt!),
      if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt!),
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
