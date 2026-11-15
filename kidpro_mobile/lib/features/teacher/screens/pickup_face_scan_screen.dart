import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:kidpro_mobile/core/constants/app_colors.dart';
import 'package:kidpro_mobile/features/teacher/utils/camera_input_image.dart';

/// Kết quả quét mặt: ảnh để gửi AI so khớp và việc người đón đã chớp mắt (người thật) hay chưa.
class PickupFaceScanResult {
  final Uint8List bytes;
  final bool livenessVerified;

  const PickupFaceScanResult(this.bytes, {required this.livenessVerified});
}

enum _ScanStep { searching, adjust, blink, eyesClosed, capturing }

/// Quét mặt trực tiếp người đến đón trẻ (BR-022): tìm khuôn mặt → đủ gần → chớp mắt → tự chụp.
/// Chớp mắt chặn việc giơ ảnh phụ huynh trên điện thoại để qua mặt AI.
class PickupFaceScanScreen extends StatefulWidget {
  final String personName;

  const PickupFaceScanScreen({super.key, required this.personName});

  @override
  State<PickupFaceScanScreen> createState() => _PickupFaceScanScreenState();
}

class _PickupFaceScanScreenState extends State<PickupFaceScanScreen> {
  // Khuôn mặt phải chiếm tối thiểu tỷ lệ này so với chiều ngang khung hình
  static const _minFaceWidthRatio = 0.28;
  // Sau thời gian này chưa tự chụp được thì hiện nút chụp tay
  static const _manualCaptureDelay = Duration(seconds: 8);

