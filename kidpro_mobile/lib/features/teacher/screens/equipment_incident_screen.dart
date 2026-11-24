import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:kidpro_mobile/core/constants/app_colors.dart';
import 'package:kidpro_mobile/features/teacher/models/teacher_models.dart';
import 'package:kidpro_mobile/features/teacher/providers/teacher_provider.dart';

class EquipmentIncidentScreen extends StatefulWidget {
  const EquipmentIncidentScreen({super.key});

  @override
  State<EquipmentIncidentScreen> createState() => _EquipmentIncidentScreenState();
}

class _EquipmentIncidentScreenState extends State<EquipmentIncidentScreen> {
  /// Chọn "Thiết bị khác" khi thiết bị chưa có trong danh mục tài sản của lớp.
  static const _other = '__other__';
  static const _msg215 = 'Vui lòng nhập mô tả chi tiết sự cố và tải lên ít nhất 01 ảnh chụp hiện trường.';
  static const _maxPhotoBytes = 10 * 1024 * 1024;

  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');

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
    _qtyCtrl.dispose();
    super.dispose();
  }

  /// UC-67 E2 (MSG-195): ảnh hiện trường chỉ JPG/PNG, tối đa 10MB.
  String? _validatePhoto(String path) {
    final lower = path.toLowerCase();
    if (!(lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png'))) {
      return 'Ảnh hiện trường chỉ nhận định dạng JPG hoặc PNG.';
    }
    if (File(path).lengthSync() > _maxPhotoBytes) return 'Ảnh hiện trường quá lớn (tối đa 10MB).';
    return null;
  }

  Future<void> _showReportModal() async {
    final prov = context.read<TeacherProvider>();
    final options = await prov.loadClassEquipmentOptions();
    if (!mounted) return;

    _nameCtrl.clear();
    _descCtrl.clear();
    _qtyCtrl.text = '1';
    String choice = options.isEmpty ? _other : '';
    String severity = 'NORMAL';
    String? photoPath;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          ClassEquipmentOption? selected;
          for (final o in options) {
            if (o.equipmentId == choice) selected = o;
          }
          void warn(String text) => ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(content: Text(text), backgroundColor: AppColors.error),
              );

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
                      const Icon(Icons.build_circle, color: AppColors.error, size: 28),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Báo hỏng Cơ sở Vật chất',
                          style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
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
                      'Chọn thiết bị trong danh mục tài sản của lớp và chụp ảnh hiện trường (BR-051). '
                      'Phiếu được gửi ngay tới Giáo vụ và Ban Giám Hiệu.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    initialValue: choice.isEmpty ? null : choice,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Thiết bị hư hỏng',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.handyman),
                    ),
                    items: [
                      for (final o in options)
                        DropdownMenuItem(
                          value: o.equipmentId,
                          enabled: o.goodQuantity > 0,
                          child: Text(
                            '${o.name} (${o.equipmentCode}) · còn tốt ${o.goodQuantity}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      const DropdownMenuItem(value: _other, child: Text('Thiết bị khác (chưa có trong danh mục)')),
                    ],
                    onChanged: (v) => setSheet(() {
                      choice = v ?? '';
                      _qtyCtrl.text = '1';
                    }),
                  ),
                  if (options.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text('Phòng học chưa có thiết bị nào trong danh mục, vui lòng nhập tên thiết bị.',
                          style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ),
                  if (choice == _other) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Tên thiết bị / Hạng mục hư hỏng',
                        hintText: 'Ví dụ: Điều hòa Daikin, Vòi nước bồn rửa...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      SizedBox(
                        width: 110,
                        child: TextField(
                          controller: _qtyCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Số lượng hỏng', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'NORMAL', label: Text('Bình thường')),
                            ButtonSegment(value: 'URGENT', label: Text('Khẩn cấp')),
                          ],
                          selected: {severity},
                          onSelectionChanged: (s) => setSheet(() => severity = s.first),
                        ),
                      ),
                    ],
                  ),
                  if (severity == 'URGENT')
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'Sự cố nguy hiểm cho trẻ: được tiếp nhận xử lý trong 2 giờ. Vui lòng cách ly trẻ khỏi khu vực nguy hiểm.',
                        style: TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w600),
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

                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    icon: Icon(photoPath != null ? Icons.check_circle : Icons.camera_alt,
                        color: photoPath != null ? AppColors.success : null),
                    label: Text(photoPath != null
                        ? 'Đã chụp ảnh hiện trường (chạm để chụp lại)'
                        : 'Chụp ảnh hiện trường (bắt buộc, JPG/PNG ≤ 10MB)'),
                    onPressed: () async {
                      final photo = await ImagePicker()
                          .pickImage(source: ImageSource.camera, maxWidth: 1280, imageQuality: 85);
                      if (photo == null) return;
                      final error = _validatePhoto(photo.path);
                      if (error != null) {
                        warn(error);
                        return;
                      }
                      setSheet(() => photoPath = photo.path);
                    },
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
                      label: const Text('Gửi báo cáo'),
                      onPressed: () async {
                        final isOther = choice == _other;
                        if (choice.isEmpty || (isOther && _nameCtrl.text.trim().isEmpty)) {
                          warn('Vui lòng chọn thiết bị trong danh mục hoặc nhập tên thiết bị.');
                          return;
                        }
                        // UC-67 E1 (MSG-215): bắt buộc mô tả và ảnh hiện trường
                        if (_descCtrl.text.trim().isEmpty || photoPath == null) {
                          warn(_msg215);
                          return;
                        }
                        final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 0;
                        final maxQty = selected?.goodQuantity;
                        if (qty < 1 || (maxQty != null && qty > maxQty)) {
                          warn('Số lượng hỏng phải từ 1 đến ${maxQty ?? 'số thiết bị hiện có'}.');
                          return;
                        }

                        Navigator.pop(ctx);
                        final msg = await prov.reportEquipmentIncident(
                          equipmentId: isOther ? null : choice,
                          equipmentName: isOther ? _nameCtrl.text.trim() : null,
                          damagedQuantity: qty,
                          severity: severity,
                          description: _descCtrl.text.trim(),
                          photoUrl: photoPath!,
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(msg ?? 'Gửi báo cáo sự cố hư hỏng cơ sở vật chất lớp học thành công.'),
                              backgroundColor: prov.lastActionFailed ? AppColors.error : AppColors.success,
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
              ? const Center(child: Text('Lớp chưa có phiếu báo hỏng nào.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: incidents.length,
                  itemBuilder: (context, index) {
                    final item = incidents[index];
                    final st = item.status.toUpperCase();
                    final isRepaired = st == 'REPAIRED' || st == 'RESOLVED';
                    final isProcessing = st == 'PROCESSING' || st == 'IN_PROGRESS';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Tên thiết bị dài thì xuống dòng, không đẩy nhãn trạng thái tràn ra ngoài
                                Expanded(
                                  child: Text(
                                    item.damagedQuantity > 1
                                        ? '${item.equipmentName} × ${item.damagedQuantity}'
                                        : item.equipmentName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isRepaired ? Colors.green.shade50 : Colors.amber.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: isRepaired ? Colors.green : Colors.amber),
                                  ),
                                  child: Text(
                                    isRepaired ? 'ĐÃ SỬA XONG' : (isProcessing ? 'ĐANG SỬA' : 'CHỜ XỬ LÝ'),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: isRepaired ? Colors.green.shade800 : Colors.amber.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (item.severity == 'URGENT')
                              const Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: Text('Khẩn cấp: nguy hiểm cho trẻ',
                                    style: TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.bold)),
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
                              'Báo cáo lúc: ${dateFmt.format(item.createdAt)} - ${item.classroomName}'
                              '${item.equipmentCode != null ? ' · Mã ${item.equipmentCode}' : ''}',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                            if (item.handlerNote != null || item.handledByName != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '${item.handledByName ?? 'Giáo vụ'}'
                                  '${item.handlerNote != null ? ': ${item.handlerNote}' : ' đã tiếp nhận'}',
                                  style: const TextStyle(fontSize: 12, color: Colors.black54),
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
}
