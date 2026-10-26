import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:kidpro_mobile/core/constants/app_colors.dart';
import 'package:kidpro_mobile/features/teacher/providers/teacher_provider.dart';

class EquipmentIncidentScreen extends StatefulWidget {
  const EquipmentIncidentScreen({super.key});

  @override
  State<EquipmentIncidentScreen> createState() => _EquipmentIncidentScreenState();
}

class _EquipmentIncidentScreenState extends State<EquipmentIncidentScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _photoUrlCtrl = TextEditingController(
      text: 'https://images.unsplash.com/photo-1585338107529-13afc5f02586?w=600');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = context.read<TeacherProvider>();
      prov.loadEquipmentIncidents(prov.currentClassId);
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _photoUrlCtrl.dispose();
    super.dispose();
  }

  void _showReportModal() {
    _nameCtrl.clear();
    _descCtrl.clear();

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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.build_circle, color: AppColors.error, size: 28),
                  const SizedBox(width: 8),
                  Text(
                    'Báo hỏng Cơ sở Vật chất (BR-051)',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Quy tắc BR-051 & BR-052: Bắt buộc đính kèm ảnh chụp hiện trường thực tế. Hệ thống tự động kiểm tra trùng lặp thiết bị đang chờ xử lý.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tên thiết bị / Hạng mục hư hỏng',
                  hintText: 'Ví dụ: Điều hòa Daikin, Vòi nước bồn rửa...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.handyman),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Mô tả hiện trạng hư hỏng',
                  hintText: 'Bị rỉ nước, quạt kêu to, chập điện...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _photoUrlCtrl,
                decoration: const InputDecoration(
                  labelText: 'URL Ảnh chụp hiện trường (Bắt buộc BR-051)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.camera_alt),
                ),
              ),
              const SizedBox(height: 20),

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
                  label: const Text('Gửi báo cáo CSVC (MSG-185)'),
                  onPressed: () async {
                    if (_nameCtrl.text.trim().isEmpty || _photoUrlCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text('Vui lòng nhập tên thiết bị và ảnh hiện trường!'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    Navigator.pop(ctx);
                    final prov = context.read<TeacherProvider>();
                    final msg = await prov.reportEquipmentIncident(
                      equipmentName: _nameCtrl.text.trim(),
                      description: _descCtrl.text.trim(),
                      photoUrl: _photoUrlCtrl.text.trim(),
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(msg ?? 'Báo cáo thành công'), backgroundColor: AppColors.success),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<TeacherProvider>();
    final incidents = prov.equipmentIncidents;
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cơ sở Vật chất & Báo hỏng'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => prov.loadEquipmentIncidents(prov.currentClassId),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.error,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Báo hỏng CSVC'),
        onPressed: _showReportModal,
      ),
      body: prov.loading
          ? const Center(child: CircularProgressIndicator())
          : incidents.isEmpty
              ? const Center(child: Text('Không có thiết bị nào đang hỏng.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: incidents.length,
                  itemBuilder: (context, index) {
                    final item = incidents[index];
                    final isRepaired = item.status == 'REPAIRED';

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
                                  item.equipmentName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isRepaired ? Colors.green.shade50 : Colors.amber.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: isRepaired ? Colors.green : Colors.amber),
                                  ),
                                  child: Text(
                                    isRepaired ? 'ĐÃ SỬA CHỮA' : 'ĐANG SỬA CHỮA',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: isRepaired ? Colors.green.shade800 : Colors.amber.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(item.description, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                            const SizedBox(height: 8),
                            if (item.photoUrl != null && item.photoUrl!.isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  item.photoUrl!,
                                  height: 120,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const SizedBox(),
                                ),
                              ),
                            const SizedBox(height: 8),
                            Text(
                              'Báo cáo lúc: ${dateFmt.format(item.createdAt)} - ${item.classroomName}',
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
