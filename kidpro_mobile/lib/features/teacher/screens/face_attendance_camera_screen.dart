import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:kidpro_mobile/core/constants/app_colors.dart';
import 'package:kidpro_mobile/features/teacher/models/teacher_models.dart';
import 'package:kidpro_mobile/features/teacher/providers/teacher_provider.dart';

class FaceAttendanceCameraScreen extends StatefulWidget {
  const FaceAttendanceCameraScreen({super.key});

  @override
  State<FaceAttendanceCameraScreen> createState() => _FaceAttendanceCameraScreenState();
}

class _FaceAttendanceCameraScreenState extends State<FaceAttendanceCameraScreen>
    with SingleTickerProviderStateMixin {
  // Configurable AI server URL (change to your laptop LAN IP, e.g. http://192.168.1.15:8000)
  String _serverBaseUrl = 'http://192.168.1.15:8000';
  final _urlCtrl = TextEditingController();

  late AnimationController _animCtrl;
  bool _isProcessing = false;
  Map<String, dynamic>? _lastResult;
  Uint8List? _capturedImageBytes;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _urlCtrl.text = _serverBaseUrl;
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = context.read<TeacherProvider>();
      if (prov.students.isEmpty) {
        prov.loadStudents(prov.currentClassId);
      }
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  void _showIpConfigDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cấu hình IP AI Server (Laptop)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nhập IP LAN của Laptop đang chạy main.py (đảm bảo điện thoại và laptop kết nối chung Wi-Fi):',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _urlCtrl,
              decoration: const InputDecoration(
                labelText: 'AI Backend Base URL',
                hintText: 'http://192.168.1.xxx:8000',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              children: [
                ActionChip(
                  label: const Text('10.0.2.2 (Emulator)', style: TextStyle(fontSize: 11)),
                  onPressed: () => _urlCtrl.text = 'http://10.0.2.2:8000',
                ),
                ActionChip(
                  label: const Text('Kiểm tra kết nối', style: TextStyle(fontSize: 11)),
                  onPressed: () => _pingServer(_urlCtrl.text.trim()),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _serverBaseUrl = _urlCtrl.text.trim());
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Đã cập nhật Server: $_serverBaseUrl')),
              );
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  Future<void> _pingServer(String url) async {
    try {
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 4)));
      final res = await dio.get(url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kết nối thành công! Đã đăng ký: ${res.data["registered_students_count"] ?? 0} học sinh'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể kết nối tới $url. Hãy kiểm tra Wi-Fi và Firewall.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// Chụp ảnh hoặc chọn ảnh từ thư viện để điểm danh
  Future<void> _captureAndCheckin({ImageSource source = ImageSource.camera}) async {
    if (_isProcessing) return;

    try {
      final XFile? photo = await _picker.pickImage(
        source: source,
        maxWidth: 640,
        maxHeight: 640,
        imageQuality: 85,
      );

      if (photo == null) return;

      final bytes = await photo.readAsBytes();

      setState(() {
        _isProcessing = true;
        _capturedImageBytes = bytes;
        _lastResult = null;
      });

      // Gửi ảnh thực tế lên FastAPI AI Engine
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ));

      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: 'face_checkin.jpg',
        ),
      });

      final response = await dio.post(
        '$_serverBaseUrl/api/v1/check-in',
        data: formData,
      );

      final data = response.data as Map<String, dynamic>;

      HapticFeedback.mediumImpact();
      setState(() {
        _lastResult = data;
        _isProcessing = false;
      });
    } on DioException catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi kết nối AI Server ($_serverBaseUrl): ${e.message ?? "Timeout"}'),
          backgroundColor: AppColors.error,
        ),
      );
    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  /// Hộp thoại thêm / đăng ký khuôn mặt trực tiếp từ điện thoại
  void _showRegisterFaceDialog() {
    final prov = context.read<TeacherProvider>();
    final students = prov.students;
    TeacherStudent? selectedStudent = students.isNotEmpty ? students.first : null;
    final classCtrl = TextEditingController(text: prov.currentClassName);
    Uint8List? regPhotoBytes;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.face_retouching_natural, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Đăng ký khuôn mặt AI', style: TextStyle(fontSize: 17)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (students.isNotEmpty) ...[
                  const Text('Chọn học sinh từ cơ sở dữ liệu:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<TeacherStudent>(
                    initialValue: selectedStudent,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: students.map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(
                        '${s.fullName} (${s.studentCode ?? "Chưa có mã"})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    )).toList(),
                    onChanged: (val) => setDialogState(() => selectedStudent = val),
                  ),
                ] else
                  const Text('Chưa có danh sách học sinh. Vui lòng tải dữ liệu lớp học trước.', style: TextStyle(color: Colors.red)),
                const SizedBox(height: 12),
                TextField(
                  controller: classCtrl,
                  readOnly: true,
                  decoration: const InputDecoration(labelText: 'Lớp học phụ trách', isDense: true, border: OutlineInputBorder()),
                ),
                const SizedBox(height: 14),

                // Xem trước ảnh chụp
                GestureDetector(
                  onTap: () async {
                    final XFile? photo = await _picker.pickImage(
                      source: ImageSource.camera,
                      maxWidth: 640,
                      maxHeight: 640,
                      imageQuality: 85,
                    );
                    if (photo != null) {
                      final bytes = await photo.readAsBytes();
                      setDialogState(() => regPhotoBytes = bytes);
                    }
                  },
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade700),
                    ),
                    child: regPhotoBytes != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(regPhotoBytes!, fit: BoxFit.cover),
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt, color: Colors.white70, size: 36),
                              SizedBox(height: 6),
                              Text('Bấm để chụp ảnh chân dung thực tế', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          ),
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
              onPressed: () async {
                if (selectedStudent == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Vui lòng chọn học sinh từ danh sách!')),
                  );
                  return;
                }
                if (regPhotoBytes == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Vui lòng chụp ảnh chân dung thực tế trước!')),
                  );
                  return;
                }

                Navigator.pop(ctx);
                setState(() => _isProcessing = true);

                try {
                  final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));
                  final formData = FormData.fromMap({
                    'student_id': selectedStudent!.id,
                    'name': selectedStudent!.fullName,
                    'class_name': prov.currentClassName,
                    'file': MultipartFile.fromBytes(regPhotoBytes!, filename: 'register.jpg'),
                  });

                  final res = await dio.post('$_serverBaseUrl/api/v1/register', data: formData);
                  setState(() => _isProcessing = false);

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Đăng ký thành công: ${res.data["name"]} (Vector 512 chiều)'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                } catch (e) {
                  setState(() => _isProcessing = false);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Lỗi đăng ký: $e'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              },
              child: const Text('Lưu vào AI Server'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _lastResult?['status'];
    final isPresent = status == 'PRESENT';
    final isUnknown = status == 'UNKNOWN';

    Color borderColor = Colors.white70;
    if (isPresent) borderColor = AppColors.success;
    if (isUnknown) borderColor = AppColors.strangerAlert;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('AI Face Attendance', style: TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_library),
            tooltip: 'Chọn ảnh từ thư viện',
            onPressed: () => _captureAndCheckin(source: ImageSource.gallery),
          ),
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: 'Đăng ký khuôn mặt mới',
            onPressed: _showRegisterFaceDialog,
          ),
          IconButton(
            icon: const Icon(Icons.settings_ethernet),
            tooltip: 'Cài đặt IP Server AI',
            onPressed: _showIpConfigDialog,
          ),
          if (_lastResult != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Xóa kết quả quét',
              onPressed: () {
                setState(() {
                  _lastResult = null;
                  _capturedImageBytes = null;
                });
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          // Camera Viewport Simulation / Captured Image Preview
          Center(
            child: Container(
              margin: const EdgeInsets.all(24),
              height: 480,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: borderColor,
                  width: isPresent || isUnknown ? 3.5 : 1.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Hiển thị ảnh vừa chụp nếu có
                    if (_capturedImageBytes != null)
                      Positioned.fill(
                        child: Image.memory(
                          _capturedImageBytes!,
                          fit: BoxFit.cover,
                        ),
                      ),

                    // Face Guide Oval
                    Container(
                      width: 220,
                      height: 300,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: borderColor.withOpacity(0.8),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(110),
                      ),
                    ),

                    // Scanning Line Animation
                    if (_isProcessing)
                      AnimatedBuilder(
                        animation: _animCtrl,
                        builder: (context, child) {
                          return Positioned(
                            top: 90 + (_animCtrl.value * 280),
                            child: Container(
                              width: 240,
                              height: 2,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.8),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                    // Overlay text
                    Positioned(
                      top: 24,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _isProcessing
                              ? 'Đang đối chiếu vector AI InsightFace...'
                              : (_capturedImageBytes != null
                                  ? 'Ảnh đã chụp • Bấm chụp lại bên dưới'
                                  : 'Căn chỉnh khuôn mặt vào giữa khung'),
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),

                    // Result Sheet (PRESENT)
                    if (isPresent)
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.success),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.check_circle, color: AppColors.success, size: 22),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'ĐIỂM DANH THÀNH CÔNG',
                                    style: TextStyle(
                                      color: AppColors.success,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'Khớp: ${((_lastResult!["confidence_score"] as num) * 100).toStringAsFixed(1)}%',
                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                ],
                              ),
                              const Divider(color: Colors.white24, height: 16),
                              Text(
                                'Học sinh: ${_lastResult!["name"]}',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              Text(
                                'Lớp: ${_lastResult!["class_name"]} • Mã: ${_lastResult!["student_id"]}',
                                style: const TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                              Text(
                                'Thời gian: ${_lastResult!["checkin_time"] ?? ""}',
                                style: const TextStyle(color: Colors.white60, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Result Sheet (UNKNOWN)
                    if (isUnknown)
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.strangerAlert),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.warning, color: AppColors.strangerAlert, size: 22),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'CẢNH BÁO: KHÔNG NHẬN DIỆN',
                                    style: TextStyle(
                                      color: AppColors.strangerAlert,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'Điểm: ${((_lastResult!["confidence_score"] as num) * 100).toStringAsFixed(1)}%',
                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _lastResult!['message'] ?? 'Khuôn mặt chưa được đăng ký trong danh sách',
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        side: const BorderSide(color: Colors.white38),
                                      ),
                                      onPressed: () => _captureAndCheckin(source: ImageSource.camera),
                                      child: const Text('Thử lại'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.warning,
                                        foregroundColor: Colors.black,
                                      ),
                                      onPressed: () {
                                        Navigator.pop(context);
                                      },
                                      child: const Text('Fallback Thủ công', style: TextStyle(fontSize: 12)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Action Button
          Positioned(
            bottom: 32,
            left: 24,
            right: 24,
            child: SizedBox(
              height: 54,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 6,
                ),
                onPressed: _isProcessing ? null : () => _captureAndCheckin(source: ImageSource.camera),
                icon: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.camera_alt),
                label: Text(
                  _isProcessing ? 'Đang phân tích khuôn mặt...' : 'Chụp & Điểm danh khuôn mặt',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
