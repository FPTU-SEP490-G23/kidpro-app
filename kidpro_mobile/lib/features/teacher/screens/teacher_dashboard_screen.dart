import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:kidpro_mobile/core/constants/app_colors.dart';
import 'package:kidpro_mobile/features/auth/providers/auth_provider.dart';
import 'package:kidpro_mobile/features/teacher/providers/teacher_provider.dart';

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TeacherProvider>().loadStrangerAlerts();
      context.read<TeacherProvider>().loadDailyMedications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final teacherProv = context.watch<TeacherProvider>();
    final alertsCount = teacherProv.strangerAlerts.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('KidPro Teacher'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Cô ${user?.fullName ?? user?.email ?? ''}',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Giáo viên chủ nhiệm',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 16),

          // High-priority alert banner if stranger alerts exist
          if (alertsCount > 0) ...[
            InkWell(
              onTap: () => context.go('/teacher/dismissal'),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.strangerAlert.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.strangerAlert, width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: AppColors.strangerAlert,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CẢNH BÁO: Phát hiện $alertsCount người lạ!',
                            style: const TextStyle(
                              color: AppColors.strangerAlert,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Nhấn để kiểm tra và xác minh an toàn tại cổng trường.',
                            style: TextStyle(fontSize: 12, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.strangerAlert),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          Text('Nhiệm vụ trong ngày', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),

          _TeacherActionCard(
            title: 'Camera AI Điểm danh (Test)',
            subtitle: 'Quét nhận diện khuôn mặt kết nối AI Server',
            icon: Icons.camera_front,
            color: Colors.deepPurple,
            onTap: () => context.go('/teacher/face-attendance'),
          ),
          const SizedBox(height: 12),

          _TeacherActionCard(
            title: 'Điểm danh buổi sáng',
            subtitle: 'Danh sách lớp & lưu trạng thái',
            icon: Icons.how_to_reg,
            color: AppColors.primary,
            onTap: () => context.go('/teacher/attendance'),
          ),
          const SizedBox(height: 12),

          _TeacherActionCard(
            title: 'Quét đón trẻ & Cảnh báo',
            subtitle: 'Đối chiếu khuôn mặt người giám hộ đón trẻ',
            icon: Icons.face_retouching_natural,
            color: AppColors.error,
            onTap: () => context.go('/teacher/dismissal'),
          ),
          const SizedBox(height: 12),

          _TeacherActionCard(
            title: 'Cho uống thuốc (14:00)',
            subtitle: '${teacherProv.medications.where((m) => m.isPending).length} bé cần uống thuốc hôm nay',
            icon: Icons.medication_liquid,
            color: AppColors.success,
            onTap: () => context.go('/teacher/medication'),
          ),
        ],
      ),
    );
  }
}

class _TeacherActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _TeacherActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: onTap,
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 26),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      ),
    );
  }
}
