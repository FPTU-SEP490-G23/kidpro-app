import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';

import 'package:kidpro_mobile/core/constants/app_colors.dart';
import 'package:kidpro_mobile/core/widgets/auth_network_image.dart';
import 'package:kidpro_mobile/features/teacher/models/teacher_models.dart';
import 'package:kidpro_mobile/features/teacher/providers/teacher_provider.dart';

/// Màn hình quét mặt phụ huynh đón trẻ (G5-UC-04, BR-022)
/// AI tự động đối chiếu khuôn mặt người đón với danh sách phụ huynh của lớp,
/// cho phép đón con và ghi nhận giờ về (check-out) vào Attendance.
class ParentPickupCameraScreen extends StatefulWidget {
  final String classId;
  final String className;

  const ParentPickupCameraScreen({
    super.key,
    required this.classId,
    required this.className,
  });

  @override
  State<ParentPickupCameraScreen> createState() => _ParentPickupCameraScreenState();
}

class _ParentPickupCameraScreenState extends State<ParentPickupCameraScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  List<CameraDescription> _cameras = [];
  CameraController? _cameraController;
  int _selectedCameraIndex = 0;
  bool _isCameraInitialized = false;
  bool _isCameraError = false;

  late FaceDetector _faceDetector;
  bool _isDetecting = false;
  bool _isProcessing = false;

  // Liveness / Trigger state
  bool _faceInFrame = false;
  // Liveness: phải thấy mắt mở -> nhắm -> mở (chớp mắt 80-1800 ms) mới chụp, chống dùng ảnh in/màn hình
  bool _sawEyesOpen = false;
  DateTime? _eyesClosedAt;
  // Thời điểm phát hiện khuôn mặt vào khung hình
  DateTime? _faceDetectedTime;
  bool _livenessPassed = false;
  // Ảnh đã chụp của lần nhận diện gần nhất, dùng lại khi cô giáo bấm xác nhận bàn giao
  Uint8List? _lastPhotoBytes;
  bool _confirming = false;
  String _statusMessage = 'Hướng camera về phía phụ huynh đến đón';

  late AnimationController _animCtrl;
  Timer? _autoResetTimer;
  ParentPickupRecognitionResult? _lastResult;

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

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        performanceMode: FaceDetectorMode.fast,
        minFaceSize: 0.15,
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initCameras();
    });
  }

  @override
  void dispose() {
    _autoResetTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _animCtrl.dispose();
    _stopAndDisposeCamera();
    _faceDetector.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
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
      return Uint8List.fromList(compressed);
    } catch (e) {
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

      // Mặc định chọn camera sau để giáo viên quay về phía phụ huynh
      int initialIndex = _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
      if (initialIndex < 0) initialIndex = 0;
      _selectedCameraIndex = initialIndex;

      await _setupCameraController(_cameras[_selectedCameraIndex]);
    } catch (e) {
      debugPrint('Error getting cameras: $e');
      setState(() {
        _isCameraError = true;
        _statusMessage = 'Lỗi camera.';
      });
    }
  }

  Future<void> _setupCameraController(CameraDescription camera) async {
    await _stopAndDisposeCamera();

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
      _statusMessage = 'Hướng camera về phía phụ huynh để nhận diện';
    });

    await controller.startImageStream(_processCameraImage);
  }

  Future<void> _toggleCamera() async {
    if (_cameras.length <= 1) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    setState(() {
      _isCameraInitialized = false;
    });
    await _setupCameraController(_cameras[_selectedCameraIndex]);
  }

  void _processCameraImage(CameraImage image) async {
    if (_isDetecting || _isProcessing || _lastResult != null) return;
    _isDetecting = true;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) return;

      final faces = await _faceDetector.processImage(inputImage);
      if (!mounted) return;

      if (faces.isEmpty) {
        if (_faceInFrame) {
          setState(() {
            _faceInFrame = false;
            _faceDetectedTime = null;
            _statusMessage = 'Hướng camera về phía phụ huynh';
          });
        }
        return;
      }

      // Tìm khuôn mặt lớn nhất
      final face = faces.reduce((curr, next) =>
          (curr.boundingBox.width * curr.boundingBox.height) >
                  (next.boundingBox.width * next.boundingBox.height)
              ? curr
              : next);

      final left = face.leftEyeOpenProbability;
      final right = face.rightEyeOpenProbability;
      if (left == null || right == null) return;
      final avg = (left + right) / 2;
      final bool eyesOpen = avg > 0.45 || left > 0.5 || right > 0.5;
      final bool eyesClosed = avg < 0.35 && left < 0.3 && right < 0.3;

      if (!_faceInFrame) {
        setState(() {
          _faceInFrame = true;
          _faceDetectedTime = DateTime.now();
          _sawEyesOpen = false;
          _eyesClosedAt = null;
          _livenessPassed = false;
          _statusMessage = 'Đã thấy phụ huynh! Vui lòng chớp mắt để xác thực...';
        });
        return;
      }

      // Kiểm tra người thật bằng một lần chớp mắt
      if (!_livenessPassed) {
        if (eyesOpen && _eyesClosedAt == null) {
          _sawEyesOpen = true;
        } else if (eyesClosed && _sawEyesOpen && _eyesClosedAt == null) {
          _eyesClosedAt = DateTime.now();
        } else if (eyesOpen && _eyesClosedAt != null) {
          final blinkMs = DateTime.now().difference(_eyesClosedAt!).inMilliseconds;
          if (blinkMs >= 80 && blinkMs <= 1800) {
            _livenessPassed = true;
            setState(() => _statusMessage = 'Đã xác thực người thật. Đang chụp...');
          } else {
            _eyesClosedAt = null;
          }
        }
        return;
      }

      if (eyesOpen) {
        _triggerCaptureAndVerify();
      }
    } catch (e) {
      debugPrint('Face detection error: $e');
    } finally {
      _isDetecting = false;
    }
  }

  Uint8List _yuv420ToNv21(CameraImage image) {
    if (image.planes.length == 1) return image.planes.first.bytes;

    final int width = image.width;
    final int height = image.height;
    final int ySize = width * height;
    final int uvSize = width * height ~/ 2;
    final Uint8List nv21 = Uint8List(ySize + uvSize);

    nv21.setRange(0, ySize, image.planes[0].bytes);

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

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_cameraController == null) return null;
    final camera = _cameras[_selectedCameraIndex];
    final sensorOrientation = camera.sensorOrientation;

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

  Future<void> _triggerCaptureAndVerify() async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Đang nhận diện phụ huynh & kiểm tra quyền đón...';
    });
    HapticFeedback.mediumImpact();

    // Watchdog dài hơn thời gian chờ mạng (45 s) để không reset khi request cũ còn chạy
    _autoResetTimer?.cancel();
    _autoResetTimer = Timer(const Duration(seconds: 50), () {
      if (mounted && _isProcessing) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Hết thời gian chờ phản hồi. Đang thử lại...';
        });
        _resetForNextParent();
      }
    });

    final provider = context.read<TeacherProvider>();

    try {
      if (_cameraController == null || !_cameraController!.value.isInitialized) {
        throw Exception('Camera chưa sẵn sàng');
      }

      if (_cameraController!.value.isStreamingImages) {
        try {
          await _cameraController!.stopImageStream();
        } catch (_) {}
      }

      final XFile photo = await _cameraController!.takePicture();
      final bytes = await photo.readAsBytes();
      final compressed = _compressImage(bytes);
      _lastPhotoBytes = compressed;

      // Chỉ nhận diện; việc bàn giao bé phải do cô giáo bấm xác nhận
      final (result, errorMsg) = await provider.recognizeParentPickup(
            classId: widget.classId,
            photoBytes: compressed,
            autoCheckout: false,
          );

      if (!mounted) return;

      if (result != null) {
        if (result.matched) {
          HapticFeedback.heavyImpact();
        } else {
          HapticFeedback.vibrate();
        }
        setState(() {
          _lastResult = result;
          _isProcessing = false;
        });

        // Tự động reset sau 4s nếu không khớp để cô giáo tiếp tục quét
        if (!result.matched) {
          _autoResetTimer?.cancel();
          _autoResetTimer = Timer(const Duration(seconds: 4), () {
            if (mounted && _lastResult != null && !_lastResult!.matched) {
              _resetForNextParent();
            }
          });
        }
      } else {
        setState(() {
          _isProcessing = false;
          _statusMessage = errorMsg;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: AppColors.error),
        );
        _autoResetTimer?.cancel();
        _autoResetTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) _resetForNextParent();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Lỗi chụp ảnh: $e';
        });
        _autoResetTimer?.cancel();
        _autoResetTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) _resetForNextParent();
        });
      }
    }
  }

  /// Cô giáo xác nhận bàn giao: gửi lại đúng ảnh đã nhận diện với autoCheckout=true
  /// (backend kiểm tra lại quyền đón trước khi ghi giờ rời lớp).
  Future<void> _confirmHandover() async {
    final bytes = _lastPhotoBytes;
    if (bytes == null) return;
    setState(() => _confirming = true);
    final (result, msg) = await context.read<TeacherProvider>().recognizeParentPickup(
          classId: widget.classId,
          photoBytes: bytes,
          autoCheckout: true,
        );
    if (!mounted) return;
    setState(() {
      _confirming = false;
      if (result != null) _lastResult = result;
    });
    final ok = result != null && result.checkoutSuccess;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Đã bàn giao bé ${result.studentName ?? ''} lúc ${result.checkoutTime ?? ''}' : msg),
      backgroundColor: ok ? AppColors.success : AppColors.error,
    ));
  }

  void _resetForNextParent() async {
    _autoResetTimer?.cancel();
    setState(() {
      _lastResult = null;
      _faceInFrame = false;
      _faceDetectedTime = null;
      _sawEyesOpen = false;
      _eyesClosedAt = null;
      _livenessPassed = false;
      _lastPhotoBytes = null;
      _isProcessing = false;
      _statusMessage = 'Hướng camera về phía phụ huynh tiếp theo';
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

  @override
  Widget build(BuildContext context) {
    final tProv = context.watch<TeacherProvider>();
    final waitingStudents = tProv.students
        .where((s) =>
            (s.status == AttendanceStatus.present || s.status == AttendanceStatus.late) &&
            (s.checkOutTime == null || s.checkOutTime!.isEmpty))
        .length;

    Color borderColor = Colors.white38;
    if (_lastResult != null) {
      borderColor = _lastResult!.matched ? AppColors.success : AppColors.error;
    } else if (_faceInFrame) {
      borderColor = Colors.cyanAccent;
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Quét mặt phụ huynh đón trẻ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text('Lớp: ${widget.className} • $waitingStudents bé chờ đón',
                style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        actions: [
          if (_cameras.length > 1)
            IconButton(
              icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
              tooltip: 'Đổi camera',
              onPressed: _toggleCamera,
            ),
        ],
      ),
      body: Column(
        children: [
          // 1. LIVE CAMERA VIEWPORT & KHUNG QUÉT MẶT PHỤ HUYNH
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_isCameraInitialized && _cameraController != null)
                  Center(
                    child: CameraPreview(_cameraController!),
                  )
                else if (_isCameraError)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_statusMessage, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                    ),
                  )
                else
                  const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),

                // Oval scanning overlay
                Center(
                  child: AnimatedBuilder(
                    animation: _animCtrl,
                    builder: (context, child) {
                      final double scale = 1.0 + (_animCtrl.value * 0.02);
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 250,
                          height: 330,
                          decoration: BoxDecoration(
                            shape: BoxShape.rectangle,
                            borderRadius: BorderRadius.circular(125),
                            border: Border.all(color: borderColor, width: 3.5),
                            boxShadow: [
                              BoxShadow(
                                color: borderColor.withValues(alpha: 0.3),
                                blurRadius: 18,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Thanh trạng thái phía trên
                Positioned(
                  top: 16,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isProcessing)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        else
                          Icon(
                            _faceInFrame ? Icons.face_rounded : Icons.camera_alt_outlined,
                            size: 16,
                            color: _faceInFrame ? Colors.cyanAccent : Colors.white70,
                          ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _statusMessage,
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. KẾT QUẢ NHẬN DIỆN & BÀN GIAO CON
          if (_lastResult != null)
            _buildResultCard(_lastResult!)
          else
            _buildManualActionBar(),
        ],
      ),
    );
  }

  Widget _buildResultCard(ParentPickupRecognitionResult result) {
    final bool isSuccess = result.matched;
    final int percentMatch = result.similarity != null ? (result.similarity! * 100).toInt() : 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSuccess ? const Color(0xFF0F2E1E) : const Color(0xFF2E0F0F),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: isSuccess ? AppColors.success : AppColors.error,
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSuccess ? AppColors.success.withValues(alpha: 0.2) : AppColors.error.withValues(alpha: 0.2),
                ),
                child: Icon(
                  isSuccess ? Icons.check_circle_rounded : Icons.warning_rounded,
                  color: isSuccess ? AppColors.success : AppColors.error,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSuccess ? 'Xác thực phụ huynh thành công!' : 'Cảnh báo: Không khớp phụ huynh!',
                      style: TextStyle(
                        color: isSuccess ? AppColors.success : AppColors.error,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      result.message,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (result.similarity != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(
                    '$percentMatch%',
                    style: TextStyle(
                      color: isSuccess ? AppColors.success : AppColors.error,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),

          if (isSuccess) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  // Ảnh hồ sơ đã đăng ký
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: (result.photoUrl != null && result.photoUrl!.isNotEmpty)
                        ? AuthNetworkImage(
                            url: result.photoUrl!,
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                            placeholder: Container(
                              width: 44,
                              height: 44,
                              color: Colors.white12,
                              child: const Icon(Icons.person_rounded, color: Colors.white, size: 20),
                            ),
                          )
                        : Container(
                            width: 44,
                            height: 44,
                            color: Colors.white12,
                            child: const Icon(Icons.person_rounded, color: Colors.white, size: 20),
                          ),
                  ),
                  // Ảnh chụp probe thực tế lúc đón (đã lưu Cloudinary & AttendancePhoto)
                  if (result.capturedPhotoUrl != null && result.capturedPhotoUrl!.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        children: [
                          AuthNetworkImage(
                            url: result.capturedPhotoUrl!,
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                            placeholder: Container(
                              width: 44,
                              height: 44,
                              color: Colors.white12,
                              child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            left: 0,
                            child: Container(
                              color: Colors.black54,
                              padding: const EdgeInsets.symmetric(vertical: 1),
                              child: const Text('Lúc đón', style: TextStyle(color: Colors.cyanAccent, fontSize: 8), textAlign: TextAlign.center),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${result.relationship ?? "Phụ huynh"}: ${result.personName ?? ""}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Bé được đón: ${result.studentName ?? ""} (${result.studentCode ?? ""})',
                          style: const TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        if (result.checkoutTime != null)
                          Text(
                            'Giờ rời lớp: ${result.checkoutTime}',
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (isSuccess && !result.checkoutSuccess && !result.alreadyCheckedOut && _lastPhotoBytes != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _confirming ? null : _confirmHandover,
                icon: _confirming
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.how_to_reg_rounded, size: 20),
                label: Text('Xác nhận bàn giao bé ${result.studentName ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ),
          ],
          if (result.alreadyCheckedOut)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text('Bé đã được bàn giao trước đó.', style: TextStyle(color: Colors.orangeAccent)),
            ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isSuccess ? AppColors.success : Colors.white24,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _resetForNextParent,
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
              label: Text(
                isSuccess ? 'Tiếp tục quét phụ huynh tiếp theo' : 'Thử quét lại',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      color: Colors.black,
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white12,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios_rounded, size: 16),
              label: const Text('Quay lại'),
            ),
          ],
        ),
      ),
    );
  }
}
