import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../services/pose_detector_service.dart';
import '../painters/pose_painter.dart';
import '../models/exercise_data.dart';
import '../providers/workout_provider.dart';
import 'results_screen.dart';

class WorkoutScreen extends StatefulWidget {
  final int targetReps;
  const WorkoutScreen({super.key, required this.targetReps});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  CameraController? _controller;
  CameraDescription? _camera;
  bool _isInitializing = true;
  final PoseDetectorService _poseDetectorService = PoseDetectorService();

  @override
  void initState() {
    super.initState();
    _poseDetectorService.feedbackNotifier.addListener(_onFeedback);
    _initialize();
  }

  void _onFeedback() {
    final feedback = _poseDetectorService.feedbackNotifier.value;
    if (feedback.repCount >= widget.targetReps) {
      _controller?.stopImageStream();
      final avgQuality = _poseDetectorService.getAverageQuality();
      context.read<WorkoutProvider>().completeWorkout('Приседания', feedback.repCount, avgQuality);
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => ResultsScreen(reps: feedback.repCount, avgQuality: avgQuality)),
      );
    }
  }

  Future<void> _initialize() async {
    final cameras = await availableCameras();
    _camera = cameras.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      _camera!,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );

    await _controller!.initialize();
    _controller!.startImageStream((image) {
      if (mounted) {
        _poseDetectorService.processImage(image, _camera!);
      }
    });

    setState(() {
      _isInitializing = false;
    });
  }

  @override
  void dispose() {
    _poseDetectorService.feedbackNotifier.removeListener(_onFeedback);
    _controller?.stopImageStream();
    _controller?.dispose();
    _poseDetectorService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          SizedBox.expand(
            child: CameraPreview(
              _controller!,
              child: ValueListenableBuilder<PoseData?>(
                valueListenable: _poseDetectorService.poseDataNotifier,
                builder: (context, poseData, child) {
                  return CustomPaint(painter: PosePainter(poseData));
                },
              ),
            ),
          ),
          ValueListenableBuilder<ExerciseFeedback>(
            valueListenable: _poseDetectorService.feedbackNotifier,
            builder: (context, feedback, child) {
              if (!feedback.isCalibrated) {
                return const CalibrationOverlay();
              }
              return WorkoutOverlay(feedback: feedback);
            },
          )
        ],
      ),
    );
  }
}

class CalibrationOverlay extends StatelessWidget {
  const CalibrationOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: const Center(
        child: Text(
          'Встаньте так, чтобы вас было видно полностью',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class WorkoutOverlay extends StatelessWidget {
  final ExerciseFeedback feedback;
  const WorkoutOverlay({super.key, required this.feedback});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const SizedBox(),
        Text(
          '${feedback.repCount}',
          style: const TextStyle(
            fontSize: 150,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [Shadow(blurRadius: 10.0, color: Colors.black, offset: Offset(2.0, 2.0))],
          ),
        ),
        if (feedback.feedbackText.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            margin: const EdgeInsets.only(bottom: 80),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              feedback.feedbackText.join('\n'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          )
        else
          const SizedBox(height: 80),
      ],
    );
  }
}