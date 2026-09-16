import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_constants.dart';

/// Official College Document metadata model (Timetable PDF, Holiday List PDF).
class DocumentModel {
  final String id;
  final String collegeId;
  final String type; // timetable_pdf, holiday_pdf
  final String title;
  final String storagePath;
  final String downloadUrl;
  final int version;
  final String? uploadedBy;
  final DateTime? uploadedAt;
  final bool isActive;

  const DocumentModel({
    required this.id,
    required this.collegeId,
    required this.type,
    required this.title,
    required this.storagePath,
    required this.downloadUrl,
    this.version = 1,
    this.uploadedBy,
    this.uploadedAt,
    this.isActive = true,
  });

  bool get isTimetablePdf => type == AppConstants.docTypeTimetablePdf;
  bool get isHolidayPdf => type == AppConstants.docTypeHolidayPdf;

  factory DocumentModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return DocumentModel(
      id: doc.id,
      collegeId: data['collegeId'] as String? ?? '',
      type: data['type'] as String? ?? AppConstants.docTypeTimetablePdf,
      title: data['title'] as String? ?? 'Document',
      storagePath: data['storagePath'] as String? ?? '',
      downloadUrl: data['downloadUrl'] as String? ?? '',
      version: data['version'] as int? ?? 1,
      uploadedBy: data['uploadedBy'] as String?,
      uploadedAt: (data['uploadedAt'] as Timestamp?)?.toDate(),
      isActive: data['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'collegeId': collegeId,
      'type': type,
      'title': title,
      'storagePath': storagePath,
      'downloadUrl': downloadUrl,
      'version': version,
      if (uploadedBy != null) 'uploadedBy': uploadedBy,
      'uploadedAt': uploadedAt != null ? Timestamp.fromDate(uploadedAt!) : FieldValue.serverTimestamp(),
      'isActive': isActive,
    };
  }
}
