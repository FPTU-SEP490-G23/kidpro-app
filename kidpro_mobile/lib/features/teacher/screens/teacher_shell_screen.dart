import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:kidpro_mobile/core/constants/app_colors.dart';
import 'package:kidpro_mobile/features/teacher/providers/teacher_provider.dart';

/// Khung chứa thanh điều hướng dưới cho vai trò Giáo viên.
/// Mỗi tab là một nhánh của StatefulShellRoute, giữ nguyên trạng thái khi chuyển tab.
class TeacherShellScreen extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const TeacherShellScreen({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    final strangerAlerts = context.watch<TeacherProvider>().strangerAlerts.length;
    final index = navigationShell.currentIndex;

    return PopScope(
      // Nút Back ở tab khác Trang chủ: quay về Trang chủ thay vì thoát app
      canPop: index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) navigationShell.goBranch(0);
      },
      child: Scaffold(
        body: navigationShell,
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: index,
          // Bấm lại tab đang mở: quay về màn gốc của tab
          onTap: (i) => navigationShell.goBranch(i, initialLocation: i == index),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: Colors.grey.shade500,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Trang chủ',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.how_to_reg_outlined),
              activeIcon: Icon(Icons.how_to_reg_rounded),
              label: 'Điểm danh',
            ),
            BottomNavigationBarItem(
              icon: Badge(
                isLabelVisible: strangerAlerts > 0,
                label: Text('$strangerAlerts'),
                child: const Icon(Icons.family_restroom_outlined),
              ),
              activeIcon: Badge(
                isLabelVisible: strangerAlerts > 0,
                label: Text('$strangerAlerts'),
                child: const Icon(Icons.family_restroom_rounded),
              ),
              label: 'Tan học',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.forum_outlined),
              activeIcon: Icon(Icons.forum_rounded),
              label: 'Nhóm lớp',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Tài khoản',
            ),
          ],
        ),
      ),
    );
  }
}
