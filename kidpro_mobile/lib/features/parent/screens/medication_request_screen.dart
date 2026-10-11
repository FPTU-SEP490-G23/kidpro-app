import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kidpro_mobile/core/constants/app_colors.dart';
import 'package:kidpro_mobile/features/parent/models/parent_models.dart';
import 'package:kidpro_mobile/features/parent/providers/parent_provider.dart';

class MedicationRequestScreen extends StatefulWidget {
  const MedicationRequestScreen({super.key});

  @override
  State<MedicationRequestScreen> createState() => _MedicationRequestScreenState();
}

class _MedicationRequestScreenState extends State<MedicationRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _medicineNameCtrl = TextEditingController();
  final _dosageCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String? _prescriptionImage;
  bool _submitting = false;

  @override
  void dispose() {
    _medicineNameCtrl.dispose();
    _dosageCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _simulatePickImage() {
    setState(() {
      _prescriptionImage = 'https://picsum.photos/400/300';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã chọn ảnh đơn thuốc minh chứng')),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    final prov = context.read<ParentProvider>();
    final success = await prov.submitMedication(
      MedicationRequest(
        studentId: '',
        medicineName: _medicineNameCtrl.text.trim(),
        dosage: _dosageCtrl.text.trim(),
        note: _noteCtrl.text.trim().isNotEmpty ? _noteCtrl.text.trim() : null,
        prescriptionImageUrl: _prescriptionImage,
      ),
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
        Navigator.pop(context);
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tên thuốc *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _medicineNameCtrl,
                decoration: InputDecoration(
                  hintText: 'Ví dụ: Hapacol 250mg, Siro ho Prospan',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Vui lòng nhập tên thuốc';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              const Text('Liều lượng & Thời điểm uống *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _dosageCtrl,
                decoration: InputDecoration(
                  hintText: 'Ví dụ: 1 gói lúc 14:00 sau ăn trưa',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Vui lòng nhập liều lượng';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              const Text('Ghi chú / Lưu ý thêm cho giáo viên', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _noteCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Pha với 50ml nước ấm, cho bé uống từ từ...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),

              // Image attachment
              const Text('Ảnh chụp đơn thuốc / Vỏ thuốc', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              InkWell(
                onTap: _simulatePickImage,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 140,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                  ),
                  child: _prescriptionImage != null
                      ? Stack(
                          alignment: Alignment.center,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(_prescriptionImage!, fit: BoxFit.cover, width: double.infinity),
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
                                  onPressed: () => setState(() => _prescriptionImage = null),
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
                              'Nhấn để chụp hoặc tải ảnh đơn thuốc',
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
                      : const Text('Gửi dặn thuốc', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
