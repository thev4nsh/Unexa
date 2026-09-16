/// Core constants for UNEXA Platform.
class AppConstants {
  static const String appName = 'UNEXA';
  static const String appTagline = 'Your Campus. One Place.';

  // Default Timezone
  static const String defaultTimezone = 'Asia/Kolkata';

  // Role Constants
  static const String roleOwner = 'owner';
  static const String roleAdmin = 'admin';
  static const String roleCoAdmin = 'co_admin';
  static const String roleModerator = 'moderator';
  static const String roleCr = 'cr';
  static const String roleStudent = 'student';

  // Account Status Constants
  static const String statusActive = 'active';
  static const String statusPending = 'pending';
  static const String statusRejected = 'rejected';
  static const String statusSuspended = 'suspended';
  static const String statusBanned = 'banned';

  // Ban Levels
  static const String banLevelModerator = 'moderator';
  static const String banLevelAdmin = 'admin';
  static const String banLevelOwner = 'owner';

  // Timetable Types
  static const String timetableTypeClass = 'class';
  static const String timetableTypeLab = 'lab';

  // Document Types
  static const String docTypeTimetablePdf = 'timetable_pdf';
  static const String docTypeHolidayPdf = 'holiday_pdf';
  static const String docTypeAcademicHandbook = 'handbook_pdf';

  // Audit Actions
  static const String auditAdminApprovedStudent = 'ADMIN_APPROVED_STUDENT';
  static const String auditAdminRejectedStudent = 'ADMIN_REJECTED_STUDENT';
  static const String auditAdminBannedStudent = 'ADMIN_BANNED_STUDENT';
  static const String auditAdminUnbannedStudent = 'ADMIN_UNBANNED_STUDENT';
  static const String auditCoAdminApprovedStudent = 'CO_ADMIN_APPROVED_STUDENT';
  static const String auditCoAdminRejectedStudent = 'CO_ADMIN_REJECTED_STUDENT';
  static const String auditModeratorApprovedStudent = 'MODERATOR_APPROVED_STUDENT';
  static const String auditModeratorRejectedStudent = 'MODERATOR_REJECTED_STUDENT';
  static const String auditModeratorBannedStudent = 'MODERATOR_BANNED_STUDENT';
  static const String auditModeratorUnbannedStudent = 'MODERATOR_UNBANNED_STUDENT';
  static const String auditModeratorSuspendedRequest = 'MODERATOR_SUSPENDED_REQUEST';
  static const String auditRoleChanged = 'ROLE_CHANGED';
  static const String auditTimetableCreated = 'TIMETABLE_CREATED';
  static const String auditTimetableUpdated = 'TIMETABLE_UPDATED';
  static const String auditTimetableDeleted = 'TIMETABLE_DELETED';
  static const String auditAnnouncementCreated = 'ANNOUNCEMENT_CREATED';
  static const String auditAnnouncementUpdated = 'ANNOUNCEMENT_UPDATED';
  static const String auditAnnouncementDeleted = 'ANNOUNCEMENT_DELETED';
  static const String auditCalendarEventCreated = 'CALENDAR_EVENT_CREATED';
  static const String auditCalendarEventUpdated = 'CALENDAR_EVENT_UPDATED';
  static const String auditCalendarEventDeleted = 'CALENDAR_EVENT_DELETED';
  static const String auditDocumentUploaded = 'DOCUMENT_UPLOADED';
  static const String auditDocumentReplaced = 'DOCUMENT_REPLACED';
  static const String auditDocumentDeleted = 'DOCUMENT_DELETED';
  static const String auditBrandingUpdated = 'BRANDING_UPDATED';
}
