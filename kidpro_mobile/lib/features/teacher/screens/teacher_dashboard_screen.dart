import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:kidpro_mobile/core/constants/app_colors.dart';
import 'package:kidpro_mobile/features/auth/providers/auth_provider.dart';
import 'package:kidpro_mobile/features/teacher/providers/teacher_provider.dart';
import 'package:kidpro_mobile/features/teacher/screens/parent_pickup_camera_screen.dart';

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  int _selectedCategoryIndex = 0;

  final List<String> _categories = [
    'Tất cả',
    'Điểm danh & Xe',
    'Sức khỏe & Bán trú',
    'Học vụ & Lớp',
    'Tương tác & Ảnh',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TeacherProvider>().initTeacherData();
    });
  }

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Chào buổi sáng';
    if (hour < 14) return 'Chào buổi trưa';
    if (hour < 18) return 'Chào buổi chiều';
    return 'Chào buổi tối';
  }

  String _getShiftGuidance() {
    final hour = DateTime.now().hour;
    if (hour < 10) {
      return 'Ưu tiên đón trẻ, điểm danh sáng & tiếp nhận dặn thuốc trước 08:30.';
    } else if (hour < 14) {
      return 'Ghi nhận khẩu phần ăn trưa, theo dõi giấc ngủ & chuẩn bị cho uống thuốc.';
    } else if (hour < 17) {
      return 'Cho uống thuốc lúc 14:00, hoàn thành nhật ký lớp & chuẩn bị trả trẻ.';
    } else {
      return 'Kiểm tra trả trẻ tận tay phụ huynh, phí đón muộn sau 17:30 & đóng chuyến xe buýt an toàn.';
    }
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: AppColors.error),
            SizedBox(width: 10),
            Text('Đăng xuất'),
          ],
        ),
        content: const Text('Cô có chắc chắn muốn đăng xuất khỏi ứng dụng KidPro Teacher không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Ở lại', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthProvider>().logout();
            },
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final teacherProv = context.watch<TeacherProvider>();
    final alertsCount = teacherProv.strangerAlerts.length;
    final pendingMedCount = teacherProv.medications.where((m) => m.isPending).length;
    final pendingLeaveCount = teacherProv.leaveRequests.where((l) => l.status == 'PENDING').length;

    return Scaffold(
      backgroundColor: AppColors.scaffoldLight,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => teacherProv.initTeacherData(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── 1. MODERN TOP APP BAR & TEACHER PROFILE ──
              SliverToBoxAdapter(
                child: _buildModernHeader(user, teacherProv),
              ),

              // ── 2. MAIN CONTENT BODY ──
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 12),

                    // Shift Guidance Alert Card
                    _buildShiftGuidanceBanner(),
                    const SizedBox(height: 14),

                    // Hero Overview Card (Class Attendance Pulse)
                    _buildHeroOverviewCard(teacherProv),
                    const SizedBox(height: 16),

                    // Priority Warning Banners (Strangers, Meds, Leaves)
                    if (alertsCount > 0 || pendingMedCount > 0 || pendingLeaveCount > 0) ...[
                      _buildPriorityAlertsSection(alertsCount, pendingMedCount, pendingLeaveCount),
                      const SizedBox(height: 18),
                    ],

                    // Quick Action 1-Tap Hub
                    _buildQuickActionHub(teacherProv),
                    const SizedBox(height: 20),

                    // Category Selector Pills
                    _buildCategoryFilterBar(),
                    const SizedBox(height: 14),

                    // Filtered Feature Modules
                    ..._buildFilteredModules(teacherProv, pendingMedCount, pendingLeaveCount),

                    const SizedBox(height: 32),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // WIDGET COMPONENTS
  // ===========================================================================

  Widget _buildModernHeader(dynamic user, TeacherProvider teacherProv) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Teacher Avatar with badge
              Stack(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.highlight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.school_rounded, color: Colors.white, size: 26),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),

              // Teacher Name & Role
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_getTimeGreeting()},',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      user?.fullName ?? 'Cô Nguyễn Thị Mai',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Action buttons (Refresh & Logout)
              Container(
                decoration: BoxDecoration(
                  color: AppColors.scaffoldLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Đồng bộ dữ liệu',
                      icon: teacherProv.loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                            )
                          : const Icon(Icons.sync_rounded, color: AppColors.primary, size: 22),
                      onPressed: () => teacherProv.initTeacherData(),
                    ),
                    IconButton(
                      tooltip: 'Đăng xuất',
                      icon: Icon(Icons.logout_rounded, color: Colors.grey.shade700, size: 20),
                      onPressed: _confirmLogout,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Class Selector Pill Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.apartment_rounded, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Lớp: ${teacherProv.currentClassName}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (teacherProv.myClasses.length > 1)
                  PopupMenuButton<String>(
                    tooltip: 'Chuyển lớp phụ trách',
                    onSelected: (classId) => teacherProv.selectClass(classId),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    itemBuilder: (context) => teacherProv.myClasses.map((c) {
                      final isSelected = c['classId']?.toString() == teacherProv.currentClassId;
                      return PopupMenuItem<String>(
                        value: c['classId']?.toString(),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                              color: isSelected ? AppColors.primary : Colors.grey,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${c['className']} (${c['studentCount'] ?? 0} bé)',
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? AppColors.primary : Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Đổi lớp',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(width: 2),
                          Icon(Icons.arrow_drop_down, color: Colors.white, size: 16),
                        ],
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${teacherProv.totalCount} học sinh',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
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

  Widget _buildShiftGuidanceBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Color(0xFFF59E0B),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.wb_sunny_rounded, color: Colors.white, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _getShiftGuidance(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF92400E),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroOverviewCard(TeacherProvider teacherProv) {
    final total = teacherProv.totalCount;
    final present = teacherProv.presentCount;
    final late = teacherProv.lateCount;
    final onLeave = teacherProv.onLeaveCount;
    final notArrived = teacherProv.notArrivedCount;

    final double presentRatio = total > 0 ? (present + late) / total : 0.0;
    final int percentInt = (presentRatio * 100).toInt();

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF275A4E), Color(0xFF193B33)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF275A4E).withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background decorative circle
          Positioned(
            right: -25,
            top: -25,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            left: -35,
            bottom: -35,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.highlight.withValues(alpha: 0.06),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top line: Status Title + Attendance Percent Ring
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.highlight,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'SĨ SỐ HIỆN DIỆN THỜI GIAN THỰC',
                              style: TextStyle(
                                color: AppColors.highlight.withValues(alpha: 0.9),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '${present + late}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              ' / $total học sinh',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Circular progress indicator
                    Container(
                      width: 58,
                      height: 58,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: presentRatio,
                            strokeWidth: 4.5,
                            backgroundColor: Colors.white.withValues(alpha: 0.15),
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.highlight),
                          ),
                          Text(
                            '$percentInt%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 4 Status Pill Grid
                Row(
                  children: [
                    Expanded(
                      child: _buildHeroStatPill(
                        label: 'Có mặt',
                        count: present,
                        color: const Color(0xFF10B981),
                        icon: Icons.check_circle_rounded,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildHeroStatPill(
                        label: 'Đi muộn',
                        count: late,
                        color: const Color(0xFFF97316),
                        icon: Icons.access_time_filled_rounded,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildHeroStatPill(
                        label: 'Có phép',
                        count: onLeave,
                        color: const Color(0xFF38BDF8),
                        icon: Icons.event_busy_rounded,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildHeroStatPill(
                        label: 'Chưa đến',
                        count: notArrived,
                        color: const Color(0xFF94A3B8),
                        icon: Icons.hourglass_top_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Fast Action Button
                InkWell(
                  onTap: () => context.go('/teacher/attendance'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.how_to_reg_rounded, color: AppColors.primary, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Mở danh sách điểm danh lớp ngay',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded, color: AppColors.primary, size: 16),
                      ],
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

  Widget _buildHeroStatPill({
    required String label,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 11, color: color),
              const SizedBox(width: 3),
              Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityAlertsSection(int strangers, int meds, int leaves) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'VIỆC CẦN XỬ LÝ GẤP',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.error,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Stranger Alert Card
        if (strangers > 0)
          InkWell(
            onTap: () => context.go('/teacher/dismissal'),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFCA5A5), width: 1.2),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CẢNH BÁO: Phát hiện $strangers người lạ tại cổng!',
                          style: const TextStyle(
                            color: Color(0xFF991B1B),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Nhấn để xác minh danh tính người đón khẩn cấp',
                          style: TextStyle(color: Color(0xFFB91C1C), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.error),
                ],
              ),
            ),
          ),

        // Pending Medication Task
        if (meds > 0)
          InkWell(
            onTap: () => context.go('/teacher/medication'),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF86EFAC), width: 1.2),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.medication_liquid_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nhiệm vụ: $meds bé cần uống thuốc lúc 14:00',
                          style: const TextStyle(
                            color: Color(0xFF166534),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Kiểm tra khoảng cách 4h & chụp ảnh xác nhận sau khi uống',
                          style: TextStyle(color: Color(0xFF15803D), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.success),
                ],
              ),
            ),
          ),

        // Pending Leave Requests
        if (leaves > 0)
          InkWell(
            onTap: () => context.go('/teacher/leave-requests'),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF93C5FD), width: 1.2),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.info,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.assignment_turned_in_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Đơn xin nghỉ: $leaves đơn phụ huynh chờ duyệt',
                          style: const TextStyle(
                            color: Color(0xFF1E40AF),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Duyệt trước 07:30 để bếp kịp cắt suất hoàn tiền ăn',
                          style: TextStyle(color: Color(0xFF2563EB), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.info),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildQuickActionHub(TeacherProvider prov) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'THAO TÁC NHANH ĐẦU NGÀY',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Colors.black54,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 10.0;
            final actions = <Widget>[
              _buildQuickActionButton(
                title: 'Điểm danh',
                subtitle: 'Thủ công',
                icon: Icons.how_to_reg_rounded,
                color: AppColors.primary,
                onTap: () => context.go('/teacher/attendance'),
              ),
              _buildQuickActionButton(
                title: 'Quét mặt AI',
                subtitle: 'Tự động',
                icon: Icons.camera_front_rounded,
                color: const Color(0xFF7C3AED),
                onTap: () => context.push('/teacher/face-attendance'),
              ),
              // Chỉ giáo viên được phân công lớp năng khiếu mới thấy nút này
              if (prov.hasExtracurricularClasses)
                _buildQuickActionButton(
                  title: 'Năng khiếu',
                  subtitle: _extracurricularProgress(prov),
                  icon: Icons.palette_rounded,
                  color: const Color(0xFFC026D3),
                  onTap: () => context.go('/teacher/extracurricular-attendance'),
                ),
              // Chỉ giáo viên được phân công phụ trách xe buýt mới thấy nút này
              if (prov.hasBusAssignment)
                _buildQuickActionButton(
                  title: 'Xe buýt',
                  subtitle: 'Đóng chuyến',
                  icon: Icons.directions_bus_rounded,
                  color: const Color(0xFFEA580C),
                  onTap: () => context.go('/teacher/bus'),
                ),
              _buildQuickActionButton(
                title: 'Tan học',
                subtitle: 'Trả trẻ',
                icon: Icons.family_restroom_rounded,
                color: const Color(0xFF0D9488),
                onTap: () => context.go('/teacher/dismissal'),
              ),
            ];

            // ≤ 4 nút: chia đều cả hàng. > 4 nút: hiện ~4.4 nút, phần còn lại kéo ngang.
            final visible = actions.length <= 4 ? actions.length.toDouble() : 4.4;
            final itemWidth = (constraints.maxWidth - gap * (visible.ceil() - 1)) / visible;

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: actions.length <= 4
                  ? const NeverScrollableScrollPhysics()
                  : const BouncingScrollPhysics(),
              clipBehavior: Clip.none,
              child: Row(
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(width: gap),
                    SizedBox(width: itemWidth, child: actions[i]),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  String _extracurricularProgress(TeacherProvider prov) {
    final classes = prov.extracurricularClasses;
    final int marked = classes.fold<int>(0, (s, c) => s + ((c['markedCount'] as num?)?.toInt() ?? 0));
    final int total = classes.fold<int>(0, (s, c) => s + ((c['studentCount'] as num?)?.toInt() ?? 0));
    return '$marked/$total bé';
  }

  Widget _buildQuickActionButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilterBar() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isSelected = _selectedCategoryIndex == index;
          return ChoiceChip(
            label: Text(_categories[index]),
            selected: isSelected,
            onSelected: (val) {
              if (val) setState(() => _selectedCategoryIndex = index);
            },
            selectedColor: AppColors.primary,
            backgroundColor: Colors.white,
            side: BorderSide(
              color: isSelected ? AppColors.primary : Colors.grey.shade300,
              width: 1,
            ),
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected ? Colors.white : Colors.grey.shade700,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            showCheckmark: false,
          );
        },
      ),
    );
  }

  List<Widget> _buildFilteredModules(TeacherProvider prov, int pendingMeds, int pendingLeaves) {
    final List<Widget> widgets = [];

    // Category 0: All, or Category 1: Attendance & Bus
    if (_selectedCategoryIndex == 0 || _selectedCategoryIndex == 1) {
      widgets.add(_buildSectionTitle('Điểm danh & An toàn Đưa đón'));
      widgets.add(const SizedBox(height: 8));
      widgets.add(_ModernActionCard(
        title: 'Điểm danh Đến Lớp Buổi Sáng',
        subtitle: '${prov.presentCount + prov.lateCount}/${prov.totalCount} bé đã đến lớp hôm nay',
        tag: 'G5-UC-01',
        icon: Icons.how_to_reg_rounded,
        color: AppColors.primary,
        onTap: () => context.go('/teacher/attendance'),
      ));
      widgets.add(const SizedBox(height: 10));
      // Chỉ giáo viên được phân công lớp năng khiếu mới thấy mục này
      if (prov.hasExtracurricularClasses) {
        final extra = prov.extracurricularClasses;
        final int marked = extra.fold<int>(0, (s, c) => s + ((c['markedCount'] as num?)?.toInt() ?? 0));
        final int total = extra.fold<int>(0, (s, c) => s + ((c['studentCount'] as num?)?.toInt() ?? 0));
        final names = extra.map((c) => c['className']?.toString() ?? '').where((n) => n.isNotEmpty).join(', ');
        widgets.add(_ModernActionCard(
          title: 'Điểm danh Lớp Năng Khiếu',
          subtitle: '$names · hôm nay đã điểm danh $marked/$total bé',
          tag: 'Bấm nút',
          icon: Icons.palette_rounded,
          color: const Color(0xFFC026D3),
          onTap: () => context.go('/teacher/extracurricular-attendance'),
        ));
        widgets.add(const SizedBox(height: 10));
      }
      widgets.add(_ModernActionCard(
        title: 'Camera AI Nhận Diện Khuôn Mặt',
        subtitle: 'Quét tự động qua AI Server mầm non',
        tag: 'AI Face',
        icon: Icons.camera_front_rounded,
        color: const Color(0xFF7C3AED),
        onTap: () => context.push('/teacher/face-attendance'),
      ));
      widgets.add(const SizedBox(height: 10));
      // Chỉ giáo viên được phân công phụ trách xe buýt mới thấy mục này
      if (prov.hasBusAssignment) {
        widgets.add(_ModernActionCard(
          title: 'Xe Buýt Đưa Đón & Quét Đuôi Xe',
          subtitle: 'Quét QR đuôi xe (BR-024) đảm bảo không bỏ quên bé',
          tag: 'G5-UC-02, 03',
          icon: Icons.directions_bus_rounded,
          color: const Color(0xFFEA580C),
          onTap: () => context.go('/teacher/bus'),
        ));
        widgets.add(const SizedBox(height: 10));
      }
      widgets.add(_ModernActionCard(
        title: 'Quét Mặt Phụ Huynh Đón Trẻ',
        subtitle: 'Đối chiếu phụ huynh trong lớp, cho đón & ghi nhận giờ về',
        tag: 'AI Pickup',
        icon: Icons.face_retouching_natural_rounded,
        color: const Color(0xFFE11D48),
        onTap: () {
          final cId = prov.currentClassId;
          if (cId.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Vui lòng chọn lớp học trước khi quét mặt.')),
            );
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ParentPickupCameraScreen(
                classId: cId,
                className: prov.currentClassName.isNotEmpty ? prov.currentClassName : 'Lớp học',
              ),
            ),
          );
        },
      ));
      widgets.add(const SizedBox(height: 10));
      widgets.add(_ModernActionCard(
        title: 'Tan Học, Trả Trẻ & Phí Đón Muộn',
        subtitle: 'Kiểm tra người ủy quyền; tự tính phí đón muộn sau 17:30 (BR-020)',
        tag: 'G5-UC-04, 05',
        icon: Icons.family_restroom_rounded,
        color: const Color(0xFF0D9488),
        onTap: () => context.go('/teacher/dismissal'),
      ));
      widgets.add(const SizedBox(height: 20));
    }

    // Category 0: All, or Category 2: Health & Catering
    if (_selectedCategoryIndex == 0 || _selectedCategoryIndex == 2) {
      widgets.add(_buildSectionTitle('Chăm sóc Sức khỏe & Bán trú'));
      widgets.add(const SizedBox(height: 8));
      widgets.add(_ModernActionCard(
        title: 'Cho Uống Thuốc & Chụp Ảnh Minh Chứng',
        subtitle: 'Khoảng cách liều ≥ 4h (BR-030); chụp ảnh lưu hồ sơ y tế',
        tag: 'G8-UC-01, 02',
        icon: Icons.medication_liquid_rounded,
        color: AppColors.success,
        badgeCount: pendingMeds,
        onTap: () => context.go('/teacher/medication'),
      ));
      widgets.add(const SizedBox(height: 10));
      widgets.add(_ModernActionCard(
        title: 'Nhập Chỉ Số Thể Chất Định Kỳ WHO',
        subtitle: 'Tự động tính BMI & phân loại theo chuẩn WHO Z-score (BR-031)',
        tag: 'G8-UC-03',
        icon: Icons.health_and_safety_rounded,
        color: const Color(0xFF2563EB),
        onTap: () => context.go('/teacher/health-metrics'),
      ));
      widgets.add(const SizedBox(height: 10));
      widgets.add(_ModernActionCard(
        title: 'Báo Cáo Sự Cố Y Tế & Sơ Cứu Khẩn Cấp',
        subtitle: 'Ghi nhận tai nạn học đường; bắt buộc sơ cứu cho ca nặng (BR-031)',
        tag: 'G8-UC-04',
        icon: Icons.emergency_rounded,
        color: AppColors.error,
        onTap: () => context.go('/teacher/health-incidents'),
      ));
      widgets.add(const SizedBox(height: 10));
      widgets.add(_ModernActionCard(
        title: 'Nhật Ký Giấc Ngủ & Khẩu Phần Ăn Trưa',
        subtitle: 'Theo dõi 4 mức ăn uống & giờ ngủ trưa của bé (BR-032)',
        tag: 'G10-UC-04, 05',
        icon: Icons.restaurant_rounded,
        color: const Color(0xFF4F46E5),
        onTap: () => context.go('/teacher/daily-activity'),
      ));
      widgets.add(const SizedBox(height: 20));
    }

    // Category 0: All, or Category 3: Academic & Classroom Management
    if (_selectedCategoryIndex == 0 || _selectedCategoryIndex == 3) {
      widgets.add(_buildSectionTitle('Đào tạo & Quản trị Lớp học'));
      widgets.add(const SizedBox(height: 8));
      widgets.add(_ModernActionCard(
        title: 'Kế Hoạch Giáo Dục Tuần (Giáo Án)',
        subtitle: 'Soạn giáo án 5 ngày dạy; nộp BGH trước 17:00 Thứ 6 (BR-053)',
        tag: 'G9-UC-01',
        icon: Icons.menu_book_rounded,
        color: const Color(0xFFF97316),
        onTap: () => context.go('/teacher/lesson-plans'),
      ));
      widgets.add(const SizedBox(height: 10));
      widgets.add(_ModernActionCard(
        title: 'Đánh Giá Chuẩn Phát Triển 5 Lĩnh Vực',
        subtitle: 'Thể chất, nhận thức, ngôn ngữ, xã hội, thẩm mỹ (≥ 50 từ BR-049)',
        tag: 'G9-UC-04',
        icon: Icons.stars_rounded,
        color: const Color(0xFF9333EA),
        onTap: () => context.go('/teacher/evaluations'),
      ));
      widgets.add(const SizedBox(height: 10));
      widgets.add(_ModernActionCard(
        title: 'Duyệt Đơn Xin Nghỉ Học Của Phụ Huynh',
        subtitle: 'Đồng bộ điểm danh & báo bếp hoàn tiền ăn trước 07:30 (BR-064)',
        tag: 'G10-UC-09',
        icon: Icons.assignment_turned_in_rounded,
        color: const Color(0xFF0284C7),
        badgeCount: pendingLeaves,
        onTap: () => context.go('/teacher/leave-requests'),
      ));
      widgets.add(const SizedBox(height: 10));
      widgets.add(_ModernActionCard(
        title: 'Báo Hỏng Cơ Sở Vật Chất Lớp Học',
        subtitle: 'Chụp ảnh hiện trường; tránh báo trùng thiết bị đang sửa (BR-051)',
        tag: 'G9-UC-06',
        icon: Icons.build_circle_rounded,
        color: const Color(0xFF78350F),
        onTap: () => context.go('/teacher/equipment'),
      ));
      widgets.add(const SizedBox(height: 20));
    }

    // Category 0: All, or Category 4: Communication & Journals
    if (_selectedCategoryIndex == 0 || _selectedCategoryIndex == 4) {
      widgets.add(_buildSectionTitle('Tương tác & Kết nối Phụ huynh'));
      widgets.add(const SizedBox(height: 8));
      widgets.add(_ModernActionCard(
        title: 'Nhóm Chat Trao Đổi Chung Của Lớp',
        subtitle: 'Tự động Silent sau 21:30 (BR-058); khóa/mở quyền chat phụ huynh',
        tag: 'G11-UC-04',
        icon: Icons.chat_bubble_rounded,
        color: AppColors.primary,
        onTap: () => context.go('/teacher/chat'),
      ));
      widgets.add(const SizedBox(height: 10));
      widgets.add(_ModernActionCard(
        title: 'Album Ảnh & Hoạt Động Của Bé',
        subtitle: 'Đăng tối đa 50 ảnh/hoạt động (BR-060); gửi thông báo tới phụ huynh',
        tag: 'G11-UC-05',
        icon: Icons.photo_library_rounded,
        color: const Color(0xFFDB2777),
        onTap: () => context.go('/teacher/journal'),
      ));
      widgets.add(const SizedBox(height: 10));
      widgets.add(_ModernActionCard(
        title: 'Thông Báo Cho Phụ Huynh Của Lớp',
        subtitle: 'Gửi thông báo riêng cho phụ huynh lớp mình phụ trách',
        tag: 'UC-81',
        icon: Icons.campaign_rounded,
        color: const Color(0xFF0EA5E9),
        onTap: () => context.go('/teacher/class-announcements'),
      ));
      widgets.add(const SizedBox(height: 20));
    }

    return widgets;
  }

  Widget _buildSectionTitle(String title) {
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
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryDark,
            letterSpacing: -0.1,
          ),
        ),
      ],
    );
  }
}

class _ModernActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String tag;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final int? badgeCount;

  const _ModernActionCard({
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.icon,
    required this.color,
    required this.onTap,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon block with soft colored background
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),

              // Title, Subtitle, Tag
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: Color(0xFF1E293B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.grey.shade300, width: 0.8),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.grey.shade600,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Trailing Badge or Arrow
              Row(
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
