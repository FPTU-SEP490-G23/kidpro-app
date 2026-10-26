import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:kidpro_mobile/core/constants/app_colors.dart';
import 'package:kidpro_mobile/features/parent/models/parent_models.dart';
import 'package:kidpro_mobile/features/parent/providers/parent_provider.dart';

class LeaveRequestScreen extends StatefulWidget {
  const LeaveRequestScreen({super.key});

  @override
  State<LeaveRequestScreen> createState() => _LeaveRequestScreenState();
}

class _LeaveRequestScreenState extends State<LeaveRequestScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  final _reasonCtrl = TextEditingController();

  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  DateTime _endDate = DateTime.now().add(const Duration(days: 1));
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ParentProvider>().loadLeaveRequests();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Check cutoff: if start date is today and past 08:00 AM
    final now = DateTime.now();
    final isToday = _startDate.year == now.year &&
        _startDate.month == now.month &&
        _startDate.day == now.day;
    final isAfter8Am = now.hour > 8 || (now.hour == 8 && now.minute > 0);

    bool eligibleMealRefund = true;
    if (isToday && isAfter8Am) {
      eligibleMealRefund = false;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Quá 08:00 AM (BR-036)'),
          content: const Text(
            'Đơn xin nghỉ nộp sau 08:00 sáng hôm nay sẽ KHÔNG được hoàn tiền ăn bán trú của ngày hôm nay theo quy chế nhà trường.\n\nBạn vẫn muốn tiếp tục gửi đơn?',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy bỏ')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Tiếp tục nộp đơn'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    setState(() => _submitting = true);
    final prov = context.read<ParentProvider>();
    final success = await prov.submitLeaveRequest(
      LeaveRequest(
        studentId: prov.selectedStudentId,
        studentName: prov.selectedStudentName,
        reason: _reasonCtrl.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
        eligibleForMealRefund: eligibleMealRefund,
      ),
    );
    setState(() => _submitting = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã gửi đơn xin nghỉ thành công!'),
            backgroundColor: AppColors.success,
          ),
        );
        _reasonCtrl.clear();
        _tabController.animateTo(1);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(prov.error ?? 'Gửi đơn thất bại'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đơn xin nghỉ học'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(icon: Icon(Icons.note_add), text: 'Nộp đơn mới'),
            Tab(icon: Icon(Icons.history), text: 'Lịch sử đơn nghỉ'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFormTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildFormTab() {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Notice banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warning.withOpacity(0.5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: AppColors.warning, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Quy định BR-018 / BR-036: Đơn xin nghỉ nộp trước 08:00 sáng sẽ được hệ thống tự động hoàn lại tiền ăn bán trú vào hóa đơn kỳ tới.',
                      style: TextStyle(color: Colors.orange.shade900, fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Student Name info
            Consumer<ParentProvider>(
              builder: (_, prov, __) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.child_care, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Học sinh: ${prov.selectedStudentName}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Date selection
            const Text('Thời gian xin nghỉ *',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickDateRange,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _startDate.isAtSameMomentAs(_endDate)
                          ? dateFormat.format(_startDate)
                          : '${dateFormat.format(_startDate)} - ${dateFormat.format(_endDate)}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                    const Icon(Icons.date_range, color: AppColors.primary, size: 22),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Reason
            const Text('Lý do xin nghỉ *',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _reasonCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Ví dụ: Bé bị sốt nhẹ, gia đình cho bé nghỉ ngơi theo dõi tại nhà...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Vui lòng nhập lý do xin nghỉ';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),

            // Submit button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Gửi đơn xin nghỉ',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Consumer<ParentProvider>(
      builder: (context, prov, child) {
        if (prov.leaveRequests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_busy, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text('Chưa có đơn xin nghỉ nào',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => prov.loadLeaveRequests(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: prov.leaveRequests.length,
            itemBuilder: (context, index) {
              final req = prov.leaveRequests[index];
              final isPending = req.status == 'PENDING';
              final isApproved = req.status == 'APPROVED';

              Color statusColor = Colors.orange;
              String statusText = 'CHỜ DUYỆT';
              if (isApproved) {
                statusColor = AppColors.success;
                statusText = 'ĐÃ DUYỆT';
              } else if (req.status == 'REJECTED') {
                statusColor = AppColors.error;
                statusText = 'TỪ CHỐI';
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          if (isPending && req.id != null)
                            TextButton.icon(
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Hủy đơn xin nghỉ?'),
                                    content: const Text('Bạn có chắc muốn hủy đơn xin nghỉ này?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Không')),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: const Text('Hủy đơn', style: TextStyle(color: Colors.white)),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await prov.cancelLeaveRequest(req.id!);
                                }
                              },
                              icon: const Icon(Icons.cancel, size: 16, color: AppColors.error),
                              label: const Text('Hủy đơn', style: TextStyle(color: AppColors.error, fontSize: 13)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 16, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            req.startDate.isAtSameMomentAs(req.endDate)
                                ? dateFormat.format(req.startDate)
                                : '${dateFormat.format(req.startDate)} - ${dateFormat.format(req.endDate)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(req.reason, style: TextStyle(color: Colors.grey.shade800, fontSize: 14)),
                      const Divider(height: 20),
                      Row(
                        children: [
                          Icon(
                            req.eligibleForMealRefund ? Icons.check_circle : Icons.remove_circle_outline,
                            size: 16,
                            color: req.eligibleForMealRefund ? AppColors.success : Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            req.eligibleForMealRefund
                                ? 'Đủ điều kiện hoàn tiền ăn bán trú'
                                : 'Không hoàn tiền ăn (Nộp sau 08:00 AM)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: req.eligibleForMealRefund ? Colors.green.shade800 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
