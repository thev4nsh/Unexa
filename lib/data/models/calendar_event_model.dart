import 'package:cloud_firestore/cloud_firestore.dart';

/// Academic Calendar Event model (Holiday, Exam, Event).
class CalendarEventModel {
  final String id;
  final String collegeId;
  final String title;
  final String? description;
  final DateTime date;
  final String? startTime;
  final String? endTime;
  final String type; // holiday, exam, academic, event
  final String? targetScope; // all, cse, 2025, etc.
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CalendarEventModel({
    required this.id,
    required this.collegeId,
    required this.title,
    this.description,
    required this.date,
    this.startTime,
    this.endTime,
    required this.type,
    this.targetScope = 'all',
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  bool get isHoliday => type.toLowerCase() == 'holiday';
  bool get isExam => type.toLowerCase() == 'exam';

  factory CalendarEventModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return CalendarEventModel(
      id: doc.id,
      collegeId: data['collegeId'] as String? ?? '',
      title: data['title'] as String? ?? 'Event',
      description: data['description'] as String?,
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      startTime: data['startTime'] as String?,
      endTime: data['endTime'] as String?,
      type: data['type'] as String? ?? 'event',
      targetScope: data['targetScope'] as String? ?? 'all',
      createdBy: data['createdBy'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'collegeId': collegeId,
      'title': title,
      if (description != null) 'description': description,
      'date': Timestamp.fromDate(date),
      if (startTime != null) 'startTime': startTime,
      if (endTime != null) 'endTime': endTime,
      'type': type,
      'targetScope': targetScope ?? 'all',
      if (createdBy != null) 'createdBy': createdBy,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
