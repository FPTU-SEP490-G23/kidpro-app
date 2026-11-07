import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:kidpro_mobile/core/constants/app_colors.dart';
import 'package:kidpro_mobile/core/network/api_client.dart';
import 'package:kidpro_mobile/core/router/app_router.dart';
import 'package:kidpro_mobile/features/auth/providers/auth_provider.dart';
import 'package:kidpro_mobile/features/parent/providers/parent_provider.dart';
import 'package:kidpro_mobile/features/teacher/providers/teacher_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('vi', null);

  await ApiClient().init();

  final authProvider = AuthProvider();
  await authProvider.tryAutoLogin();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => ParentProvider()),
        ChangeNotifierProvider(create: (_) => TeacherProvider()),
      ],
      child: const KidProApp(),
    ),
  );
}

class KidProApp extends StatefulWidget {
  const KidProApp({super.key});

  @override
  State<KidProApp> createState() => _KidProAppState();
}

class _KidProAppState extends State<KidProApp> {
  // Tạo router đúng 1 lần. Trước đây router bị tạo lại mỗi khi AuthProvider thay đổi:
  // mất trạng thái điều hướng, trùng GlobalKey của navigator và có thể làm mất thanh điều hướng giáo viên.
  // Thay đổi đăng nhập/đăng xuất đã được xử lý qua refreshListenable trong appRouter.
  late final GoRouter _router = appRouter(context.read<AuthProvider>());

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = _router;

    return MaterialApp.router(
      title: 'KidPro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
