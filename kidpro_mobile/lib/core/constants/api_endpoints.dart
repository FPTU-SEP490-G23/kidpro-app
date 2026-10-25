/// API endpoint constants matching KidPro Spring Boot backend.
class ApiEndpoints {
  ApiEndpoints._();

  // Auth
  static const login = '/api/auth/login';
  static const register = '/api/auth/register';
  static const refreshToken = '/api/auth/refresh-token';
  static const userMe = '/api/users/me';

  // Parent - Invoices & Payment
  static const parentInvoices = '/api/parents/invoices';
  static String parentInvoiceDetail(String id) =>
      '/api/parents/invoices/$id';
  static String parentInvoiceVietQr(String id) =>
      '/api/parents/invoices/$id/vietqr';
  static String parentInvoiceReceipt(String id) =>
      '/api/parents/invoices/$id/receipt';
  static String parentInvoiceDisputes(String id) =>
      '/api/parents/invoices/$id/disputes';

  // Parent - Leave Requests (G10-UC-08)
  static const parentLeaveRequests = '/api/parents/leave-requests';
  static String parentLeaveRequestCancel(int id) =>
      '/api/parents/leave-requests/$id';

  // Parent - Emergency Pickups (G5-UC-07)
  static const parentEmergencyPickups = '/api/parents/emergency-pickups';
  static String parentEmergencyPickupRevoke(int id) =>
      '/api/parents/emergency-pickups/$id/revoke';

  // Parent - Authorized Guardians (G4-UC-03)
  static const parentGuardians = '/api/parents/guardians';
  static String parentStudentGuardians(String studentId) =>
      '/api/parents/students/$studentId/guardians';
  static String parentGuardianRevoke(int id) =>
      '/api/parents/guardians/$id';

  // Parent - Medication Requests (G10-UC-01)
  static const parentMedications = '/api/parents/medications';
  static String parentMedicationCancel(int id) =>
      '/api/parents/medications/$id';

  // Parent - Allergies & Health Profile (G4-UC-06)
  static const parentAllergies = '/api/parents/allergies';
  static String parentAllergyDelete(int id) =>
      '/api/parents/allergies/$id';

  // Parent - Decree 13 Biometric Purge (UC-Decree13)
  static String parentBiometricPurgeOtp(String studentId) =>
      '/api/parents/students/$studentId/biometric-purge/request-otp';
  static String parentBiometricPurgeConfirm(String studentId) =>
      '/api/parents/students/$studentId/biometric-purge/confirm';

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
}
