import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:kidpro_mobile/core/constants/app_colors.dart';
import 'package:kidpro_mobile/features/teacher/models/teacher_models.dart';
import 'package:kidpro_mobile/features/teacher/providers/teacher_provider.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = context.read<TeacherProvider>();
      prov.loadStudents(prov.currentClassId);
    });
  }

  Color _getStatusColor(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return AppColors.present;
      case AttendanceStatus.notArrived:
        return AppColors.notArrived;
      case AttendanceStatus.onLeave:
        return AppColors.onLeave;
    }
  }

  String _getStatusText(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return 'Có mặt';
      case AttendanceStatus.notArrived:
        return 'Chưa đến';
      case AttendanceStatus.onLeave:
        return 'Nghỉ phép';
    }
  }

  Future<void> _saveBatch() async {
    final prov = context.read<TeacherProvider>();
    final success = await prov.saveBatchAttendance();
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã lưu điểm danh cả lớp thành công!'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(prov.error ?? 'Lưu điểm danh thất bại'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final teacherProv = context.watch<TeacherProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Điểm danh sáng'),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt),
            tooltip: 'Quét khuôn mặt AI',
            onPressed: () => context.go('/teacher/face-attendance'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Stat summary header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Theme.of(context).cardColor,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatBadge(
                  label: 'Có mặt',
                  count: teacherProv.presentCount,
                  color: AppColors.present,
                ),
                _StatBadge(
                  label: 'Chưa đến',
                  count: teacherProv.notArrivedCount,
                  color: AppColors.notArrived,
                ),
                _StatBadge(
                  label: 'Nghỉ phép',
                  count: teacherProv.onLeaveCount,
                  color: AppColors.onLeave,
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Students list
          Expanded(
            child: teacherProv.loading
                ? const Center(child: CircularProgressIndicator())
                : teacherProv.students.isEmpty
                    ? const Center(
                        child: Text('Không có học sinh trong danh sách', style: TextStyle(color: Colors.grey)),
                      )
                    : ListView.builder(
                        itemCount: teacherProv.students.length,
                        itemBuilder: (context, index) {
                          final student = teacherProv.students[index];
                          final statusColor = _getStatusColor(student.status);

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.grey.shade200,
                              child: Text(
                                student.fullName.isNotEmpty ? student.fullName[0] : 'B',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(student.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text('Mã: ${student.studentCode ?? "N/A"}'),
                            trailing: InkWell(
                              onTap: () => teacherProv.toggleStudentStatus(index),
                              borderRadius: BorderRadius.circular(20),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: statusColor, width: 1.5),
                                ),
                                child: Text(
                                  _getStatusText(student.status),
                                  style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // Save batch footer
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: teacherProv.loading ? null : _saveBatch,
                  icon: const Icon(Icons.check),
                  label: const Text('Lưu điểm danh cả lớp', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatBadge({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
