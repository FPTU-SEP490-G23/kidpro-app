import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:kidpro_mobile/core/constants/app_colors.dart';
import 'package:kidpro_mobile/features/auth/providers/auth_provider.dart';
import 'package:kidpro_mobile/features/parent/providers/parent_provider.dart';

class ParentDashboardScreen extends StatelessWidget {
  const ParentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final parentProv = context.watch<ParentProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('KidPro Parent'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Greeting & Profile Header
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary.withOpacity(0.15),
                child: const Icon(Icons.family_restroom, color: AppColors.primary, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Xin chào, ${user?.fullName ?? "Phụ huynh"}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Cổng thông tin gia đình trực tuyến',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Active Student Card
          Container(
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
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.child_care, color: AppColors.primary, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        parentProv.selectedStudentName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Đang học tại trường • Điểm danh: ĐÃ ĐẾN LỚP',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Core Actions Grid
          const _SectionTitle('Tiện ích học tập & Học phí'),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.55,
            children: [
              _ActionCard(
                icon: Icons.receipt_long,
                label: 'Học phí & VietQR',
                subLabel: 'BR-040 Napas 247',
                color: AppColors.info,
                onTap: () => context.go('/parent/invoices'),
              ),
              _ActionCard(
                icon: Icons.event_busy,
                label: 'Xin nghỉ học',
                subLabel: 'Hoàn tiền ăn trước 8h',
                color: AppColors.warning,
                onTap: () => context.go('/parent/leave'),
              ),
              _ActionCard(
                icon: Icons.medication,
                label: 'Dặn uống thuốc',
                subLabel: 'Kê toa y tế BR-029',
                color: AppColors.success,
                onTap: () => context.go('/parent/medication'),
              ),
              _ActionCard(
                icon: Icons.chat_bubble_outline,
                label: 'Nhắn tin với cô',
                subLabel: 'Trao đổi hàng ngày',
                color: AppColors.accent,
                onTap: () => context.go('/parent/chat'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Safety & Health Grid
          const _SectionTitle('An toàn trả trẻ & Quyền riêng tư'),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.55,
            children: [
              _ActionCard(
                icon: Icons.qr_code_2,
                label: 'Đón hộ đột xuất',
                subLabel: 'Mã QR 60p (BR-022)',
                color: Colors.deepOrange,
                onTap: () => context.go('/parent/emergency-pickup'),
              ),
              _ActionCard(
                icon: Icons.people_alt_outlined,
                label: 'Người đón thường xuyên',
                subLabel: 'Tối đa 3 người (BR-012)',
                color: Colors.purple,
                onTap: () => context.go('/parent/guardians'),
              ),
              _ActionCard(
                icon: Icons.medical_information_outlined,
                label: 'Hồ sơ Dị ứng của bé',
                subLabel: 'Liên thông Bếp & Y tế',
                color: AppColors.error,
                onTap: () => context.go('/parent/allergies'),
              ),
              _ActionCard(
                icon: Icons.shield_outlined,
                label: 'Quyền riêng tư AI',
                subLabel: 'Nghị định 13/2023/NĐ-CP',
                color: Colors.indigo,
                onTap: () => context.go('/parent/biometric-purge'),
              ),
            ],
          ),

          const SizedBox(height: 24),
          const _SectionTitle('Dòng thời gian hôm nay'),
          const SizedBox(height: 12),
          const _TimelineItem(
            time: '07:35',
            title: 'Điểm danh camera AI',
            subtitle: 'Bé Nguyễn Tuấn Kiệt đã vào trường an toàn',
            icon: Icons.check_circle,
            color: AppColors.present,
          ),
          const _TimelineItem(
            time: '11:30',
            title: 'Bữa trưa & Uống thuốc',
            subtitle: 'Ăn hết suất cơm • Cô đã cho uống 5ml Siro Prospan',
            icon: Icons.restaurant,
            color: AppColors.info,
          ),
          const _TimelineItem(
            time: '12:00',
            title: 'Ngủ trưa',
            subtitle: 'Bé ngủ ngon giấc 90 phút',
            icon: Icons.bedtime,
            color: AppColors.accent,
          ),
          const SizedBox(height: 20),
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
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: color.withOpacity(0.15),
                    child: Icon(icon, color: color, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              if (subLabel != null) ...[
                const SizedBox(height: 2),
                Text(
                  subLabel!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(
              time,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
