import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kidpro_mobile/core/constants/app_colors.dart';
import 'package:kidpro_mobile/features/teacher/providers/teacher_provider.dart';

class BusAttendanceScreen extends StatefulWidget {
  const BusAttendanceScreen({super.key});

  @override
  State<BusAttendanceScreen> createState() => _BusAttendanceScreenState();
}

class _BusAttendanceScreenState extends State<BusAttendanceScreen> {
  final _qrTokenCtrl = TextEditingController(text: 'BUS-TAIL-QR-2026-OK');
  final _photoUrlCtrl = TextEditingController(
      text: 'https://images.unsplash.com/photo-1570125909232-eb263c188f7e?w=500');

  @override
  void initState() {
    super.initState();
    // Lấy tuyến xe được phân công cho giáo viên, tự tải chuyến đầu tiên
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TeacherProvider>().loadBusRoutes();
    });
  }

  @override
  void dispose() {
    _qrTokenCtrl.dispose();
    _photoUrlCtrl.dispose();
    super.dispose();
  }

  void _showSafetyClosureModal() {
    final trip = context.read<TeacherProvider>().currentBusTrip;
    final remainingCount = trip?.remainingCount ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified_user, color: AppColors.primary, size: 28),
                const SizedBox(width: 8),
                Text(
                  'Kiểm tra khoang xe & Đóng chuyến (BR-024)',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: remainingCount == 0 ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: remainingCount == 0 ? Colors.green : Colors.red,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    remainingCount == 0 ? Icons.check_circle : Icons.error,
                    color: remainingCount == 0 ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      remainingCount == 0
                          ? 'Đã xác nhận 0 học sinh còn sót lại trên xe.'
                          : 'CẢNH BÁO (MSG-099): Còn $remainingCount học sinh chưa xuống xe! Không thể đóng chuyến.',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: remainingCount == 0 ? Colors.green.shade800 : Colors.red.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _photoUrlCtrl,
              decoration: const InputDecoration(
                labelText: 'URL Ảnh chụp khoang xe kiểm tra an toàn',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.camera_alt),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _qrTokenCtrl,
              decoration: const InputDecoration(
                labelText: 'Mã quét QR dán ở đuôi xe (Tail Scan Token)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.qr_code_scanner),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.lock_clock),
                label: const Text('Xác nhận An toàn & Đóng Chuyến (MSG-100)'),
                onPressed: trip == null ? null : () async {
                  Navigator.pop(ctx);
                  final msg = await context.read<TeacherProvider>().performBusSafetyClosure(
                        tripId: trip.tripId,
                        photoUrl: _photoUrlCtrl.text.trim(),
                        qrTailScanToken: _qrTokenCtrl.text.trim(),
                      );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(msg ?? 'Đã hoàn tất đóng chuyến'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<TeacherProvider>();
    final trip = prov.currentBusTrip;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Điểm danh Xe Buýt Tuyến'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => prov.loadBusRoutes(),
          ),
        ],
      ),
      body: prov.loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Thẻ thông tin chuyến đi
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                trip?.plateNumber ?? '29B-678.90',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ),
                            Text(
                              trip?.isSafetyClosed == true ? 'Đã đóng chuyến' : 'Đang hoạt động',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: trip?.isSafetyClosed == true ? Colors.grey : AppColors.success,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          trip?.routeName ?? 'Tuyến số 01: Đưa đón học sinh',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem('Tổng học sinh', '${trip?.totalStudents ?? 0}', Colors.blue),
                            _buildStatItem('Trên xe', '${trip?.onboardCount ?? 0}', Colors.orange),
                            _buildStatItem('Đã xuống xe', '${trip?.deboardedCount ?? 0}', Colors.green),
                            _buildStatItem('Còn lại', '${trip?.remainingCount ?? 0}', Colors.red),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                Text('Danh sách trạm đón / trả', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),

                if (trip == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('Chưa được phân công tuyến xe buýt nào',
                          style: TextStyle(color: Colors.grey)),
                    ),
                  )
                else if (trip.stops.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('Tuyến này chưa có điểm dừng',
                          style: TextStyle(color: Colors.grey)),
                    ),
                  )
                else
                  ...trip.stops.map((stop) => _buildStopTile(
                        context,
                        stopName: stop.stopName,
                        time: stop.estimatedTime,
                        boardedCount: stop.boardedCount,
                        deboardedCount: stop.deboardedCount,
                        isPassed: stop.isPassed,
                        isDestination: stop.isDestination,
                      )),

                const SizedBox(height: 24),

                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.fact_check),
                  label: const Text('Quy trình Kiểm tra An toàn & Đóng chuyến (BR-024)'),
                  onPressed: _showSafetyClosureModal,
                ),
              ],
            ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _buildStopTile(
    BuildContext context, {
    required String stopName,
    required String time,
    required int boardedCount,
    required int deboardedCount,
    required bool isPassed,
    bool isDestination = false,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isDestination ? Colors.red.shade100 : Colors.blue.shade100,
          child: Icon(
            isDestination ? Icons.school : Icons.directions_bus,
            color: isDestination ? Colors.red : Colors.blue,
          ),
        ),
        title: Text(stopName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text('Thời gian dự kiến: $time'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.green.shade300),
          ),
          child: Text(
            isDestination ? 'Trả: $deboardedCount' : 'Đón: $boardedCount',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800, fontSize: 12),
          ),
        ),
      ),
    );
  }
}
