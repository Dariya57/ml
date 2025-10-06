import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../models/exercise_data.dart';

class PosePainter extends CustomPainter {
  final PoseData? poseData;
  PosePainter(this.poseData);

  @override
  void paint(Canvas canvas, Size size) {
    final pose = poseData?.pose;
    final imageSize = poseData?.imageSize;
    if (pose == null || imageSize == null) return;

    final paint = Paint()..color = Colors.lightBlueAccent..strokeWidth = 4.0..strokeCap = StrokeCap.round;
    final landmarks = pose.landmarks;

    void drawLine(PoseLandmarkType type1, PoseLandmarkType type2) {
      final p1 = landmarks[type1];
      final p2 = landmarks[type2];
      if (p1 != null && p2 != null) {
        canvas.drawLine(_scalePoint(p1, size, imageSize), _scalePoint(p2, size, imageSize), paint);
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
    if (poseData!.rotation == InputImageRotation.rotation90deg || poseData!.rotation == InputImageRotation.rotation270deg) {
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