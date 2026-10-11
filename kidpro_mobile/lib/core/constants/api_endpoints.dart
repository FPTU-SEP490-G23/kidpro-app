/// API endpoint constants matching KidPro Spring Boot backend.
class ApiEndpoints {
  ApiEndpoints._();

  // Auth
  static const login = '/api/auth/login';
  static const register = '/api/auth/register';
  static const refreshToken = '/api/auth/refresh-token';
  static const userMe = '/api/users/me';

  // Parent
  static const parentInvoices = '/api/parents/invoices';
  static String parentInvoiceVietQr(String id) =>
      '/api/parents/invoices/$id/vietqr';
  static String parentInvoiceDisputes(String id) =>
      '/api/parents/invoices/$id/disputes';
  static const parentLeaveRequests = '/api/parents/leave-requests';
  static const parentMedications = '/api/parents/medications';
  static String parentStudentMedications(String studentId) =>
      '/api/parents/students/$studentId/medications';
  static String parentStudentGuardians(String studentId) =>
      '/api/parents/students/$studentId/guardians';
  static const parentEmergencyPickups = '/api/parents/emergency-pickups';

  // Teacher
  static String teacherClassStudents(String classId) =>
      '/api/teachers/classes/$classId/students';
  static const teacherAttendanceBatch = '/api/teachers/attendance/batch';

  // Attendance / Face Recognition
  static const faceLogs = '/api/attendance/face-logs';
  static const faceLogsUnresolved = '/api/attendance/face-logs/unresolved-alerts';
  static String faceLogResolve(String id) =>
      '/api/attendance/face-logs/$id/resolve-alert';

  // Health
  static const medications = '/api/health/medications';
  static String medicationAdminister(String id) =>
      '/api/health/medications/$id/administer';
  static const mealRecords = '/api/health/meal-records';
  static const napRecords = '/api/health/nap-records';
  static const journalPosts = '/api/health/journal-posts';
  static String journalPostsByClass(String classId) =>
      '/api/health/journal-posts/class/$classId';

  // Chat
  static const chatThreads = '/api/chat/threads';
  static String chatMessages(String threadId) =>
      '/api/chat/threads/$threadId/messages';
  static String chatMarkRead(String threadId) =>
      '/api/chat/threads/$threadId/read';

  // Notifications
  static const notifications = '/api/notifications';
  static const notificationsFcmToken = '/api/notifications/fcm-token';
  static const notificationsUnreadCount = '/api/notifications/unread-count';

  // Finance
  static String financeInvoiceVietQr(String id) =>
      '/api/finance/invoices/$id/vietqr';
}
