import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kidpro_mobile/core/constants/app_colors.dart';
import 'package:kidpro_mobile/features/auth/providers/auth_provider.dart';
import 'package:kidpro_mobile/features/auth/widgets/change_password_dialog.dart';
import 'package:kidpro_mobile/features/teacher/providers/teacher_provider.dart';

/// Tab "Tài khoản" của giáo viên: thông tin cá nhân, lớp phụ trách và đăng xuất.
class TeacherProfileScreen extends StatelessWidget {
  const TeacherProfileScreen({super.key});

  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Đăng xuất'),
        content: const Text('Cô có chắc chắn muốn đăng xuất khỏi ứng dụng KidPro Teacher không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Ở lại', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<AuthProvider>().logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final prov = context.watch<TeacherProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tài khoản giáo viên'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: () => prov.loadMyClasses(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Thông tin cá nhân
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: const Icon(Icons.school_rounded, color: Colors.white, size: 34),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.fullName ?? 'Giáo viên',
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        if (user != null && user.email.isNotEmpty)
                          Text(user.email, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
                        if (user?.phone != null)
                          Text(user!.phone!, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Giáo viên chủ nhiệm',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Lớp phụ trách
            const Text(
              'Lớp phụ trách',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primaryDark),
            ),
            const SizedBox(height: 8),
            if (prov.myClasses.isEmpty)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.info_outline, color: Colors.grey),
                  title: Text(prov.currentClassName),
                  subtitle: const Text('Chưa có phân công lớp trên hệ thống'),
                ),
              )
            else
              ...prov.myClasses.map((c) {
                final classId = c['classId']?.toString() ?? '';
                final selected = classId == prov.currentClassId;
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: selected ? AppColors.primary : Colors.grey.shade200,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.apartment_rounded, color: AppColors.primary),
                    title: Text(
                      c['className']?.toString() ?? 'Lớp học',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('${c['studentCount'] ?? 0} học sinh'),
                    trailing: selected
                        ? const Chip(
                            label: Text('Đang chọn', style: TextStyle(fontSize: 10, color: Colors.white)),
                            backgroundColor: AppColors.primary,
                          )
                        : OutlinedButton(
                            onPressed: classId.isEmpty ? null : () => prov.selectClass(classId),
                            child: const Text('Chọn', style: TextStyle(fontSize: 11)),
                          ),
                  ),
                );
              }),
            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => showChangePasswordDialog(context),
                icon: const Icon(Icons.lock_outline),
                label: const Text('Đổi mật khẩu', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _confirmLogout(context),
                icon: const Icon(Icons.logout),
                label: const Text('Đăng xuất tài khoản', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