  final _detector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      performanceMode: FaceDetectorMode.fast,
      minFaceSize: 0.15,
    ),
  );

  List<CameraDescription> _cameras = [];
  int _cameraIndex = 0;
  CameraController? _controller;
  String? _cameraError;

  bool _detecting = false;
  _ScanStep _step = _ScanStep.searching;
  String _message = 'Đưa khuôn mặt người đón vào giữa khung';
  DateTime? _eyesClosedAt;
  bool _showManualCapture = false;
  Timer? _manualTimer;

  @override
  void initState() {
    super.initState();
    _initCameras();
  }

  @override
  void dispose() {
    _manualTimer?.cancel();
    _disposeController();
    _detector.close();
    super.dispose();
  }

  Future<void> _disposeController() async {
    final controller = _controller;
    _controller = null;
    if (controller == null) return;
    try {
      if (controller.value.isStreamingImages) await controller.stopImageStream();
      await controller.dispose();
    } catch (e) {
      debugPrint('Pickup face scan dispose error: $e');
    }
  }

  Future<void> _initCameras() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _cameraError = 'Không tìm thấy camera trên thiết bị.');
        return;
      }
      // Mặc định camera sau: giáo viên hướng máy về phía người đến đón
      final back = _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
      _cameraIndex = back >= 0 ? back : 0;
      await _startCamera();
    } catch (e) {
      if (mounted) setState(() => _cameraError = 'Không mở được camera: $e');
    }
  }

  Future<void> _startCamera() async {
    await _disposeController();
    var controller = CameraController(
      _cameras[_cameraIndex],
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );
    try {
      await controller.initialize();
    } catch (_) {
      controller = CameraController(
        _cameras[_cameraIndex],
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await controller.initialize();
    }
    if (!mounted) {
      await controller.dispose();
      return;
    }
    _controller = controller;
    _resetScan();
    await controller.startImageStream(_onFrame);
  }

  void _resetScan() {
    _manualTimer?.cancel();
    _manualTimer = Timer(_manualCaptureDelay, () {
      if (mounted) setState(() => _showManualCapture = true);
    });
    setState(() {
      _cameraError = null;
      _step = _ScanStep.searching;
      _message = 'Đưa khuôn mặt người đón vào giữa khung';
      _eyesClosedAt = null;
      _showManualCapture = false;
    });
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _step == _ScanStep.capturing) return;
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    await _startCamera();
  }

  Future<void> _onFrame(CameraImage image) async {
    final controller = _controller;
    if (_detecting || controller == null || _step == _ScanStep.capturing) return;
    _detecting = true;
    try {
      final input = inputImageFromCameraImage(image, _cameras[_cameraIndex], controller);
      if (input == null) return;
      final faces = await _detector.processImage(input);
      if (!mounted || _step == _ScanStep.capturing) return;

      final rotation = input.metadata?.rotation;
      final uprightWidth = (rotation == InputImageRotation.rotation90deg || rotation == InputImageRotation.rotation270deg)
          ? image.height
          : image.width;
      _analyze(faces, uprightWidth.toDouble());
    } catch (e) {
      debugPrint('Pickup face scan frame error: $e');
    } finally {
      _detecting = false;
    }
  }

  void _analyze(List<Face> faces, double frameWidth) {
    if (faces.isEmpty) {
      _setStep(_ScanStep.searching, 'Đưa khuôn mặt người đón vào giữa khung');
      return;
    }
    final face = faces.reduce((a, b) =>
        a.boundingBox.width * a.boundingBox.height >= b.boundingBox.width * b.boundingBox.height ? a : b);

    if (face.boundingBox.width / frameWidth < _minFaceWidthRatio) {
      _setStep(_ScanStep.adjust, 'Đưa camera lại gần khuôn mặt hơn');
      return;
    }

    final left = face.leftEyeOpenProbability;
    final right = face.rightEyeOpenProbability;
    if (left == null || right == null) {
      _setStep(_ScanStep.adjust, 'Nhìn thẳng vào camera, không đeo kính râm');
      return;
    }
    final avg = (left + right) / 2;
    final eyesOpen = avg > 0.55;
    final eyesClosed = avg < 0.35 || left < 0.30 || right < 0.30;

    switch (_step) {
      case _ScanStep.searching:
      case _ScanStep.adjust:
        if (eyesOpen) {
          _setStep(_ScanStep.blink, 'Mời người đón chớp mắt một cái');
        } else {
          _setStep(_ScanStep.adjust, 'Mở mắt và nhìn thẳng vào camera');
        }
        break;
      case _ScanStep.blink:
        // Khung hình mắt lưng chừng (đang nhắm dần) thì giữ nguyên bước chờ chớp mắt
        if (eyesClosed) {
          _eyesClosedAt = DateTime.now();
          _setStep(_ScanStep.eyesClosed, 'Đang nhận nhịp chớp mắt...');
        }
        break;
      case _ScanStep.eyesClosed:
        if (eyesOpen) {
          final ms = _eyesClosedAt == null ? 0 : DateTime.now().difference(_eyesClosedAt!).inMilliseconds;
          if (ms >= 60 && ms <= 1600) {
            _capture(livenessVerified: true);
          } else {
            _setStep(_ScanStep.blink, 'Chớp mắt tự nhiên một cái nhé');
          }
        }
        break;
      case _ScanStep.capturing:
        break;
    }
  }

  void _setStep(_ScanStep step, String message) {
    if (_step == step && _message == message) return;
    setState(() {
      _step = step;
      _message = message;
    });
  }

  Future<void> _capture({required bool livenessVerified}) async {
    final controller = _controller;
    if (controller == null || _step == _ScanStep.capturing) return;
    _manualTimer?.cancel();
    setState(() {
      _step = _ScanStep.capturing;
      _message = 'Đang chụp khuôn mặt...';
    });
    HapticFeedback.mediumImpact();
    try {
      if (controller.value.isStreamingImages) await controller.stopImageStream();
      final photo = await controller.takePicture();
      final bytes = await photo.readAsBytes();
      if (!mounted) return;
      Navigator.of(context).pop(PickupFaceScanResult(bytes, livenessVerified: livenessVerified));
    } catch (e) {
      debugPrint('Pickup face capture error: $e');
      if (!mounted) return;
      _resetScan();
      setState(() => _message = 'Chụp chưa được, đang quét lại...');
      await controller.startImageStream(_onFrame);
    }
  }

  Color get _frameColor {
    switch (_step) {
      case _ScanStep.searching:
        return Colors.white;
      case _ScanStep.adjust:
        return AppColors.warning;
      case _ScanStep.blink:
      case _ScanStep.eyesClosed:
      case _ScanStep.capturing:
        return AppColors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Quét mặt người đón'),
        actions: [
          if (_cameras.length > 1)
            IconButton(
              tooltip: 'Đổi camera trước/sau',
              icon: const Icon(Icons.cameraswitch_rounded),
              onPressed: _switchCamera,
            ),
        ],
      ),
      body: _cameraError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_cameraError!,
                    textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, height: 1.4)),
              ),
            )
          : controller == null || !controller.value.isInitialized
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildPreview(controller),
                    CustomPaint(painter: _OvalMaskPainter(color: _frameColor)),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 24,
                      child: _buildStatusPanel(),
                    ),
                  ],
                ),
    );
  }

  Widget _buildPreview(CameraController controller) {
    final size = controller.value.previewSize;
    if (size == null) return CameraPreview(controller);
    // Lấp đầy màn hình theo chiều đứng (previewSize trả về theo chiều ngang cảm biến)
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(width: size.height, height: size.width, child: CameraPreview(controller)),
      ),
    );
  }

  Widget _buildStatusPanel() {
    final capturing = _step == _ScanStep.capturing;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Đang xác thực: ${widget.personName}',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12.5),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (capturing) ...[
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                const SizedBox(width: 8),
              ] else
                Icon(Icons.face_retouching_natural, color: _frameColor, size: 20),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  _message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (_showManualCapture && !capturing) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              onPressed: () => _capture(livenessVerified: false),
              icon: const Icon(Icons.camera_alt_outlined, size: 18),
              label: const Text(
                'Không nhận được chớp mắt? Chụp tay',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Phủ tối ngoài khung oval, viền oval đổi màu theo trạng thái quét.
class _OvalMaskPainter extends CustomPainter {
  final Color color;

  _OvalMaskPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final oval = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.42),
      width: size.width * 0.68,
      height: size.width * 0.68 * 1.3,
    );
    final mask = Path()
      ..addRect(Offset.zero & size)
      ..addOval(oval)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(mask, Paint()..color = Colors.black.withValues(alpha: 0.55));
    canvas.drawOval(
      oval,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
  }

  @override
  bool shouldRepaint(covariant _OvalMaskPainter oldDelegate) => oldDelegate.color != color;
}
