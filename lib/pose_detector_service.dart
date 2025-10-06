import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:vector_math/vector_math.dart' as vector;

class PoseData {
  final Pose? pose;
  final Size imageSize;
  final InputImageRotation rotation;
  final CameraLensDirection cameraLensDirection;
  PoseData(
      {required this.pose,
      required this.imageSize,
      required this.rotation,
      required this.cameraLensDirection});
}

class ExerciseFeedback {
  final int repCount;
  final double qualityScore;
  final List<String> feedbackText;
  ExerciseFeedback(
      {this.repCount = 0,
      this.qualityScore = 0.0,
      this.feedbackText = const []});
}

class PoseDetectorService {
  final PoseDetector _poseDetector;
  bool _isProcessing = false;
  String _currentStage = 'up';
  double _lastQualityScore = 0.0;

  final ValueNotifier<ExerciseFeedback> feedbackNotifier =
      ValueNotifier(ExerciseFeedback());
  final ValueNotifier<PoseData?> poseDataNotifier = ValueNotifier(null);

  PoseDetectorService()
      : _poseDetector = PoseDetector(
          options: PoseDetectorOptions(
              model: PoseDetectionModel.accurate,
              mode: PoseDetectionMode.stream),
        );

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

    poseDataNotifier.value = PoseData(
      pose: poses.isNotEmpty ? poses.first : null,
      imageSize: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: inputImage.metadata!.rotation,
      cameraLensDirection: camera.lensDirection,
    );

    if (poses.isNotEmpty) {
      _analyzeSquat(poses.first);
    }

    _isProcessing = false;
  }

  void _analyzeSquat(Pose pose) {
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];

    if (leftShoulder != null &&
        leftHip != null &&
        leftKnee != null &&
        leftAnkle != null) {
      final kneeAngle = _calculateAngle(leftHip, leftKnee, leftAnkle);
      final hipAngle = _calculateAngle(leftShoulder, leftHip, leftKnee);

      double backScore = (hipAngle / 180.0).clamp(0.0, 1.0);
      double depthScore = 0.0;
      final currentFeedback = <String>[];

      if (backScore < 0.9 && _currentStage == 'down') {
        currentFeedback.add("Держи спину прямее!");
      }

      if (kneeAngle < 100) {
        _currentStage = 'down';
        if (leftHip.y < leftKnee.y) {
          depthScore = (leftHip.y / leftKnee.y).clamp(0.5, 1.0);
          currentFeedback.add("Садись глубже!");
        } else {
          depthScore = 1.0;
        }
        _lastQualityScore = (backScore * 60) + (depthScore * 40);
      } else if (kneeAngle > 160 && _currentStage == 'down') {
        _currentStage = 'up';

        feedbackNotifier.value = ExerciseFeedback(
          repCount: feedbackNotifier.value.repCount + 1,
          qualityScore: _lastQualityScore,
          feedbackText: feedbackNotifier.value.feedbackText,
        );
        _lastQualityScore = 0.0;
        return;
      }

      feedbackNotifier.value = ExerciseFeedback(
        repCount: feedbackNotifier.value.repCount,
        qualityScore: feedbackNotifier.value.qualityScore,
        feedbackText: currentFeedback,
      );
    }
  }

  double _calculateAngle(PoseLandmark a, PoseLandmark b, PoseLandmark c) {
    final radians =
        atan2(c.y - b.y, c.x - b.x) - atan2(a.y - b.y, a.x - b.x);
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
    feedbackNotifier.dispose();
    poseDataNotifier.dispose();
  }
}

class PosePainter extends CustomPainter {
  final PoseData? poseData;

  PosePainter(this.poseData);

  @override
  void paint(Canvas canvas, Size size) {
    final pose = poseData?.pose;
    final imageSize = poseData?.imageSize;
    if (pose == null || imageSize == null) return;

    final paint = Paint()
      ..color = Colors.lightBlueAccent
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    final landmarks = pose.landmarks;

    void drawLine(PoseLandmarkType type1, PoseLandmarkType type2) {
      final p1 = landmarks[type1];
      final p2 = landmarks[type2];
      if (p1 != null && p2 != null) {
        canvas.drawLine(
          _scalePoint(p1, size, imageSize),
          _scalePoint(p2, size, imageSize),
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
      canvas.drawCircle(_scalePoint(landmark, size, imageSize), 3.0, paint);
    }
  }

  Offset _scalePoint(PoseLandmark landmark, Size canvasSize, Size imageSize) {
    final double hRatio, vRatio;
    if (poseData!.rotation == InputImageRotation.rotation90deg ||
        poseData!.rotation == InputImageRotation.rotation270deg) {
      hRatio = canvasSize.width / imageSize.height;
      vRatio = canvasSize.height / imageSize.width;
    } else {
      hRatio = canvasSize.width / imageSize.width;
      vRatio = canvasSize.height / imageSize.height;
    }

    double x = landmark.x * hRatio;
    double y = landmark.y * vRatio;

    if (poseData!.cameraLensDirection == CameraLensDirection.front) {
      x = canvasSize.width - x;
    }

    return Offset(x, y);
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) {
    return poseData != oldDelegate.poseData;
  }
}