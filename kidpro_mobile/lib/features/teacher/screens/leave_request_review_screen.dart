import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kidpro_mobile/core/constants/app_colors.dart';
import 'package:kidpro_mobile/features/teacher/providers/teacher_provider.dart';

class LeaveRequestReviewScreen extends StatefulWidget {
  const LeaveRequestReviewScreen({super.key});

  @override
  State<LeaveRequestReviewScreen> createState() => _LeaveRequestReviewScreenState();
}

class _LeaveRequestReviewScreenState extends State<LeaveRequestReviewScreen> {
  final _commentCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TeacherProvider>().loadTeacherLeaveRequests();
    });
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  void _showActionDialog(int requestId, bool isApprove) {
    _commentCtrl.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isApprove ? 'Phê duyệt đơn xin nghỉ học' : 'Từ chối đơn xin nghỉ học'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isApprove
                  ? 'Xác nhận duyệt đơn. Điểm danh đã được hệ thống tự đánh khi phụ huynh gửi đơn: '
                      'trước 08:00 là "Vắng có phép" (trừ tiền ăn sáng + trưa), từ 08:00 là "Vắng không phép" (không trừ tiền ăn).'
                  : 'Vui lòng nhập lý do từ chối đơn:',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _commentCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: isApprove ? 'Ghi chú cho phụ huynh (Tùy chọn)' : 'Lý do từ chối (Bắt buộc)',
                border: const OutlineInputBorder(),
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
              backgroundColor: isApprove ? AppColors.success : AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final status = isApprove ? 'APPROVED' : 'REJECTED';
              try {
                final msg = await context.read<TeacherProvider>().reviewLeaveRequest(
                      requestId,
                      status,
                      _commentCtrl.text.trim(),
                    );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(msg ?? 'Cập nhật thành công'), backgroundColor: AppColors.success),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
                  );
                }
              }
            },
            child: Text(isApprove ? 'Duyệt đơn' : 'Từ chối'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<TeacherProvider>();
    final requests = prov.leaveRequests;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Duyệt Đơn Xin Nghỉ Học'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => prov.loadTeacherLeaveRequests(),
          ),
        ],
      ),
      body: prov.loading
          ? const Center(child: CircularProgressIndicator())
          : requests.isEmpty
              ? const Center(child: Text('Không có đơn xin nghỉ học nào cần xử lý.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final item = requests[index];
                    final isPending = item.status == 'PENDING';
                    final isApproved = item.status == 'APPROVED';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  item.studentName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isPending
                                        ? Colors.amber.shade50
                                        : (isApproved ? Colors.green.shade50 : Colors.red.shade50),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isPending
                                          ? Colors.amber
                                          : (isApproved ? Colors.green : Colors.red),
                                    ),
                                  ),
                                  child: Text(
                                    isPending ? 'CHỜ DUYỆT' : (isApproved ? 'ĐÃ DUYỆT' : 'TỪ CHỐI'),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isPending
                                          ? Colors.amber.shade900
                                          : (isApproved ? Colors.green.shade800 : Colors.red.shade800),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.date_range, size: 16, color: Colors.grey),
                                const SizedBox(width: 6),
                                Text(
                                  'Từ: ${item.startDate}  đến: ${item.endDate}',
                                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Lý do: ${item.reason}',
                              style: const TextStyle(fontSize: 13, color: Colors.black87),
                            ),
                            const SizedBox(height: 8),
                            if (item.mealRefundEligible)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check, size: 14, color: Colors.blue),
                                    SizedBox(width: 4),
                                    Text(
                                      'Đủ điều kiện hoàn tiền ăn bếp (BR-065)',
                                      style: TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              )
                            else
                              const Text(
                                'Vắng không phép - không hoàn tiền ăn (nộp từ 08:00)',
                                style: TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            if (isPending) ...[
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        side: const BorderSide(color: Colors.red),
                                      ),
                                      onPressed: () => _showActionDialog(item.id, false),
                                      child: const Text('Từ chối'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.success,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () => _showActionDialog(item.id, true),
                                      child: const Text('Phê duyệt'),
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
}
