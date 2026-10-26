import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kidpro_mobile/core/constants/app_colors.dart';
import 'package:kidpro_mobile/features/teacher/providers/teacher_provider.dart';

class HealthMetricsScreen extends StatefulWidget {
  const HealthMetricsScreen({super.key});

  @override
  State<HealthMetricsScreen> createState() => _HealthMetricsScreenState();
}

class _HealthMetricsScreenState extends State<HealthMetricsScreen> {
  final Map<String, TextEditingController> _heightControllers = {};
  final Map<String, TextEditingController> _weightControllers = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = context.read<TeacherProvider>();
      prov.loadHealthMetricsEntrySheet(prov.currentClassId).then((_) {
        _initControllers();
      });
    });
  }

  void _initControllers() {
    final metrics = context.read<TeacherProvider>().healthMetrics;
    for (final item in metrics) {
      _heightControllers[item.studentId] = TextEditingController(
        text: item.heightCm != null ? item.heightCm.toString() : '',
      );
      _weightControllers[item.studentId] = TextEditingController(
        text: item.weightKg != null ? item.weightKg.toString() : '',
      );
    }
    setState(() {});
  }

  @override
  void dispose() {
    for (final c in _heightControllers.values) {
      c.dispose();
    }
    for (final c in _weightControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _calculateWhoStatus(double? heightCm, double? weightKg) {
    if (heightCm == null || weightKg == null || heightCm <= 0) return 'Chưa đo';
    final heightM = heightCm / 100.0;
    final bmi = weightKg / (heightM * heightM);

    if (bmi < 14.0) return 'Suy dinh dưỡng';
    if (bmi < 17.0) return 'Bình thường';
    if (bmi < 19.0) return 'Thừa cân';
    return 'Béo phì';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Bình thường':
        return Colors.green;
      case 'Suy dinh dưỡng':
        return Colors.orange;
      case 'Thừa cân':
        return Colors.deepOrange;
      case 'Béo phì':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<TeacherProvider>();
    final metrics = prov.healthMetrics;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chỉ số Thể chất Định kỳ (WHO)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => prov.loadHealthMetricsEntrySheet(prov.currentClassId),
          ),
        ],
      ),
      body: prov.loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  color: Colors.blue.shade50,
                  padding: const EdgeInsets.all(12),
                  child: const Row(
                    children: [
                      Icon(Icons.health_and_safety, color: AppColors.primary),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Quy tắc BR-031: Nhập chiều cao & cân nặng. Hệ thống tự động tính chỉ số BMI và phân loại thể trạng theo chuẩn WHO.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: metrics.isEmpty
                      ? const Center(
                          child: Text(
                            'Chưa có danh sách học sinh cần đo thể lực trong lớp',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: metrics.length,
                    itemBuilder: (context, index) {
                      final item = metrics[index];
                      final heightCtrl = _heightControllers[item.studentId];
                      final weightCtrl = _weightControllers[item.studentId];

                      final hVal = double.tryParse(heightCtrl?.text ?? '');
                      final wVal = double.tryParse(weightCtrl?.text ?? '');
                      final status = _calculateWhoStatus(hVal, wVal);
                      final bmiStr = (hVal != null && wVal != null && hVal > 0)
                          ? (wVal / ((hVal / 100) * (hVal / 100))).toStringAsFixed(1)
                          : '--';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    item.studentName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(status).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: _getStatusColor(status)),
                                    ),
                                    child: Text(
                                      status,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: _getStatusColor(status),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: heightCtrl,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: const InputDecoration(
                                        labelText: 'Chiều cao (cm)',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: weightCtrl,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: const InputDecoration(
                                        labelText: 'Cân nặng (kg)',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      children: [
                                        const Text('BMI', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                        Text(bmiStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      ],
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
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.save),
                      label: const Text('Lưu toàn bộ chỉ số thể chất (MSG-131)'),
                      onPressed: () async {
                        final batchList = <Map<String, dynamic>>[];
                        for (final item in metrics) {
                          final h = double.tryParse(_heightControllers[item.studentId]?.text ?? '');
                          final w = double.tryParse(_weightControllers[item.studentId]?.text ?? '');
                          if (h != null && w != null) {
                            batchList.add({
                              'studentId': item.studentId,
                              'heightCm': h,
                              'weightKg': w,
                            });
                          }
                        }

                        final msg = await prov.submitHealthMetricsBatch(batchList);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(msg ?? 'Lưu thành công'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
