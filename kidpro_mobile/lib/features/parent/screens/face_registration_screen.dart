import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:kidpro_mobile/core/constants/app_colors.dart';
import 'package:kidpro_mobile/core/network/api_client.dart';
import 'package:kidpro_mobile/features/parent/models/parent_models.dart';
import 'package:kidpro_mobile/features/parent/providers/parent_provider.dart';

class FaceRegistrationScreen extends StatefulWidget {
  const FaceRegistrationScreen({super.key});

  @override
  State<FaceRegistrationScreen> createState() => _FaceRegistrationScreenState();
}

class _FaceRegistrationScreenState extends State<FaceRegistrationScreen> {
  final ImagePicker _picker = ImagePicker();
  Uint8List? _capturedImageBytes;
  String? _capturedFilename;
  bool _submitting = false;

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: source,
        // Phụ huynh chụp cho bé nên mặc định dùng camera sau
        preferredCameraDevice: CameraDevice.rear,
        maxWidth: 640,
        maxHeight: 640,
        imageQuality: 88,
      );

      if (photo == null) return;

      final bytes = await photo.readAsBytes();
      setState(() {
        _capturedImageBytes = bytes;
        _capturedFilename = photo.name;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không mở được camera: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _submitRegistration(String studentId, String studentName) async {
    if (_capturedImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chụp ảnh chân dung của bé trước!'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    final prov = context.read<ParentProvider>();
    final success = await prov.registerStudentFace(
      studentId,
      _capturedImageBytes!,
      _capturedFilename ?? 'student_face.jpg',
    );

    setState(() => _submitting = false);

    if (!mounted) return;

    if (success) {
      setState(() {
        _capturedImageBytes = null;
        _capturedFilename = null;
      });
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.success, size: 28),
              SizedBox(width: 8),
              Text('Đăng ký thành công!'),
            ],
          ),
          content: Text(
            'Ảnh khuôn mặt của bé $studentName đã được lưu trữ thành công và đồng bộ vào hệ thống AI để cô giáo điểm danh tự động.',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đã hiểu'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(prov.error ?? 'Đăng ký khuôn mặt thất bại. Vui lòng thử lại!'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ParentProvider>();
    final currentStudent = prov.selectedStudent;
    final activeFace = prov.activeFaceFile;
    final baseUrl = ApiClient().baseUrl;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Đăng ký khuôn mặt cho bé'),
      ),
      body: currentStudent == null
          ? const Center(child: Text('Chưa có thông tin học sinh'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Selector bé (nếu phụ huynh có nhiều con)
                  if (prov.students.length > 1) ...[
                    const Text(
                      'Chọn bé cần đăng ký khuôn mặt:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<StudentSummary>(
                          value: currentStudent,
                          isExpanded: true,
                          items: prov.students.map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(
                              '${s.fullName} (${s.className ?? "Lớp"}) - Mã: ${s.studentCode}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          )).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              prov.selectStudent(val);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 2. Card trạng thái khuôn mặt hiện tại
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: activeFace != null
                          ? AppColors.success.withValues(alpha: 0.08)
                          : Colors.orange.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: activeFace != null
                            ? AppColors.success.withValues(alpha: 0.4)
                            : Colors.orange.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar ảnh mẫu đã đăng ký
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: activeFace != null && activeFace.photoUrl.isNotEmpty
                              ? Image.network(
                                  activeFace.photoUrl.startsWith('http')
                                      ? activeFace.photoUrl
                                      : '$baseUrl${activeFace.photoUrl}',
                                  width: 72,
                                  height: 72,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 72,
                                    height: 72,
                                    color: Colors.grey.shade300,
                                    child: const Icon(Icons.face, size: 36, color: Colors.grey),
                                  ),
                                )
                              : Container(
                                  width: 72,
                                  height: 72,
                                  color: Colors.orange.shade100,
                                  child: const Icon(
                                    Icons.face_retouching_natural,
                                    size: 36,
                                    color: Colors.orange,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    currentStudent.fullName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: activeFace != null ? AppColors.success : Colors.orange,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      activeFace != null ? 'ĐÃ ĐĂNG KÝ' : 'CHƯA ĐĂNG KÝ',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Lớp: ${currentStudent.className ?? "N/A"} • Mã: ${currentStudent.studentCode}',
                                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                activeFace != null
                                    ? 'Dữ liệu khuôn mặt đang hoạt động tốt cho nhận diện AI.'
                                    : 'Bé chưa có ảnh khuôn mặt mẫu. Hãy chụp ảnh bên dưới để kích hoạt điểm danh.',
                                style: TextStyle(
                                  color: activeFace != null ? AppColors.success : Colors.orange.shade800,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 3. Khung chụp / xem trước ảnh mới (căn giữa, chạm để mở camera)
                  const Center(
                    child: Text(
                      'Ảnh chân dung mới của bé',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      'Đưa mặt bé vào giữa khung oval rồi chụp',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildCaptureFrame(),
                  const SizedBox(height: 14),

                  // 4. Sau khi chụp: nút Chụp lại / Bỏ ảnh (trước khi chụp thì chạm vào khung để mở camera)
                  if (_capturedImageBytes != null) ...[
                    _buildCaptureActions(),
                    const SizedBox(height: 18),
                  ] else
                    const SizedBox(height: 4),

                  // 5. Hướng dẫn chụp ảnh đạt chuẩn
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue, size: 18),
                            SizedBox(width: 6),
                            Text(
                              'Lưu ý để nhận diện chính xác nhất:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildGuideItem('Khuôn mặt bé nhìn thẳng vào ống kính camera.'),
                        _buildGuideItem('Ánh sáng rõ ràng, không bị sương mù, chói hoặc ngược sáng.'),
                        _buildGuideItem('Không đeo kính râm, khẩu trang hoặc mũ che khuất trán/mắt.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 6. Nút gửi đăng ký
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _submitting
                          ? null
                          : () => _submitRegistration(currentStudent.studentId, currentStudent.fullName),
                      icon: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.verified_user),
                      label: Text(
                        _submitting ? 'Đang lưu trữ & trích xuất khuôn mặt...' : 'Xác nhận & Lưu ảnh đăng ký',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  /// Khung xem trước tỉ lệ chân dung 3:4, căn giữa màn hình, có oval hướng dẫn vị trí mặt.
  Widget _buildCaptureFrame() {
    final hasPhoto = _capturedImageBytes != null;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: Material(
            color: hasPhoto ? Colors.black : AppColors.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(24),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _submitting ? null : () => _pickPhoto(ImageSource.camera),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: hasPhoto ? AppColors.primary : AppColors.primary.withValues(alpha: 0.3),
                    width: hasPhoto ? 2.5 : 1.5,
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, box) {
                    // Oval chiếm ~62% chiều rộng, tỉ lệ 3:4 giống khuôn mặt
                    final ovalW = box.maxWidth * 0.62;
                    final ovalH = ovalW * 4 / 3;
                    return Stack(
                      fit: StackFit.expand,
                      alignment: Alignment.center,
                      children: [
                        if (hasPhoto)
                          Image.memory(_capturedImageBytes!, fit: BoxFit.cover)
                        else
                          Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Icon(Icons.photo_camera_outlined,
                                  size: 30, color: AppColors.primary.withValues(alpha: 0.7)),
                              const SizedBox(height: 6),
                              Text(
                                'Chạm để mở camera',
                                style: TextStyle(
                                  color: AppColors.primary.withValues(alpha: 0.85),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 18),
                            ],
                          ),
                        Center(
                          child: Container(
                            width: ovalW,
                            height: ovalH,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.all(Radius.elliptical(ovalW / 2, ovalH / 2)),
                              border: Border.all(
                                color: hasPhoto ? Colors.white : AppColors.primary.withValues(alpha: 0.45),
                                width: 2.5,
                              ),
                            ),
                            child: hasPhoto
                                ? null
                                : Icon(Icons.face_outlined,
                                    size: ovalW * 0.45, color: AppColors.primary.withValues(alpha: 0.25)),
                          ),
                        ),
                        if (hasPhoto)
                          Positioned(
                            top: 10,
                            left: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.success,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check, color: Colors.white, size: 14),
                                  SizedBox(width: 4),
                                  Text('Đã chụp',
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Hai nút "Chụp lại" / "Bỏ ảnh", chỉ hiện sau khi đã chụp.
  Widget _buildCaptureActions() {
    final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary, width: 1.4),
                shape: buttonShape,
              ),
              onPressed: _submitting ? null : () => _pickPhoto(ImageSource.camera),
              icon: const Icon(Icons.refresh),
              label: const Text('Chụp lại', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: BorderSide(color: AppColors.error.withValues(alpha: 0.6), width: 1.4),
                shape: buttonShape,
              ),
              onPressed: _submitting
                  ? null
                  : () => setState(() {
                        _capturedImageBytes = null;
                        _capturedFilename = null;
                      }),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Bỏ ảnh', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGuideItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.blue.shade900, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

