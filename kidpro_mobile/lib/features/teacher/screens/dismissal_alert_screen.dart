import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:kidpro_mobile/core/constants/app_colors.dart';
import 'package:kidpro_mobile/core/models/pickup_models.dart';
import 'package:kidpro_mobile/features/teacher/models/teacher_models.dart';
import 'package:kidpro_mobile/features/teacher/providers/teacher_provider.dart';
import 'package:kidpro_mobile/features/teacher/screens/pickup_qr_scanner_screen.dart';
import 'package:kidpro_mobile/features/teacher/widgets/pickup_face_check.dart';
import 'package:kidpro_mobile/features/teacher/widgets/pickup_handover_sheet.dart';

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
  final _otpCtrl = TextEditingController();

  // Đón muộn: tự tải lại mỗi phút để phí tạm tính luôn cập nhật (BR-020)
  Timer? _latePickupTimer;

  // Đón hộ (BR-022)
  EmergencyPickupInfo? _pickupInfo;
  String? _pickupCode;
  String? _pickupError;
  bool _pickupBusy = false;
  // Kết quả quét mặt người đón hộ (chỉ khi phụ huynh có gửi ảnh, BR-022)
  PickupFaceVerification? _pickupFace;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = context.read<TeacherProvider>();
      prov.loadStrangerAlerts();
      prov.loadStudents(prov.currentClassId);
      prov.loadLatePickups();
    });
    _latePickupTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) context.read<TeacherProvider>().loadLatePickups();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _flashController.dispose();
    _noteCtrl.dispose();
    _latePickupTimer?.cancel();
    _otpCtrl.dispose();
    super.dispose();
  }

  void _showSnack(String message, {required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? AppColors.success : AppColors.error,
      ),
    );
  }

  // ── Trả trẻ cho phụ huynh / người đón thường xuyên, có quét mặt (G5-UC-04, BR-022) ──
  Future<void> _confirmCheckout(TeacherStudent student) async {
    final message = await showPickupHandoverSheet(context, student);
    if (message != null && mounted) _showSnack(message, success: true);
  }

  // ── Đón hộ: kiểm tra mã QR / OTP (G5-UC-06, BR-022) ──
  Future<void> _scanQr() async {
    final code = await Navigator.of(context, rootNavigator: true).push<String>(
      MaterialPageRoute(builder: (_) => const PickupQrScannerScreen()),
    );
    if (code != null && mounted) await _verifyCode(code);
  }

  Future<void> _verifyCode(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) {
      setState(() => _pickupError = 'Vui lòng quét mã QR hoặc nhập mã OTP.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _pickupBusy = true;
      _pickupError = null;
      _pickupInfo = null;
      _pickupFace = null;
    });
    final (info, message) = await context.read<TeacherProvider>().verifyEmergencyPickup(trimmed);
    if (!mounted) return;
    setState(() {
      _pickupBusy = false;
      _pickupInfo = info;
      _pickupCode = info != null ? trimmed : null;
      _pickupError = info == null ? message : null;
    });
  }

  /// Đón hộ có ảnh: tự gọi khi quét mặt khớp. Không có ảnh: giáo viên bấm "Bàn giao" sau khi đối chiếu CCCD.
  Future<void> _confirmHandover() async {
    final info = _pickupInfo;
    final code = _pickupCode;
    if (info == null || code == null || _pickupBusy) return;

    if (!info.hasPickupPhoto) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Bàn giao trẻ cho người đón hộ'),
          content: Text(
            'Cô đã đối chiếu CCCD của ${info.pickupPersonName} và xác nhận bàn giao bé ${info.studentName}?',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Bàn giao'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }

    setState(() => _pickupBusy = true);
    final (success, message) = await context.read<TeacherProvider>().confirmEmergencyPickup(
          info,
          code,
          faceVerificationId: info.hasPickupPhoto ? _pickupFace?.verificationId : null,
        );
    if (!mounted) return;
    setState(() {
      _pickupBusy = false;
      if (success) {
        _resetPickup();
      } else {
        _pickupError = message;
      }
    });
    _showSnack(message, success: success);
  }

  void _resetPickup() {
    _pickupInfo = null;
    _pickupCode = null;
    _pickupError = null;
    _pickupFace = null;
    _otpCtrl.clear();
  }

  String _shortTime(String? time) {
    if (time == null || time.isEmpty) return '--:--';
    return time.length >= 5 ? time.substring(0, 5) : time;
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
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            const Tab(
              icon: Icon(Icons.family_restroom_rounded),
              text: 'Trả trẻ',
            ),
            const Tab(
              icon: Icon(Icons.qr_code_scanner_rounded),
              text: 'Đón hộ',
            ),
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
          _buildHandoverTab(students),
          _buildEmergencyPickupTab(),

          // ── Tab 3: Cảnh báo người lạ (G5-UC-04) ──
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

          // ── Tab 4: Đón muộn tự động tính phí (G5-UC-05, BR-020) ──
          _buildLatePickupTab(),
        ],
      ),
    );
  }

  // ── Tab 4: Hệ thống tự tính, giáo viên chỉ theo dõi (BR-020) ──
  Widget _buildLatePickupTab() {
    final prov = context.watch<TeacherProvider>();
    final records = prov.latePickups;
    final waiting = records.where((r) => r.isWaiting).toList();
    final pickedUp = records.where((r) => !r.isWaiting).toList();
    final money = NumberFormat.decimalPattern('vi_VN');
    final total = records.fold<double>(0, (sum, r) => sum + r.feeAmount);

    return RefreshIndicator(
      onRefresh: () => prov.loadLatePickups(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
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
                      'Hệ thống tự tính phí đón muộn: bé chưa được trả sau 17:30 tính 30.000đ/giờ '
                      '(giờ chưa trọn tính 1 giờ), chỉ tính đến 19:00 — tối đa 60.000đ. '
                      'Phí chốt khi bấm trả trẻ. Danh sách tự cập nhật mỗi phút.',
                      style: TextStyle(fontSize: 13, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _lateStat('Đang chờ đón', '${waiting.length}', AppColors.error)),
              const SizedBox(width: 10),
              Expanded(child: _lateStat('Đã trả muộn', '${pickedUp.length}', AppColors.primary)),
              const SizedBox(width: 10),
              Expanded(child: _lateStat('Tổng phí', '${money.format(total)}đ', Colors.orange.shade800)),
            ],
          ),
          if (prov.latePickupsError != null) ...[
            const SizedBox(height: 12),
            Text(prov.latePickupsError!, style: const TextStyle(color: AppColors.error)),
          ],
          const SizedBox(height: 16),
          if (records.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(Icons.check_circle_outline, size: 64, color: AppColors.success.withOpacity(0.6)),
                  const SizedBox(height: 12),
                  const Text('Chưa có bé nào bị đón muộn hôm nay',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text('Sau 17:30, bé chưa được trả sẽ tự hiện ở đây.',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          if (waiting.isNotEmpty) ...[
            Text('Đang chờ đón (phí còn tăng)', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...waiting.map((r) => _latePickupTile(r, money)),
            const SizedBox(height: 12),
          ],
          if (pickedUp.isNotEmpty) ...[
            Text('Đã trả muộn (phí đã chốt)', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...pickedUp.map((r) => _latePickupTile(r, money)),
          ],
        ],
      ),
    );
  }

  Widget _lateStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          FittedBox(
            child: Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _latePickupTile(LatePickupRecord r, NumberFormat money) {
    final hours = r.lateMinutes ~/ 60;
    final minutes = r.lateMinutes % 60;
    final lateText = hours > 0 ? '$hours giờ $minutes phút' : '$minutes phút';
    final color = r.isWaiting ? AppColors.error : AppColors.primary;
    final subtitle = <String>[
      r.isWaiting ? 'Chưa được đón · muộn $lateText' : 'Trả lúc ${r.pickupTime} · muộn $lateText',
      if (r.parentName != null) 'PH: ${r.parentName}${r.parentPhone != null ? ' · ${r.parentPhone}' : ''}',
    ].join('\n');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withOpacity(0.4)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.12),
          child: Icon(r.isWaiting ? Icons.hourglass_top_rounded : Icons.check_rounded, color: color),
        ),
        title: Text(r.studentName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, height: 1.35)),
        isThreeLine: r.parentName != null,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${money.format(r.feeAmount)}đ',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
            Text('${r.chargedHours} giờ', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  // ── Tab 1: Trả trẻ cho bố mẹ đón bình thường (G5-UC-04) ──
  Widget _buildHandoverTab(List<TeacherStudent> students) {
    final present = students
        .where((s) => s.status == AttendanceStatus.present || s.status == AttendanceStatus.late)
        .toList()
      ..sort((a, b) {
        // Bé chưa về lên trước
        final aOut = a.checkOutTime != null ? 1 : 0;
        final bOut = b.checkOutTime != null ? 1 : 0;
        if (aOut != bOut) return aOut - bOut;
        return a.fullName.compareTo(b.fullName);
      });
    final checkedOut = present.where((s) => s.checkOutTime != null).length;

    if (present.isEmpty) {
      return RefreshIndicator(
        onRefresh: () {
          final prov = context.read<TeacherProvider>();
          return prov.loadStudents(prov.currentClassId);
        },
        child: ListView(
          children: [
            const SizedBox(height: 120),
            Icon(
              context.watch<TeacherProvider>().studentsError != null ? Icons.cloud_off_rounded : Icons.groups_outlined,
              size: 72,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                context.watch<TeacherProvider>().studentsError ?? 'Chưa có bé nào được điểm danh có mặt hôm nay',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 6),
            const Center(
              child: Text(
                'Kéo xuống để tải lại. Hãy điểm danh buổi sáng trước khi trả trẻ.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () {
        final prov = context.read<TeacherProvider>();
        return prov.loadStudents(prov.currentClassId);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.family_restroom_rounded, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Đã trả $checkedOut/${present.length} bé',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                Text(
                  'Còn ${present.length - checkedOut} bé',
                  style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Bố mẹ hoặc người đón thường xuyên: bấm "Trả trẻ" và quét mặt. Người đón hộ có mã QR: dùng tab "Đón hộ".',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          ...present.map((s) {
            final isOut = s.checkOutTime != null;
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                leading: CircleAvatar(
                  backgroundColor: isOut ? Colors.grey.shade200 : AppColors.primary.withValues(alpha: 0.12),
                  child: Text(
                    s.fullName.isNotEmpty ? s.fullName.trim().split(' ').last[0] : '?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isOut ? Colors.grey : AppColors.primary,
                    ),
                  ),
                ),
                title: Text(
                  s.fullName,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isOut ? Colors.grey.shade600 : Colors.black87,
                  ),
                ),
                subtitle: Text(
                  'Đến lớp: ${_shortTime(s.checkInTime)}${s.studentCode != null ? '  •  ${s.studentCode}' : ''}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: isOut
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Đã về ${_shortTime(s.checkOutTime)}',
                          style: const TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      )
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _confirmCheckout(s),
                        child: const Text('Trả trẻ'),
                      ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Tab 2: Đón hộ bằng mã QR / OTP (G5-UC-06, BR-022) ──
  Widget _buildEmergencyPickupTab() {
    final info = _pickupInfo;
    final timeFmt = DateFormat('HH:mm');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: Colors.blue.shade50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.blue.shade200),
          ),
          child: const Padding(
            padding: EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.info, size: 26),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Quy tắc BR-022: Người đón hộ phải có mã QR hoặc OTP do phụ huynh tạo, hiệu lực tối đa 60 phút. Mỗi mã chỉ dùng được 1 lần.',
                    style: TextStyle(fontSize: 13, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Quét QR
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _pickupBusy ? null : _scanQr,
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: const Text('Quét mã QR của người đón', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey.shade300)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text('hoặc nhập mã OTP', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            ),
            Expanded(child: Divider(color: Colors.grey.shade300)),
          ],
        ),
        const SizedBox(height: 12),

        // Nhập OTP
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _otpCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textInputAction: TextInputAction.done,
                onSubmitted: _pickupBusy ? null : _verifyCode,
                style: const TextStyle(fontSize: 20, letterSpacing: 6, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  hintText: '••••••',
                  counterText: '',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.pin_outlined),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 56,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _pickupBusy ? null : () => _verifyCode(_otpCtrl.text),
                child: const Text('Kiểm tra'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        if (_pickupBusy)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          ),

        // Mã không hợp lệ
        if (!_pickupBusy && _pickupError != null)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.gpp_bad_rounded, color: AppColors.error),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$_pickupError\n\nKHÔNG bàn giao trẻ. Liên hệ phụ huynh để xác minh.',
                    style: const TextStyle(color: Color(0xFF991B1B), height: 1.35),
                  ),
                ),
              ],
            ),
          ),

        // Mã hợp lệ: thông tin để đối chiếu
        if (!_pickupBusy && info != null)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.success, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.verified_user_rounded, color: AppColors.success),
                      SizedBox(width: 8),
                      Text(
                        'Mã đón hộ hợp lệ',
                        style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _infoRow(Icons.child_care_rounded, 'Bé',
                          '${info.studentName}${info.className != null ? ' (${info.className})' : ''}'),
                      _infoRow(Icons.badge_rounded, 'Người đón', info.pickupPersonName),
                      if (info.pickupPersonPhone != null)
                        _infoRow(Icons.phone_rounded, 'Số điện thoại', info.pickupPersonPhone!),
                      if (info.parentName != null)
                        _infoRow(Icons.person_rounded, 'Phụ huynh ủy quyền', info.parentName!),
                      if (info.validUntil != null)
                        _infoRow(Icons.timer_outlined, 'Hiệu lực đến', timeFmt.format(info.validUntil!)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          info.hasPickupPhoto
                              ? 'Phụ huynh có gửi ảnh người đón: quét mặt, khớp thì tự động bàn giao.'
                              : 'Phụ huynh không gửi ảnh người đón: đối chiếu CCCD rồi bấm "Bàn giao".',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                        ),
                      ),
                      if (info.hasPickupPhoto) ...[
                        const SizedBox(height: 12),
                        PickupFaceCheck(
                          key: ValueKey('emergency_${info.authorizationId}'),
                          studentId: info.studentId,
                          personType: 'EMERGENCY',
                          personName: info.pickupPersonName,
                          authorizationId: info.authorizationId,
                          onResult: (r) {
                            setState(() => _pickupFace = r);
                            // Khuôn mặt khớp: tự động bàn giao
                            if (r != null && r.matched) _confirmHandover();
                          },
                        ),
                        if (_pickupFace != null && !_pickupFace!.matched) ...[
                          const SizedBox(height: 12),
                          CallParentsCard(
                            title: 'Khuôn mặt không khớp với ảnh phụ huynh đã gửi.',
                            parents: [
                              if (info.parentName != null) (name: info.parentName!, phone: info.parentPhone),
                            ],
                          ),
                        ],
                      ],
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => setState(_resetPickup),
                              child: const Text('Hủy'),
                            ),
                          ),
                          if (!info.hasPickupPhoto) ...[
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: _pickupBusy ? null : _confirmHandover,
                                icon: const Icon(Icons.how_to_reg_rounded),
                                label: const Text('Bàn giao'),
                              ),
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
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
