import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PoseData {
  final Pose? pose;
  final Size imageSize;
  final InputImageRotation rotation;
  final CameraLensDirection cameraLensDirection;
  PoseData({required this.pose, required this.imageSize, required this.rotation, required this.cameraLensDirection});
}

class ExerciseFeedback {
  final int repCount;
  final double qualityScore;
  final List<String> feedbackText;
  final bool isCalibrated;
  ExerciseFeedback({this.repCount = 0, this.qualityScore = 0.0, this.feedbackText = const [], this.isCalibrated = false});
}

class WorkoutSession {
  final DateTime date;
  final String exercise;
  final int reps;
  final double avgQuality;
  WorkoutSession({required this.date, required this.exercise, required this.reps, required this.avgQuality});

  Map<String, dynamic> toJson() => {'date': date.toIso8601String(), 'exercise': exercise, 'reps': reps, 'avgQuality': avgQuality};
  factory WorkoutSession.fromJson(Map<String, dynamic> json) => WorkoutSession(date: DateTime.parse(json['date']), exercise: json['exercise'], reps: json['reps'], avgQuality: json['avgQuality']);
}