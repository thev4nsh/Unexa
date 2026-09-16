import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_constants.dart';

/// Dynamic Timetable Entry model.
class TimetableEntryModel {
  final String id;
  final String collegeId;
  final String departmentId;
  final String batchId;
  final String? batchName;
  final String? sectionId;
  final String? sectionName;
  final String? subjectId;
  final int? year;
  final int? semester;
  final String subjectName;
  final String type; // class, lab
  final String? faculty;
  final String room; // e.g., Room 204, Lab 2
  final String day; // Monday, Tuesday, etc.
  final String startTime; // e.g., 10:00 AM
  final String endTime; // e.g., 11:00 AM
  final bool isActive;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TimetableEntryModel({
    required this.id,
    required this.collegeId,
    required this.departmentId,
    required this.batchId,
    this.batchName,
    this.sectionId,
    this.sectionName,
    this.subjectId,
    this.year,
    this.semester,
    required this.subjectName,
    this.type = AppConstants.timetableTypeClass,
    this.faculty,
    required this.room,
    required this.day,
    required this.startTime,
    required this.endTime,
    this.isActive = true,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  bool get isLab => type.toLowerCase() == AppConstants.timetableTypeLab;
  bool get isClass => !isLab;

  factory TimetableEntryModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return TimetableEntryModel(
      id: doc.id,
      collegeId: data['collegeId'] as String? ?? '',
      departmentId: data['departmentId'] as String? ?? '',
      batchId: data['batchId'] as String? ?? '',
      batchName: data['batchName'] as String?,
      sectionId: data['sectionId'] as String?,
      sectionName: data['sectionName'] as String?,
      subjectId: data['subjectId'] as String?,
      year: data['year'] as int?,
      semester: data['semester'] as int?,
      subjectName: data['subjectName'] as String? ?? 'Subject',
      type: data['type'] as String? ?? AppConstants.timetableTypeClass,
      faculty: data['faculty'] as String?,
      room: data['room'] as String? ?? 'TBD',
      day: data['day'] as String? ?? 'Monday',
      startTime: data['startTime'] as String? ?? '09:00 AM',
      endTime: data['endTime'] as String? ?? '10:00 AM',
      isActive: data['isActive'] as bool? ?? true,
      createdBy: data['createdBy'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'collegeId': collegeId,
      'departmentId': departmentId,
      'batchId': batchId,
      if (batchName != null) 'batchName': batchName,
      if (sectionId != null) 'sectionId': sectionId,
      if (sectionName != null) 'sectionName': sectionName,
      if (subjectId != null) 'subjectId': subjectId,
      if (year != null) 'year': year,
      if (semester != null) 'semester': semester,
      'subjectName': subjectName,
      'type': type,
      if (faculty != null) 'faculty': faculty,
      'room': room,
      'day': day,
      'startTime': startTime,
      'endTime': endTime,
      'isActive': isActive,
      if (createdBy != null) 'createdBy': createdBy,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  TimetableEntryModel copyWith({
    String? id,
    String? collegeId,
    String? departmentId,
    String? batchId,
    String? batchName,
    String? sectionId,
    String? sectionName,
    String? subjectId,
    int? year,
    int? semester,
    String? subjectName,
    String? type,
    String? faculty,
    String? room,
    String? day,
    String? startTime,
    String? endTime,
    bool? isActive,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TimetableEntryModel(
      id: id ?? this.id,
      collegeId: collegeId ?? this.collegeId,
      departmentId: departmentId ?? this.departmentId,
      batchId: batchId ?? this.batchId,
      batchName: batchName ?? this.batchName,
      sectionId: sectionId ?? this.sectionId,
      sectionName: sectionName ?? this.sectionName,
      subjectId: subjectId ?? this.subjectId,
      year: year ?? this.year,
      semester: semester ?? this.semester,
      subjectName: subjectName ?? this.subjectName,
      type: type ?? this.type,
      faculty: faculty ?? this.faculty,
      room: room ?? this.room,
      day: day ?? this.day,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isActive: isActive ?? this.isActive,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
