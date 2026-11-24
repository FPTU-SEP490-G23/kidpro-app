import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:kidpro_mobile/core/constants/app_colors.dart';
import 'package:kidpro_mobile/features/parent/providers/parent_provider.dart';
import 'package:kidpro_mobile/features/parent/screens/journal_post_detail_sheet.dart';

class RecordsOverviewScreen extends StatefulWidget {
  final int initialTab;
  const RecordsOverviewScreen({super.key, this.initialTab = 0});

  @override
  State<RecordsOverviewScreen> createState() => _RecordsOverviewScreenState();
}

class _RecordsOverviewScreenState extends State<RecordsOverviewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<Tab> _tabs = const [
    Tab(icon: Icon(Icons.restaurant_outlined), text: 'Sinh hoạt'),
    Tab(icon: Icon(Icons.how_to_reg_outlined), text: 'Điểm danh'),
    Tab(icon: Icon(Icons.favorite_outline), text: 'Y tế & WHO'),
    Tab(icon: Icon(Icons.photo_library_outlined), text: 'Nhật ký ảnh'),
    Tab(icon: Icon(Icons.stars_outlined), text: 'Đánh giá 5L'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, _tabs.length - 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ParentProvider>();
    final student = prov.selectedStudent;

    return Scaffold(
      appBar: AppBar(
        title: Text(student != null ? 'Sổ điện tử • ${student.fullName}' : 'Sổ điện tử'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: AppColors.accent,
          indicatorWeight: 3,
          tabs: _tabs,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDailyActivityTab(prov),
          _buildAttendanceTab(prov),
          _buildHealthTab(prov),
          _buildJournalTab(prov),
          _buildDevelopmentTab(prov),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: SỔ SINH HOẠT HẰNG NGÀY
  // ==========================================
  Widget _buildDailyActivityTab(ParentProvider prov) {
    if (prov.dailyActivities.isEmpty) {
      return _buildEmptyState(
        icon: Icons.restaurant,
        title: 'Chưa có nhật ký sinh hoạt',
        subtitle: 'Giáo viên sẽ cập nhật mức độ ăn 4 bữa và giấc ngủ trưa của bé mỗi ngày.',
        onRefresh: () => prov.loadDailyActivities(),
      );
    }

    return RefreshIndicator(
      onRefresh: () => prov.loadDailyActivities(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: prov.dailyActivities.length,
        itemBuilder: (context, idx) {
          final act = prov.dailyActivities[idx];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 1.5,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 16, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Ngày: ${act.date ?? "Hôm nay"}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ],
                      ),
                      if (act.recordedByName != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Cô: ${act.recordedByName}',
                            style: const TextStyle(fontSize: 11, color: AppColors.primaryDark),
                          ),
                        ),
                    ],
                  ),
                  const Divider(height: 20),
                  // Bữa ăn 4 cữ
                  const Text('Dinh dưỡng 4 bữa trong ngày:',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildMealBadge('Sáng', act.breakfastConsumption),
                      _buildMealBadge('Phụ sáng', act.morningSnackConsumption),
                      _buildMealBadge('Trưa', act.lunchConsumption),
                      _buildMealBadge('Xế', act.afternoonSnackConsumption),
                    ],
                  ),
                  if (act.mealNote != null && act.mealNote!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Ghi chú ăn: ${act.mealNote}',
                        style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                  ],
                  const SizedBox(height: 14),
                  // Giấc ngủ
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.bedtime_outlined, color: Colors.indigo, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Giấc ngủ trưa: ${act.napDurationMinutes != null ? '${act.napDurationMinutes} phút' : 'chưa ghi nhận'}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13, color: Colors.indigo),
                              ),
                              Text(
                                'Chất lượng: ${act.sleepQuality ?? "chưa ghi nhận"} ${act.napNote != null ? "• " + act.napNote! : ""}',
                                style: TextStyle(fontSize: 12, color: Colors.indigo.shade800),
                              ),
                              if (act.toiletCount != null)
                                Text(
                                  'Vệ sinh: ${act.toiletCount} lần${act.toiletNote != null && act.toiletNote!.isNotEmpty ? ' • ${act.toiletNote}' : ''}',
                                  style: TextStyle(fontSize: 12, color: Colors.teal.shade800),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (act.generalNote != null && act.generalNote!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.chat_bubble_outline, size: 16, color: AppColors.accent),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Nhận xét của cô: ${act.generalNote}',
                            style: const TextStyle(fontSize: 13, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMealBadge(String label, String? level) {
    Color bg = Colors.grey.shade100;
    Color fg = Colors.grey.shade700;
    String display = 'Chưa ăn';

    if (level != null) {
      if (level.contains('ALL') || level.contains('GOOD') || level.contains('HET')) {
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        display = 'Hết suất';
      } else if (level.contains('HALF') || level.contains('MEDIUM')) {
        bg = Colors.amber.shade50;
        fg = Colors.amber.shade900;
        display = '1/2 suất';
      } else if (level.contains('LITTLE') || level.contains('POOR')) {
        bg = Colors.red.shade50;
        fg = Colors.red.shade800;
        display = 'Ăn ít';
      } else {
        display = level;
      }
    }

    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: fg.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            const SizedBox(height: 2),
            Text(
              display,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 2: SỔ ĐIỂM DANH ĐIỆN TỬ
  // ==========================================
  Widget _buildAttendanceTab(ParentProvider prov) {
    if (prov.attendances.isEmpty) {
      return _buildEmptyState(
        icon: Icons.how_to_reg,
        title: 'Chưa có dữ liệu điểm danh',
        subtitle: 'Camera AI và giáo viên sẽ ghi nhận lúc bé đến và rời lớp mỗi ngày.',
        onRefresh: () => prov.loadAttendances(),
      );
    }

    return RefreshIndicator(
      onRefresh: () => prov.loadAttendances(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: prov.attendances.length,
        itemBuilder: (context, idx) {
          final item = prov.attendances[idx];
          final isPresent = item.status == 'PRESENT' || item.status == 'CO_MAT';
          final isOnLeave = item.status == 'ON_LEAVE' || item.status == 'NGHI_PHEP';

          Color statusColor = isPresent
              ? AppColors.success
              : (isOnLeave ? AppColors.warning : AppColors.error);
          String statusText = isPresent
              ? 'Có mặt'
              : (isOnLeave ? 'Nghỉ có phép' : 'Vắng mặt');

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: statusColor.withOpacity(0.12),
                    child: Icon(
                      isPresent ? Icons.check : (isOnLeave ? Icons.event_busy : Icons.close),
                      color: statusColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ngày: ${item.date ?? "---"}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              'Đến: ${item.checkInTime != null ? item.checkInTime!.substring(0, 5) : "---"}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Về: ${item.checkOutTime != null ? item.checkOutTime!.substring(0, 5) : "Chưa về"}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                        if (item.notes != null && item.notes!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text('Ghi chú: ${item.notes}',
                              style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ==========================================
  // TAB 3: SỔ Y TẾ & THỂ CHẤT WHO
  // ==========================================
  Widget _buildHealthTab(ParentProvider prov) {
    return RefreshIndicator(
      onRefresh: () async {
        await prov.loadGrowthHistory();
        await prov.loadAllergies();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Quick Link to Allergies
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            color: Colors.red.shade50,
            child: ListTile(
              leading: const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28),
              title: const Text('Hồ sơ dị ứng của bé', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                prov.allergies.isNotEmpty
                    ? '${prov.allergies.length} cảnh báo dị ứng đã khai báo'
                    : 'Chưa có ghi nhận dị ứng thực phẩm/thuốc',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/parent/allergies'),
            ),
          ),
          const SizedBox(height: 16),

          const Text('Lịch sử đo chỉ số thể chất (Chuẩn WHO):',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          if (prov.growthHistory.isEmpty)
            _buildEmptyState(
              icon: Icons.monitor_weight_outlined,
              title: 'Chưa có số đo thể chất',
              subtitle: 'Nhân viên y tế học đường sẽ đo chiều cao, cân nặng định kỳ mỗi quý.',
              onRefresh: () => prov.loadGrowthHistory(),
            )
          else
            ...prov.growthHistory.map((m) {
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Ngày đo: ${m.measuredDate ?? "---"}',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              m.zscoreCategory ?? 'Bình thường',
                              style: const TextStyle(
                                  color: AppColors.primaryDark,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricTile(
                              icon: Icons.height,
                              label: 'Chiều cao',
                              value: '${m.heightCm ?? 0} cm',
                            ),
                          ),
                          Expanded(
                            child: _buildMetricTile(
                              icon: Icons.monitor_weight_outlined,
                              label: 'Cân nặng',
                              value: '${m.weightKg ?? 0} kg',
                            ),
                          ),
                          Expanded(
                            child: _buildMetricTile(
                              icon: Icons.speed,
                              label: 'BMI',
                              value: '${m.bmi?.toStringAsFixed(1) ?? "---"}',
                            ),
                          ),
                        ],
                      ),
                      if (m.note != null && m.note!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('Đánh giá: ${m.note}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildMetricTile({required IconData icon, required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 4: SỔ NHẬT KÝ LỚP HỌC (ALBUM ẢNH)
  // ==========================================
  Widget _buildJournalTab(ParentProvider prov) {
    if (prov.journalPosts.isEmpty) {
      return _buildEmptyState(
        icon: Icons.photo_library_outlined,
        title: 'Chưa có nhật ký hoạt động',
        subtitle: 'Giáo viên sẽ đăng tải các khoảnh khắc học tập, vui chơi và trải nghiệm của lớp.',
        onRefresh: () {
          final classId = prov.selectedStudent?.classId;
          if (classId != null) return prov.loadJournalPosts(classId);
          return Future.value();
        },
      );
    }

    return RefreshIndicator(
      onRefresh: () {
        final classId = prov.selectedStudent?.classId;
        if (classId != null) return prov.loadJournalPosts(classId);
        return Future.value();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: prov.journalPosts.length,
        itemBuilder: (context, idx) {
          final post = prov.journalPosts[idx];
          return Card(
            margin: const EdgeInsets.only(bottom: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                backgroundColor: Colors.transparent,
                builder: (_) => JournalPostDetailSheet(
                  post: post,
                  loadDetail: post.postId == null
                      ? () async => post
                      : () => prov.loadJournalPostDetail(post.postId!),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (post.imageUrls.isNotEmpty)
                    SizedBox(
                      height: 200,
                      width: double.infinity,
                      child: Image.network(
                        post.imageUrls.first,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.broken_image, size: 40, color: Colors.grey),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                post.title ?? 'Hoạt động lớp',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                            Text(
                              post.createdAt != null && post.createdAt!.length >= 10
                                  ? post.createdAt!.substring(0, 10)
                                  : '',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          post.content ?? '',
                          style: TextStyle(color: Colors.grey.shade800, fontSize: 13, height: 1.4),
                        ),
                        if (post.teacherName != null) ...[
                          const SizedBox(height: 8),
                          Text('Đăng bởi: ${post.teacherName}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                        ],
                        const SizedBox(height: 10),
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.open_in_new, size: 15, color: AppColors.primary),
                            SizedBox(width: 5),
                            Text(
                              'Chạm để xem chi tiết',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ==========================================
  // TAB 5: SỔ ĐÁNH GIÁ PHÁT TRIỂN 5 LĨNH VỰC
  // ==========================================
  Widget _buildDevelopmentTab(ParentProvider prov) {
    if (prov.evaluations.isEmpty) {
      return _buildEmptyState(
        icon: Icons.stars_outlined,
        title: 'Chưa có phiếu đánh giá định kỳ',
        subtitle: 'Giáo viên chủ nhiệm sẽ đánh giá 5 lĩnh vực mầm non vào cuối mỗi học kỳ.',
        onRefresh: () => prov.loadEvaluations(),
      );
    }

    return RefreshIndicator(
      onRefresh: () => prov.loadEvaluations(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: prov.evaluations.length,
        itemBuilder: (context, idx) {
          final eval = prov.evaluations[idx];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Kỳ: ${eval.evaluationPeriod ?? "Học kỳ"}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          eval.status == 'APPROVED' ? 'Đã duyệt' : 'Bản đánh giá',
                          style: const TextStyle(
                              color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  const Text('5 Lĩnh vực phát triển mầm non:',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 10),
                  _buildDomainRow('1. Phát triển Thể chất', eval.physicalScore),
                  _buildDomainRow('2. Phát triển Nhận thức', eval.cognitiveScore),
                  _buildDomainRow('3. Phát triển Ngôn ngữ', eval.languageScore),
                  _buildDomainRow('4. Tình cảm & Kỹ năng xã hội', eval.socialEmotionalScore),
                  _buildDomainRow('5. Phát triển Thẩm mỹ', eval.aestheticScore),
                  if (eval.reviewNote != null && eval.reviewNote!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.comment, size: 16, color: Colors.amber),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Nhận xét: ${eval.reviewNote}',
                              style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDomainRow(String title, String? score) {
    Color color = AppColors.primary;
    String display = score ?? 'Đạt chuẩn';
    if (display == 'GOOD' || display == 'DAT_TOT') {
      display = 'Tốt';
      color = AppColors.success;
    } else if (display == 'PASS' || display == 'DAT') {
      display = 'Đạt yêu cầu';
      color = AppColors.info;
    } else if (display == 'NEEDS_IMPROVEMENT' || display == 'CHUA_DAT') {
      display = 'Cần rèn luyện';
      color = AppColors.warning;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 13)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              display,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required Future<void> Function() onRefresh,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: AppColors.primary.withOpacity(0.08),
              child: Icon(icon, size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Tải lại dữ liệu'),
            ),
          ],
        ),
      ),
    );
  }
}
