import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:kidpro_mobile/core/constants/app_colors.dart';
import 'package:kidpro_mobile/features/teacher/providers/teacher_provider.dart';

class HealthIncidentsScreen extends StatefulWidget {
  const HealthIncidentsScreen({super.key});

  @override
  State<HealthIncidentsScreen> createState() => _HealthIncidentsScreenState();
}

class _HealthIncidentsScreenState extends State<HealthIncidentsScreen> {
  final _descCtrl = TextEditingController();
  final _firstAidCtrl = TextEditingController();
  String? _selectedStudentId;
  String _incidentType = 'TRẦY XƯỚC';
  String _severity = 'MILD';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prov = context.read<TeacherProvider>();
      await prov.loadStudents(prov.currentClassId);
      if (prov.students.isNotEmpty) {
        prov.loadHealthIncidents(prov.students.first.id);
      }
    });
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _firstAidCtrl.dispose();
    super.dispose();
  }

  void _showReportIncidentDialog() {
    _descCtrl.clear();
    _firstAidCtrl.clear();
    _severity = 'MILD';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final students = context.watch<TeacherProvider>().students;
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.emergency, color: AppColors.error, size: 28),
                      const SizedBox(width: 8),
                      Text(
                        'Báo cáo Sự cố Y tế & Sơ cứu (BR-031)',
                        style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    value: _selectedStudentId ?? (students.isNotEmpty ? students.first.id : null),
                    decoration: const InputDecoration(
                      labelText: 'Chọn học sinh',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: students.map((s) => DropdownMenuItem(
                      value: s.id,
                      child: Text(s.fullName),
                    )).toList(),
                    onChanged: (val) => setModalState(() => _selectedStudentId = val),
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    value: _incidentType,
                    decoration: const InputDecoration(
                      labelText: 'Loại sự cố y tế',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'TRẦY XƯỚC', child: Text('Trầy xước da / Vết thương hở nhẹ')),
                      DropdownMenuItem(value: 'SỐT CAO', child: Text('Sốt cao đột ngột (trên 38.5°C)')),
                      DropdownMenuItem(value: 'DỊ ỨNG', child: Text('Dị ứng thức ăn / Mẩn ngứa')),
                      DropdownMenuItem(value: 'VA ĐẬP', child: Text('Va đập mạnh / Chấn thương phần mềm')),
                      DropdownMenuItem(value: 'ĐAU BỤNG', child: Text('Đau bụng / Nôn trớ')),
                    ],
                    onChanged: (val) => setModalState(() => _incidentType = val ?? 'TRẦY XƯỚC'),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      const Text('Mức độ: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      ChoiceChip(
                        label: const Text('Nhẹ (MILD)'),
                        selected: _severity == 'MILD',
                        onSelected: (val) => setModalState(() => _severity = 'MILD'),
                      ),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: const Text('Vừa (MODERATE)'),
                        selected: _severity == 'MODERATE',
                        onSelected: (val) => setModalState(() => _severity = 'MODERATE'),
                      ),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: const Text('Nặng (SEVERE)'),
                        selected: _severity == 'SEVERE',
                        selectedColor: Colors.red.shade100,
                        onSelected: (val) => setModalState(() => _severity = 'SEVERE'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Mô tả chi tiết sự cố',
                      hintText: 'Bé bị ngã ở đâu, thời điểm nào, biểu hiện của bé...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _firstAidCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: _severity == 'SEVERE'
                          ? 'Biện pháp sơ cứu khẩn cấp (Bắt buộc theo BR-031)'
                          : 'Biện pháp sơ cứu tại chỗ',
                      hintText: 'Đã rửa vết thương, chườm lạnh, cho uống hạ sốt...',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.send),
                      label: const Text('Gửi báo cáo sự cố (MSG-135)'),
                      onPressed: () async {
                        if (_severity == 'SEVERE' && _firstAidCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('BR-031: Bắt buộc mô tả phương án sơ cứu cho ca nghiêm trọng!'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        if (students.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Chưa có học sinh trong lớp để ghi nhận sự cố!'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        Navigator.pop(ctx);
                        final studentId = _selectedStudentId ?? students.first.id;
                        final msg = await context.read<TeacherProvider>().reportHealthIncident(
                              studentId: studentId,
                              incidentType: _incidentType,
                              severity: _severity,
                              description: _descCtrl.text.trim(),
                              firstAidGiven: _firstAidCtrl.text.trim(),
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
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<TeacherProvider>();
    final incidents = prov.healthIncidents;
    final timeFmt = DateFormat('HH:mm - dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sự cố Y tế & Sơ cứu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (prov.students.isNotEmpty) {
                prov.loadHealthIncidents(prov.students.first.id);
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.error,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_alert),
        label: const Text('Báo cáo sự cố'),
        onPressed: _showReportIncidentDialog,
      ),
      body: incidents.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.health_and_safety, size: 64, color: Colors.green.shade300),
                  const SizedBox(height: 12),
                  const Text('Không có sự cố y tế nào ghi nhận hôm nay.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: incidents.length,
              itemBuilder: (context, index) {
                final item = incidents[index];
                final isSevere = item.severity == 'SEVERE';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSevere ? Colors.red : Colors.orange.shade200,
                      width: isSevere ? 1.5 : 1.0,
                    ),
                  ),
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
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isSevere ? Colors.red.shade50 : Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: isSevere ? Colors.red : Colors.orange),
                              ),
                              child: Text(
                                item.severity,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: isSevere ? Colors.red : Colors.orange.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Loại sự cố: ${item.incidentType}',
                          style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black87),
                        ),
                        const SizedBox(height: 4),
                        Text(item.description, style: const TextStyle(fontSize: 13, color: Colors.black54)),
                        if (item.firstAidGiven != null && item.firstAidGiven!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.medical_services, size: 16, color: Colors.green),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Sơ cứu: ${item.firstAidGiven}',
                                    style: TextStyle(fontSize: 12, color: Colors.green.shade900),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          timeFmt.format(item.createdAt),
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
