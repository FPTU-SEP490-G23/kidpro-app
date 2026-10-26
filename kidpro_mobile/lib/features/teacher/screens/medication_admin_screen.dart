import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:kidpro_mobile/core/constants/app_colors.dart';
import 'package:kidpro_mobile/features/teacher/providers/teacher_provider.dart';

class MedicationAdminScreen extends StatefulWidget {
  const MedicationAdminScreen({super.key});

  @override
  State<MedicationAdminScreen> createState() => _MedicationAdminScreenState();
}

class _MedicationAdminScreenState extends State<MedicationAdminScreen> {
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TeacherProvider>().loadDailyMedications();
    });
  }

  void _showAdministerDialog(String medicationId, String studentName) {
    String? capturedPhotoPath;
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Xác nhận: $studentName'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Yêu cầu chụp ảnh minh chứng thực tế khi bé uống thuốc:',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final XFile? photo = await _picker.pickImage(
                      source: ImageSource.camera,
                      maxWidth: 800,
                      maxHeight: 800,
                      imageQuality: 85,
                    );
                    if (photo != null) {
                      setDialogState(() {
                        capturedPhotoPath = photo.path;
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 130,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: capturedPhotoPath != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: capturedPhotoPath!.startsWith('http')
                                ? Image.network(capturedPhotoPath!, fit: BoxFit.cover)
                                : Image.file(File(capturedPhotoPath!), fit: BoxFit.cover),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt, size: 36, color: Colors.grey.shade600),
                              const SizedBox(height: 6),
                              const Text('Bấm để chụp ảnh bé uống thuốc', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú (tùy chọn)',
                    hintText: 'Bé uống ngoan, không nôn trớ...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (capturedPhotoPath == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Vui lòng chụp ảnh minh chứng thực tế trước khi xác nhận!'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                  return;
                }
                Navigator.pop(ctx);
                final resultMsg = await context.read<TeacherProvider>().administerMedication(
                      medicationId,
                      capturedPhotoPath!,
                      noteCtrl.text.trim().isNotEmpty ? noteCtrl.text.trim() : null,
                    );
                if (mounted && resultMsg != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(resultMsg),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              },
              child: const Text('Xác nhận đã uống'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final teacherProv = context.watch<TeacherProvider>();
    final list = teacherProv.medications;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dặn thuốc lúc 14:00'),
      ),
      body: teacherProv.loading
          ? const Center(child: CircularProgressIndicator())
          : list.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.medical_services_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      const Text(
                        'Hôm nay không có học sinh nào cần uống thuốc',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final task = list[index];

                    return Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  task.studentName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: task.isAdministered
                                        ? AppColors.success.withOpacity(0.12)
                                        : AppColors.warning.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    task.isAdministered ? 'Đã uống' : 'Chờ uống (14:00)',
                                    style: TextStyle(
                                      color: task.isAdministered ? AppColors.success : AppColors.warning,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text('Thuốc: ${task.medicineName}', style: const TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text('Liều lượng: ${task.dosage}', style: const TextStyle(color: Colors.black87)),
                            if (task.note != null) ...[
                              const SizedBox(height: 4),
                              Text('Dặn dò: ${task.note}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                            ],
                            const SizedBox(height: 14),
                            if (task.isPending)
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () => _showAdministerDialog(task.id, task.studentName),
                                  icon: const Icon(Icons.camera_alt_outlined),
                                  label: const Text('Chụp ảnh & Xác nhận uống thuốc'),
                                ),
                              )
                            else if (task.proofImageUrl != null)
                              Row(
                                children: [
                                  const Icon(Icons.check_circle, color: AppColors.success, size: 18),
                                  const SizedBox(width: 6),
                                  const Text('Đã có ảnh minh chứng thực tế', style: TextStyle(color: AppColors.success, fontSize: 13)),
                                ],
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
