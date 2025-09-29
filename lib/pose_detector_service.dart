import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class CoordinateTranslator {
  static Offset transform(
      {required PoseLandmark landmark,
      required Size canvasSize,
      required Size imageSize,
      required InputImageRotation rotation,
      required CameraLensDirection cameraLensDirection}) {
    final double x = landmark.x;
    final double y = landmark.y;

    final double hRatio = canvasSize.width /
        (rotation == InputImageRotation.rotation90deg ||
                rotation == InputImageRotation.rotation270deg
            ? imageSize.height
            : imageSize.width);
    final double vRatio = canvasSize.height /
        (rotation == InputImageRotation.rotation90deg ||
                rotation == InputImageRotation.rotation270deg
            ? imageSize.width
            : imageSize.height);

    double scaledX = x * hRatio;
    double scaledY = y * vRatio;

    if (cameraLensDirection == CameraLensDirection.front) {
      scaledX = canvasSize.width - scaledX;
    }

    return Offset(scaledX, scaledY);
  }
}

class PoseDetectorService {
  final PoseDetector _poseDetector;
  final PosePainter painter;
  bool _isProcessing = false;

  String _currentStage = 'up';
  int _squatCount = 0;

  PoseDetectorService(this.painter)
      : _poseDetector = PoseDetector(
          options: PoseDetectorOptions(
            model: PoseDetectionModel.base,
            mode: PoseDetectionMode.stream,
          ),
        );

  int get squatCount => _squatCount;

  Future<void> processImage(
      CameraImage image, CameraDescription camera) async {
    if (_isProcessing) return;
    _isProcessing = true;

    final inputImage = _inputImageFromCameraImage(image, camera);
    if (inputImage == null) {
      _isProcessing = false;
      return;
    }

    final poses = await _poseDetector.processImage(inputImage);
    if (poses.isNotEmpty) {
      painter.update(
        poses.first,
        Size(image.width.toDouble(), image.height.toDouble()),
        inputImage.metadata!.rotation,
        camera.lensDirection,
      );
      _analyzeSquat(poses.first);
    } else {
      painter.clear();
    }

    _isProcessing = false;
  }

  void _analyzeSquat(Pose pose) {
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];

    if (leftHip != null && leftKnee != null && leftAnkle != null) {
      final angle = _calculateAngle(leftHip, leftKnee, leftAnkle);

      if (angle < 100 && _currentStage == 'up') {
        _currentStage = 'down';
      } else if (angle > 160 && _currentStage == 'down') {
        _currentStage = 'up';
        _squatCount++;
      }
    }
  }

  double _calculateAngle(PoseLandmark a, PoseLandmark b, PoseLandmark c) {
    final radians = atan2(c.y - b.y, c.x - b.x) - atan2(a.y - b.y, a.x - b.x);
    double angle = radians.abs() * 180.0 / pi;
    if (angle > 180.0) {
      angle = 360.0 - angle;
    }
    return angle;
  }

  InputImage? _inputImageFromCameraImage(
      CameraImage image, CameraDescription camera) {
    final rotation =
        InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    if (rotation == null) return null;

    return InputImage.fromBytes(
      bytes: image.planes.first.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  void dispose() {
    _poseDetector.close();
  }
}

// PosePainter теперь наследуется от ChangeNotifier, чтобы сообщать об обновлениях
class PosePainter extends CustomPainter with ChangeNotifier {
  Pose? _pose;
  Size? _imageSize;
  InputImageRotation _rotation = InputImageRotation.rotation0deg;
  CameraLensDirection _cameraLensDirection = CameraLensDirection.front;

  void update(Pose pose, Size imageSize, InputImageRotation rotation,
      CameraLensDirection direction) {
    _pose = pose;
    _imageSize = imageSize;
    _rotation = rotation;
    _cameraLensDirection = direction;
    notifyListeners(); // Сообщаем виджету, что нужно перерисоваться
  }

  void clear() {
    _pose = null;
    _imageSize = null;
    notifyListeners();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (_pose == null || _imageSize == null) return;

    final paint = Paint()
      ..color = Colors.lightBlueAccent
      ..strokeWidth = 4.0;

    final landmarks = _pose!.landmarks;

    void drawLine(PoseLandmarkType type1, PoseLandmarkType type2) {
      final p1 = landmarks[type1];
      final p2 = landmarks[type2];
      if (p1 != null && p2 != null) {
        canvas.drawLine(
          CoordinateTranslator.transform(
              landmark: p1,
              canvasSize: size,
              imageSize: _imageSize!,
              rotation: _rotation,
              cameraLensDirection: _cameraLensDirection),
          CoordinateTranslator.transform(
              landmark: p2,
              canvasSize: size,
              imageSize: _imageSize!,
              rotation: _rotation,
              cameraLensDirection: _cameraLensDirection),
          paint,
        );
      }
    }

    drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder);
    drawLine(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip);
    drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip);
    drawLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip);
    drawLine(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee);
    drawLine(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee);
    drawLine(PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle);
    drawLine(PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle);

    for (final landmark in landmarks.values) {
      canvas.drawCircle(
        CoordinateTranslator.transform(
            landmark: landmark,
            canvasSize: size,
            imageSize: _imageSize!,
            rotation: _rotation,
            cameraLensDirection: _cameraLensDirection),
        2.5,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) {
    return true;
  }
}