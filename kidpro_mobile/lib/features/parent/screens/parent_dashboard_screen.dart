import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:kidpro_mobile/core/constants/app_colors.dart';
import 'package:kidpro_mobile/features/auth/providers/auth_provider.dart';
import 'package:kidpro_mobile/features/parent/models/parent_models.dart';
import 'package:kidpro_mobile/features/parent/providers/parent_provider.dart';
import 'package:kidpro_mobile/features/parent/screens/invoices_screen.dart';
import 'package:kidpro_mobile/features/parent/screens/records_overview_screen.dart';
import 'package:kidpro_mobile/features/parent/screens/requests_overview_screen.dart';

class ParentDashboardScreen extends StatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ParentProvider>().loadMyStudents();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final parentProv = context.watch<ParentProvider>();
    final currentStudent = parentProv.selectedStudent;

    final List<Widget> tabs = [
      _buildHomeTab(user, parentProv, currentStudent),
      const RecordsOverviewScreen(),
      const RequestsOverviewScreen(),
      const InvoicesScreen(),
      _buildProfileTab(user, parentProv, currentStudent),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: tabs,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey.shade500,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Trang chủ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_outlined),
            activeIcon: Icon(Icons.menu_book),
            label: 'Sổ điện tử',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            activeIcon: Icon(Icons.assignment),
            label: 'Đơn từ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'Học phí',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Tài khoản',
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 0: TRANG CHỦ (HOME DASHBOARD)
  // ==========================================
  Widget _buildHomeTab(dynamic user, ParentProvider parentProv, StudentSummary? currentStudent) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KidPro — Cổng Phụ huynh', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: 'Lời nhắn với cô',
            onPressed: () => context.push('/parent/chat'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Đăng xuất',
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<ParentProvider>().loadMyStudents(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Student Card Header
            _buildStudentCard(parentProv, currentStudent),
            const SizedBox(height: 20),

            // Sổ điện tử Banner Shortcuts (6 Sổ)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const _SectionTitle('Sổ điện tử & Nhật ký (6 Sổ)'),
                TextButton(
                  onPressed: () => setState(() => _currentIndex = 1),
                  child: const Text('Xem tất cả >', style: TextStyle(color: AppColors.primary)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildRecordsGrid(parentProv),
            const SizedBox(height: 22),

            // Trung tâm Đơn từ & Phiếu yêu cầu (11 Loại)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const _SectionTitle('Thủ tục & Đơn từ (11 loại)'),
                TextButton(
                  onPressed: () => setState(() => _currentIndex = 2),
                  child: const Text('Quản lý đơn >', style: TextStyle(color: AppColors.primary)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildRequestsGrid(parentProv),
            const SizedBox(height: 22),

            // Trạng thái sinh hoạt hôm nay
            const _SectionTitle('Tình hình hôm nay của bé'),
            const SizedBox(height: 12),
            _buildTodayStatusCard(parentProv),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentCard(ParentProvider parentProv, StudentSummary? currentStudent) {
    if (parentProv.loading && parentProv.students.isEmpty) {
      return Container(
        height: 84,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 12),
              Text('Đang tải hồ sơ học sinh từ Supabase...'),
            ],
          ),
        ),
      );
    }

    if (parentProv.students.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.amber.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.amber.shade800),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Chưa có hồ sơ học sinh nào liên kết với tài khoản này.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white,
            child: const Icon(Icons.child_care, color: AppColors.primary, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        currentStudent?.fullName ?? parentProv.selectedStudentName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (parentProv.students.length > 1)
                      PopupMenuButton<StudentSummary>(
                        icon: const Icon(Icons.swap_horiz, color: Colors.white),
                        tooltip: 'Chuyển đổi bé',
                        onSelected: (student) => parentProv.selectStudent(student),
                        itemBuilder: (context) => parentProv.students
                            .map((s) => PopupMenuItem(
                                  value: s,
                                  child: Row(
                                    children: [
                                      Icon(
                                        s.studentId == currentStudent?.studentId
                                            ? Icons.check_circle
                                            : Icons.radio_button_unchecked,
                                        color: s.studentId == currentStudent?.studentId
                                            ? AppColors.primary
                                            : Colors.grey,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(s.displayName),
                                    ],
                                  ),
                                ))
                            .toList(),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${currentStudent?.className ?? "Lớp học"} • Mã: ${currentStudent?.studentCode ?? ""}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordsGrid(ParentProvider prov) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.1,
      children: [
        _buildIconTile(
          icon: Icons.restaurant,
          label: 'Sổ sinh hoạt',
          badge: prov.dailyActivities.isNotEmpty ? '${prov.dailyActivities.length} ngày' : null,
          color: Colors.orange,
          onTap: () {
            setState(() => _currentIndex = 1);
          },
        ),
        _buildIconTile(
          icon: Icons.how_to_reg,
          label: 'Điểm danh',
          badge: prov.attendances.isNotEmpty ? '${prov.attendances.length} ngày' : null,
          color: AppColors.success,
          onTap: () {
            setState(() => _currentIndex = 1);
          },
        ),
        _buildIconTile(
          icon: Icons.monitor_weight_outlined,
          label: 'Sức khỏe WHO',
          badge: prov.growthHistory.isNotEmpty ? '${prov.growthHistory.length} lần' : null,
          color: Colors.pink,
          onTap: () {
            setState(() => _currentIndex = 1);
          },
        ),
        _buildIconTile(
          icon: Icons.photo_library_outlined,
          label: 'Nhật ký ảnh',
          badge: prov.journalPosts.isNotEmpty ? '${prov.journalPosts.length} bài' : null,
          color: Colors.purple,
          onTap: () {
            setState(() => _currentIndex = 1);
          },
        ),
        _buildIconTile(
          icon: Icons.stars_outlined,
          label: 'Sổ điện tử',
          badge: prov.evaluations.isNotEmpty ? '${prov.evaluations.length} kỳ' : null,
          color: Colors.indigo,
          onTap: () {
            setState(() => _currentIndex = 1);
          },
        ),
        _buildIconTile(
          icon: Icons.chat_bubble_outline,
          label: 'Tin nhắn cô',
          badge: '24/7',
          color: Colors.teal,
          onTap: () => context.push('/parent/chat'),
        ),
      ],
    );
  }

  Widget _buildRequestsGrid(ParentProvider prov) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.6,
      children: [
        _ActionCard(
          icon: Icons.event_busy,
          label: 'Xin nghỉ học',
          subLabel: 'Hoàn tiền ăn trước 8h',
          color: AppColors.warning,
          onTap: () => context.push('/parent/leave'),
        ),
        _ActionCard(
          icon: Icons.medication_outlined,
          label: 'Dặn uống thuốc',
          subLabel: 'Kê toa y tế BR-029',
          color: AppColors.success,
          onTap: () => context.push('/parent/medication'),
        ),
        _ActionCard(
          icon: Icons.qr_code_2,
          label: 'Đón hộ đột xuất',
          subLabel: 'Mã QR 60p (BR-022)',
          color: Colors.deepOrange,
          onTap: () => context.push('/parent/emergency-pickup'),
        ),
        _ActionCard(
          icon: Icons.add_circle_outline,
          label: 'Trung tâm đơn',
          subLabel: '11 loại đơn hành chính',
          color: AppColors.primary,
          onTap: () => context.push('/parent/requests/center'),
        ),
      ],
    );
  }

  Widget _buildIconTile({
    required IconData icon,
    required String label,
    String? badge,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (badge != null)
                Text(
                  badge,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodayStatusCard(ParentProvider prov) {
    final latestAct = prov.dailyActivities.isNotEmpty ? prov.dailyActivities.first : null;
    final latestAtt = prov.attendances.isNotEmpty ? prov.attendances.first : null;

    return Card(
      elevation: 0.8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _TimelineItem(
              time: latestAtt?.checkInTime != null ? latestAtt!.checkInTime!.substring(0, 5) : '07:35',
              title: 'Điểm danh camera AI',
              subtitle: latestAtt != null && latestAtt.status == 'PRESENT'
                  ? 'Bé đã vào lớp an toàn'
                  : 'Đã ghi nhận điểm danh có mặt',
              icon: Icons.check_circle,
              color: AppColors.present,
            ),
            const Divider(height: 20),
            _TimelineItem(
              time: '11:30',
              title: 'Bữa trưa dinh dưỡng',
              subtitle: latestAct?.lunchConsumption != null
                  ? 'Mức tiêu thụ: ${latestAct!.lunchConsumption}'
                  : 'Bé ăn ngoan, đạt tiêu chuẩn dinh dưỡng',
              icon: Icons.restaurant,
              color: AppColors.info,
            ),
            const Divider(height: 20),
            _TimelineItem(
              time: '12:00',
              title: 'Giấc ngủ trưa',
              subtitle: latestAct?.sleepQuality != null
                  ? '${latestAct!.sleepQuality} • ${latestAct.napDurationMinutes ?? 120} phút'
                  : 'Bé ngủ ngon giấc',
              icon: Icons.bedtime,
              color: AppColors.accent,
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 4: TÀI KHOẢN PHỤ HUYNH
  // ==========================================
  Widget _buildProfileTab(dynamic user, ParentProvider parentProv, StudentSummary? currentStudent) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ phụ huynh'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  child: const Icon(Icons.person, color: AppColors.primary, size: 40),
                ),
                const SizedBox(height: 12),
                Text(
                  user?.fullName ?? 'Phụ huynh KidPro',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  user?.email ?? 'phuhuynh@kidpro.edu.vn',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const _SectionTitle('Quản lý hồ sơ học sinh'),
          const SizedBox(height: 8),
          ...parentProv.students.map((s) => Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const Icon(Icons.child_care, color: AppColors.primary),
                  title: Text(s.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Lớp: ${s.className ?? "N/A"} • Mã: ${s.studentCode}'),
                  trailing: s.studentId == currentStudent?.studentId
                      ? const Chip(
                          label: Text('Đang chọn', style: TextStyle(fontSize: 10, color: Colors.white)),
                          backgroundColor: AppColors.primary,
                        )
                      : OutlinedButton(
                          onPressed: () => parentProv.selectStudent(s),
                          child: const Text('Chọn', style: TextStyle(fontSize: 11)),
                        ),
                ),
              )),
          const SizedBox(height: 20),

          const _SectionTitle('Cài đặt & Quyền riêng tư'),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.people_alt_outlined, color: Colors.purple),
                  title: const Text('Người đón ủy quyền thường xuyên'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/parent/guardians'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.warning_amber_rounded, color: AppColors.error),
                  title: const Text('Hồ sơ dị ứng thực phẩm/thuốc'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/parent/allergies'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.shield_outlined, color: Colors.indigo),
                  title: const Text('Quyền riêng tư AI (Nghị định 13)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/parent/biometric-purge'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => context.read<AuthProvider>().logout(),
              icon: const Icon(Icons.logout),
              label: const Text('Đăng xuất tài khoản', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold));
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subLabel;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    this.subLabel,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: color.withValues(alpha: 0.15),
                    child: Icon(icon, color: color, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (subLabel != null) ...[
                const SizedBox(height: 4),
                Text(
                  subLabel!,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final String time;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _TimelineItem({
    required this.time,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            time,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          ),
        ),
        const SizedBox(width: 12),
        CircleAvatar(
          radius: 12,
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ],
          ),
        ),
      ],
    );
  }
}
