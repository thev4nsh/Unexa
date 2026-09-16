import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_constants.dart';

/// Multi-tenant College / Institute configuration model.
class CollegeModel {
  final String id;
  final String name;
  final String? logoUrl;
  final String primaryColorHex;
  final String secondaryColorHex;
  final List<String> allowedEmailDomains;
  final String timezone;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CollegeModel({
    required this.id,
    required this.name,
    this.logoUrl,
    this.primaryColorHex = '#1E3A8A',
    this.secondaryColorHex = '#0D9488',
    this.allowedEmailDomains = const [],
    this.timezone = AppConstants.defaultTimezone,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory CollegeModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return CollegeModel(
      id: doc.id,
      name: data['name'] as String? ?? 'Campus',
      logoUrl: data['logoUrl'] as String?,
      primaryColorHex: data['primaryColorHex'] as String? ?? '#1E3A8A',
      secondaryColorHex: data['secondaryColorHex'] as String? ?? '#0D9488',
      allowedEmailDomains: List<String>.from(data['allowedEmailDomains'] as List? ?? []),
      timezone: data['timezone'] as String? ?? AppConstants.defaultTimezone,
      isActive: data['isActive'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      if (logoUrl != null) 'logoUrl': logoUrl,
      'primaryColorHex': primaryColorHex,
      'secondaryColorHex': secondaryColorHex,
      'allowedEmailDomains': allowedEmailDomains,
      'timezone': timezone,
      'isActive': isActive,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  CollegeModel copyWith({
    String? id,
    String? name,
    String? logoUrl,
    String? primaryColorHex,
    String? secondaryColorHex,
    List<String>? allowedEmailDomains,
    String? timezone,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CollegeModel(
      id: id ?? this.id,
      name: name ?? this.name,
      logoUrl: logoUrl ?? this.logoUrl,
      primaryColorHex: primaryColorHex ?? this.primaryColorHex,
      secondaryColorHex: secondaryColorHex ?? this.secondaryColorHex,
      allowedEmailDomains: allowedEmailDomains ?? this.allowedEmailDomains,
      timezone: timezone ?? this.timezone,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
