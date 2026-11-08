import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:kidpro_mobile/core/constants/app_colors.dart';
import 'package:kidpro_mobile/features/parent/models/parent_models.dart';
import 'package:kidpro_mobile/features/parent/providers/parent_provider.dart';

class MedicationRequestScreen extends StatefulWidget {
  const MedicationRequestScreen({super.key});

  @override
  State<MedicationRequestScreen> createState() =>
      _MedicationRequestScreenState();
}

class _MedicationRequestScreenState extends State<MedicationRequestScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  final _medicineNameCtrl = TextEditingController();
  final _dosageCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  Uint8List? _prescriptionBytes;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ParentProvider>().loadMedications();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _medicineNameCtrl.dispose();
    _dosageCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  /// Chỉ cho chụp trực tiếp bằng camera; ảnh được upload lên cloud khi gửi đơn.
  Future<void> _pickPrescriptionImage() async {
    final photo = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 85,
    );
    if (photo == null) return;
    final bytes = await photo.readAsBytes();
    if (!mounted) return;
    setState(() => _prescriptionBytes = bytes);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    final prov = context.read<ParentProvider>();
    final success = await prov.submitMedication(
      MedicationRequest(
        studentId: prov.selectedStudentId,
        studentName: prov.selectedStudentName,
        medicineName: _medicineNameCtrl.text.trim(),
        dosage: _dosageCtrl.text.trim(),
        note: _noteCtrl.text.trim().isNotEmpty ? _noteCtrl.text.trim() : null,
        instructions:
            '${_medicineNameCtrl.text.trim()}: ${_dosageCtrl.text.trim()}. ${_noteCtrl.text.trim()}',
      ),
      prescriptionPhoto: _prescriptionBytes,
    );
    setState(() => _submitting = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã gửi yêu cầu dặn thuốc thành công!'),
            backgroundColor: AppColors.success,
          ),
        );
        _medicineNameCtrl.clear();
        _dosageCtrl.clear();
        _noteCtrl.clear();
        setState(() => _prescriptionBytes = null);
        _tabController.animateTo(1);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(prov.error ?? 'Gửi dặn thuốc thất bại'),
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
        title: const Text('Dặn thuốc cho bé'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(icon: Icon(Icons.add_circle_outline), text: 'Tạo đơn mới'),
            Tab(icon: Icon(Icons.history), text: 'Lịch sử dặn thuốc'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCreateTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildCreateTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Rule notice
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.medical_services_outlined, color: AppColors.info, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Quy định BR-029: Giáo viên & Y tế chỉ tiếp nhận và cho bé uống thuốc có nhãn mác rõ ràng kèm đơn dặn thuốc hoặc toa thuốc của bác sĩ.',
                      style: TextStyle(color: Colors.blue.shade900, fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const Text('Tên thuốc *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _medicineNameCtrl,
              decoration: InputDecoration(
                hintText: 'Ví dụ: Hapacol 250mg, Siro ho Prospan',
                prefixIcon: const Icon(Icons.medication),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Vui lòng nhập tên thuốc';
                return null;
              },
            ),
            const SizedBox(height: 16),

            const Text('Liều lượng & Thời điểm uống *',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _dosageCtrl,
              decoration: InputDecoration(
                hintText: 'Ví dụ: 1 gói (5ml) lúc 11:30 sau ăn trưa',
                prefixIcon: const Icon(Icons.access_time),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Vui lòng nhập liều lượng';
                return null;
              },
            ),
            const SizedBox(height: 16),

            const Text('Ghi chú / Lưu ý thêm cho giáo viên',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _noteCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Pha với 50ml nước ấm, dỗ bé uống từ từ...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),

            // Image attachment
            const Text('Ảnh chụp đơn thuốc / Vỏ thuốc minh chứng',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickPrescriptionImage,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: _prescriptionBytes != null
                    ? Stack(
                        alignment: Alignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(_prescriptionBytes!,
                                fit: BoxFit.cover, width: double.infinity),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: CircleAvatar(
                              backgroundColor: Colors.black54,
                              radius: 16,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.close, color: Colors.white, size: 18),
                                onPressed: () => setState(() => _prescriptionBytes = null),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt_outlined, size: 36, color: Colors.grey.shade600),
                          const SizedBox(height: 8),
                          Text(
                            'Nhấn để chụp ảnh đơn thuốc bằng camera',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 32),

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
                    : const Text('Gửi dặn thuốc',
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
        if (prov.medications.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.medication_outlined, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text('Chưa có yêu cầu dặn thuốc nào',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => prov.loadMedications(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: prov.medications.length,
            itemBuilder: (context, index) {
              final item = prov.medications[index];
              final isPending = item.status == 'PENDING';
              final isAccepted = item.status == 'ACCEPTED';
              final isCompleted = item.status == 'COMPLETED';

              Color statusColor = Colors.orange;
              String statusText = 'CHỜ TIẾP NHẬN';
              if (isAccepted) {
                statusColor = AppColors.info;
                statusText = 'ĐÃ TIẾP NHẬN';
              } else if (isCompleted) {
                statusColor = AppColors.success;
                statusText = 'ĐÃ CHO UỐNG';
              } else if (item.status == 'CANCELLED') {
                statusColor = AppColors.error;
                statusText = 'ĐÃ HỦY';
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
                          if (isPending && item.id != null)
                            TextButton.icon(
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Hủy yêu cầu dặn thuốc?'),
                                    content: const Text('Bạn có chắc muốn hủy đơn dặn thuốc này?'),
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
                                  await prov.cancelMedication(item.id!);
                                }
                              },
                              icon: const Icon(Icons.cancel, size: 16, color: AppColors.error),
                              label: const Text('Hủy đơn', style: TextStyle(color: AppColors.error, fontSize: 13)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        item.instructions,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text(
                            'Thời gian: ${dateFormat.format(item.startDate)} - ${dateFormat.format(item.endDate)}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
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
