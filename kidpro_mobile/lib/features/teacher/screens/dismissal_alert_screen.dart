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
    with SingleTickerProviderStateMixin {
  late AnimationController _flashController;
  final _noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TeacherProvider>().loadStrangerAlerts();
    });
  }

  @override
  void dispose() {
    _flashController.dispose();
    _noteCtrl.dispose();
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
                hintText: 'Ví dụ: Đã gọi điện cho mẹ xác nhận...',
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
    final timeFormat = DateFormat('HH:mm:ss - dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tan học & Cảnh báo an toàn'),
      ),
      body: alerts.isEmpty
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
    );
  }
}
