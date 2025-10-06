import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import '../models/exercise_data.dart';

class PoseDetectorService {
  final PoseDetector _poseDetector;
  bool _isProcessing = false;
  String _currentStage = 'up';
  double _lastQualityScore = 0.0;
  bool _isCalibrated = false;
  final List<double> _qualityScores = [];

  final ValueNotifier<ExerciseFeedback> feedbackNotifier = ValueNotifier(ExerciseFeedback());
  final ValueNotifier<PoseData?> poseDataNotifier = ValueNotifier(null);

  PoseDetectorService()
      : _poseDetector = PoseDetector(
          options: PoseDetectorOptions(model: PoseDetectionModel.accurate, mode: PoseDetectionMode.stream),
        );

  Future<void> processImage(CameraImage image, CameraDescription camera) async {
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
      if (!_isCalibrated) {
        _calibrate(poses.first);
      } else {
        _analyzeSquat(poses.first);
      }
    }
    _isProcessing = false;
  }

  void _calibrate(Pose pose) {
    final requiredLandmarks = [
      PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftHip, PoseLandmarkType.rightHip,
      PoseLandmarkType.leftKnee, PoseLandmarkType.rightKnee,
      PoseLandmarkType.leftAnkle, PoseLandmarkType.rightAnkle,
    ];
    bool allVisible = requiredLandmarks.every((type) => (pose.landmarks[type]?.likelihood ?? 0) > 0.5);
    _isCalibrated = allVisible;
    feedbackNotifier.value = ExerciseFeedback(isCalibrated: _isCalibrated);
  }

  void _analyzeSquat(Pose pose) {
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];

    if (leftShoulder != null && leftHip != null && leftKnee != null && leftAnkle != null) {
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
        _qualityScores.add(_lastQualityScore);
        feedbackNotifier.value = ExerciseFeedback(
          repCount: feedbackNotifier.value.repCount + 1,
          qualityScore: _lastQualityScore,
          feedbackText: [],
          isCalibrated: _isCalibrated,
        );
        _lastQualityScore = 0.0;
        return;
      }
      feedbackNotifier.value = ExerciseFeedback(
        repCount: feedbackNotifier.value.repCount,
        qualityScore: feedbackNotifier.value.qualityScore,
        feedbackText: currentFeedback,
        isCalibrated: _isCalibrated,
      );
    }
  }

  double getAverageQuality() {
    if (_qualityScores.isEmpty) return 0.0;
    return _qualityScores.reduce((a, b) => a + b) / _qualityScores.length;
  }

  double _calculateAngle(PoseLandmark a, PoseLandmark b, PoseLandmark c) {
    final radians = atan2(c.y - b.y, c.x - b.x) - atan2(a.y - b.y, a.x - b.x);
    double angle = radians.abs() * 180.0 / pi;
    if (angle > 180.0) angle = 360.0 - angle;
    return angle;
  }

  InputImage? _inputImageFromCameraImage(CameraImage image, CameraDescription camera) {
    final rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation);
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