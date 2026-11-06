import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:kidpro_mobile/core/constants/api_endpoints.dart';
import 'package:kidpro_mobile/core/network/api_client.dart';
import 'package:kidpro_mobile/core/storage/secure_storage_helper.dart';
import 'package:kidpro_mobile/core/constants/app_colors.dart';
import 'package:kidpro_mobile/features/teacher/models/teacher_models.dart';
import 'package:kidpro_mobile/features/teacher/providers/teacher_provider.dart';

enum LivenessStep {
  searchingFace, // Bước 1: Đang tìm khuôn mặt
  faceDetected,  // Bước 2: Đã thấy mặt, kiểm tra mở mắt
  waitingBlink,  // Bước 3: Mắt đã mở, đang đợi bé chớp mắt
  eyesClosed,    // Bước 3b: Đang ghi nhận nhịp nhắm mắt
  passed,        // Bước 4: Chớp mắt thành công -> Xác thực người thật!
}

class FaceAttendanceCameraScreen extends StatefulWidget {
  const FaceAttendanceCameraScreen({super.key});

  @override
  State<FaceAttendanceCameraScreen> createState() => _FaceAttendanceCameraScreenState();
}

class _FaceAttendanceCameraScreenState extends State<FaceAttendanceCameraScreen>
    with SingleTickerProviderStateMixin {
  // Configurable AI server URL (Wi-Fi LAN IP or USB adb reverse)
  String _serverBaseUrl = 'http://192.168.10.51:8000';
  final _urlCtrl = TextEditingController();

  // Camera & ML Kit
  List<CameraDescription> _cameras = [];
  CameraController? _cameraController;
  int _selectedCameraIndex = 0;
  bool _isCameraInitialized = false;
  bool _isCameraError = false;

  late FaceDetector _faceDetector;
  bool _isDetecting = false;

  // Liveness Detection State (4 bước tương tác trực quan)
  LivenessStep _livenessStep = LivenessStep.searchingFace;
  String _statusMessage = 'Vui lòng đưa mặt vào giữa khung camera';
  DateTime? _blinkStartTime;
  double? _leftEyeOpen;
  double? _rightEyeOpen;

  // Animation & Processing
  late AnimationController _animCtrl;
  bool _isProcessing = false;
  Map<String, dynamic>? _lastResult;
  Uint8List? _capturedImageBytes;
  final ImagePicker _picker = ImagePicker();

  static final Map<DeviceOrientation, int> _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  @override
  void initState() {
    super.initState();
    _serverBaseUrl = ApiClient().aiBaseUrl;
    _urlCtrl.text = _serverBaseUrl;

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    // Khởi tạo ML Kit Face Detector: Bật phân loại mắt (Classification) & minFaceSize 0.15 để bắt mặt nhạy hơn
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        performanceMode: FaceDetectorMode.fast,
        minFaceSize: 0.15,
      ),
    );

    // Nạp danh sách học sinh và khởi tạo camera
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

    // Chuẩn format: NV21 cho Android và BGRA8888 cho iOS
    ImageFormatGroup formatGroup = Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888;

    CameraController controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: formatGroup,
    );

    try {
      await controller.initialize();
    } catch (_) {
      // Fallback nếu máy không hỗ trợ NV21 trực tiếp
      controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await controller.initialize();
    }

    _cameraController = controller;

    if (!mounted) return;

    setState(() {
      _isCameraInitialized = true;
      _isCameraError = false;
      _livenessStep = LivenessStep.searchingFace;
      _statusMessage = 'Bé vui lòng nhìn vào giữa khung camera';
    });

    // Bắt đầu luồng phân tích hình ảnh theo thời gian thực (Live Stream 30 FPS)
    await controller.startImageStream(_processCameraImage);
  }

  /// Đổi giữa Camera Trước và Sau
  Future<void> _toggleCamera() async {
    if (_cameras.length <= 1) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    setState(() {
      _isCameraInitialized = false;
      _livenessStep = LivenessStep.searchingFace;
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

  /// Chuyển đổi YUV420 3-planes sang NV21 1-plane chuẩn trên Android
  Uint8List _yuv420ToNv21(CameraImage image) {
    if (image.planes.length == 1) {
      return image.planes.first.bytes;
    }

    final int width = image.width;
    final int height = image.height;
    final int ySize = width * height;
    final int uvSize = width * height ~/ 2;
    final Uint8List nv21 = Uint8List(ySize + uvSize);

    // 1. Sao chép Plane Y
    final Uint8List yPlane = image.planes[0].bytes;
    nv21.setRange(0, ySize, yPlane);

    // 2. Trộn U và V xen kẽ (V trước, U sau) cho chuẩn NV21
    if (image.planes.length >= 3) {
      final Uint8List uPlane = image.planes[1].bytes;
      final Uint8List vPlane = image.planes[2].bytes;
      final int uvRowStride = image.planes[1].bytesPerRow;
      final int uvPixelStride = image.planes[1].bytesPerPixel ?? 2;

      int uvIndex = ySize;
      final int halfHeight = height ~/ 2;
      final int halfWidth = width ~/ 2;

      for (int row = 0; row < halfHeight; row++) {
        for (int col = 0; col < halfWidth; col++) {
          final int pIndex = row * uvRowStride + col * uvPixelStride;
          if (pIndex < vPlane.length && pIndex < uPlane.length && uvIndex + 1 < nv21.length) {
            nv21[uvIndex++] = vPlane[pIndex];
            nv21[uvIndex++] = uPlane[pIndex];
          }
        }
      }
    }

    return nv21;
  }

  /// Chuyển đổi CameraImage sang InputImage với bù góc quay cảm biến chính xác
  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_cameraController == null) return null;
    final camera = _cameras[_selectedCameraIndex];
    final sensorOrientation = camera.sensorOrientation;

    // Tính toán góc bù xoay theo hướng thiết bị và loại camera (Trước/Sau)
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var compensation = _orientations[_cameraController!.value.deviceOrientation] ?? 0;
      if (camera.lensDirection == CameraLensDirection.front) {
        compensation = (sensorOrientation + compensation) % 360;
      } else {
        compensation = (sensorOrientation - compensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(compensation);
    }
    rotation ??= InputImageRotationValue.fromRawValue(sensorOrientation);
    if (rotation == null) return null;

    final bytes = _yuv420ToNv21(image);

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: Platform.isAndroid ? InputImageFormat.nv21 : InputImageFormat.bgra8888,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  /// Thuật toán 4 bước kiểm tra người thật (Liveness Check)
  void _analyzeLiveness(List<Face> faces) {
    if (faces.isEmpty) {
      if (_livenessStep != LivenessStep.searchingFace) {
        setState(() {
          _livenessStep = LivenessStep.searchingFace;
          _statusMessage = 'Vui lòng đưa mặt vào giữa khung camera';
          _leftEyeOpen = null;
          _rightEyeOpen = null;
        });
      }
      return;
    }

    // Chọn khuôn mặt lớn nhất (trung tâm bé trước camera)
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

    if (left == null || right == null) {
      if (_livenessStep == LivenessStep.searchingFace) {
        setState(() {
          _livenessStep = LivenessStep.faceDetected;
          _statusMessage = 'Đã thấy khuôn mặt, đang định vị mắt...';
        });
      }
      return;
    }

    // Tỷ lệ mở mắt trung bình
    final double avgEye = (left + right) / 2.0;
    final bool areEyesOpen = avgEye > 0.55;
    final bool areEyesClosed = avgEye < 0.35 || left < 0.30 || right < 0.30;

    switch (_livenessStep) {
      case LivenessStep.searchingFace:
      case LivenessStep.faceDetected:
        if (areEyesOpen) {
          setState(() {
            _livenessStep = LivenessStep.waitingBlink;
            _statusMessage = 'Bé hãy chớp mắt nhẹ một cái nhé! 😉';
          });
        } else {
          setState(() {
            _livenessStep = LivenessStep.faceDetected;
            _statusMessage = 'Bé vui lòng mở to mắt nhìn vào camera';
          });
        }
        break;

      case LivenessStep.waitingBlink:
        if (areEyesClosed) {
          _blinkStartTime = DateTime.now();
          setState(() {
            _livenessStep = LivenessStep.eyesClosed;
            _statusMessage = 'Đang nhận diện nhịp nhắm mắt...';
          });
        }
        break;

      case LivenessStep.eyesClosed:
        if (areEyesOpen) {
          // Đo thời gian chớp mắt tự nhiên (80ms - 1600ms)
          final durationMs = _blinkStartTime != null
              ? DateTime.now().difference(_blinkStartTime!).inMilliseconds
              : 0;

          if (durationMs >= 80 && durationMs <= 1600) {
            setState(() {
              _livenessStep = LivenessStep.passed;
              _statusMessage = '✅ Đã xác thực người thật! Đang đối chiếu AI...';
            });
            _onLivenessPassed();
          } else {
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

  /// Khi đã chớp mắt người thật -> Tự động chụp và gửi lên AI Server
  Future<void> _onLivenessPassed() async {
    HapticFeedback.heavyImpact();
    setState(() => _isProcessing = true);

    try {
      if (_cameraController != null && _cameraController!.value.isInitialized) {
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

      // Khi AI nhận diện thành công: Lưu vào Spring Boot (attendances, attendance_photos, face_recognition_logs)
      if (data['status'] == 'PRESENT' && data['student_id'] != null) {
        try {
          final scannedBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
          final logPayload = {
            'studentId': data['student_id'],
            'confidenceScore': data['confidence_score'] ?? 0.85,
            'photoUrl': scannedBase64,
            'recognitionType': 'ATTENDANCE_CHECK_IN',
            'personType': 'STUDENT',
          };
          final backendRes = await ApiClient().dio.post(
            ApiEndpoints.faceLogs,
            data: logPayload,
          );
          if (backendRes.data != null && backendRes.data['registeredPhotoUrl'] != null) {
            data['registered_photo_url'] = backendRes.data['registeredPhotoUrl'];
          }
          if (mounted) {
            final tProv = context.read<TeacherProvider>();
            tProv.loadStudents(tProv.currentClassId);
          }
        } catch (backendErr) {
          debugPrint('Lỗi đồng bộ backend face-logs: $backendErr');
        }
      }

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
      _livenessStep = LivenessStep.searchingFace;
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

  Future<void> _initAiServer() async {
    final saved = await SecureStorageHelper.getAiServerUrl();
    if (saved != null && saved.isNotEmpty && saved != 'http://192.168.10.131:8000' && saved != 'http://192.168.10.125:8000') {
      _serverBaseUrl = saved;
    } else {
      _serverBaseUrl = ApiClient().aiBaseUrl;
    }
    if (mounted) {
      setState(() => _urlCtrl.text = _serverBaseUrl);
    }
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
                hintText: 'http://127.0.0.1:8000 hoặc http://192.168.10.51:8000',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              children: [
                ActionChip(
                  label: const Text('Wi-Fi LAN (192.168.10.51:8000)', style: TextStyle(fontSize: 11)),
                  onPressed: () => _urlCtrl.text = 'http://192.168.10.51:8000',
                ),
                ActionChip(
                  label: const Text('USB Cáp (127.0.0.1:8000)', style: TextStyle(fontSize: 11)),
                  onPressed: () => _urlCtrl.text = 'http://127.0.0.1:8000',
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
              SecureStorageHelper.saveAiServerUrl(_urlCtrl.text.trim());
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

  /// Đăng ký học sinh mới
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

  /// Widget hiển thị 4 bước kiểm tra người thật tương tác trực quan
  Widget _buildLivenessStepper() {
    final bool step1Done = _livenessStep != LivenessStep.searchingFace;
    final bool step2Done = _livenessStep == LivenessStep.waitingBlink ||
        _livenessStep == LivenessStep.eyesClosed ||
        _livenessStep == LivenessStep.passed;
    final bool step3Done = _livenessStep == LivenessStep.eyesClosed || _livenessStep == LivenessStep.passed;
    final bool step4Done = _livenessStep == LivenessStep.passed;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xEE111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStepItem(1, 'Tìm mặt', step1Done, _livenessStep == LivenessStep.searchingFace),
              _buildStepArrow(),
              _buildStepItem(2, 'Mở mắt', step2Done, _livenessStep == LivenessStep.faceDetected),
              _buildStepArrow(),
              _buildStepItem(3, 'Chớp mắt', step3Done, _livenessStep == LivenessStep.waitingBlink || _livenessStep == LivenessStep.eyesClosed),
              _buildStepArrow(),
              _buildStepItem(4, 'Xác thực', step4Done, _livenessStep == LivenessStep.passed),
            ],
          ),
          if (_leftEyeOpen != null && _rightEyeOpen != null && _lastResult == null) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildEyeProbChip('Mắt Trái', _leftEyeOpen!),
                const SizedBox(width: 10),
                _buildEyeProbChip('Mắt Phải', _rightEyeOpen!),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStepItem(int stepNumber, String title, bool isDone, bool isActive) {
    Color color = Colors.white38;
    if (isDone) {
      color = AppColors.success;
    } else if (isActive) {
      color = Colors.lightBlueAccent;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone
                ? AppColors.success
                : (isActive ? Colors.lightBlueAccent.withValues(alpha: 0.25) : Colors.white10),
            border: Border.all(color: color, width: isActive ? 2 : 1),
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Text(
                    '$stepNumber',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: isActive || isDone ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildStepArrow() {
    return const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.white24);
  }

  Widget _buildEyeProbChip(String label, double prob) {
    final bool isOpen = prob > 0.55;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isOpen ? Colors.greenAccent : Colors.orangeAccent,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOpen ? Icons.remove_red_eye : Icons.remove_red_eye_outlined,
            size: 13,
            color: isOpen ? Colors.greenAccent : Colors.orangeAccent,
          ),
          const SizedBox(width: 4),
          Text(
            '$label: ${(prob * 100).toInt()}%',
            style: TextStyle(
              color: isOpen ? Colors.greenAccent : Colors.orangeAccent,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _lastResult?['status'];
    final isPresent = status == 'PRESENT';
    final isUnknown = status == 'UNKNOWN';

    // Viền khung tương tác đổi màu theo 4 bước
    Color borderColor = Colors.white38;
    if (_livenessStep == LivenessStep.faceDetected) {
      borderColor = Colors.cyanAccent;
    } else if (_livenessStep == LivenessStep.waitingBlink) {
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
      body: Column(
        children: [
          // 1. THANH 4 BƯỚC TƯƠNG TÁC TRỰC QUAN (Hiển thị rõ ràng trạng thái)
          _buildLivenessStepper(),

          // 2. LIVE CAMERA VIEWPORT & KHUNG OVAL TƯƠNG TÁC ĐỔI MÀU
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
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
                    // Hiển thị Camera Live Stream
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

                    // Khung Oval định vị mặt bé (Tự động đổi màu theo 4 bước)
                    Container(
                      width: 220,
                      height: 280,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: borderColor.withValues(alpha: 0.9),
                          width: 3.0,
                        ),
                        borderRadius: BorderRadius.circular(110),
                      ),
                    ),

                    // Hiệu ứng Quét Scanner khi đang xử lý
                    if (_isProcessing)
                      AnimatedBuilder(
                        animation: _animCtrl,
                        builder: (context, child) {
                          return Positioned(
                            top: 80 + (_animCtrl.value * 250),
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

                    // Hướng dẫn trạng thái dạng Badge động
                    Positioned(
                      top: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: borderColor.withValues(alpha: 0.7)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _livenessStep == LivenessStep.passed
                                  ? Icons.verified
                                  : (_livenessStep == LivenessStep.eyesClosed
                                      ? Icons.remove_red_eye_outlined
                                      : Icons.face),
                              color: borderColor,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _statusMessage,
                              style: TextStyle(
                                color: borderColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // RESULT SHEET (PRESENT - ĐIỂM DANH THÀNH CÔNG)
                    if (isPresent)
                      Positioned(
                        bottom: 12,
                        left: 12,
                        right: 12,
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
                              Row(
                                children: [
                                  if (_capturedImageBytes != null) ...[
                                    Column(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.memory(
                                            _capturedImageBytes!,
                                            width: 52,
                                            height: 52,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        const Text('Ảnh lúc quét', style: TextStyle(color: Colors.white60, fontSize: 10)),
                                      ],
                                    ),
                                    const SizedBox(width: 10),
                                  ],
                                  if (_lastResult!['registered_photo_url'] != null) ...[
                                    Column(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.network(
                                            _lastResult!['registered_photo_url'].toString().startsWith('http')
                                                ? _lastResult!['registered_photo_url'].toString()
                                                : '${ApiClient().baseUrl}${_lastResult!['registered_photo_url']}',
                                            width: 52,
                                            height: 52,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Container(
                                              width: 52,
                                              height: 52,
                                              color: Colors.white12,
                                              child: const Icon(Icons.face, size: 24, color: Colors.white54),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        const Text('Ảnh PH đăng ký', style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    const SizedBox(width: 12),
                                  ],
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Học sinh: ${_lastResult!["name"]}',
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                        ),
                                        Text(
                                          'Lớp: ${_lastResult!["class_name"]} • Mã: ${_lastResult!["student_id"]}',
                                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
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
                              const SizedBox(height: 10),
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

                    // RESULT SHEET (UNKNOWN - KHÔNG NHẬN DIỆN ĐƯỢC)
                    if (isUnknown)
                      Positioned(
                        bottom: 12,
                        left: 12,
                        right: 12,
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
                              const SizedBox(height: 10),
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

          // 3. NÚT CHỤP THỦ CÔNG DỰ PHÒNG Ở DƯỚI CÙNG
          if (_lastResult == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
