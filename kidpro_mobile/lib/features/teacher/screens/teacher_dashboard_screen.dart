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
      context.read<TeacherProvider>().initTeacherData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final teacherProv = context.watch<TeacherProvider>();
    final alertsCount = teacherProv.strangerAlerts.length;
    final pendingMedCount = teacherProv.medications.where((m) => m.isPending).length;
    final pendingLeaveCount = teacherProv.leaveRequests.where((l) => l.status == 'PENDING').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('KidPro Teacher'),
        actions: [
          IconButton(
            tooltip: 'Làm mới dữ liệu',
            icon: const Icon(Icons.refresh),
            onPressed: () => teacherProv.initTeacherData(),
          ),
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => teacherProv.initTeacherData(),
        child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner thông tin giáo viên & Lớp phụ trách từ Supabase
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, Colors.blue.shade700],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.school, size: 32, color: AppColors.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.fullName ?? 'Giáo viên Chủ nhiệm',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Phụ trách: ${teacherProv.currentClassName}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (teacherProv.myClasses.length > 1) ...[
                            const SizedBox(width: 4),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.arrow_drop_down_circle_outlined, color: Colors.white, size: 18),
                              tooltip: 'Đổi lớp phụ trách',
                              onSelected: (classId) => teacherProv.selectClass(classId),
                              itemBuilder: (context) => teacherProv.myClasses.map((c) {
                                return PopupMenuItem<String>(
                                  value: c['classId']?.toString(),
                                  child: Text('${c['className']} (${c['studentCount'] ?? 0} HS)'),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // High-priority alert banner if stranger alerts exist
          if (alertsCount > 0) ...[
            InkWell(
              onTap: () => context.go('/teacher/dismissal'),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.strangerAlert.withValues(alpha: 0.12),
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CẢNH BÁO: Phát hiện $alertsCount người lạ!',
                            style: const TextStyle(
                              color: AppColors.strangerAlert,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
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
            const SizedBox(height: 16),
          ],

          // ── PHÂN HỆ 1: ĐIỂM DANH & AN TOÀN ĐƯA ĐÓN ──
          _buildSectionHeader('Điểm danh & An toàn Đưa đón'),
          const SizedBox(height: 8),
          _TeacherActionCard(
            title: 'Điểm danh Đến Lớp Buổi Sáng (G5-UC-01)',
            subtitle: '${teacherProv.presentCount}/${teacherProv.students.length} học sinh đã đến lớp',
            icon: Icons.how_to_reg,
            color: AppColors.primary,
            onTap: () => context.go('/teacher/attendance'),
          ),
          const SizedBox(height: 10),
          _TeacherActionCard(
            title: 'Camera AI Nhận Diện Khuôn Mặt',
            subtitle: 'Điểm danh tự động qua AI Server mầm non',
            icon: Icons.camera_front,
            color: Colors.deepPurple,
            onTap: () => context.go('/teacher/face-attendance'),
          ),
          const SizedBox(height: 10),
          _TeacherActionCard(
            title: 'Điểm danh Xe Buýt & Kiểm tra Khoang xe (G5-UC-02, G5-UC-03)',
            subtitle: 'Quét QR đuôi xe & xác nhận 0 bé còn sót (BR-024)',
            icon: Icons.directions_bus,
            color: Colors.orange.shade800,
            onTap: () => context.go('/teacher/bus'),
          ),
          const SizedBox(height: 10),
          _TeacherActionCard(
            title: 'Tan học, Đón Trẻ & Tính Phí Đón Muộn (G5-UC-04, G5-UC-05)',
            subtitle: 'Kiểm tra người ủy quyền & tính phí lũy tiến sau 17:00 (BR-020)',
            icon: Icons.face_retouching_natural,
            color: Colors.teal,
            onTap: () => context.go('/teacher/dismissal'),
          ),
          const SizedBox(height: 20),

          // ── PHÂN HỆ 2: CHĂM SÓC SỨC KHỎE & BÁN TRÚ ──
          _buildSectionHeader('Chăm sóc Sức khỏe & Bán trú'),
          const SizedBox(height: 8),
          _TeacherActionCard(
            title: 'Cho Uống Thuốc & Chụp Ảnh Minh Chứng (G8-UC-01, G8-UC-02)',
            subtitle: '$pendingMedCount bé cần uống thuốc hôm nay (Khoảng cách 4h BR-030)',
            icon: Icons.medication_liquid,
            color: AppColors.success,
            badgeCount: pendingMedCount,
            onTap: () => context.go('/teacher/medication'),
          ),
          const SizedBox(height: 10),
          _TeacherActionCard(
            title: 'Nhập Chỉ Số Thể Chất Định Kỳ WHO (G8-UC-03)',
            subtitle: 'Tự động tính BMI & phân loại thể trạng theo chuẩn WHO (BR-031)',
            icon: Icons.health_and_safety,
            color: Colors.blue.shade700,
            onTap: () => context.go('/teacher/health-metrics'),
          ),
          const SizedBox(height: 10),
          _TeacherActionCard(
            title: 'Báo cáo Sự Cố Y Tế & Sơ Cứu Khẩn Cấp (G8-UC-04)',
            subtitle: 'Bắt buộc phương án sơ cứu cho ca nghiêm trọng (BR-031)',
            icon: Icons.emergency,
            color: AppColors.error,
            onTap: () => context.go('/teacher/health-incidents'),
          ),
          const SizedBox(height: 10),
          _TeacherActionCard(
            title: 'Nhật ký Giấc Ngủ & Khẩu Phần Ăn Bán Trú (G10-UC-04, G10-UC-05)',
            subtitle: 'Theo dõi giấc ngủ trưa & 4 mức ăn uống của trẻ (BR-032)',
            icon: Icons.restaurant,
            color: Colors.indigo,
            onTap: () => context.go('/teacher/daily-activity'),
          ),
          const SizedBox(height: 20),

          // ── PHÂN HỆ 3: ĐÀO TẠO & QUẢN LÝ LỚP HỌC ──
          _buildSectionHeader('Đào tạo & Quản lý Lớp học'),
          const SizedBox(height: 8),
          _TeacherActionCard(
            title: 'Soạn & Nộp Kế Hoạch Giáo Dục Tuần (G9-UC-01)',
            subtitle: 'Nộp giáo án 5 ngày dạy học lên BGH trước 17:00 T6 (BR-053)',
            icon: Icons.menu_book,
            color: Colors.deepOrange,
            onTap: () => context.go('/teacher/lesson-plans'),
          ),
          const SizedBox(height: 10),
          _TeacherActionCard(
            title: 'Đánh Giá Chuẩn Phát Triển 5 Lĩnh Vực (G9-UC-04)',
            subtitle: 'Thể chất, nhận thức, ngôn ngữ, xã hội, thẩm mỹ (≥ 50 từ BR-049)',
            icon: Icons.stars,
            color: Colors.purple,
            onTap: () => context.go('/teacher/evaluations'),
          ),
          const SizedBox(height: 10),
          _TeacherActionCard(
            title: 'Duyệt Đơn Xin Nghỉ Học của Phụ Huynh (G10-UC-09)',
            subtitle: 'Đồng bộ điểm danh & hoàn tiền ăn bếp trước 07:30 (BR-064, BR-065)',
            icon: Icons.assignment_turned_in,
            color: Colors.blueGrey,
            badgeCount: pendingLeaveCount,
            onTap: () => context.go('/teacher/leave-requests'),
          ),
          const SizedBox(height: 10),
          _TeacherActionCard(
            title: 'Báo Hỏng Cơ Sở Vật Chất Lớp Học (G9-UC-06)',
            subtitle: 'Báo hỏng kèm ảnh hiện trường & chống trùng lặp (BR-051, BR-052)',
            icon: Icons.build_circle,
            color: Colors.brown,
            onTap: () => context.go('/teacher/equipment'),
          ),
          const SizedBox(height: 20),

          // ── PHÂN HỆ 4: TƯƠNG TÁC & KẾT NỐI PHỤ HUYNH ──
          _buildSectionHeader('Tương tác & Kết nối Phụ huynh'),
          const SizedBox(height: 8),
          _TeacherActionCard(
            title: 'Nhóm Chat Chung của Lớp (G11-UC-04)',
            subtitle: 'Điều phối thảo luận, chế độ Silent sau 21:30 & khóa chat (BR-058, BR-059)',
            icon: Icons.chat_bubble,
            color: AppColors.primary,
            onTap: () => context.go('/teacher/chat'),
          ),
          const SizedBox(height: 10),
          _TeacherActionCard(
            title: 'Album Ảnh & Hoạt Động Lớp Học (G11-UC-05)',
            subtitle: 'Đăng tối đa 50 ảnh/hoạt động, gắn thẻ học sinh (BR-060)',
            icon: Icons.photo_library,
            color: Colors.pink,
            onTap: () => context.go('/teacher/journal'),
          ),
          const SizedBox(height: 24),
        ],
      ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

class _TeacherActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final int? badgeCount;

  const _TeacherActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        onTap: onTap,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badgeCount != null && badgeCount! > 0)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
