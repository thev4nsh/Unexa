import 'package:cloud_firestore/cloud_firestore.dart';

/// Dynamic Department model (e.g., Computer Science & Engineering).
class DepartmentModel {
  final String id;
  final String collegeId;
  final String name;
  final String code;

  const DepartmentModel({
    required this.id,
    required this.collegeId,
    required this.name,
    required this.code,
  });

  // Identity by id — Firestore streams re-emit NEW instances on every
  // snapshot; dropdowns match the selected value against list items and
  // would crash (red assertion screen) without value-based equality.
  @override
  bool operator ==(Object other) => other is DepartmentModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  factory DepartmentModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return DepartmentModel(
      id: doc.id,
      collegeId: data['collegeId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      code: data['code'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'collegeId': collegeId,
        'name': name,
        'code': code,
      };
}

/// Dynamic Batch model (e.g., 2025, 2026).
class BatchModel {
  final String id;
  final String collegeId;
  final String? departmentId;
  final String name;

  const BatchModel({
    required this.id,
    required this.collegeId,
    this.departmentId,
    required this.name,
  });

  @override
  bool operator ==(Object other) => other is BatchModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  factory BatchModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return BatchModel(
      id: doc.id,
      collegeId: data['collegeId'] as String? ?? '',
      departmentId: data['departmentId'] as String?,
      name: data['name'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'collegeId': collegeId,
        if (departmentId != null) 'departmentId': departmentId,
        'name': name,
      };
}

/// Dynamic Section model (e.g., Section A, Section B).
class SectionModel {
  final String id;
  final String collegeId;
  final String? batchId;
  final String name;

  const SectionModel({
    required this.id,
    required this.collegeId,
    this.batchId,
    required this.name,
  });

  @override
  bool operator ==(Object other) => other is SectionModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  factory SectionModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return SectionModel(
      id: doc.id,
      collegeId: data['collegeId'] as String? ?? '',
      batchId: data['batchId'] as String?,
      name: data['name'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'collegeId': collegeId,
        if (batchId != null) 'batchId': batchId,
        'name': name,
      };
}

/// Dynamic Subject model (e.g., Database Management Systems).
class SubjectModel {
  final String id;
  final String collegeId;
  final String? departmentId;
  final String name;
  final String? code;

  const SubjectModel({
    required this.id,
    required this.collegeId,
    this.departmentId,
    required this.name,
    this.code,
  });

  @override
  bool operator ==(Object other) => other is SubjectModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  factory SubjectModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return SubjectModel(
      id: doc.id,
      collegeId: data['collegeId'] as String? ?? '',
      departmentId: data['departmentId'] as String?,
      name: data['name'] as String? ?? '',
      code: data['code'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'collegeId': collegeId,
        if (departmentId != null) 'departmentId': departmentId,
        'name': name,
        if (code != null) 'code': code,
      };
}

/// Faculty member on the institute roster — picked from a searchable list
/// when adding timetable classes instead of typing the name every time.
class FacultyModel {
  final String id;
  final String collegeId;
  final String name;
  final String? departmentId;
  final String? departmentName;

  const FacultyModel({
    required this.id,
    required this.collegeId,
    required this.name,
    this.departmentId,
    this.departmentName,
  });

  // Identity by id — Firestore streams re-emit NEW instances on every
  // snapshot; pickers match the selected value against list items and
  // would crash without value-based equality.
  @override
  bool operator ==(Object other) => other is FacultyModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  factory FacultyModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return FacultyModel(
      id: doc.id,
      collegeId: data['collegeId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      departmentId: data['departmentId'] as String?,
      departmentName: data['departmentName'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'collegeId': collegeId,
        'name': name,
        if (departmentId != null && departmentId!.isNotEmpty)
          'departmentId': departmentId,
        if (departmentName != null && departmentName!.isNotEmpty)
          'departmentName': departmentName,
      };
}
