import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kidpro_mobile/core/constants/app_colors.dart';
import 'package:kidpro_mobile/features/parent/models/parent_models.dart';
import 'package:kidpro_mobile/features/parent/providers/parent_provider.dart';

class AllergyProfileScreen extends StatefulWidget {
  const AllergyProfileScreen({super.key});

  @override
  State<AllergyProfileScreen> createState() => _AllergyProfileScreenState();
}

class _AllergyProfileScreenState extends State<AllergyProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ParentProvider>().loadAllergies();
    });
  }

  Color _severityColor(String severity) {
    switch (severity.toUpperCase()) {
      case 'SEVERE':
        return AppColors.error;
      case 'MODERATE':
        return Colors.orange.shade700;
      case 'MILD':
      default:
        return AppColors.info;
    }
  }

  String _severityLabel(String severity) {
    switch (severity.toUpperCase()) {
      case 'SEVERE':
        return 'NGUY HIỂM / SỐC PHẢN VỆ';
      case 'MODERATE':
        return 'TRUNG BÌNH';
      case 'MILD':
      default:
        return 'NHẸ';
    }
  }

  IconData _typeIcon(String type) {
    switch (type.toUpperCase()) {
      case 'FOOD':
        return Icons.restaurant_menu;
      case 'MEDICATION':
        return Icons.medication_liquid;
      case 'WEATHER':
        return Icons.cloud_outlined;
      case 'OTHER':
      default:
        return Icons.nature_people;
    }
  }

  void _showAddAllergyModal(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final allergenCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String selectedType = 'FOOD';
    String selectedSeverity = 'SEVERE';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Khai báo dị ứng mới cho bé',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  const Text('Loại dị ứng *',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'FOOD', child: Text('Thực phẩm / Thức ăn')),
                      DropdownMenuItem(value: 'MEDICATION', child: Text('Thuốc / Kháng sinh')),
                      DropdownMenuItem(value: 'WEATHER', child: Text('Thời tiết / Môi trường')),
                      DropdownMenuItem(value: 'OTHER', child: Text('Khác / Côn trùng')),
                    ],
                    onChanged: (v) => setModalState(() => selectedType = v!),
                  ),
                  const SizedBox(height: 14),

                  const Text('Chất gây dị ứng (Dị nguyên) *',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: allergenCtrl,
                    decoration: InputDecoration(
                      hintText: 'Ví dụ: Tôm biển, Đậu phộng, Penicillin...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Vui lòng nhập tên dị nguyên' : null,
                  ),
                  const SizedBox(height: 14),

                  const Text('Mức độ nghiêm trọng *',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedSeverity,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'SEVERE', child: Text('Nghiêm trọng (Nguy cơ sốc phản vệ)')),
                      DropdownMenuItem(value: 'MODERATE', child: Text('Trung bình (Mẩn ngứa, nôn trớ)')),
                      DropdownMenuItem(value: 'MILD', child: Text('Nhẹ (Hắt hơi, đỏ da nhẹ)')),
                    ],
                    onChanged: (v) => setModalState(() => selectedSeverity = v!),
                  ),
                  const SizedBox(height: 14),

                  const Text('Triệu chứng & Lưu ý cho Y tế / Bếp ăn',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Mô tả phản ứng của bé và hướng xử lý khi xảy ra sự cố...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        final prov = context.read<ParentProvider>();
                        final messenger = ScaffoldMessenger.of(context);
                        final allergy = AllergyAlert(
                          studentId: prov.selectedStudentId,
                          allergyType: selectedType,
                          allergen: allergenCtrl.text.trim(),
                          severity: selectedSeverity,
                          description: descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null,
                        );
                        Navigator.pop(ctx);
                        final success = await prov.createAllergy(allergy);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(success
                                ? 'Đã ghi nhận dị ứng y tế thành công!'
                                : (prov.error ?? 'Thất bại')),
                            backgroundColor:
                                success ? AppColors.success : AppColors.error,
                          ),
                        );
                      },
                      child: const Text('Lưu thông tin dị ứng',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ dị ứng của bé'),
      ),
      body: Consumer<ParentProvider>(
        builder: (context, prov, child) {
          return Column(
            children: [
              // Notice banner
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 26),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Liên thông Dữ liệu Y tế & Bếp ăn (BR-014)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.error,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tất cả dị nguyên được đăng ký tại đây sẽ tự động hiển thị trên bảng cảnh báo của Nhân viên Y tế và Bếp trưởng để loại trừ khỏi khẩu phần ăn của bé.',
                            style: TextStyle(fontSize: 13, color: Colors.red.shade900, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: prov.allergies.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.health_and_safety_outlined, size: 64, color: Colors.green.shade400),
                            const SizedBox(height: 16),
                            const Text(
                              'Bé chưa ghi nhận dị ứng nào',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Nhấn nút bên dưới để thêm nếu bé có tiền sử dị ứng',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => prov.loadAllergies(),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: prov.allergies.length,
                          itemBuilder: (context, index) {
                            final item = prov.allergies[index];
                            final color = _severityColor(item.severity);

                            return Card(
                              margin: const EdgeInsets.only(bottom: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: color.withOpacity(0.4), width: 1.5),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              backgroundColor: color.withOpacity(0.12),
                                              child: Icon(_typeIcon(item.allergyType), color: color),
                                            ),
                                            const SizedBox(width: 12),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.allergen,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 17,
                                                  ),
                                                ),
                                                Text(
                                                  'Phân loại: ${item.allergyType}',
                                                  style: TextStyle(
                                                    color: Colors.grey.shade600,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: color.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: color.withOpacity(0.3)),
                                          ),
                                          child: Text(
                                            _severityLabel(item.severity),
                                            style: TextStyle(
                                              color: color,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (item.description != null && item.description!.isNotEmpty) ...[
                                      const Divider(height: 20),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              item.description!,
                                              style: TextStyle(color: Colors.grey.shade800, fontSize: 13, height: 1.3),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    if (item.allergyId != null) ...[
                                      const SizedBox(height: 10),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton.icon(
                                          onPressed: () async {
                                            final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title: const Text('Xóa thông tin dị ứng?'),
                                                content: Text('Xác nhận bé không còn bị dị ứng với "${item.allergen}"?'),
                                                actions: [
                                                  TextButton(
                                                      onPressed: () => Navigator.pop(ctx, false),
                                                      child: const Text('Hủy')),
                                                  ElevatedButton(
                                                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                                                    onPressed: () => Navigator.pop(ctx, true),
                                                    child: const Text('Xóa dị ứng',
                                                        style: TextStyle(color: Colors.white)),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (confirm == true) {
                                              await prov.deleteAllergy(item.allergyId!);
                                            }
                                          },
                                          icon: const Icon(Icons.delete_outline, size: 16, color: Colors.grey),
                                          label: const Text('Xóa', style: TextStyle(color: Colors.grey, fontSize: 13)),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),

              // Bottom add button
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, -2))
                  ],
                ),
                child: SafeArea(
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => _showAddAllergyModal(context),
                      icon: const Icon(Icons.add_alert),
                      label: const Text(
                        'Khai báo dị ứng mới',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
