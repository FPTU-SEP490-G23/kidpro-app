import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:kidpro_mobile/core/constants/app_colors.dart';
import 'package:kidpro_mobile/features/teacher/providers/teacher_provider.dart';

class DismissalAlertScreen extends StatefulWidget {
  const DismissalAlertScreen({super.key});

  @override
  State<DismissalAlertScreen> createState() => _DismissalAlertScreenState();
}

class _DismissalAlertScreenState extends State<DismissalAlertScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _flashController;
  final _noteCtrl = TextEditingController();
  final _exemptionReasonCtrl = TextEditingController();

  String? _selectedStudentId;
  TimeOfDay _pickupTime = const TimeOfDay(hour: 17, minute: 45);
  bool _isExempted = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = context.read<TeacherProvider>();
      prov.loadStrangerAlerts();
      prov.loadStudents(prov.currentClassId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _flashController.dispose();
    _noteCtrl.dispose();
    _exemptionReasonCtrl.dispose();
    super.dispose();
  }

  void _showResolveDialog(String alertId) {
    _noteCtrl.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xử lý an toàn'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ghi chú kết quả xác minh người đón:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Ví dụ: Đã gọi điện cho mẹ xác nhận ủy quyền...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await context
                  .read<TeacherProvider>()
                  .resolveStrangerAlert(alertId, _noteCtrl.text.trim());
              if (mounted && success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã đánh dấu xử lý cảnh báo an toàn'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            child: const Text('Đã xử lý'),
          ),
        ],
      ),
    );
  }

  double _calculateLateFee(TimeOfDay time, bool isExempted) {
    if (isExempted) return 0.0;
    final totalMinutes = time.hour * 60 + time.minute;
    const cutoffMinutes = 17 * 60; // 17:00
    final lateMinutes = totalMinutes - cutoffMinutes;

    if (lateMinutes <= 30) return 0.0; // Ân hạn 30 phút theo BR-020
    if (lateMinutes <= 60) return 30000.0;
    final extraHours = ((lateMinutes - 60) / 60.0).ceil();
    return 30000.0 + (extraHours * 30000.0);
  }

  @override
  Widget build(BuildContext context) {
    final teacherProv = context.watch<TeacherProvider>();
    final alerts = teacherProv.strangerAlerts;
    final students = teacherProv.students;
    final timeFormat = DateFormat('HH:mm:ss - dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tan học & Đón trả trẻ'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: Badge(
                isLabelVisible: alerts.isNotEmpty,
                label: Text('${alerts.length}'),
                child: const Icon(Icons.security),
              ),
              text: 'Cảnh báo Người lạ',
            ),
            const Tab(
              icon: Icon(Icons.timer_outlined),
              text: 'Theo dõi Đón muộn',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Tab 1: Cảnh báo người lạ (G5-UC-04) ──
          alerts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shield_outlined, size: 72, color: AppColors.success.withOpacity(0.6)),
                      const SizedBox(height: 16),
                      const Text(
                        'Khu vực đón trẻ an toàn',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Không phát hiện người lạ chưa ủy quyền.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: alerts.length,
                  itemBuilder: (context, index) {
                    final alert = alerts[index];

                    return AnimatedBuilder(
                      animation: _flashController,
                      builder: (context, child) {
                        final color = Color.lerp(
                          AppColors.strangerAlert,
                          Colors.orange,
                          _flashController.value,
                        )!;

                        return Card(
                          elevation: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: color, width: 2),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.warning, color: color, size: 28),
                                    const SizedBox(width: 8),
                                    Text(
                                      'CẢNH BÁO NGƯỜI LẠ!',
                                      style: TextStyle(
                                        color: color,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (alert.snapshotUrl != null)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(
                                      alert.snapshotUrl!,
                                      height: 160,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        height: 120,
                                        color: Colors.grey.shade200,
                                        child: const Center(
                                          child: Icon(Icons.person_off, size: 48, color: Colors.grey),
                                        ),
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 12),
                                Text(
                                  'Thời điểm: ${timeFormat.format(alert.detectedAt)}',
                                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                                ),
                                if (alert.confidence != null)
                                  Text(
                                    'Độ khớp cao nhất: ${(alert.confidence! * 100).toStringAsFixed(1)}% (Dưới ngưỡng an toàn)',
                                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                                  ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.strangerAlert,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: () => _showResolveDialog(alert.id),
                                    icon: const Icon(Icons.verified_user),
                                    label: const Text('Xử lý / Xác minh phụ huynh'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),

          // ── Tab 2: Theo dõi Đón Muộn & Tính phí (G5-UC-05, BR-020) ──
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: Colors.amber.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.amber.shade400),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.amber, size: 28),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Quy tắc BR-020: Giờ tan trường là 17:00. Miễn phí ân hạn 30 phút đầu (đến 17:30). Sau 17:30 tính 30.000 VNĐ/giờ lũy tiến.',
                          style: TextStyle(fontSize: 13, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text('Ghi nhận mốc giờ đón muộn', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),

              // Chọn học sinh
              DropdownButtonFormField<String>(
                value: _selectedStudentId ?? (students.isNotEmpty ? students.first.id : null),
                decoration: const InputDecoration(
                  labelText: 'Chọn học sinh đón muộn',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.child_care),
                ),
                items: students.map((s) => DropdownMenuItem(
                  value: s.id,
                  child: Text('${s.fullName} (${s.studentCode ?? "Chưa có mã"})'),
                )).toList(),
                onChanged: (val) => setState(() => _selectedStudentId = val),
              ),
              const SizedBox(height: 16),

              // Chọn giờ đón
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                leading: const Icon(Icons.access_time, color: AppColors.primary),
                title: const Text('Thời gian phụ huynh đón thực tế'),
                subtitle: Text(
                  '${_pickupTime.format(context)} (Muộn: ${((_pickupTime.hour * 60 + _pickupTime.minute) - 17 * 60).clamp(0, 300)} phút)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: TextButton(
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: _pickupTime,
                    );
                    if (picked != null) {
                      setState(() => _pickupTime = picked);
                    }
                  },
                  child: const Text('Đổi giờ'),
                ),
              ),
              const SizedBox(height: 16),

              // Miễn phí đón muộn
              CheckboxListTile(
                value: _isExempted,
                title: const Text('Miễn phí đón muộn (Lý do khách quan)'),
                subtitle: const Text('Thời tiết xấu, sự cố đột xuất có xác nhận của BGH'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) => setState(() => _isExempted = val ?? false),
              ),
              if (_isExempted) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _exemptionReasonCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Lý do miễn trừ',
                    hintText: 'Nhập lý do miễn giảm phí đón muộn...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Phí tạm tính
              Builder(
                builder: (context) {
                  final fee = _calculateLateFee(_pickupTime, _isExempted);
                  final currencyFmt = NumberFormat.currency(locale: 'vi_VN', symbol: 'VNĐ');
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Mức phí đón muộn dự tính:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          currencyFmt.format(fee),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: fee > 0 ? AppColors.error : AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Xác nhận & Ghi nhận Đón Muộn (MSG-094)'),
                onPressed: () async {
                  final studentId = _selectedStudentId ?? (students.isNotEmpty ? students.first.id : '');
                  if (studentId.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Vui lòng chọn học sinh')),
                    );
                    return;
                  }

                  final timeStr = '${_pickupTime.hour.toString().padLeft(2, '0')}:${_pickupTime.minute.toString().padLeft(2, '0')}';
                  final msg = await teacherProv.recordLatePickup(
                    studentId: studentId,
                    pickupTime: timeStr,
                    isExempted: _isExempted,
                    exemptionReason: _isExempted ? _exemptionReasonCtrl.text.trim() : null,
                  );

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(msg ?? 'Ghi nhận thành công'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
