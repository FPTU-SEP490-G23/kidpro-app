import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kidpro_mobile/features/auth/providers/auth_provider.dart';
import 'package:kidpro_mobile/features/auth/screens/login_screen.dart';
import 'package:kidpro_mobile/features/parent/screens/parent_dashboard_screen.dart';
import 'package:kidpro_mobile/features/parent/screens/invoices_screen.dart';
import 'package:kidpro_mobile/features/parent/screens/vietqr_payment_screen.dart';
import 'package:kidpro_mobile/features/parent/screens/leave_request_screen.dart';
import 'package:kidpro_mobile/features/parent/screens/medication_request_screen.dart';
import 'package:kidpro_mobile/features/parent/screens/chat_list_screen.dart';
import 'package:kidpro_mobile/features/parent/screens/chat_detail_screen.dart';
import 'package:kidpro_mobile/features/parent/screens/emergency_pickup_screen.dart';
import 'package:kidpro_mobile/features/parent/screens/authorized_guardians_screen.dart';
import 'package:kidpro_mobile/features/parent/screens/allergy_profile_screen.dart';
import 'package:kidpro_mobile/features/parent/screens/biometric_purge_screen.dart';
import 'package:kidpro_mobile/features/parent/screens/records_overview_screen.dart';
import 'package:kidpro_mobile/features/parent/screens/requests_overview_screen.dart';
import 'package:kidpro_mobile/features/parent/screens/request_center_screen.dart';
import 'package:kidpro_mobile/features/parent/screens/parent_notification_screen.dart';
import 'package:kidpro_mobile/features/parent/screens/pickup_face_registration_screen.dart';
import 'package:kidpro_mobile/features/parent/screens/face_registration_screen.dart';
import 'package:kidpro_mobile/features/teacher/screens/teacher_dashboard_screen.dart';
import 'package:kidpro_mobile/features/teacher/screens/teacher_profile_screen.dart';
import 'package:kidpro_mobile/features/teacher/screens/teacher_shell_screen.dart';
import 'package:kidpro_mobile/features/teacher/screens/attendance_screen.dart';
import 'package:kidpro_mobile/features/teacher/screens/face_attendance_camera_screen.dart';
import 'package:kidpro_mobile/features/teacher/screens/dismissal_alert_screen.dart';
import 'package:kidpro_mobile/features/teacher/screens/medication_admin_screen.dart';
import 'package:kidpro_mobile/features/teacher/screens/bus_attendance_screen.dart';
import 'package:kidpro_mobile/features/teacher/screens/health_metrics_screen.dart';
import 'package:kidpro_mobile/features/teacher/screens/health_incidents_screen.dart';
import 'package:kidpro_mobile/features/teacher/screens/daily_activity_screen.dart';
import 'package:kidpro_mobile/features/teacher/screens/lesson_plan_screen.dart';
import 'package:kidpro_mobile/features/teacher/screens/development_evaluation_screen.dart';
import 'package:kidpro_mobile/features/teacher/screens/equipment_incident_screen.dart';
import 'package:kidpro_mobile/features/teacher/screens/leave_request_review_screen.dart';
import 'package:kidpro_mobile/features/teacher/screens/class_chat_room_screen.dart';
import 'package:kidpro_mobile/features/teacher/screens/classroom_journal_screen.dart';
import 'package:kidpro_mobile/features/teacher/screens/extracurricular_attendance_screen.dart';
import 'package:kidpro_mobile/features/teacher/screens/class_announcement_screen.dart';
import 'package:kidpro_mobile/features/parent/screens/daily_menu_screen.dart';
import 'package:kidpro_mobile/features/parent/screens/class_announcements_screen.dart';
import 'package:kidpro_mobile/features/parent/screens/withdrawal_request_screen.dart';
import 'package:kidpro_mobile/features/parent/screens/survey_screens.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter appRouter(AuthProvider auth) => GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: '/login',
      refreshListenable: auth,
      redirect: (context, state) {
        final loggedIn = auth.status == AuthStatus.authenticated;
        final isLoginRoute = state.matchedLocation == '/login';

        if (!loggedIn && !isLoginRoute) {
          return '/login';
        }
        if (loggedIn && isLoginRoute) {
          return auth.isParent ? '/parent' : '/teacher';
        }
        // Chặn truy cập chéo khu vực theo vai trò (RBAC phía app)
        final loc = state.matchedLocation;
        if (loggedIn && auth.isParent && loc.startsWith('/teacher')) return '/parent';
        if (loggedIn && !auth.isParent && loc.startsWith('/parent')) return '/teacher';
        return null;
      },
      routes: [
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),

        // ── Parent routes ──
        GoRoute(
          path: '/parent',
          builder: (_, __) => const ParentDashboardScreen(),
          routes: [
            GoRoute(
                path: 'invoices',
                builder: (_, __) => const InvoicesScreen()),
            GoRoute(
                path: 'invoices/:id/pay',
                builder: (_, state) => VietQrPaymentScreen(
                    invoiceId: state.pathParameters['id']!)),
            GoRoute(
                path: 'leave',
                builder: (_, __) => const LeaveRequestScreen()),
            GoRoute(
                path: 'medication',
                builder: (_, __) => const MedicationRequestScreen()),
            GoRoute(
                path: 'chat',
                builder: (_, __) => const ChatListScreen()),
            GoRoute(
                path: 'chat/private/:studentId',
                builder: (_, state) => ChatDetailScreen(
                    threadId: state.pathParameters['studentId']!,
                    isPrivate: true,
                    title: state.uri.queryParameters['title'])),
            GoRoute(
                path: 'chat/:threadId',
                builder: (_, state) => ChatDetailScreen(
                    threadId: state.pathParameters['threadId']!,
                    title: state.uri.queryParameters['title'])),
            GoRoute(
                path: 'emergency-pickup',
                builder: (_, __) => const EmergencyPickupScreen()),
            GoRoute(
                path: 'guardians',
                builder: (_, __) => const AuthorizedGuardiansScreen()),
            GoRoute(
                path: 'allergies',
                builder: (_, __) => const AllergyProfileScreen()),
            GoRoute(
                path: 'biometric-purge',
                builder: (_, __) => const BiometricPurgeScreen()),
            GoRoute(
                path: 'face-registration',
                builder: (_, __) => const FaceRegistrationScreen()),
            GoRoute(
                path: 'records',
                builder: (_, __) => const RecordsOverviewScreen()),
            GoRoute(
                path: 'requests',
                builder: (_, __) => const RequestsOverviewScreen()),
            GoRoute(
                path: 'requests/center',
                builder: (_, __) => const RequestCenterScreen()),
            GoRoute(
                path: 'notifications',
                builder: (_, __) => const ParentNotificationScreen()),
            GoRoute(
                path: 'pickup-faces',
                builder: (_, __) => const PickupFaceRegistrationScreen()),
            GoRoute(
                path: 'daily-menu',
                builder: (_, __) => const DailyMenuScreen()),
            GoRoute(
                path: 'class-announcements',
                builder: (_, __) => const ClassAnnouncementsScreen()),
            GoRoute(
                path: 'withdrawal',
                builder: (_, __) => const WithdrawalRequestScreen()),
            GoRoute(
                path: 'surveys',
                builder: (_, state) =>
                    SurveyListScreen(openTitle: state.uri.queryParameters['open'])),
            GoRoute(
                path: 'surveys/:id',
                builder: (_, state) => SurveyFillScreen(surveyId: state.pathParameters['id']!)),
          ],
        ),

        // ── Teacher routes: thanh điều hướng dưới 5 tab ──
        StatefulShellRoute.indexedStack(
          builder: (_, __, navigationShell) => TeacherShellScreen(navigationShell: navigationShell),
          branches: [
            // Tab 0: Trang chủ + các chức năng mở từ Dashboard (vẫn hiện thanh điều hướng)
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/teacher',
                builder: (_, __) => const TeacherDashboardScreen(),
                routes: [
                  // Camera quét mặt điểm danh: toàn màn hình, che thanh điều hướng
                  GoRoute(
                      path: 'face-attendance',
                      parentNavigatorKey: _rootNavigatorKey,
                      builder: (_, __) => const FaceAttendanceCameraScreen()),
                  GoRoute(
                      path: 'medication',
                      builder: (_, __) => const MedicationAdminScreen()),
                  GoRoute(
                      path: 'bus',
                      builder: (_, __) => const BusAttendanceScreen()),
                  GoRoute(
                      path: 'health-metrics',
                      builder: (_, __) => const HealthMetricsScreen()),
                  GoRoute(
                      path: 'health-incidents',
                      builder: (_, __) => const HealthIncidentsScreen()),
                  GoRoute(
                      path: 'daily-activity',
                      builder: (_, __) => const DailyActivityScreen()),
                  GoRoute(
                      path: 'lesson-plans',
                      builder: (_, __) => const LessonPlanScreen()),
                  GoRoute(
                      path: 'evaluations',
                      builder: (_, __) => const DevelopmentEvaluationScreen()),
                  GoRoute(
                      path: 'equipment',
                      builder: (_, __) => const EquipmentIncidentScreen()),
                  GoRoute(
                      path: 'leave-requests',
                      builder: (_, __) => const LeaveRequestReviewScreen()),
                  GoRoute(
                      path: 'notifications',
                      builder: (_, __) => const ParentNotificationScreen()),
                  GoRoute(
                      path: 'journal',
                      builder: (_, __) => const ClassroomJournalScreen()),
                  GoRoute(
                      path: 'class-announcements',
                      builder: (_, __) => const ClassAnnouncementScreen()),
                  GoRoute(
                      path: 'extracurricular-attendance',
                      builder: (_, __) => const ExtracurricularAttendanceScreen()),
                ],
              ),
            ]),
            // Tab 1: Điểm danh
            StatefulShellBranch(routes: [
              GoRoute(
                  path: '/teacher/attendance',
                  builder: (_, __) => const AttendanceScreen()),
            ]),
            // Tab 2: Tan học (trả trẻ, đón hộ, người lạ, đón muộn)
            StatefulShellBranch(routes: [
              GoRoute(
                  path: '/teacher/dismissal',
                  builder: (_, __) => const DismissalAlertScreen()),
            ]),
            // Tab 3: Nhóm lớp
            StatefulShellBranch(routes: [
              GoRoute(
                  path: '/teacher/chat',
                  builder: (_, __) => const ClassChatRoomScreen()),
            ]),
            // Tab 4: Tài khoản
            StatefulShellBranch(routes: [
              GoRoute(
                  path: '/teacher/profile',
                  builder: (_, __) => const TeacherProfileScreen()),
            ]),
          ],
        ),
      ],
    );
