import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:kidpro_mobile/core/constants/api_endpoints.dart';
import 'package:kidpro_mobile/core/network/api_client.dart';
import 'package:kidpro_mobile/core/storage/secure_storage_helper.dart';
import 'package:kidpro_mobile/core/constants/app_colors.dart';
import 'package:kidpro_mobile/features/teacher/providers/teacher_provider.dart';
import 'package:kidpro_mobile/features/teacher/utils/liveness_direction_mapper.dart';

enum LivenessStep {
  searchingFace, // Bước 1: Đang tìm khuôn mặt
  faceDetected,  // Bước 2: Đã thấy mặt, kiểm tra mở mắt
  waitingBlink,  // Bước 3: Mắt đã mở, đang đợi bé chớp mắt
  eyesClosed,    // Bước 3b: Đang ghi nhận nhịp nhắm mắt
  waitingTurn,   // Bước 3c: Thử thách xoay đầu từ server (Active Liveness - OPT-004)
  passed,        // Bước 4: Xác thực người thật hoàn tất
}

class FaceAttendanceCameraScreen extends StatefulWidget {
  const FaceAttendanceCameraScreen({super.key});

  @override
  State<FaceAttendanceCameraScreen> createState() => _FaceAttendanceCameraScreenState();
}

class _FaceAttendanceCameraScreenState extends State<FaceAttendanceCameraScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // Configurable AI server URL (Wi-Fi LAN IP or USB adb reverse)
  String _serverBaseUrl = ApiClient().aiBaseUrl;
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

  // Liveness Challenge Server-side State (OPT-004)
  String? _activeChallengeId;
  String? _activeChallengeAction; // 'TURN_LEFT' hoặc 'TURN_RIGHT'
  Uint8List? _turnImageBytes;

  // Animation & Processing
  late AnimationController _animCtrl;
  bool _isProcessing = false;
  Timer? _autoResetTimer;
  Map<String, dynamic>? _lastResult;
  Uint8List? _capturedImageBytes;
  final ImagePicker _picker = ImagePicker();

  Future<void> _fetchServerChallenge() async {
    try {
      final res = await ApiClient().dio.post(ApiEndpoints.faceChallenge);
      if (res.data != null && res.data['challenge_id'] != null) {
        if (mounted) {
          setState(() {
            _activeChallengeId = res.data['challenge_id'];
            _activeChallengeAction = res.data['action'];
          });
          debugPrint('🛡️ [OPT-004] Nhận challenge liveness: id=$_activeChallengeId, action=$_activeChallengeAction');
        }
      }
    } catch (e) {
      debugPrint('ℹ️ Không thể nạp server challenge (có thể offline hoặc bypass): $e');
    }
  }

  static final Map<DeviceOrientation, int> _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _serverBaseUrl = ApiClient().aiBaseUrl;
    _urlCtrl.text = _serverBaseUrl;
    _initAiServer();

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
      _fetchServerChallenge();
      _initCameras();
    });
  }

  @override
  void dispose() {
    _autoResetTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _animCtrl.dispose();
    _urlCtrl.dispose();
    _stopAndDisposeCamera();
    _faceDetector.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // WARN-04: Quản lý vòng đời camera khi app vào chế độ nền / chuyển màn hình
    final CameraController? controller = _cameraController;
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      if (controller != null && controller.value.isInitialized) {
        _stopAndDisposeCamera();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_cameraController == null || !_cameraController!.value.isInitialized) {
        if (_cameras.isNotEmpty && mounted) {
          _setupCameraController(_cameras[_selectedCameraIndex]);
        }
      }
    }
  }

  /// WARN-03: Resize về tối đa 1024x768 px và nén JPEG chất lượng 80% (giảm còn ~150KB - 200KB)
  Uint8List _compressImage(Uint8List rawBytes) {
    try {
      final decoded = img.decodeImage(rawBytes);
      if (decoded == null) return rawBytes;

      img.Image processed = decoded;
      const int maxDim = 1024;
      if (decoded.width > maxDim || decoded.height > maxDim) {
        if (decoded.width >= decoded.height) {
          processed = img.copyResize(decoded, width: maxDim);
        } else {
          processed = img.copyResize(decoded, height: maxDim);
        }
      }

      final compressed = img.encodeJpg(processed, quality: 80);
      debugPrint('📸 [WARN-03] Nén ảnh camera: ${rawBytes.length ~/ 1024}KB -> ${compressed.length ~/ 1024}KB');
      return Uint8List.fromList(compressed);
    } catch (e) {
      debugPrint('⚠️ Lỗi nén ảnh, fallback dùng ảnh gốc: $e');
      return rawBytes;
    }
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

    // Tỷ lệ mở mắt trung bình và kiểm tra linh hoạt góc nghiêng
    final double avgEye = (left + right) / 2.0;
    final bool areEyesOpen = avgEye > 0.45 || left > 0.50 || right > 0.50;
    final bool areEyesClosed = avgEye < 0.35 || left < 0.28 || right < 0.28;

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
          // Đo thời gian chớp mắt tự nhiên (80ms - 1800ms)
          final durationMs = _blinkStartTime != null
              ? DateTime.now().difference(_blinkStartTime!).inMilliseconds
              : 0;

          if (durationMs >= 80 && durationMs <= 1800) {
            if (_activeChallengeAction != null && _activeChallengeAction!.isNotEmpty) {
              // OPT-004: Chuyển sang bước quay đầu theo thử thách ngẫu nhiên từ server
              setState(() {
                _livenessStep = LivenessStep.waitingTurn;
                _statusMessage = LivenessDirectionMapper.getInstructionMessage(_activeChallengeAction!);
              });
            } else {
              setState(() {
                _livenessStep = LivenessStep.passed;
                _statusMessage = '✅ Đã xác thực người thật! Đang đối chiếu AI...';
              });
              _onLivenessPassed();
            }
          } else {
            setState(() {
              _livenessStep = LivenessStep.waitingBlink;
              _statusMessage = 'Bé hãy chớp mắt tự nhiên nhé!';
            });
          }
        }
        break;

      case LivenessStep.waitingTurn:
        final yaw = face.headEulerAngleY ?? 0.0;
        final isFront = _cameras.isNotEmpty &&
            _cameras[_selectedCameraIndex].lensDirection == CameraLensDirection.front;
        final isTurned = LivenessDirectionMapper.isTurnDirectionSatisfied(
          action: _activeChallengeAction ?? '',
          headEulerAngleY: yaw,
          isFrontCamera: isFront,
        );

        if (isTurned) {
          setState(() {
            _livenessStep = LivenessStep.passed;
            _statusMessage = '✅ Đã hoàn thành thử thách! Đang đối chiếu AI...';
          });
          _onLivenessPassed();
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

    // Watchdog: dài hơn tổng thời gian chờ mạng (connect 15 s + receive 15 s) để không reset
    // khi request cũ còn chạy (tránh kết quả cũ ghi đè người quét kế tiếp)
    _autoResetTimer?.cancel();
    _autoResetTimer = Timer(const Duration(seconds: 32), () {
      if (mounted && _isProcessing) {
        debugPrint('⚠️ [Watchdog] Quá thời gian chờ nhận diện AI (32s). Tự động phục hồi...');
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Hết thời gian chờ nhận diện AI. Đang quét lại...';
        });
        _resetForNextStudent();
      }
    });

    try {
      if (_cameraController == null || !_cameraController!.value.isInitialized) {
        throw Exception('Camera chưa sẵn sàng hoặc bị ngắt kết nối');
      }

      if (_cameraController!.value.isStreamingImages) {
        try {
          await _cameraController!.stopImageStream();
        } catch (e) {
          debugPrint('Lỗi dừng camera stream: $e');
        }
      }

      final XFile photo = await _cameraController!.takePicture();
      final bytes = await photo.readAsBytes();
      final compressedBytes = _compressImage(bytes);

      if (mounted) {
        setState(() {
          _capturedImageBytes = compressedBytes;
        });
      }

      await _submitCheckinToServer(compressedBytes, isLivenessVerified: true);
    } catch (e) {
      debugPrint('Error on liveness auto capture: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Lỗi camera khi chụp. Đang thử lại...';
        });
        _autoResetTimer?.cancel();
        _autoResetTimer = Timer(const Duration(milliseconds: 1500), () {
          if (mounted) _resetForNextStudent();
        });
      }
    }
  }

  /// OPT-003 & OPT-002: Điểm danh Server-to-Server qua Spring Boot Backend
  Future<void> _submitCheckinToServer(Uint8List bytes, {required bool isLivenessVerified}) async {
    try {
      final tProv = context.read<TeacherProvider>();
      final curClassId = tProv.currentClassId;

      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: 'face_checkin.jpg',
        ),
        if (_turnImageBytes != null)
          'turnFile': MultipartFile.fromBytes(
            _turnImageBytes!,
            filename: 'face_turn.jpg',
          ),
        if (curClassId.isNotEmpty) 'classId': curClassId,
        if (_activeChallengeId != null) 'challengeId': _activeChallengeId,
        if (_activeChallengeAction != null) 'turnAction': _activeChallengeAction,
      });

      // OPT-003: Gọi trực tiếp Spring Boot Backend với Bearer JWT token tự động
      final response = await ApiClient().dio.post(
        ApiEndpoints.faceCheckIn,
        data: formData,
      );

      final data = response.data as Map<String, dynamic>;
      data['liveness_verified'] = isLivenessVerified;

      // Khi Spring Boot xác nhận PRESENT hoặc LATE: Cập nhật danh sách học sinh
      if (data['status'] == 'PRESENT' || data['status'] == 'LATE') {
        if (mounted) {
          final tProv = context.read<TeacherProvider>();
          tProv.loadStudents(tProv.currentClassId);
        }
      }

      HapticFeedback.mediumImpact();
      if (mounted) {
        setState(() {
          _lastResult = data;
          _isProcessing = false;
        });

        // Nếu không nhận diện được hoặc ảnh mờ: Tự động lên lịch reset sau 4s để cô giáo không cần chạm tay
        if (data['status'] != 'PRESENT') {
          _autoResetTimer?.cancel();
          _autoResetTimer = Timer(const Duration(seconds: 4), () {
            if (mounted && _lastResult != null && _lastResult!['status'] != 'PRESENT') {
              _resetForNextStudent();
            }
          });
        }
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Lỗi kết nối điểm danh: ${e.response?.data?["message"] ?? e.message ?? "Timeout"}. Đang thử lại...';
          _lastResult = {
            'status': 'ERROR',
            'confidence_score': 0.0,
            'message': e.response?.data?['message'] ?? e.message ?? 'Lỗi kết nối máy chủ',
          };
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi điểm danh: ${e.response?.data?["message"] ?? e.message ?? "Timeout"}'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 2),
          ),
        );
        _autoResetTimer?.cancel();
        _autoResetTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) _resetForNextStudent();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Lỗi xử lý: $e';
          _lastResult = {
            'status': 'ERROR',
            'confidence_score': 0.0,
            'message': 'Lỗi xử lý: $e',
          };
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.error, duration: const Duration(seconds: 2)),
        );
        _autoResetTimer?.cancel();
        _autoResetTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) _resetForNextStudent();
        });
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
    _autoResetTimer?.cancel();
    setState(() {
      _lastResult = null;
      _capturedImageBytes = null;
      _turnImageBytes = null;
      _activeChallengeId = null;
      _activeChallengeAction = null;
      _livenessStep = LivenessStep.searchingFace;
      _statusMessage = 'Bé vui lòng nhìn vào camera';
      _isProcessing = false;
    });

    _fetchServerChallenge();

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
            children: [
              Expanded(child: _buildStepItem(1, 'Tìm mặt', step1Done, _livenessStep == LivenessStep.searchingFace)),
              _buildStepArrow(),
              Expanded(child: _buildStepItem(2, 'Mở mắt', step2Done, _livenessStep == LivenessStep.faceDetected)),
              _buildStepArrow(),
              Expanded(child: _buildStepItem(3, 'Chớp mắt', step3Done, _livenessStep == LivenessStep.waitingBlink || _livenessStep == LivenessStep.eyesClosed)),
              _buildStepArrow(),
              Expanded(child: _buildStepItem(4, 'Xác thực', step4Done, _livenessStep == LivenessStep.passed)),
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
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
    final isFailedOrUnknown = _lastResult != null && !isPresent;
    final isBlurred = status == 'BLURRED';

    // Viền khung tương tác đổi màu theo 4 bước
    Color borderColor = Colors.white38;
    if (_livenessStep == LivenessStep.faceDetected) {
      borderColor = Colors.cyanAccent;
    } else if (_livenessStep == LivenessStep.waitingBlink) {
      borderColor = Colors.lightBlueAccent;
    } else if (_livenessStep == LivenessStep.eyesClosed) {
      borderColor = Colors.amberAccent;
    } else if (isPresent) {
      borderColor = AppColors.success;
    } else if (isFailedOrUnknown) {
      borderColor = isBlurred ? AppColors.warning : AppColors.strangerAlert;
    } else if (_livenessStep == LivenessStep.passed) {
      borderColor = Colors.cyanAccent;
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
              icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
              tooltip: 'Đổi camera trước/sau',
              onPressed: _toggleCamera,
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
                  width: _livenessStep == LivenessStep.passed || isPresent || isFailedOrUnknown ? 3.5 : 2.0,
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

                    // Khung Oval định vị mặt bé (Chỉ hiện khi chưa có kết quả)
                    if (_lastResult == null)
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

                    // Hướng dẫn trạng thái dạng Badge động (Chống tràn viền)
                    Positioned(
                      top: 14,
                      left: 14,
                      right: 14,
                      child: Center(
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
                              Flexible(
                                child: Text(
                                  _statusMessage,
                                  style: TextStyle(
                                    color: borderColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // RESULT SHEET (PRESENT - ĐIỂM DANH THÀNH CÔNG - Scroll & Responsive chống tràn viền)
                    if (isPresent)
                      Positioned(
                        bottom: 12,
                        left: 12,
                        right: 12,
                        child: Container(
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.sizeOf(context).height * 0.45,
                          ),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xEE111827),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.success, width: 1.5),
                          ),
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.check_circle, color: AppColors.success, size: 22),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'ĐIỂM DANH THÀNH CÔNG',
                                        style: TextStyle(
                                          color: AppColors.success,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
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
                                              width: 50,
                                              height: 50,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          const Text('Ảnh lúc quét', style: TextStyle(color: Colors.white60, fontSize: 10)),
                                        ],
                                      ),
                                      const SizedBox(width: 8),
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
                                              width: 50,
                                              height: 50,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => Container(
                                                width: 50,
                                                height: 50,
                                                color: Colors.white12,
                                                child: const Icon(Icons.face, size: 24, color: Colors.white54),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          const Text('Ảnh PH đăng ký', style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                      const SizedBox(width: 10),
                                    ],
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Học sinh: ${_lastResult!["name"]}',
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Lớp: ${_lastResult!["class_name"]} • Mã: ${_lastResult!["student_id"]}',
                                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(
                                      _lastResult!['liveness_verified'] == true ? Icons.shield : Icons.shield_outlined,
                                      color: _lastResult!['liveness_verified'] == true ? Colors.greenAccent : Colors.amberAccent,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        _lastResult!['liveness_verified'] == true
                                            ? 'Xác thực người thật: Đã qua (Chớp mắt)'
                                            : 'Xác thực: Chụp thủ công',
                                        style: TextStyle(
                                          color: _lastResult!['liveness_verified'] == true ? Colors.greenAccent : Colors.amberAccent,
                                          fontSize: 11,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
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
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                    ),
                                    onPressed: _resetForNextStudent,
                                    icon: const Icon(Icons.arrow_forward, size: 18),
                                    label: const Text(
                                      'Điểm danh bé tiếp theo',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // RESULT SHEET (KHÔNG THÀNH CÔNG / ẢNH MỜ / CHƯA NHẬN DIỆN ĐƯỢC - Scroll & Responsive)
                    if (isFailedOrUnknown)
                      Positioned(
                        bottom: 12,
                        left: 12,
                        right: 12,
                        child: Container(
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.sizeOf(context).height * 0.45,
                          ),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xEE111827),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isBlurred ? AppColors.warning : AppColors.strangerAlert,
                              width: 1.5,
                            ),
                          ),
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      isBlurred ? Icons.motion_photos_off : Icons.warning_amber_rounded,
                                      color: isBlurred ? AppColors.warning : AppColors.strangerAlert,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        isBlurred ? 'ẢNH BỊ MỜ / RUNG TAY' : 'CHƯA TRÙNG KHỚP KHUÔN MẶT',
                                        style: TextStyle(
                                          color: isBlurred ? AppColors.warning : AppColors.strangerAlert,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (_lastResult!["confidence_score"] != null && (_lastResult!["confidence_score"] as num) > 0) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white12,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'Điểm: ${((_lastResult!["confidence_score"] as num) * 100).toStringAsFixed(1)}%',
                                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _lastResult!['message'] ?? (isBlurred ? 'Ảnh bị nhòe do rung lắc. Giữ yên máy để nhận diện rõ hơn.' : 'Khuôn mặt chưa trùng khớp với học sinh trong danh sách.'),
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  '(Hệ thống sẽ tự động mở lại camera sau 4 giây)',
                                  style: TextStyle(color: Colors.white38, fontSize: 10, fontStyle: FontStyle.italic),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isBlurred ? AppColors.warning : Colors.white24,
                                          foregroundColor: isBlurred ? Colors.black : Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                        ),
                                        onPressed: _resetForNextStudent,
                                        icon: const Icon(Icons.refresh, size: 16),
                                        label: const Text(
                                          'Thử lại ngay',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.white,
                                          side: const BorderSide(color: Colors.white38),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                        ),
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text(
                                          'Điểm danh thủ công',
                                          style: TextStyle(fontSize: 11),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // Nút Reset/Quét lại nhanh ở góc phải trên (chống đơ kẹt trong mọi trường hợp)
                    if (_livenessStep == LivenessStep.passed || _isProcessing || _lastResult != null)
                      Positioned(
                        top: 14,
                        right: 14,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: _resetForNextStudent,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white38),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.refresh, color: Colors.white, size: 16),
                                  SizedBox(width: 4),
                                  Text(
                                    'Quét lại',
                                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
