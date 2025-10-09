import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../services/pose_detector_service.dart';
import '../painters/pose_painter.dart';
import '../models/data_models.dart';
import '../providers/workout_provider.dart';
import 'results_screen.dart';

class WorkoutScreen extends StatefulWidget {
  final int targetReps;
  final ExerciseType exerciseType;
  final String exerciseName;

  const WorkoutScreen({
    super.key, 
    required this.targetReps, 
    required this.exerciseType,
    required this.exerciseName,
  });

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  CameraController? _controller;
  CameraDescription? _camera;
  bool _isInitializing = true;
  late PoseDetectorService _poseDetectorService;

  @override
  void initState() {
    super.initState();
    _poseDetectorService = PoseDetectorService();
    _poseDetectorService.feedbackNotifier.addListener(_onFeedback);
    _poseDetectorService.setExercise(widget.exerciseType);
    _initialize();
  }

  void _onFeedback() {
    final feedback = _poseDetectorService.feedbackNotifier.value;
    if (feedback.repCount >= widget.targetReps) {
      _controller?.stopImageStream();
      final results = _poseDetectorService.getWorkoutResults();
      context.read<WorkoutProvider>().completeWorkout(widget.exerciseName, feedback.repCount, results['avgQuality']);
      
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => ResultsScreen(
          reps: feedback.repCount,
          avgQuality: results['avgQuality'],
          errorCounts: results['errorCounts'],
        )),
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
              return WorkoutOverlay(feedback: feedback, targetReps: widget.targetReps);
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
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'Встаньте так, чтобы вас было видно полностью в кадре',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

class WorkoutOverlay extends StatelessWidget {
  final ExerciseFeedback feedback;
  final int targetReps;
  const WorkoutOverlay({super.key, required this.feedback, required this.targetReps});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        SafeArea(
          child: Align(
            alignment: Alignment.topLeft,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ),
        Text(
          '${feedback.repCount} / $targetReps',
          style: const TextStyle(
            fontSize: 120,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [Shadow(blurRadius: 10.0, color: Colors.black, offset: Offset(2.0, 2.0))],
          ),
        ),
        const SizedBox(height: 120),
      ],
    );
  }
}