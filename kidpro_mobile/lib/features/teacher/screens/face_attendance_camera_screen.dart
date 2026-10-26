import 'dart:async';
import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:kidpro_mobile/core/constants/app_colors.dart';
import 'package:kidpro_mobile/features/teacher/models/teacher_models.dart';
import 'package:kidpro_mobile/features/teacher/providers/teacher_provider.dart';

enum LivenessStep {
  noFace,
  waitingBlink,
  eyesClosed,
  passed,
}

class FaceAttendanceCameraScreen extends StatefulWidget {
  const FaceAttendanceCameraScreen({super.key});

  @override
  State<FaceAttendanceCameraScreen> createState() => _FaceAttendanceCameraScreenState();
}

class _FaceAttendanceCameraScreenState extends State<FaceAttendanceCameraScreen>
    with SingleTickerProviderStateMixin {
  // Configurable AI server URL (Wi-Fi LAN IP or USB adb reverse)
  String _serverBaseUrl = 'http://192.168.10.125:8000';
  final _urlCtrl = TextEditingController();

  // Camera & ML Kit
  List<CameraDescription> _cameras = [];
  CameraController? _cameraController;
  int _selectedCameraIndex = 0;
  bool _isCameraInitialized = false;
  bool _isCameraError = false;

  late FaceDetector _faceDetector;
  bool _isDetecting = false;

  // Liveness Detection State
  LivenessStep _livenessStep = LivenessStep.noFace;
  String _statusMessage = 'Vui lòng nhìn vào camera';
  DateTime? _blinkStartTime;
  double? _leftEyeOpen;
  double? _rightEyeOpen;

  // Animation & Processing
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
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    // Khởi tạo ML Kit Face Detector với tính năng phân loại độ mở mắt (Classification)
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true, // Quan trọng: đo tỷ lệ mở của 2 mắt
        performanceMode: FaceDetectorMode.fast,
        minFaceSize: 0.20,
      ),
    );

    // Nạp danh sách học sinh
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = context.read<TeacherProvider>();
      if (prov.students.isEmpty) {
        prov.loadStudents(prov.currentClassId);
      }
      _initCameras();
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _urlCtrl.dispose();
    _stopAndDisposeCamera();
    _faceDetector.close();
    super.dispose();
  }

  Future<void> _stopAndDisposeCamera() async {
    try {
      if (_cameraController != null) {
        if (_cameraController!.value.isStreamingImages) {
          await _cameraController!.stopImageStream();
        }
        await _cameraController!.dispose();
        _cameraController = null;
      }
    } catch (e) {
      debugPrint('Error disposing camera: $e');
    }
  }

  /// Khởi tạo camera thiết bị
  Future<void> _initCameras() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _isCameraError = true;
          _statusMessage = 'Không tìm thấy camera trên thiết bị.';
        });
        return;
      }

      // Ưu tiên camera sau (để cô giáo quay vào học sinh) hoặc camera trước
      int initialIndex = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      if (initialIndex < 0) initialIndex = 0;
      _selectedCameraIndex = initialIndex;

      await _setupCameraController(_cameras[_selectedCameraIndex]);
    } catch (e) {
      debugPrint('Error getting cameras: $e');
      setState(() {
        _isCameraError = true;
        _statusMessage = 'Lỗi camera. Bạn có thể dùng nút chụp thủ công.';
      });
    }
  }

  Future<void> _setupCameraController(CameraDescription camera) async {
    await _stopAndDisposeCamera();

    final controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    _cameraController = controller;

    try {
      await controller.initialize();
      if (!mounted) return;

      setState(() {
        _isCameraInitialized = true;
        _isCameraError = false;
        _statusMessage = 'Bé vui lòng nhìn vào camera';
      });

      // Bắt đầu luồng phân tích hình ảnh theo thời gian thực (Live Stream)
      await controller.startImageStream(_processCameraImage);
    } catch (e) {
      debugPrint('Error initializing camera controller: $e');
      if (mounted) {
        setState(() {
          _isCameraInitialized = false;
          _isCameraError = true;
        });
      }
    }
  }

  /// Đổi giữa Camera Trước và Sau
  Future<void> _toggleCamera() async {
    if (_cameras.length <= 1) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    setState(() {
      _isCameraInitialized = false;
      _livenessStep = LivenessStep.noFace;
    });
    await _setupCameraController(_cameras[_selectedCameraIndex]);
  }

  /// Xử lý từng frame từ camera gửi vào Google ML Kit
  void _processCameraImage(CameraImage image) async {
    if (_isDetecting || _isProcessing || _livenessStep == LivenessStep.passed || _lastResult != null) {
      return;
    }

    _isDetecting = true;
    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) return;

      final faces = await _faceDetector.processImage(inputImage);
      if (!mounted) return;

      _analyzeLiveness(faces);
    } catch (e) {
      debugPrint('MLKit processImage error: $e');
    } finally {
      _isDetecting = false;
    }
  }

  /// Thuật toán phát hiện chớp mắt tự nhiên (Liveness Check)
  void _analyzeLiveness(List<Face> faces) {
    if (faces.isEmpty) {
      if (_livenessStep != LivenessStep.noFace) {
        setState(() {
          _livenessStep = LivenessStep.noFace;
          _statusMessage = 'Vui lòng nhìn vào khung camera';
          _leftEyeOpen = null;
          _rightEyeOpen = null;
        });
      }
      return;
    }

    // Chọn khuôn mặt chiếm diện tích lớn nhất (trọng tâm bé đứng trước camera)
    final face = faces.reduce((curr, next) =>
        (curr.boundingBox.width * curr.boundingBox.height) >
                (next.boundingBox.width * next.boundingBox.height)
            ? curr
            : next);

    final left = face.leftEyeOpenProbability;
    final right = face.rightEyeOpenProbability;

    setState(() {
      _leftEyeOpen = left;
      _rightEyeOpen = right;
    });

    if (left == null || right == null) return;

    // Ngưỡng: Mắt mở (> 65%), Mắt nhắm (< 25%)
    final bool areEyesOpen = left > 0.65 && right > 0.65;
    final bool areEyesClosed = left < 0.25 && right < 0.25;

    switch (_livenessStep) {
      case LivenessStep.noFace:
        if (areEyesOpen) {
          setState(() {
            _livenessStep = LivenessStep.waitingBlink;
            _statusMessage = 'Bé hãy chớp mắt nhẹ một cái nhé! 😉';
          });
        }
        break;

      case LivenessStep.waitingBlink:
        if (areEyesClosed) {
          _blinkStartTime = DateTime.now();
          setState(() {
            _livenessStep = LivenessStep.eyesClosed;
            _statusMessage = 'Đang nhận diện nhịp chớp mắt...';
          });
        }
        break;

      case LivenessStep.eyesClosed:
        if (areEyesOpen) {
          // Đo khoảng thời gian nhắm mắt (1 nhịp chớp tự nhiên: 100ms - 1500ms)
          final durationMs = _blinkStartTime != null
              ? DateTime.now().difference(_blinkStartTime!).inMilliseconds
              : 0;

          if (durationMs >= 100 && durationMs <= 1500) {
            // Xác nhận Liveness PASSED!
            setState(() {
              _livenessStep = LivenessStep.passed;
              _statusMessage = '✅ Đã xác thực người thật! Đang nhận diện...';
            });
            _onLivenessPassed();
          } else {
            // Nhắm mắt quá lâu hoặc giật lag -> Chờ nhịp chớp tiếp theo
            setState(() {
              _livenessStep = LivenessStep.waitingBlink;
              _statusMessage = 'Bé hãy chớp mắt tự nhiên nhé!';
            });
          }
        }
        break;

      case LivenessStep.passed:
        break;
    }
  }

  /// Khi đã chớp mắt người thật -> Tự động chụp frame rõ nét và gửi lên AI Server
  Future<void> _onLivenessPassed() async {
    HapticFeedback.heavyImpact();
    setState(() => _isProcessing = true);

    try {
      if (_cameraController != null && _cameraController!.value.isInitialized) {
        // Tạm dừng image stream trước khi chụp ảnh để tránh xung đột phần cứng
        if (_cameraController!.value.isStreamingImages) {
          await _cameraController!.stopImageStream();
        }

        final XFile photo = await _cameraController!.takePicture();
        final bytes = await photo.readAsBytes();

        setState(() {
          _capturedImageBytes = bytes;
        });

        await _submitCheckinToServer(bytes, isLivenessVerified: true);
      }
    } catch (e) {
      debugPrint('Error on liveness auto capture: $e');
      setState(() => _isProcessing = false);
    }
  }

  /// Gửi ảnh lên FastAPI AI Backend
  Future<void> _submitCheckinToServer(Uint8List bytes, {required bool isLivenessVerified}) async {
    try {
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
      data['liveness_verified'] = isLivenessVerified;

      HapticFeedback.mediumImpact();
      if (mounted) {
        setState(() {
          _lastResult = data;
          _isProcessing = false;
        });
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi kết nối AI Server ($_serverBaseUrl): ${e.message ?? "Timeout"}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  /// Chụp hoặc chọn ảnh thủ công (Dự phòng cho cô giáo)
  Future<void> _manualCaptureAndCheckin({ImageSource source = ImageSource.camera}) async {
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
        _livenessStep = LivenessStep.passed;
      });

      await _submitCheckinToServer(bytes, isLivenessVerified: false);
    } catch (e) {
      setState(() => _isProcessing = false);
    }
  }

  /// Reset để điểm danh bé tiếp theo
  void _resetForNextStudent() async {
    setState(() {
      _lastResult = null;
      _capturedImageBytes = null;
      _livenessStep = LivenessStep.noFace;
      _statusMessage = 'Bé vui lòng nhìn vào camera';
      _isProcessing = false;
    });

    try {
      if (_cameraController != null &&
          _cameraController!.value.isInitialized &&
          !_cameraController!.value.isStreamingImages) {
        await _cameraController!.startImageStream(_processCameraImage);
      }
    } catch (e) {
      debugPrint('Error restarting stream: $e');
    }
  }

  /// Chuyển đổi CameraImage sang InputImage cho Google ML Kit
  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_cameraController == null) return null;
    final camera = _cameras[_selectedCameraIndex];
    final sensorOrientation = camera.sensorOrientation;

    final rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.nv21;

    if (image.planes.isEmpty) return null;

    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  /// Cài đặt IP Server
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
              'Chọn USB (cắm cáp) hoặc Wi-Fi LAN kết nối đến Python AI backend:',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _urlCtrl,
              decoration: const InputDecoration(
                labelText: 'AI Backend Base URL',
                hintText: 'http://127.0.0.1:8000 hoặc http://192.168.10.125:8000',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              children: [
                ActionChip(
                  label: const Text('USB Cáp (127.0.0.1:8000)', style: TextStyle(fontSize: 11)),
                  onPressed: () => _urlCtrl.text = 'http://127.0.0.1:8000',
                ),
                ActionChip(
                  label: const Text('Wi-Fi LAN (192.168.10.125)', style: TextStyle(fontSize: 11)),
                  onPressed: () => _urlCtrl.text = 'http://192.168.10.125:8000',
                ),
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

  /// Đăng ký khuôn mặt mới
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
                final messenger = ScaffoldMessenger.of(context);
                if (selectedStudent == null) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Vui lòng chọn học sinh từ danh sách!')),
                  );
                  return;
                }
                if (regPhotoBytes == null) {
                  messenger.showSnackBar(
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
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Đăng ký thành công: ${res.data["name"]} (Vector 512 chiều)'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                } catch (e) {
                  setState(() => _isProcessing = false);
                  if (mounted) {
                    messenger.showSnackBar(
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

    // Viền đổi màu theo trạng thái Liveness
    Color borderColor = Colors.white54;
    if (_livenessStep == LivenessStep.waitingBlink) {
      borderColor = Colors.lightBlueAccent;
    } else if (_livenessStep == LivenessStep.eyesClosed) {
      borderColor = Colors.amberAccent;
    } else if (_livenessStep == LivenessStep.passed || isPresent) {
      borderColor = AppColors.success;
    } else if (isUnknown) {
      borderColor = AppColors.strangerAlert;
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('AI Live Face & Blink Detection', style: TextStyle(fontSize: 16)),
        actions: [
          if (_cameras.length > 1)
            IconButton(
              icon: const Icon(Icons.flip_camera_ios),
              tooltip: 'Đổi Camera Trước/Sau',
              onPressed: _toggleCamera,
            ),
          IconButton(
            icon: const Icon(Icons.photo_library),
            tooltip: 'Chọn ảnh từ thư viện',
            onPressed: () => _manualCaptureAndCheckin(source: ImageSource.gallery),
          ),
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: 'Đăng ký học sinh mới',
            onPressed: _showRegisterFaceDialog,
          ),
          IconButton(
            icon: const Icon(Icons.settings_ethernet),
            tooltip: 'Cài đặt IP AI Server',
            onPressed: _showIpConfigDialog,
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Live Camera Viewport hoặc Preview
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              height: 520,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: borderColor,
                  width: _livenessStep == LivenessStep.passed || isPresent || isUnknown ? 3.5 : 2.0,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Hiển thị Camera Controller nếu sẵn sàng
                    if (_isCameraInitialized && _cameraController != null && _capturedImageBytes == null)
                      SizedBox.expand(
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: _cameraController!.value.previewSize?.height ?? 720,
                            height: _cameraController!.value.previewSize?.width ?? 1280,
                            child: CameraPreview(_cameraController!),
                          ),
                        ),
                      )
                    else if (_capturedImageBytes != null)
                      Positioned.fill(
                        child: Image.memory(
                          _capturedImageBytes!,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      // Fallback UI nếu không có camera
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isCameraError ? Icons.videocam_off : Icons.camera_front,
                            color: Colors.white54,
                            size: 54,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _statusMessage,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),

                    // Khung Oval định vị mặt bé
                    Container(
                      width: 220,
                      height: 290,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: borderColor.withValues(alpha: 0.85),
                          width: 2.5,
                        ),
                        borderRadius: BorderRadius.circular(110),
                      ),
                    ),

                    // Hiệu ứng Quét Scanner
                    if (_isProcessing)
                      AnimatedBuilder(
                        animation: _animCtrl,
                        builder: (context, child) {
                          return Positioned(
                            top: 100 + (_animCtrl.value * 260),
                            child: Container(
                              width: 240,
                              height: 3,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.9),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                    // Floating Header: Trạng thái chớp mắt & Tỷ lệ mở mắt
                    Positioned(
                      top: 16,
                      left: 16,
                      right: 16,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: borderColor.withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _livenessStep == LivenessStep.passed
                                      ? Icons.verified
                                      : (_livenessStep == LivenessStep.eyesClosed
                                          ? Icons.remove_red_eye_outlined
                                          : Icons.remove_red_eye),
                                  color: borderColor,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    _statusMessage,
                                    style: TextStyle(
                                      color: borderColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Live Eye Open Probability Bars (Thước đo độ mở mắt trực tiếp)
                          if (_leftEyeOpen != null && _rightEyeOpen != null && _lastResult == null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Trái: ${(_leftEyeOpen! * 100).toInt()}%',
                                    style: TextStyle(
                                      color: _leftEyeOpen! > 0.65 ? Colors.greenAccent : Colors.orangeAccent,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Phải: ${(_rightEyeOpen! * 100).toInt()}%',
                                    style: TextStyle(
                                      color: _rightEyeOpen! > 0.65 ? Colors.greenAccent : Colors.orangeAccent,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // KẾT QUẢ THÀNH CÔNG (PRESENT)
                    if (isPresent)
                      Positioned(
                        bottom: 14,
                        left: 14,
                        right: 14,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xEE111827),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.success, width: 1.5),
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
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Khớp: ${((_lastResult!["confidence_score"] as num) * 100).toStringAsFixed(1)}%',
                                      style: const TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(color: Colors.white24, height: 14),
                              Text(
                                'Học sinh: ${_lastResult!["name"]}',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              Text(
                                'Lớp: ${_lastResult!["class_name"]} • Mã: ${_lastResult!["student_id"]}',
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    _lastResult!['liveness_verified'] == true ? Icons.shield : Icons.shield_outlined,
                                    color: _lastResult!['liveness_verified'] == true ? Colors.greenAccent : Colors.amberAccent,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _lastResult!['liveness_verified'] == true
                                        ? 'Xác thực người thật: Đã qua (Chớp mắt)'
                                        : 'Xác thực: Chụp thủ công',
                                    style: TextStyle(
                                      color: _lastResult!['liveness_verified'] == true ? Colors.greenAccent : Colors.amberAccent,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                height: 38,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.success,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: _resetForNextStudent,
                                  icon: const Icon(Icons.arrow_forward, size: 18),
                                  label: const Text('Điểm danh bé tiếp theo', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // KẾT QUẢ CẢNH BÁO (UNKNOWN)
                    if (isUnknown)
                      Positioned(
                        bottom: 14,
                        left: 14,
                        right: 14,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xEE111827),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.strangerAlert, width: 1.5),
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
                                    style: const TextStyle(color: Colors.white70, fontSize: 11),
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
                                      onPressed: _resetForNextStudent,
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
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Thủ công', style: TextStyle(fontSize: 12)),
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

          // Nút chụp thủ công phía dưới (dự phòng nếu không dùng tự động chớp mắt)
          if (_lastResult == null)
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 6,
                  ),
                  onPressed: _isProcessing ? null : () => _manualCaptureAndCheckin(source: ImageSource.camera),
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.camera_alt),
                  label: Text(
                    _isProcessing ? 'Đang phân tích...' : 'Chụp điểm danh thủ công (Dự phòng)',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
