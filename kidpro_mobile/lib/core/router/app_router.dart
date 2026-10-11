import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:kidpro_mobile/features/auth/providers/auth_provider.dart';
import 'package:kidpro_mobile/features/auth/screens/login_screen.dart';
import 'package:kidpro_mobile/features/parent/screens/parent_dashboard_screen.dart';
import 'package:kidpro_mobile/features/parent/screens/invoices_screen.dart';
import 'package:kidpro_mobile/features/parent/screens/vietqr_payment_screen.dart';
import 'package:kidpro_mobile/features/parent/screens/leave_request_screen.dart';
import 'package:kidpro_mobile/features/parent/screens/medication_request_screen.dart';
import 'package:kidpro_mobile/features/parent/screens/chat_list_screen.dart';
import 'package:kidpro_mobile/features/parent/screens/chat_detail_screen.dart';
import 'package:kidpro_mobile/features/teacher/screens/teacher_dashboard_screen.dart';
import 'package:kidpro_mobile/features/teacher/screens/attendance_screen.dart';
import 'package:kidpro_mobile/features/teacher/screens/face_attendance_camera_screen.dart';
import 'package:kidpro_mobile/features/teacher/screens/dismissal_alert_screen.dart';
import 'package:kidpro_mobile/features/teacher/screens/medication_admin_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter appRouter(AuthProvider auth) => GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: '/teacher',
      refreshListenable: auth,
      redirect: (context, state) {
        // Cho phép truy cập trực tiếp các route mà không bắt buộc đăng nhập (test mode)
        final loggedIn = auth.status == AuthStatus.authenticated;
        final isLoginRoute = state.matchedLocation == '/login';

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
          ],
        ),

        // ── Teacher routes ──
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
          ],
        ),
      ],
    );
