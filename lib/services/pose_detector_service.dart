import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import '../models/data_models.dart';

class PoseDetectorService {
  final PoseDetector _poseDetector;
  bool _isProcessing = false;
  String _currentStage = 'up';
  bool _isCalibrated = false;
  final List<double> _qualityScores = [];
  final List<String> _errorLog = [];
  
  late ExerciseType _currentExercise;

  final ValueNotifier<ExerciseFeedback> feedbackNotifier = ValueNotifier(ExerciseFeedback());
  final ValueNotifier<PoseData?> poseDataNotifier = ValueNotifier(null);

  PoseDetectorService()
      : _poseDetector = PoseDetector(
          options: PoseDetectorOptions(model: PoseDetectionModel.accurate, mode: PoseDetectionMode.stream),
        );

  void setExercise(ExerciseType exercise) {
    _currentExercise = exercise;
    _currentStage = exercise == ExerciseType.crunches ? 'down' : 'up';
    _qualityScores.clear();
    _errorLog.clear();
    feedbackNotifier.value = ExerciseFeedback(isCalibrated: feedbackNotifier.value.isCalibrated);
  }

  Future<void> processImage(CameraImage image, CameraDescription camera) async {
    if (_isProcessing) return;
    _isProcessing = true;
    final inputImage = _inputImageFromCameraImage(image, camera);
    if (inputImage == null) {
      _isProcessing = false; return;
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
        _analyzePose(poses.first);
      }
    }
    _isProcessing = false;
  }
  
  void _analyzePose(Pose pose) {
    switch (_currentExercise) {
      case ExerciseType.squats: _analyzeSquat(pose); break;
      case ExerciseType.pushups: _analyzePushup(pose); break;
      case ExerciseType.crunches: _analyzeCrunch(pose); break;
    }
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
    feedbackNotifier.value = ExerciseFeedback(isCalibrated: _isCalibrated, repCount: feedbackNotifier.value.repCount);
  }

  void _analyzeSquat(Pose pose) {
    final landmarks = pose.landmarks;
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final leftKnee = landmarks[PoseLandmarkType.leftKnee];
    final leftAnkle = landmarks[PoseLandmarkType.leftAnkle];

    if (leftShoulder != null && leftHip != null && leftKnee != null && leftAnkle != null) {
      final kneeAngle = _calculateAngle(leftHip, leftKnee, leftAnkle);
      final hipAngle = _calculateAngle(leftShoulder, leftHip, leftKnee);

      if (kneeAngle < 100 && _currentStage == 'up') {
        _currentStage = 'down';
        double backScore = (hipAngle / 180.0).clamp(0.0, 1.0);
        double depthScore = (leftHip.y >= leftKnee.y) ? 1.0 : (leftHip.y / leftKnee.y).clamp(0.5, 1.0);
        if (backScore < 0.9) _errorLog.add("Спина была согнута");
        if (depthScore < 1.0) _errorLog.add("Присед был неглубоким");
        _qualityScores.add((backScore * 60) + (depthScore * 40));
      } else if (kneeAngle > 160 && _currentStage == 'down') {
        _currentStage = 'up';
        feedbackNotifier.value = ExerciseFeedback(
          repCount: feedbackNotifier.value.repCount + 1,
          isCalibrated: _isCalibrated,
        );
      }
    }
  }
  
  void _analyzePushup(Pose pose) {
    final landmarks = pose.landmarks;
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final leftElbow = landmarks[PoseLandmarkType.leftElbow];
    final leftWrist = landmarks[PoseLandmarkType.leftWrist];
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final leftKnee = landmarks[PoseLandmarkType.leftKnee];

    if (leftShoulder != null && leftElbow != null && leftWrist != null && leftHip != null && leftKnee != null) {
      final elbowAngle = _calculateAngle(leftShoulder, leftElbow, leftWrist);
      final bodyAngle = _calculateAngle(leftShoulder, leftHip, leftKnee);
      
      if (elbowAngle < 90 && _currentStage == 'up') {
        _currentStage = 'down';
        double bodyScore = (bodyAngle / 180.0).clamp(0.0, 1.0);
        if (bodyScore < 0.9) _errorLog.add("Держи тело прямым!");
        _qualityScores.add(bodyScore * 100);
      } else if (elbowAngle > 160 && _currentStage == 'down') {
        _currentStage = 'up';
        feedbackNotifier.value = ExerciseFeedback(
          repCount: feedbackNotifier.value.repCount + 1,
          isCalibrated: _isCalibrated,
        );
      }
    }
  }

  void _analyzeCrunch(Pose pose) {
    final landmarks = pose.landmarks;
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final leftKnee = landmarks[PoseLandmarkType.leftKnee];
    final leftWrist = landmarks[PoseLandmarkType.leftWrist];
    final leftEar = landmarks[PoseLandmarkType.leftEar];

    if (leftShoulder != null && leftHip != null && leftKnee != null && leftWrist != null && leftEar != null) {
      final hipAngle = _calculateAngle(leftShoulder, leftHip, leftKnee);
      
      if (hipAngle < 135 && _currentStage == 'down') {
        _currentStage = 'up';
        double handMovementScore = 1.0;
        final handHeadDistance = sqrt(pow(leftWrist.x - leftEar.x, 2) + pow(leftWrist.y - leftEar.y, 2));
        if (handHeadDistance > 0.15) { 
          handMovementScore = 0.5;
          _errorLog.add("Руки отрываются от головы");
        }
        _qualityScores.add(handMovementScore * 100);
      } else if (hipAngle > 150 && _currentStage == 'up') {
        _currentStage = 'down';
        feedbackNotifier.value = ExerciseFeedback(
          repCount: feedbackNotifier.value.repCount + 1,
          isCalibrated: _isCalibrated,
        );
      }
    }
  }

  Map<String, dynamic> getWorkoutResults() {
    double avgQuality = 0;
    if (_qualityScores.isNotEmpty) {
      avgQuality = _qualityScores.reduce((a, b) => a + b) / _qualityScores.length;
    }
    Map<String, int> errorCounts = {};
    for (var error in _errorLog) {
      errorCounts[error] = (errorCounts[error] ?? 0) + 1;
    }
    return {'avgQuality': avgQuality, 'errorCounts': errorCounts};
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