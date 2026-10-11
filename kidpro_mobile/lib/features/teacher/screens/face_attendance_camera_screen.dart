import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:kidpro_mobile/core/constants/app_colors.dart';

class FaceAttendanceCameraScreen extends StatefulWidget {
  const FaceAttendanceCameraScreen({super.key});

  @override
  State<FaceAttendanceCameraScreen> createState() => _FaceAttendanceCameraScreenState();
}

class _FaceAttendanceCameraScreenState extends State<FaceAttendanceCameraScreen>
    with SingleTickerProviderStateMixin {
  // Configurable AI server URL (change to your laptop LAN IP, e.g. http://192.168.1.15:8000)
  String _serverBaseUrl = 'http://10.0.2.2:8000';
  final _urlCtrl = TextEditingController();

  late AnimationController _animCtrl;
  bool _isProcessing = false;
  Map<String, dynamic>? _lastResult;

  @override
  void initState() {
    super.initState();
    _urlCtrl.text = _serverBaseUrl;
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
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
          children: [
            const Text(
              'Nhập địa chỉ IP LAN của laptop đang chạy FastAPI (ví dụ: http://192.168.1.50:8000 hoặc http://10.0.2.2:8000 trên Emulator):',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _urlCtrl,
              decoration: const InputDecoration(
                labelText: 'AI Backend Base URL',
                border: OutlineInputBorder(),
              ),
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

  Future<void> _performFaceCheckin() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _lastResult = null;
    });

    try {
      // 1. Tạo hoặc nén ảnh mẫu 640px JPEG (Trên thiết bị thật: chụp từ camera controller)
      // Tạo một ảnh JPEG 1x1 giả lập hoặc đọc từ camera
      final sampleJpgBytes = _createSampleJpegBytes();

      // 2. Gọi HTTP POST multipart/form-data tới FastAPI
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));

      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          sampleJpgBytes,
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
          content: Text('Lỗi kết nối AI Server: ${e.message ?? "Timeout"}'),
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

  // Tạo mock JPEG byte stream 640x480 để test API trực tiếp
  Uint8List _createSampleJpegBytes() {
    // Header JPEG tối giản
    return Uint8List.fromList([
      0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
      0x01, 0x01, 0x00, 0x48, 0x00, 0x48, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43,
      0x00, 0x08, 0x06, 0x06, 0x07, 0x06, 0x05, 0x08, 0x07, 0x07, 0x07, 0x09,
      0x09, 0x08, 0x0A, 0x0C, 0x14, 0x0D, 0x0C, 0x0B, 0x0B, 0x0C, 0x19, 0x12,
      0x13, 0x0F, 0x14, 0x1D, 0x1A, 0x1F, 0x1E, 0x1D, 0x1A, 0x1C, 0x1C, 0x20,
      0x24, 0x2E, 0x27, 0x20, 0x22, 0x2C, 0x23, 0x1C, 0x1C, 0x28, 0x37, 0x29,
      0x2C, 0x30, 0x31, 0x34, 0x34, 0x34, 0x1F, 0x27, 0x39, 0x3D, 0x38, 0x32,
      0x3C, 0x2E, 0x33, 0x34, 0x32, 0xFF, 0xC0, 0x00, 0x0B, 0x08, 0x00, 0x01,
      0x00, 0x01, 0x01, 0x01, 0x11, 0x00, 0xFF, 0xC4, 0x00, 0x1F, 0x00, 0x00,
      0x01, 0x05, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00,
      0x00, 0x00, 0x00, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
      0x09, 0x0A, 0x0B, 0xFF, 0xDA, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3F,
      0x00, 0x7F, 0x00, 0xFF, 0xD9
    ]);
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
            icon: const Icon(Icons.settings_ethernet),
            tooltip: 'Cài đặt IP Server',
            onPressed: _showIpConfigDialog,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera Viewport Simulation
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
              child: Stack(
                alignment: Alignment.center,
                children: [
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
                            : 'Căn chỉnh khuôn mặt vào giữa khung',
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
                                    onPressed: _performFaceCheckin,
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
                onPressed: _isProcessing ? null : _performFaceCheckin,
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
