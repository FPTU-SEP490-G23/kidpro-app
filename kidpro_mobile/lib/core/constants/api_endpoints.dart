/// API endpoint constants matching KidPro Spring Boot backend.
class ApiEndpoints {
  ApiEndpoints._();

  // Auth
  static const login = '/api/auth/login';
  static const register = '/api/auth/register';
  static const refreshToken = '/api/auth/refresh-token';
  static const userMe = '/api/auth/me';

  // Parent - Students (Children)
  static const parentStudents = '/api/parents/students';

  // Parent - Electronic Records (6 Sổ điện tử)
  static String parentDailyActivities(String studentId) =>
      '/api/parents/students/$studentId/daily-activities';
  static String parentAttendances(String studentId) =>
      '/api/parents/students/$studentId/attendances';
  static String parentEvaluations(String studentId) =>
      '/api/parents/students/$studentId/evaluations';
  static String parentGrowthHistory(String studentId) =>
      '/api/health/metrics/student/$studentId/growth-history';
  static String parentJournalPosts(String classId) =>
      '/api/health/journal-posts/class/$classId';

  // Parent - Unified Requests & Forms (11 loại đơn từ)
  static String parentAllRequests(String studentId) =>
      '/api/parents/students/$studentId/all-requests';
  static const parentClassTransfer = '/api/parents/class-transfer-requests';
  static const parentBusRegister = '/api/parents/bus-registers';
  static const parentExtracurricularRegister = '/api/parents/extracurricular-registers';
  static const parentOtherRequest = '/api/parents/other-requests';
  static const parentAvailableClasses = '/api/parents/available-classes';
  static const parentAvailableBuses = '/api/parents/available-buses';
  static const parentAvailableExtracurricular = '/api/parents/available-extracurricular';

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
  static String teacherDailyCheckin(String classId) =>
      '/api/attendance/class/$classId/daily-checkin';
  static String teacherDailyDismissal(String classId) =>
      '/api/attendance/class/$classId/daily-dismissal';

  // Bus Attendance (G5-UC-02, G5-UC-03, BR-024)
  static const busCheckin = '/api/attendance/bus/stops/checkin';
  static String busSafetyClosure(String tripId) =>
      '/api/attendance/bus/trips/$tripId/safety-closure';

  // Late Pickup & Progressive Fee (G5-UC-05, BR-020)
  static const latePickupRecord = '/api/attendance/late-pickups/record';
  static const latePickupRules = '/api/admin/late-pickup-rules';

  // Health Metrics (WHO) (G8-UC-03, BR-031)
  static const healthMetricsBatch = '/api/health/metrics/batch';
  static String healthMetricsEntrySheet(String classId) =>
      '/api/health/metrics/class/$classId/entry-sheet';
  static String healthMetricsGrowthHistory(String studentId) =>
      '/api/health/metrics/student/$studentId/growth-history';

  // Health Incidents (G8-UC-04, BR-031)
  static const healthIncidents = '/api/health/incidents';
  static String healthIncidentsByStudent(String studentId) =>
      '/api/health/incidents/student/$studentId';
  static String healthIncidentResolve(int id) =>
      '/api/health/incidents/$id/resolve';

  // Lesson Plans (G9-UC-01, BR-053)
  static const lessonPlans = '/api/academic/lesson-plans';
  static String lessonPlansByClass(String classId) =>
      '/api/academic/lesson-plans/class/$classId';

  // Development Evaluations (G9-UC-04, BR-049)
  static const developmentEvaluations = '/api/academic/development-evaluations';
  static String developmentEvaluationsByClass(String classId) =>
      '/api/academic/development-evaluations/class/$classId';

  // Classroom Equipment Incidents (G9-UC-06, BR-051, BR-052)
  static const equipmentIncidents = '/api/academic/equipment/incidents';
  static String equipmentIncidentsByClass(String classroomId) =>
      '/api/academic/equipment/incidents/class/$classroomId';

  // Teacher Leave Request Review (G10-UC-09, BR-064, BR-065)
  static const teacherLeaveRequests = '/api/teachers/leave-requests';
  static String teacherLeaveRequestReview(int id) =>
      '/api/teachers/leave-requests/$id';

  // Announcements (G11-UC-02, BR-056)
  static const announcements = '/api/comms/announcements';
  static String announcementDetail(int id) =>
      '/api/comms/announcements/$id';

  // Class Chat (G11-UC-04, BR-058, BR-059)
  static String classChatMessages(String classId) =>
      '/api/comms/chat/rooms/$classId/messages';
  static String classChatLock(String classId) =>
      '/api/comms/chat/rooms/$classId/lock';

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
