/// Centralized Firestore paths ensuring multi-tenant isolation.
class FirestorePaths {
  // Global collection for colleges
  static const String colleges = 'colleges';

  /// Global app-update config: config/appUpdate (institute-independent).
  static const String appUpdateConfigPath = 'config/appUpdate';

  // Global user index for quick tenant routing on authentication
  static const String globalUsers = 'users';

  // Subcollections under each college
  static String college(String collegeId) => 'colleges/$collegeId';
  static String users(String collegeId) => 'colleges/$collegeId/users';
  static String user(String collegeId, String uid) => 'colleges/$collegeId/users/$uid';

  static String departments(String collegeId) => 'colleges/$collegeId/departments';
  static String department(String collegeId, String deptId) => 'colleges/$collegeId/departments/$deptId';

  static String programs(String collegeId) => 'colleges/$collegeId/programs';
  static String program(String collegeId, String progId) => 'colleges/$collegeId/programs/$progId';

  static String batches(String collegeId) => 'colleges/$collegeId/batches';
  static String batch(String collegeId, String batchId) => 'colleges/$collegeId/batches/$batchId';

  static String sections(String collegeId) => 'colleges/$collegeId/sections';
  static String section(String collegeId, String sectionId) => 'colleges/$collegeId/sections/$sectionId';

  static String subjects(String collegeId) => 'colleges/$collegeId/subjects';
  static String subject(String collegeId, String subjectId) => 'colleges/$collegeId/subjects/$subjectId';

  static String faculties(String collegeId) => 'colleges/$collegeId/faculties';
  static String faculty(String collegeId, String facultyId) => 'colleges/$collegeId/faculties/$facultyId';

  static String classes(String collegeId) => 'colleges/$collegeId/classes';
  static String classDoc(String collegeId, String classId) => 'colleges/$collegeId/classes/$classId';

  static String timetable(String collegeId) => 'colleges/$collegeId/timetable';
  static String timetableEntry(String collegeId, String entryId) => 'colleges/$collegeId/timetable/$entryId';

  static String announcements(String collegeId) => 'colleges/$collegeId/announcements';
  static String announcement(String collegeId, String announcementId) => 'colleges/$collegeId/announcements/$announcementId';

  static String calendarEvents(String collegeId) => 'colleges/$collegeId/calendarEvents';
  static String calendarEvent(String collegeId, String eventId) => 'colleges/$collegeId/calendarEvents/$eventId';

  static String documents(String collegeId) => 'colleges/$collegeId/documents';
  static String document(String collegeId, String documentId) => 'colleges/$collegeId/documents/$documentId';

  static String auditLogs(String collegeId) => 'colleges/$collegeId/auditLogs';
  static String auditLog(String collegeId, String logId) => 'colleges/$collegeId/auditLogs/$logId';

  static String verificationRequests(String collegeId) => 'colleges/$collegeId/verificationRequests';
  static String verificationRequest(String collegeId, String requestId) => 'colleges/$collegeId/verificationRequests/$requestId';

  // Storage Paths
  static String storageCollegeLogo(String collegeId) => 'colleges/$collegeId/branding/logo';
  static String storageDocument(String collegeId, String docId, String fileName) => 'colleges/$collegeId/documents/$docId/$fileName';
}
