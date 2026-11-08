import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:kidpro_mobile/core/constants/app_colors.dart';
import 'package:kidpro_mobile/features/teacher/models/teacher_models.dart';
import 'package:kidpro_mobile/features/teacher/providers/teacher_provider.dart';
import 'package:kidpro_mobile/features/teacher/screens/parent_pickup_camera_screen.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  DateTime _selectedDate = DateTime.now();
  String _searchQuery = '';
  AttendanceStatus? _filterStatus; // null means 'All'
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final prov = context.read<TeacherProvider>();
    if (prov.currentClassId.isEmpty) {
      await prov.loadMyClasses();
    }
    await prov.loadStudents(prov.currentClassId, _selectedDate);
  }

  Color _getStatusColor(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return AppColors.present;
      case AttendanceStatus.late:
        return AppColors.late;
      case AttendanceStatus.onLeave:
        return AppColors.onLeave;
      case AttendanceStatus.notArrived:
        return AppColors.notArrived;
    }
  }

  String _getStatusText(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return 'Có mặt';
      case AttendanceStatus.late:
        return 'Đi muộn';
      case AttendanceStatus.onLeave:
        return 'Nghỉ phép';
      case AttendanceStatus.notArrived:
        return 'Chưa đến';
    }
  }

  IconData _getStatusIcon(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return Icons.check_circle_rounded;
      case AttendanceStatus.late:
        return Icons.access_time_filled_rounded;
      case AttendanceStatus.onLeave:
        return Icons.event_busy_rounded;
      case AttendanceStatus.notArrived:
        return Icons.radio_button_unchecked_rounded;
    }
  }

  String _formatDateVietnamese(DateTime d) {
    const days = [
      'Thứ Hai',
      'Thứ Ba',
      'Thứ Tư',
      'Thứ Năm',
      'Thứ Sáu',
      'Thứ Bảy',
      'Chủ Nhật'
    ];
    final dayName = days[d.weekday - 1];
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final year = d.year.toString();
    return '$dayName, $day/$month/$year';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    // BR-018: Giới hạn không chọn quá 7 ngày trước để tránh khóa sổ học vụ
    final initialDate = _selectedDate;
    final firstDate = now.subtract(const Duration(days: 7));
    final lastDate = now.add(const Duration(days: 1));

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(firstDate) ? firstDate : initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'CHỌN NGÀY ĐIỂM DANH',
      confirmText: 'CHỌN',
      cancelText: 'HỦY',
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadData();
    }
  }

  Future<void> _confirmMarkAllPresent() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.present),
            SizedBox(width: 8),
            Text('Điểm danh nhanh', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Đánh dấu TẤT CẢ học sinh trong lớp là "Có mặt" với giờ hiện tại?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      context.read<TeacherProvider>().markAllPresent();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã cập nhật tất cả học sinh là "Có mặt"'),
          backgroundColor: AppColors.present,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _saveBatch() async {
    final prov = context.read<TeacherProvider>();
    final success = await prov.saveBatchAttendance(date: _selectedDate);
    if (mounted) {
      if (success) {
        final dStr =
            '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white),
                const SizedBox(width: 8),
                Text('Đã lưu sổ điểm danh ngày $dStr thành công!'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(prov.error ?? 'Lưu điểm danh thất bại'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showStudentDetailSheet(TeacherStudent student, int studentIndex) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _StudentDetailSheet(
        student: student,
        studentIndex: studentIndex,
        onSaved: () => setState(() {}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final teacherProv = context.watch<TeacherProvider>();
    final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());
    final dateFormatted = _formatDateVietnamese(_selectedDate);

    // Filter students
    final filteredStudents = teacherProv.students.where((s) {
      if (_filterStatus != null && s.status != _filterStatus) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final nameMatches = s.fullName.toLowerCase().contains(q);
        final codeMatches = s.studentCode?.toLowerCase().contains(q) ?? false;
        return nameMatches || codeMatches;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.scaffoldLight,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Column(
          children: [
            const Text(
              'Điểm danh lớp học',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              teacherProv.currentClassName.isNotEmpty
                  ? teacherProv.currentClassName
                  : 'Lớp học',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'Quét AI Face Điểm danh',
            onPressed: () => context.push('/teacher/face-attendance'),
          ),
          IconButton(
            icon: const Icon(Icons.face_retouching_natural_rounded),
            tooltip: 'Quét mặt phụ huynh đón trẻ',
            onPressed: () {
              final cId = teacherProv.currentClassId;
              if (cId.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Vui lòng chọn lớp học trước khi quét.')),
                );
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ParentPickupCameraScreen(
                    classId: cId,
                    className: teacherProv.currentClassName.isNotEmpty
                        ? teacherProv.currentClassName
                        : 'Lớp học',
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Date Bar ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.white,
            child: Row(
              children: [
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          dateFormatted,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_drop_down, size: 18, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                if (!isToday)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedDate = DateTime.now();
                      });
                      _loadData();
                    },
                    icon: const Icon(Icons.today_rounded, size: 16, color: AppColors.primary),
                    label: const Text('Hôm nay', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ),

          // ── KPI Stats Header (4 Statuses) ──
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'Có mặt',
                    count: teacherProv.presentCount,
                    color: AppColors.present,
                    icon: Icons.check_circle_rounded,
                    isSelected: _filterStatus == AttendanceStatus.present,
                    onTap: () => setState(() {
                      _filterStatus = _filterStatus == AttendanceStatus.present
                          ? null
                          : AttendanceStatus.present;
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    title: 'Đi muộn',
                    count: teacherProv.lateCount,
                    color: AppColors.late,
                    icon: Icons.access_time_filled_rounded,
                    isSelected: _filterStatus == AttendanceStatus.late,
                    onTap: () => setState(() {
                      _filterStatus = _filterStatus == AttendanceStatus.late
                          ? null
                          : AttendanceStatus.late;
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    title: 'Nghỉ phép',
                    count: teacherProv.onLeaveCount,
                    color: AppColors.onLeave,
                    icon: Icons.event_busy_rounded,
                    isSelected: _filterStatus == AttendanceStatus.onLeave,
                    onTap: () => setState(() {
                      _filterStatus = _filterStatus == AttendanceStatus.onLeave
                          ? null
                          : AttendanceStatus.onLeave;
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    title: 'Chưa đến',
                    count: teacherProv.notArrivedCount,
                    color: AppColors.notArrived,
                    icon: Icons.pending_actions_rounded,
                    isSelected: _filterStatus == AttendanceStatus.notArrived,
                    onTap: () => setState(() {
                      _filterStatus = _filterStatus == AttendanceStatus.notArrived
                          ? null
                          : AttendanceStatus.notArrived;
                    }),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

          // ── Quick Action & Search/Filter Row ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val.trim()),
                      decoration: InputDecoration(
                        hintText: 'Tìm theo tên hoặc mã HS...',
                        hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                        prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.primary),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    backgroundColor: Colors.white,
                  ),
                  onPressed: _confirmMarkAllPresent,
                  icon: const Icon(Icons.done_all_rounded, size: 18),
                  label: const Text(
                    'Cả lớp có mặt',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // ── Filter Chips Bar ──
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                _FilterChip(
                  label: 'Tất cả (${teacherProv.totalCount})',
                  isSelected: _filterStatus == null,
                  onSelected: () => setState(() => _filterStatus = null),
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: 'Có mặt (${teacherProv.presentCount})',
                  color: AppColors.present,
                  isSelected: _filterStatus == AttendanceStatus.present,
                  onSelected: () => setState(() => _filterStatus = AttendanceStatus.present),
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: 'Đi muộn (${teacherProv.lateCount})',
                  color: AppColors.late,
                  isSelected: _filterStatus == AttendanceStatus.late,
                  onSelected: () => setState(() => _filterStatus = AttendanceStatus.late),
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: 'Nghỉ phép (${teacherProv.onLeaveCount})',
                  color: AppColors.onLeave,
                  isSelected: _filterStatus == AttendanceStatus.onLeave,
                  onSelected: () => setState(() => _filterStatus = AttendanceStatus.onLeave),
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: 'Chưa đến (${teacherProv.notArrivedCount})',
                  color: AppColors.notArrived,
                  isSelected: _filterStatus == AttendanceStatus.notArrived,
                  onSelected: () => setState(() => _filterStatus = AttendanceStatus.notArrived),
                ),
              ],
            ),
          ),

          // ── Students List ──
          Expanded(
            child: teacherProv.loading
                ? const Center(child: CircularProgressIndicator())
                : filteredStudents.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              teacherProv.studentsError != null
                                  ? Icons.cloud_off_rounded
                                  : Icons.person_search_rounded,
                              size: 56,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Text(
                                _searchQuery.isNotEmpty
                                    ? 'Không tìm thấy học sinh phù hợp'
                                    : teacherProv.studentsError ?? 'Không có học sinh trong danh sách',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                              ),
                            ),
                            if (teacherProv.studentsError != null && _searchQuery.isEmpty) ...[
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: _loadData,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Thử lại'),
                              ),
                            ],
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async => _loadData(),
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 90),
                          itemCount: filteredStudents.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final student = filteredStudents[index];
                            final originalIndex = teacherProv.students.indexOf(student);

                            return _StudentAttendanceCard(
                              student: student,
                              onTapDetail: () => _showStudentDetailSheet(student, originalIndex),
                              onStatusChanged: (newStatus) {
                                teacherProv.setStudentStatus(originalIndex, newStatus);
                              },
                              getStatusColor: _getStatusColor,
                              getStatusText: _getStatusText,
                              getStatusIcon: _getStatusIcon,
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),

      // ── Bottom Fixed Save Bar ──
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              offset: const Offset(0, -4),
              blurRadius: 10,
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hiện diện: ${teacherProv.presentCount + teacherProv.lateCount}/${teacherProv.totalCount} học sinh',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      teacherProv.notArrivedCount > 0
                          ? 'Còn ${teacherProv.notArrivedCount} bé chưa điểm danh'
                          : 'Đã hoàn tất kiểm diện',
                      style: TextStyle(
                        fontSize: 12,
                        color: teacherProv.notArrivedCount > 0 ? AppColors.warning : AppColors.success,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                onPressed: teacherProv.loading ? null : _saveBatch,
                icon: teacherProv.loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.cloud_upload_rounded, size: 20),
                label: const Text(
                  'Lưu điểm danh',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Sub-components
// ─────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String title;
  final int count;
  final Color color;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatCard({
    required this.title,
    required this.count,
    required this.color,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : color.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 2),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;
  final Color? color;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? AppColors.primary;
    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : Colors.grey.shade800,
          ),
        ),
      ),
    );
  }
}

class _StudentAttendanceCard extends StatelessWidget {
  final TeacherStudent student;
  final VoidCallback onTapDetail;
  final ValueChanged<AttendanceStatus> onStatusChanged;
  final Color Function(AttendanceStatus) getStatusColor;
  final String Function(AttendanceStatus) getStatusText;
  final IconData Function(AttendanceStatus) getStatusIcon;

  const _StudentAttendanceCard({
    required this.student,
    required this.onTapDetail,
    required this.onStatusChanged,
    required this.getStatusColor,
    required this.getStatusText,
    required this.getStatusIcon,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = getStatusColor(student.status);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: student.status == AttendanceStatus.notArrived
              ? Colors.grey.shade200
              : statusColor.withOpacity(0.35),
          width: 1.2,
        ),
      ),
      child: InkWell(
        onTap: onTapDetail,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: Avatar, Info, and Status Icon Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: statusColor.withOpacity(0.15),
                    child: Text(
                      student.fullName.isNotEmpty
                          ? student.fullName.trim().split(' ').last[0]
                          : 'B',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student.fullName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                student.studentCode ?? 'N/A',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (student.checkInTime != null && student.checkInTime!.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Icon(Icons.schedule_rounded, size: 13, color: Colors.grey.shade600),
                              const SizedBox(width: 2),
                              Text(
                                student.checkInTime!,
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                              ),
                            ],
                            if (student.checkInMethod == 'AI_FACE_RECOGNITION') ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.purple.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'AI Face',
                                  style: TextStyle(fontSize: 10, color: Colors.purple.shade700),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert_rounded, color: Colors.grey),
                    tooltip: 'Chi tiết đón trẻ',
                    onPressed: onTapDetail,
                  ),
                ],
              ),

              // Note snippet or guardian if present
              if ((student.notes != null && student.notes!.isNotEmpty) ||
                  (student.guardianName != null && student.guardianName!.isNotEmpty)) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 14, color: Colors.amber.shade900),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          student.notes != null && student.notes!.isNotEmpty
                              ? student.notes!
                              : 'Người đưa: ${student.guardianName}',
                          style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 10),

              // ── 4-Segment Quick Attendance Switcher ──
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    _QuickStatusButton(
                      label: 'Có mặt',
                      color: AppColors.present,
                      isSelected: student.status == AttendanceStatus.present,
                      onTap: () => onStatusChanged(AttendanceStatus.present),
                    ),
                    _QuickStatusButton(
                      label: 'Muộn',
                      color: AppColors.late,
                      isSelected: student.status == AttendanceStatus.late,
                      onTap: () => onStatusChanged(AttendanceStatus.late),
                    ),
                    _QuickStatusButton(
                      label: 'Phép',
                      color: AppColors.onLeave,
                      isSelected: student.status == AttendanceStatus.onLeave,
                      onTap: () => onStatusChanged(AttendanceStatus.onLeave),
                    ),
                    _QuickStatusButton(
                      label: 'Vắng',
                      color: AppColors.notArrived,
                      isSelected: student.status == AttendanceStatus.notArrived,
                      onTap: () => onStatusChanged(AttendanceStatus.notArrived),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickStatusButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _QuickStatusButton({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? Colors.white : Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Detailed Check-in Bottom Sheet (Màn hình chi tiết đón trẻ)
// ─────────────────────────────────────────────────────────────

class _StudentDetailSheet extends StatefulWidget {
  final TeacherStudent student;
  final int studentIndex;
  final VoidCallback onSaved;

  const _StudentDetailSheet({
    required this.student,
    required this.studentIndex,
    required this.onSaved,
  });

  @override
  State<_StudentDetailSheet> createState() => _StudentDetailSheetState();
}

class _StudentDetailSheetState extends State<_StudentDetailSheet> {
  late AttendanceStatus _status;
  late TextEditingController _notesCtrl;
  late TextEditingController _guardianCtrl;
  late TextEditingController _tempCtrl;
  TimeOfDay _checkInTime = TimeOfDay.now();
  String? _capturedPhotoUrl;

  @override
  void initState() {
    super.initState();
    _status = widget.student.status;
    _notesCtrl = TextEditingController(text: widget.student.notes ?? '');
    _guardianCtrl = TextEditingController(text: widget.student.guardianName ?? '');
    _tempCtrl = TextEditingController(
      text: widget.student.temperature != null ? widget.student.temperature.toString() : '36.5',
    );
    _capturedPhotoUrl = widget.student.photoUrl;

    if (widget.student.checkInTime != null && widget.student.checkInTime!.contains(':')) {
      final parts = widget.student.checkInTime!.split(':');
      if (parts.length >= 2) {
        final h = int.tryParse(parts[0]) ?? DateTime.now().hour;
        final m = int.tryParse(parts[1]) ?? DateTime.now().minute;
        _checkInTime = TimeOfDay(hour: h, minute: m);
      }
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _guardianCtrl.dispose();
    _tempCtrl.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(source: ImageSource.camera, maxWidth: 800);
      if (photo != null) {
        setState(() {
          _capturedPhotoUrl = photo.path;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã chụp ảnh minh chứng đón trẻ')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi máy ảnh: $e')),
        );
      }
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _checkInTime,
      helpText: 'GIỜ ĐẾN LỚP',
    );
    if (picked != null) {
      setState(() => _checkInTime = picked);
    }
  }

  void _saveDetails() {
    final prov = context.read<TeacherProvider>();
    final formattedTime =
        '${_checkInTime.hour.toString().padLeft(2, '0')}:${_checkInTime.minute.toString().padLeft(2, '0')}';
    final temp = double.tryParse(_tempCtrl.text.trim());

    prov.updateStudentDetails(
      index: widget.studentIndex,
      status: _status,
      checkInTime: (_status == AttendanceStatus.present || _status == AttendanceStatus.late)
          ? formattedTime
          : null,
      notes: _notesCtrl.text.trim(),
      temperature: temp,
      guardianName: _guardianCtrl.text.trim(),
      photoUrl: _capturedPhotoUrl,
    );

    widget.onSaved();
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã cập nhật thông tin điểm danh của ${widget.student.fullName}'),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header info
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.primary.withOpacity(0.12),
                  child: Text(
                    widget.student.fullName.isNotEmpty
                        ? widget.student.fullName.trim().split(' ').last[0]
                        : 'B',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.student.fullName,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Mã HS: ${widget.student.studentCode ?? "N/A"}',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // ── Chọn trạng thái điểm danh ──
            const Text(
              'Trạng thái điểm danh',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _StatusSelectTile(
                  label: 'Có mặt',
                  color: AppColors.present,
                  isSelected: _status == AttendanceStatus.present,
                  onTap: () => setState(() => _status = AttendanceStatus.present),
                ),
                const SizedBox(width: 8),
                _StatusSelectTile(
                  label: 'Đi muộn',
                  color: AppColors.late,
                  isSelected: _status == AttendanceStatus.late,
                  onTap: () => setState(() => _status = AttendanceStatus.late),
                ),
                const SizedBox(width: 8),
                _StatusSelectTile(
                  label: 'Nghỉ phép',
                  color: AppColors.onLeave,
                  isSelected: _status == AttendanceStatus.onLeave,
                  onTap: () => setState(() => _status = AttendanceStatus.onLeave),
                ),
                const SizedBox(width: 8),
                _StatusSelectTile(
                  label: 'Chưa đến',
                  color: AppColors.notArrived,
                  isSelected: _status == AttendanceStatus.notArrived,
                  onTap: () => setState(() => _status = AttendanceStatus.notArrived),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Giờ đến & Thân nhiệt ──
            if (_status == AttendanceStatus.present || _status == AttendanceStatus.late) ...[
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Giờ đến lớp',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: _selectTime,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time_rounded, size: 18, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Text(
                                  '${_checkInTime.hour.toString().padLeft(2, '0')}:${_checkInTime.minute.toString().padLeft(2, '0')}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Thân nhiệt (°C)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _tempCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            hintText: '36.5',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            prefixIcon: const Icon(Icons.thermostat_rounded, size: 18, color: Colors.orange),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ],

            // ── Người đưa trẻ đến lớp ──
            const Text(
              'Người đưa trẻ đến trường',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _guardianCtrl,
              decoration: InputDecoration(
                hintText: 'Mẹ Nguyễn Thị Mai / Bố...',
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                filled: true,
                fillColor: Colors.grey.shade50,
                prefixIcon: const Icon(Icons.person_pin_rounded, size: 18, color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ── Ghi chú tình trạng trẻ ──
            const Text(
              'Ghi chú tình trạng bé lúc đón',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'VD: Bé ho nhẹ, mẹ dặn uống thêm nước ấm, mang thêm sữa...',
                contentPadding: const EdgeInsets.all(12),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ── Chụp ảnh minh chứng đón trẻ ──
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                side: BorderSide(color: Colors.grey.shade400),
              ),
              onPressed: _takePhoto,
              icon: Icon(
                _capturedPhotoUrl != null ? Icons.check_circle : Icons.camera_alt_outlined,
                color: _capturedPhotoUrl != null ? AppColors.success : AppColors.primary,
              ),
              label: Text(
                _capturedPhotoUrl != null
                    ? 'Đã có ảnh minh chứng đón trẻ (Chụp lại)'
                    : 'Chụp ảnh phụ huynh / bé lúc đón',
                style: TextStyle(
                  color: _capturedPhotoUrl != null ? AppColors.success : AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Save button ──
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _saveDetails,
                child: const Text(
                  'Cập nhật thông tin bé',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusSelectTile extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatusSelectTile({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color : color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : color.withOpacity(0.3),
              width: isSelected ? 2 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : color,
            ),
          ),
        ),
      ),
    );
  }
}
