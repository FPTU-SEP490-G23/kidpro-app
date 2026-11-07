import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

const _deviceOrientations = {
  DeviceOrientation.portraitUp: 0,
  DeviceOrientation.landscapeLeft: 90,
  DeviceOrientation.portraitDown: 180,
  DeviceOrientation.landscapeRight: 270,
};

/// Góc xoay khung hình camera so với chiều đứng của màn hình (bù hướng thiết bị và camera trước/sau).
InputImageRotation? cameraImageRotation(CameraDescription camera, CameraController controller) {
  final sensorOrientation = camera.sensorOrientation;
  if (Platform.isIOS) return InputImageRotationValue.fromRawValue(sensorOrientation);

  var compensation = _deviceOrientations[controller.value.deviceOrientation] ?? 0;
  if (camera.lensDirection == CameraLensDirection.front) {
    compensation = (sensorOrientation + compensation) % 360;
  } else {
    compensation = (sensorOrientation - compensation + 360) % 360;
  }
  return InputImageRotationValue.fromRawValue(compensation);
}

/// Chuyển khung hình CameraImage sang InputImage cho Google ML Kit.
InputImage? inputImageFromCameraImage(CameraImage image, CameraDescription camera, CameraController controller) {
  final rotation = cameraImageRotation(camera, controller);
  if (rotation == null) return null;
  return InputImage.fromBytes(
    bytes: _yuv420ToNv21(image),
    metadata: InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: Platform.isAndroid ? InputImageFormat.nv21 : InputImageFormat.bgra8888,
      bytesPerRow: image.planes.first.bytesPerRow,
    ),
  );
}

/// Gộp YUV420 3-plane thành NV21 1-plane (Android). Ảnh đã 1-plane thì giữ nguyên.
Uint8List _yuv420ToNv21(CameraImage image) {
  if (image.planes.length == 1) return image.planes.first.bytes;

  final width = image.width;
  final height = image.height;
  final ySize = width * height;
  final nv21 = Uint8List(ySize + width * height ~/ 2);
  nv21.setRange(0, ySize, image.planes[0].bytes);

  if (image.planes.length >= 3) {
    final uPlane = image.planes[1].bytes;
    final vPlane = image.planes[2].bytes;
    final uvRowStride = image.planes[1].bytesPerRow;
    final uvPixelStride = image.planes[1].bytesPerPixel ?? 2;
    var uvIndex = ySize;
    for (var row = 0; row < height ~/ 2; row++) {
      for (var col = 0; col < width ~/ 2; col++) {
        final p = row * uvRowStride + col * uvPixelStride;
        if (p < vPlane.length && p < uPlane.length && uvIndex + 1 < nv21.length) {
          nv21[uvIndex++] = vPlane[p];
          nv21[uvIndex++] = uPlane[p];
        }
      }
    }
  }
  return nv21;
}
