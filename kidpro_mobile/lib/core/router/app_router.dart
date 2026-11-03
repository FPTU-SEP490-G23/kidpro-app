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
import 'package:kidpro_mobile/features/parent/screens/face_registration_screen.dart';
import 'package:kidpro_mobile/features/teacher/screens/teacher_dashboard_screen.dart';
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
                path: 'chat/:threadId',
                builder: (_, state) => ChatDetailScreen(
                    threadId: state.pathParameters['threadId']!)),
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
          ],
        ),

        // ── Teacher routes (Full 18 use cases) ──
        GoRoute(
          path: '/teacher',
          builder: (_, __) => const TeacherDashboardScreen(),
          routes: [
            GoRoute(
                path: 'attendance',
                builder: (_, __) => const AttendanceScreen()),
            GoRoute(
                path: 'face-attendance',
                builder: (_, __) => const FaceAttendanceCameraScreen()),
            GoRoute(
                path: 'dismissal',
                builder: (_, __) => const DismissalAlertScreen()),
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
                path: 'chat',
                builder: (_, __) => const ClassChatRoomScreen()),
            GoRoute(
                path: 'journal',
                builder: (_, __) => const ClassroomJournalScreen()),
          ],
        ),
      ],
    );
